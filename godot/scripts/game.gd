extends RefCounted

const Rules = preload("res://scripts/rules.gd")
const Opponent = preload("res://scripts/opponent.gd")

var players: Array = []
var wall: Array = []
var _wall_size := 0
var _wall_slots: Array = []
var _wall_opening: Array = []
var _wall_takes: Array = []
var scores := [0, 0, 0, 0]
var dealer := 0
var current := 0
var round_number := 1
var round_limit := 15
var luck := "normal"
var gold := -1
var indicator := -1
var drawn := -1
var can_self_win := true
var phase := "turn"
var last_discard := {}
var pending := {}
var latest := {}
var result := {}
var revision := 0
var action_revision := 0
var gold_dice: Array = []
var gold_index := -1
var dealer_rolls: Dictionary = {}
var deal_flowers: Array = []
var deal_initial_hands: Array = []
var deal_draws: Array = []
var last_flowers: Array = []
var flower_revision := 0
var _online := false
var _claim_serial := 0
var _passed_claims: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _dice_rng := RandomNumberGenerator.new()
var _next_gold_dice: Array = []


func _init(seed_value := -1, rounds := 15, luck_setting := "normal", online := false, dealer_seat := 0) -> void:
	round_limit = clampi(rounds, 1, 32)
	_online = online
	dealer = posmod(dealer_seat, 4)
	luck = luck_setting if not _online and luck_setting in ["unlucky", "lucky"] else "normal"
	if seed_value < 0:
		_rng.randomize()
		_dice_rng.randomize()
	else:
		_rng.seed = seed_value
		_dice_rng.seed = seed_value + 104729
	start_round()


func set_next_gold_dice(dice: Array) -> void:
	_next_gold_dice = dice.duplicate()


func start_round() -> void:
	action_revision += 1
	if _next_gold_dice.size() == 2:
		gold_dice = _next_gold_dice.duplicate()
		_next_gold_dice = []
	else:
		gold_dice = [_dice_rng.randi_range(1, 6), _dice_rng.randi_range(1, 6)]
	deal(Rules.make_wall(_rng))
	if luck != "normal":
		var best := opening_deal()
		var best_score := Opponent.opening_value(players[0].hand, gold, dealer == 0)
		for candidate in range(4):
			deal(Rules.make_wall(_rng))
			var value := Opponent.opening_value(players[0].hand, gold, dealer == 0)
			if (luck == "lucky" and value > best_score) or (luck == "unlucky" and value < best_score):
				best = opening_deal()
				best_score = value
		players = best.players
		wall = best.wall
		_wall_size = best.wall_size
		_wall_slots = best.wall_slots
		_wall_opening = best.wall_opening
		gold = best.gold
		indicator = best.indicator
		gold_index = best.gold_index
		deal_initial_hands = best.initial_hands
		deal_flowers = best.flowers
		deal_draws = best.draws
	last_discard = {}
	_passed_claims = [{}, {}, {}, {}]
	pending = {}
	result = {}
	current = dealer
	drawn = -1
	can_self_win = true
	note("start", dealer)
	open_claims("heaven")


func opening_deal() -> Dictionary:
	return {"players": players, "wall": wall, "gold": gold, "indicator": indicator, "gold_index": gold_index,
		"wall_size": _wall_size, "wall_slots": _wall_slots, "wall_opening": _wall_opening,
		"initial_hands": deal_initial_hands, "flowers": deal_flowers, "draws": deal_draws}


func _reset_wall_geometry() -> void:
	_wall_size = wall.size()
	_wall_slots = range(_wall_size)
	_wall_opening = []
	_wall_takes = []


func _take_wall(index: int, seat: int, kind: String, end: String, events: Array) -> int:
	events.append({"slot": _wall_slots.pop_at(index), "seat": seat, "kind": kind, "end": end})
	return wall.pop_at(index)


