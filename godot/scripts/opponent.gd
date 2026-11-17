extends RefCounted

const Rules = preload("res://scripts/rules.gd")

var _known: Array
var _own: Array
var _gold: int
var _gold_outs := 0
var _shapes := {}
var _difficulty := "normal"
var _opponents: Array = []


static func choose(view: Dictionary, moves: Array, difficulty := "normal") -> Dictionary:
	for move in moves:
		if move.type == "win":
			return move
	if moves.size() <= 1:
		return moves[0] if not moves.is_empty() else {}
	var brain := new()
	brain._difficulty = difficulty
	return brain.pick(view, moves)


static func opening_value(hand: Array, gold: int, is_dealer: bool) -> float:
	var brain := new()
	brain._gold = gold
	brain._known = Rules.counts([gold])
	brain._own = Rules.counts(hand)
	brain._gold_outs = brain.gold_outs([gold], hand)
	var wilds := Rules.gold_count(hand, gold)
	if wilds >= 3:
		return 40.0
	if not is_dealer:
		if Rules.winning(hand + [gold], 0, gold):
			return 30.0 + wilds
		return brain.rating(hand, 0)
	if Rules.winning(hand, 0, gold):
		return 30.0 + wilds
	var best := -INF
	for tile in Rules.unique(hand):
		var remaining := remove_tiles(hand, [tile])
		if Rules.winning(remaining + [gold], 0, gold):
			return 30.0 + wilds
		best = maxf(best, brain.rating(remaining, 0))
	return best


func pick(view: Dictionary, moves: Array) -> Dictionary:
	var player: Dictionary = view.players[view.seat]
	var hand: Array = player.hand
	var open: int = player.melds.size()
	var visible: Array = []
	for other in view.players:
		visible.append_array(other.river)
		for meld in other.melds:
			visible.append_array(meld.tiles.filter(func(tile): return tile >= 0))
	if view.indicator >= 0:
		visible.append(view.indicator)
	_known = Rules.counts(visible)
	_own = Rules.counts(hand)
	_gold = view.gold
	_gold_outs = gold_outs(visible, hand)
	if _difficulty == "hard":
		for seat in range(view.players.size()):
			if seat != view.seat:
				_opponents.append(view.players[seat])
	var first_cycle: Dictionary = view.get("first_cycle", {})
	var follow_tile: int = first_cycle.get("tile", -1) if first_cycle.get("next_seat", -1) == view.seat else -1
	if Rules.is_gold(follow_tile, _gold):
		follow_tile = -1
	for move in moves:
		if move.type == "pass":
			var preserve_cycle := follow_tile in hand and weak_first_cycle_hand(hand, open)
			return choose_claim(hand, open, moves, move, preserve_cycle)

	var best: Dictionary = moves[0]
	var best_score := -INF
	var follow: Dictionary = {}
	var follow_score := -INF
	var scores: Array[float] = []
	for move in moves:
		var tile: int = move.tile
		var score: float
		match move.type:
			"discard":
				score = discard_value(hand, open, tile)
				if tile == follow_tile:
					follow = move
					follow_score = score
			"declareGoldGap":
				score = discard_value(hand, open, tile) + 0.35 if _gold_outs > 0 else -INF
			"concealedKong":
				score = rating(remove_tiles(hand, [tile, tile, tile, tile]), open + 1) + 0.35
			_:
				score = rating(remove_tiles(hand, [tile]), open) + 0.35
		if score > best_score:
			best_score = score
			best = move
		scores.append(score)
	# The fourth matching discard immediately redeals, so a weak hand can give up more for it.
	var follow_tolerance := 1.35 if first_cycle.get("count", 0) == 3 else 0.32
	if not follow.is_empty() and follow_score >= best_score - follow_tolerance and weak_first_cycle_hand(hand, open):
		return follow
	if _difficulty == "easy":
		var near: Array = []
		for index in range(scores.size()):
			if scores[index] >= best_score - 0.17:
				near.append(moves[index])
		return near.pick_random()
	return best


func gold_outs(visible: Array, hand: Array) -> int:
	var copies := 0
	for tile in Rules.gold_tiles(_gold):
		copies += 4 if tile < Rules.SEASONS else 1
	return maxi(0, copies - Rules.gold_count(visible, _gold) - Rules.gold_count(hand, _gold))


func weak_first_cycle_hand(hand: Array, open: int) -> bool:
	# Use the same group assessment on every difficulty, including easy's rough ranking.
	var natural := _own.duplicate()
	if _gold >= 0 and _gold < Rules.NUMBERED:
		natural[_gold] = 0
	var shape := open * 2 + strength(natural, 5 - open, true) + Rules.gold_count(hand, _gold) * 1.45
	return shape < 8.0


func choose_claim(hand: Array, open: int, moves: Array, skip: Dictionary, preserve_cycle: bool) -> Dictionary:
	var best := skip
	var best_score := rating(hand, open) + (0.48 if preserve_cycle else 0.23)
	for move in moves:
		if move.type == "pass":
			continue
		var remaining := remove_tiles(hand, move.tiles)
		var score := -INF
		if move.type == "kong":
			score = rating(remaining, open + 1) + 0.35
		else:
			for tile in move.get("discards", Rules.unique(remaining)):
				score = maxf(score, discard_value(remaining, open + 1, tile))
		if score > best_score:
			best_score = score
			best = move
	return best