func _wall_view() -> Dictionary:
	if _wall_slots.size() != wall.size():
		return {"size": wall.size(), "slots": range(wall.size()), "opening": [], "takes": []}
	return {"size": _wall_size, "slots": _wall_slots.duplicate(),
		"opening": _wall_opening.duplicate(true), "takes": _wall_takes.duplicate(true)}


func deal(shuffled: Array) -> void:
	wall = shuffled
	_reset_wall_geometry()
	players = []
	for seat in range(4):
		players.append({"hand": [], "melds": [], "flowers": [], "river": [], "discarded_gold": false,
			"lock_discards": [], "locked": false, "gold_gap": []})
	var order := Rules.order_from(dealer)
	for index in range(16):
		for seat in order:
			players[seat].hand.append(_take_wall(0, seat, "deal", "head", _wall_opening))
	players[dealer].hand.append(_take_wall(0, dealer, "deal", "head", _wall_opening))
	deal_initial_hands = players.map(func(player): return player.hand.duplicate())
	deal_draws = []
	if wall.is_empty():
		indicator = -1
		gold = -1
		gold_index = -1
	else:
		var sum := 2
		if gold_dice.size() == 2:
			sum = int(gold_dice[0]) + int(gold_dice[1])
		gold_index = posmod(wall.size() - 1 - 2 * (sum - 1), wall.size())
		indicator = _take_wall(gold_index, -1, "gold", "indicator", _wall_opening)
		gold = indicator
	for player in players:
		player.flowers = player.hand.filter(func(tile): return Rules.is_flower(tile, gold))
		player.hand = player.hand.filter(func(tile): return not Rules.is_flower(tile, gold))

	deal_flowers = []
	for seat in order:
		for tile in players[seat].flowers:
			deal_flowers.append({"round": 0, "seat": seat, "tile": tile})

	var flower_debts := players.map(func(player): return player.flowers.size())
	var flower_round := 0
	while flower_debts.any(func(count): return count > 0):
		flower_round += 1
		var next_debts := [0, 0, 0, 0]
		for seat in order:
			for count in range(flower_debts[seat]):
				var tile := _take_wall(-1, seat, "replacement", "tail", _wall_opening)
				var flower := Rules.is_flower(tile, gold)
				var take: Dictionary = _wall_opening.back()
				take.round = flower_round
				if flower:
					take.kind = "flower"
				deal_draws.append({"round": flower_round, "seat": seat, "tile": tile, "flower": flower, "slot": take.slot})
				if flower:
					players[seat].flowers.append(tile)
					deal_flowers.append({"round": flower_round, "seat": seat, "tile": tile})
					next_debts[seat] += 1
				else:
					players[seat].hand.append(tile)
		flower_debts = next_debts
	last_flowers = []

func next_round() -> bool:
	if phase != "result" or is_table_finished():
		return false
	if result.winner >= 0 and result.winner != dealer:
		dealer = (dealer + 1) % 4
	round_number += 1
	start_round()
	return true


func is_table_finished() -> bool:
	return phase == "result" and round_number >= round_limit


func standings() -> Array:
	var seats := [0, 1, 2, 3]
	seats.sort_custom(func(a, b): return a < b if scores[a] == scores[b] else scores[a] > scores[b])
	var rows := []
	var rank := 1
	for index in range(seats.size()):
		var seat: int = seats[index]
		if index > 0 and scores[seat] != scores[seats[index - 1]]:
			rank = index + 1
		rows.append({"seat": seat, "rank": rank, "score": scores[seat]})
	return rows


func note(kind: String, seat: int, tile := -1) -> void:
	revision += 1
	latest = {"type": kind, "seat": seat, "tile": tile, "revision": revision}


static func action(kind: String, data := {}) -> Dictionary:
	var id := kind
	for key in ["kind", "tile", "tiles"]:
		if data.has(key):
			id += ":" + str(data[key])
	var move := {"type": kind, "id": id}
	move.merge(data)
	return move


func open_claims(kind: String) -> void:
	var order := Rules.order_from((dealer + 1) % 4 if kind == "grab" else dealer)
	var offers := {}
	for seat in order:
		var hand: Array = players[seat].hand
		var moves: Array = []
		if kind == "heaven" and seat == dealer and Rules.winning(hand, 0, gold):
			moves.append(action("win", {"kind": kind}))
		elif kind == "three" and Rules.gold_count(hand, gold) >= 3:
			moves.append(action("win", {"kind": kind}))
		elif kind == "grab":
			if seat == dealer:
				for tile in Rules.unique(hand):
					var changed := hand.duplicate()
					changed.erase(tile)
					changed.append(gold)
					if Rules.winning(changed, 0, gold):
						moves.append(action("win", {"kind": kind, "tile": tile}))
			elif Rules.winning(hand + [gold], 0, gold):
				moves.append(action("win", {"kind": kind}))
		if not moves.is_empty():
			offers[seat] = moves
	if begin_claims("opening", order, offers, {"kind": kind}):
		return
	if kind == "heaven":
		open_claims("three")
	elif kind == "three":
		open_claims("grab")
	else:
		phase = "turn"


func begin_claims(stage: String, order: Array, offers: Dictionary, details: Dictionary) -> bool:
	if offers.is_empty():
		return false
	var eligible := order.filter(func(seat): return offers.has(seat))
	phase = stage
	pending = {"eligible": eligible, "replies": {}, "options": offers}
	pending.merge(details)
	if _uses_ordered_claims():
		if not _online:
			_claim_serial += 1
			for seat in eligible:
				for move in offers[seat]:
					move.id += "@%d" % _claim_serial
		_offer_next_claim()
		return true
	_claim_serial += 1
	for seat in eligible:
		offers[seat].append(action("pass"))
		for move in offers[seat]:
			move.id += "@%d" % _claim_serial
	return true


func _uses_ordered_claims() -> bool:
	return _online or phase in ["opening", "robKong"]


func claim_rank(seat: int, move: Dictionary) -> int:
	var priority: int = Rules.PRIORITY[move.type]
	if priority == 0:
		return 0
	var order_bonus: int = 3 - pending.eligible.find(seat)
	if move.type == "win":
		return Rules.win_rank(move.get("pattern", move.kind)) * 8 + order_bonus
	return priority * 4 + order_bonus


func _offer_next_claim() -> void:
	var actor := -1
	var highest := 0
	var other_highest := 0
	for seat in pending.eligible:
		var seat_highest := 0
		for move in pending.options[seat]:
			seat_highest = maxi(seat_highest, claim_rank(seat, move))
		if seat_highest > highest:
			actor = seat
			other_highest = highest
			highest = seat_highest
		else:
			other_highest = maxi(other_highest, seat_highest)
	if actor < 0:
		_resolve_claim(-1, {})
		return
	pending.actor = actor
	pending.offered = pending.options[actor].filter(func(move): return claim_rank(actor, move) > other_highest)


func online_actor() -> int:
	if phase == "turn":
		return current
	if phase in ["opening", "reaction", "robKong"]:
		return pending.get("actor", -1)
	return -1


func online_timeout_action() -> Dictionary:
	var choices := actions(online_actor())
	if phase != "turn":
		return choices.back() if not choices.is_empty() else {}
	var fallback := {}
	for move in choices:
		if move.type != "discard":
			continue
		if move.tile == drawn and not Rules.is_gold(move.tile, gold):
			return move
		if fallback.is_empty() or (Rules.is_gold(fallback.tile, gold) and not Rules.is_gold(move.tile, gold)):
			fallback = move
	return fallback


func human_claims() -> Array:
	if pending.replies.has(0) or not pending.options.has(0):
		return []
	var decided := 0
	var possible := 0
	for seat in pending.eligible:
		if seat == 0:
			continue
		if pending.replies.has(seat):
			decided = maxi(decided, claim_rank(seat, pending.replies[seat]))
		else:
			for move in pending.options[seat]:
				possible = maxi(possible, claim_rank(seat, move))
	var available: Array = []
	for move in pending.options[0]:
		var rank := claim_rank(0, move)
		if rank <= decided:
			continue
		if rank < possible:
			return []
		available.append(move)
	if not available.is_empty():
		available.append(pending.options[0].back())
	return available