static func remove_tiles(hand: Array, tiles: Array) -> Array:
	var reduced := hand.duplicate()
	for tile in tiles:
		reduced.erase(tile)
	return reduced


func discard_value(tiles: Array, open: int, tile: int) -> float:
	if tile >= Rules.NUMBERED:
		return rating(remove_tiles(tiles, [tile]), open) - 3.0
	var discarding_gold := Rules.is_gold(tile, _gold)
	var rank := tile % 9
	var safety: float = (_known[tile] + (1 if rank in [0, 8] else 0)) * 0.015
	if _difficulty == "hard" and not discarding_gold:
		for other in _opponents:
			if not other.river.has(tile):
				var exposure: float = maxf(0.0, 3.0 - _known[tile] - _own[tile])
				safety -= exposure * (0.012 + 0.017 * other.melds.size())
	return rating(remove_tiles(tiles, [tile]), open) + safety - (3.0 if discarding_gold else 0.0)


func rating(tiles: Array, open: int) -> float:
	var natural := Rules.counts(tiles)
	var wilds := Rules.gold_count(tiles, _gold)
	if _gold >= 0 and _gold < Rules.NUMBERED:
		natural[_gold] = 0
	if _difficulty == "easy":
		return open * 2.4 + rough_shape(natural) + wilds * 1.6
	var shape := open * 2 + strength(natural, 5 - open, true) + wilds * 1.45
	if shape < 8:
		return shape + improvement(natural, open, shape - open * 2 - wilds * 1.45)
	var outs := 0
	for tile in range(Rules.NUMBERED):
		var available: int = 4 - _known[tile] - _own[tile]
		if available > 0 and Rules.winning(tiles + [tile], open, _gold):
			outs += available
	if _gold >= Rules.NUMBERED and _gold_outs > 0 and Rules.winning(tiles + [_gold], open, _gold):
		outs += _gold_outs
	if outs > 0:
		return 15.0 + outs * 0.07 + shape * 0.01
	return shape + improvement(natural, open, shape - open * 2 - wilds * 1.45)


func improvement(natural: Array, open: int, base: float) -> float:
	if _difficulty != "hard":
		return 0.0
	var outs := _gold_outs if _gold >= Rules.NUMBERED else 0
	for tile in range(Rules.NUMBERED):
		var available: int = 4 - _known[tile] - _own[tile]
		if available <= 0:
			continue
		if tile == _gold:
			outs += available
		else:
			natural[tile] += 1
			if strength(natural, 5 - open, true) > base + 0.1:
				outs += available
			natural[tile] -= 1
	return outs * 0.012


func rough_shape(natural: Array) -> float:
	var score := 0.0
	for tile in range(Rules.NUMBERED):
		if natural[tile] == 0:
			continue
		var rank := tile % 9
		score += maxf(0, natural[tile] - 1) * 0.67
		if rank < 8 and natural[tile + 1] > 0:
			score += 0.49
		if rank < 7 and natural[tile + 2] > 0:
			score += 0.23
			if natural[tile + 1] > 0:
				score += 0.52
	return score


# Split the natural tiles between complete groups, near-groups and the pair.
func strength(natural: Array, slots: int, pair: bool) -> int:
	var tile := natural.find_custom(func(count): return count > 0)
	if tile < 0 or (slots == 0 and not pair):
		return 0
	var key := "%s:%s:%s" % [PackedByteArray(natural).hex_encode(), slots, pair]
	if _shapes.has(key):
		return _shapes[key]
	var best := take(natural, [tile], slots, pair)
	var count: int = natural[tile]
	if count >= 2 and pair:
		best = maxi(best, 1 + take(natural, [tile, tile], slots, false))
	if slots > 0:
		if count >= 2:
			best = maxi(best, 1 + take(natural, [tile, tile], slots - 1, pair))
		if count >= 3:
			best = maxi(best, 2 + take(natural, [tile, tile, tile], slots - 1, pair))
		var rank := tile % 9
		var adjacent: bool = rank < 8 and natural[tile + 1] > 0
		var gap: bool = rank < 7 and natural[tile + 2] > 0
		if adjacent:
			best = maxi(best, 1 + take(natural, [tile, tile + 1], slots - 1, pair))
		if gap:
			best = maxi(best, 1 + take(natural, [tile, tile + 2], slots - 1, pair))
		if adjacent and gap:
			best = maxi(best, 2 + take(natural, [tile, tile + 1, tile + 2], slots - 1, pair))
	_shapes[key] = best
	return best


func take(natural: Array, tiles: Array, slots: int, pair: bool) -> int:
	for tile in tiles:
		natural[tile] -= 1
	var score := strength(natural, slots, pair)
	for tile in tiles:
		natural[tile] += 1
	return score