func advance_claims() -> void:
	if pending.options.has(0) and not pending.replies.has(0):
		var best := 0
		for seat in pending.replies:
			best = maxi(best, claim_rank(seat, pending.replies[seat]))
		if pending.options[0].all(func(move): return claim_rank(0, move) <= best):
			pending.replies[0] = pending.options[0].back()
	if pending.replies.size() == pending.eligible.size():
		resolve_claims()


func win_kind(seat: int, incoming := -1) -> String:
	var player: Dictionary = players[seat]
	var hand: Array = player.hand
	var meld_count: int = player.melds.size()
	var self_draw := incoming < 0
	if not player.gold_gap.is_empty():
		return ""
	if not self_draw and (player.discarded_gold or Rules.idle_gold(hand, meld_count, gold)):
		return ""
	if self_draw and Rules.gold_count(hand, gold) >= 3:
		return "three"
	var full := hand if self_draw else hand + [incoming]
	if Rules.winning(full, meld_count, gold):
		return "self" if self_draw else "discard"
	return ""


func win_pattern(seat: int, hand: Array, incoming: int, method: String) -> String:
	var player: Dictionary = players[seat]
	var full: Array = hand if incoming < 0 else hand + [incoming]
	var idle := false
	if method == "self" and drawn >= 0 and not Rules.is_gold(drawn, gold):
		var prior: Array = hand.duplicate()
		prior.erase(drawn)
		idle = Rules.idle_gold(prior, player.melds.size(), gold)
	var base: int = Rules.base_value(full, player.flowers, player.melds, gold, seat, dealer).base
	return Rules.best_pattern(full, player.melds, gold, method, base, idle)


func listening_discards(hand: Array, open_count: int) -> Array:
	var options := []
	for discard_tile in Rules.unique(hand):
		var remainder := hand.duplicate()
		remainder.erase(discard_tile)
		# A gold can stand in for any structural wait without checking hidden tiles.
		if Rules.winning(remainder + [gold], open_count, gold):
			options.append(discard_tile)
	return options


func actions(seat: int) -> Array:
	var options := _action_options(seat)
	if not _online:
		return options
	var stamped: Array = []
	for move in options:
		var option: Dictionary = move.duplicate(true)
		option.id += "@%d" % action_revision
		stamped.append(option)
	return stamped


func _action_options(seat: int) -> Array:
	if phase in ["opening", "reaction", "robKong"]:
		if _uses_ordered_claims():
			if seat != online_actor():
				return []
			var pass_move := action("pass")
			if not _online:
				pass_move.id += "@%d" % _claim_serial
			return pending.offered + [pass_move]
		if seat == 0:
			return human_claims()
		return [] if pending.replies.has(seat) else pending.options.get(seat, [])
	if phase != "turn" or current != seat:
		return []
	var player: Dictionary = players[seat]
	var hand: Array = player.hand
	var options: Array = []
	var kind := win_kind(seat) if can_self_win and drawn >= 0 else ""
	if not kind.is_empty():
		var win_move := action("win", {"kind": kind})
		win_move.pattern = win_pattern(seat, hand, -1, kind)
		options.append(win_move)
	if can_self_win and player.gold_gap.is_empty() and wall.size() > Rules.RESERVE:
		var counts := Rules.counts(hand)
		for tile in range(Rules.NUMBERED):
			if Rules.is_gold(tile, gold):
				continue
			if counts[tile] == 4:
				options.append(action("concealedKong", {"tile": tile}))
			if counts[tile] > 0 and player.melds.any(func(meld): return meld.type == "pong" and meld.tiles[0] == tile):
				options.append(action("addedKong", {"tile": tile}))
	var sorted: Array
	if player.locked or not player.gold_gap.is_empty():
		sorted = [drawn] if drawn >= 0 and drawn in hand else []
	elif not player.lock_discards.is_empty():
		sorted = player.lock_discards.duplicate()
	else:
		sorted = Rules.unique(hand)
	sorted.sort()
	for tile in sorted:
		options.append(action("discard", {"tile": tile}))
	if (not player.locked and player.lock_discards.is_empty() and player.gold_gap.is_empty()
			and gold >= 0 and gold < Rules.NUMBERED and gold % 9 not in [0, 8]):
		var gap := [gold - 1, gold + 1]
		if gap.all(func(tile): return tile in hand):
			for tile in sorted:
				var remainder := hand.duplicate()
				remainder.erase(tile)
				if Rules.gold_gap(remainder, player.melds.size(), gold, gap):
					options.append(action("declareGoldGap", {"tile": tile, "tiles": gap}))
	return options


func reaction_actions(seat: int, source: int, tile: int) -> Array:
	if Rules.is_gold(tile, gold):
		return []
	var options: Array = []
	var blocked: Array = _passed_claims[seat].get(tile, [])
	var kind := "" if "win" in blocked else win_kind(seat, tile)
	if not kind.is_empty():
		var win_move := action("win", {"kind": kind})
		win_move.pattern = win_pattern(seat, players[seat].hand, tile, kind)
		options.append(win_move)
	var player: Dictionary = players[seat]
	if player.locked or not player.gold_gap.is_empty():
		return options
	var is_upstream := seat == (source + 1) % 4
	var restricted := (seat == posmod(dealer - 1, 4) and not is_upstream
		and Rules.gold_count(player.hand, gold) == 0)
	var counts := Rules.counts(player.hand)
	if counts[tile] >= 2 and "pong" not in blocked:
		var pong := {"tile": tile, "tiles": [tile, tile]}
		if restricted:
			var remainder: Array = player.hand.duplicate()
			remainder.erase(tile)
			remainder.erase(tile)
			var discards := listening_discards(remainder, player.melds.size() + 1)
			if not discards.is_empty():
				pong.discards = discards
				options.append(action("pong", pong))
		else:
			options.append(action("pong", pong))
	if not restricted and counts[tile] >= 3 and wall.size() > Rules.RESERVE:
		options.append(action("kong", {"tile": tile, "tiles": [tile, tile, tile]}))
	if not is_upstream:
		return options
	var suit_start := tile - tile % 9
	for start in range(maxi(tile - 2, suit_start), mini(tile, suit_start + 6) + 1):
		var tiles := [start, start + 1, start + 2]
		tiles.erase(tile)
		if tiles.all(func(other): return not Rules.is_gold(other, gold) and counts[other] > 0):
			options.append(action("chow", {"tile": tile, "tiles": tiles}))
	return options


func act(seat: int, id: String) -> bool:
	var offered := actions(seat)
	for move in offered:
		if move.id != id:
			continue
		action_revision += 1
		if phase == "reaction" and move.type == "pass":
			var blocked: Array = _passed_claims[seat].get(pending.tile, [])
			for option in offered:
				if option.type in ["pong", "win"] and option.type not in blocked:
					blocked.append(option.type)
			if not blocked.is_empty():
				_passed_claims[seat][pending.tile] = blocked
		if phase in ["opening", "reaction", "robKong"]:
			if _uses_ordered_claims():
				if move.type == "pass":
					pending.options[seat] = pending.options[seat].filter(func(candidate): return not pending.offered.has(candidate))
					_offer_next_claim()
				else:
					_resolve_claim(seat, move)
			else:
				pending.replies[seat] = move
				advance_claims()
		elif move.type == "discard":
			discard(seat, move.tile)
		elif move.type == "declareGoldGap":
			players[seat].gold_gap = move.tiles.duplicate()
			discard(seat, move.tile, true)
		elif move.type == "win":
			finish_win(seat, -1, move.kind)
		elif move.type == "addedKong":
			open_rob_kong(seat, move)
		else:
			self_kong(seat, move)
		return true
	return false


func discard(seat: int, tile: int, declare_gap := false) -> void:
	var player: Dictionary = players[seat]
	player.hand.erase(tile)
	player.river.append(tile)
	if not player.lock_discards.is_empty():
		player.locked = true
		player.lock_discards = []
	if Rules.is_gold(tile, gold):
		player.discarded_gold = true
	drawn = -1
	last_discard = {"seat": seat, "tile": tile}
	note("discard", seat, tile)
	if declare_gap:
		latest.gold_gap = true
	var next_seat := (seat + 1) % 4
	var order := Rules.order_from(next_seat).slice(0, 3)
	var offers := {}
	for other in order:
		var choices := reaction_actions(other, seat, tile)
		if not choices.is_empty():
			offers[other] = choices
	if not begin_claims("reaction", order, offers, {"from": seat, "tile": tile}):
		draw_tile(next_seat, false)


func resolve_claims() -> void:
	var winner := -1
	var best := 0
	for seat in pending.eligible:
		var rank := claim_rank(seat, pending.replies[seat])
		if rank > best:
			winner = seat
			best = rank
	_resolve_claim(winner, pending.replies.get(winner, {}))


func _resolve_claim(winner: int, move: Dictionary) -> void:
	var decided := pending
	pending = {}
	if phase == "opening":
		var kind: String = decided.kind
		if winner < 0:
			if kind == "heaven":
				open_claims("three")
			elif kind == "three":
				open_claims("grab")
			else:
				phase = "turn"
			return
		if kind == "grab":
			if winner == dealer:
				var discarded: int = move.tile
				players[winner].hand.erase(discarded)
				players[winner].river.append(discarded)
			players[winner].hand.append(indicator)
			indicator = -1
		finish_win(winner, -1, kind)
		return

	var source: int = decided.from
	var tile: int = decided.tile
	if phase == "robKong":
		if winner < 0:
			self_kong(source, decided.kong_move)
		else:
			players[source].hand.erase(tile)
			players[winner].hand.append(tile)
			finish_win(winner, source, "rob")
		return
	if winner < 0:
		draw_tile((source + 1) % 4, false)
		return
	players[source].river.pop_back()
	last_discard = {}
	var player: Dictionary = players[winner]
	if move.type == "win":
		player.hand.append(tile)
		finish_win(winner, source, move.kind)
		return
	for own_tile in move.tiles:
		player.hand.erase(own_tile)
	var tiles: Array = move.tiles + [tile]
	tiles.sort()
	player.melds.append({"type": move.type, "tiles": tiles, "from": source, "claimed": tile})
	if move.has("discards"):
		player.lock_discards = move.discards.duplicate()
	note(move.type, winner, tile)
	if move.type == "kong":
		draw_tile(winner, true)
	else:
		current = winner
		phase = "turn"
		can_self_win = false


func open_rob_kong(seat: int, move: Dictionary) -> void:
	var order := Rules.order_from((seat + 1) % 4).slice(0, 3)
	var offers := {}
	for other in order:
		if not win_kind(other, move.tile).is_empty():
			var rob := action("win", {"kind": "rob"})
			rob.pattern = win_pattern(other, players[other].hand, move.tile, "rob")
			offers[other] = [rob]
	if not begin_claims("robKong", order, offers, {"from": seat, "tile": move.tile, "kong_move": move}):
		self_kong(seat, move)


func self_kong(seat: int, move: Dictionary) -> void:
	var tile: int = move.tile
	var player: Dictionary = players[seat]
	if move.type == "concealedKong":
		for index in range(4):
			player.hand.erase(tile)
		player.melds.append({"type": move.type, "tiles": [tile, tile, tile, tile], "from": seat})
	else:
		player.hand.erase(tile)
		for meld in player.melds:
			if meld.type == "pong" and meld.tiles[0] == tile:
				meld.type = move.type
				meld.tiles.append(tile)
				break
	note(move.type, seat, -1 if move.type == "concealedKong" else tile)
	draw_tile(seat, true)


func draw_tile(seat: int, supplement: bool) -> void:
	var player: Dictionary = players[seat]
	if _wall_slots.size() != wall.size():
		_reset_wall_geometry()
	if wall.size() > Rules.RESERVE:
		_passed_claims[seat].clear()
	last_flowers = []
	var flower_round := 0
	while wall.size() > Rules.RESERVE:
		var tile := _take_wall(-1 if supplement else 0, seat, "draw",
			"tail" if supplement else "head", _wall_takes)
		if not Rules.is_flower(tile, gold):
			player.hand.append(tile)
			current = seat
			phase = "turn"
			can_self_win = true
			drawn = tile
			if Rules.is_gold(tile, gold) and (player.locked or not player.gold_gap.is_empty()):
				var previous := latest
				finish_win(seat, -1, "goldGap" if not player.gold_gap.is_empty() else "self")
				if previous.type == "discard" or Rules.MELD_NAMES.has(previous.type):
					latest.previous = previous
			if not last_flowers.is_empty():
				flower_revision += 1
			return
		_wall_takes.back().kind = "flower"
		flower_round += 1
		player.flowers.append(tile)
		last_flowers.append({"round": flower_round, "seat": seat, "tile": tile})
		supplement = true
	if not last_flowers.is_empty():
		flower_revision += 1
	finish({"kind": "draw", "winner": -1, "from": -1, "deltas": [0, 0, 0, 0]})


func finish_win(winner: int, source: int, kind: String) -> void:
	var player: Dictionary = players[winner]
	var idle := false
	if kind == "self" and drawn >= 0 and not Rules.is_gold(drawn, gold):
		var prior: Array = player.hand.duplicate()
		prior.erase(drawn)
		idle = Rules.idle_gold(prior, player.melds.size(), gold)
	finish(Rules.score(winner, source, kind, player.hand, player.flowers, player.melds, gold, dealer, idle))


func finish(settlement: Dictionary) -> void:
	result = settlement
	for seat in range(4):
		scores[seat] += result.deltas[seat]
	phase = "result"
	if result.winner >= 0:
		note("win", result.winner)


func view(seat: int) -> Dictionary:
	var public_players: Array = []
	var reveal := phase == "result"
	for other in range(4):
		var player: Dictionary = players[other]
		var shown: Dictionary = {
			"count": player.hand.size(), "river": player.river.duplicate(),
			"flowers": player.flowers.duplicate(), "melds": player.melds.duplicate(true),
			"discarded_gold": player.discarded_gold, "gold_gap": player.gold_gap.duplicate(),
		}
		if other == seat or reveal:
			shown.hand = player.hand.duplicate()
		else:
			for meld in shown.melds:
				if meld.type == "concealedKong":
					meld.tiles = [-1, -1, -1, -1]
		public_players.append(shown)
	var sees_claim: bool = phase in ["opening", "robKong"] and online_actor() == seat
	var visible_draws: Array = []
	for draw in deal_draws:
		if int(draw.seat) == seat or bool(draw.flower):
			visible_draws.append(draw)
	return {
		"seat": seat, "dealer": dealer, "round": round_number, "gold": gold, "indicator": indicator,
		"round_limit": round_limit, "table_finished": is_table_finished(),
		"scores": scores.duplicate(), "current": current, "phase": phase, "remaining": maxi(0, wall.size() - Rules.RESERVE),
		"wall": _wall_view(),
		"opening": pending.get("kind", "") if sees_claim else "",
		"rob_tile": pending.tile if phase == "robKong" and sees_claim else -1,
		"last_discard": last_discard, "latest": latest, "result": result,
		"drawn": drawn if current == seat and phase == "turn" else -1, "players": public_players,
		"gold_dice": gold_dice.duplicate(), "gold_index": gold_index,
		"dealer_rolls": dealer_rolls.duplicate(true),
		"deal_flowers": deal_flowers.duplicate(true),
		"deal_initial_hand": deal_initial_hands[seat].duplicate() if seat >= 0 and seat < deal_initial_hands.size() else [],
		"deal_draws": visible_draws,
		"last_flowers": last_flowers.duplicate(true), "flower_revision": flower_revision,
	}
