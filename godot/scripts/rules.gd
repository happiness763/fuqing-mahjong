extends RefCounted

const NUMBERED := 27
const RESERVE := 18
const RANKS := ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
const SUITS := ["万", "筒", "条"]
const FLOWERS := "东南西北中发白春夏秋冬梅兰竹菊"
const SEASONS := 34
const PLANTS := 38
const TILE_TYPES := 42
const WIN_NAMES := {
	"discard": "点炮", "self": "自摸", "rob": "抢杠", "idle": "闲金", "three": "三金倒",
	"grab": "抢金", "sparrow": "金雀", "dragon": "金龙", "goldGap": "金坎", "heaven": "天胡",
	"pure": "正清", "pengpeng": "碰碰胡", "dandiao": "单吊",
}
const MULTIPLIERS := {
	"discard": 1, "self": 2, "rob": 2, "idle": 2, "three": 3, "grab": 3,
	"sparrow": 4, "dragon": 5, "goldGap": 4, "heaven": 5, "pure": 5,
	"pengpeng": 3, "dandiao": 5,
}
const OFFSETS := {"idle": 10, "sparrow": 40, "dragon": 50, "goldGap": 40, "heaven": 50, "pure": 50,
	"dandiao": 50}
const MELD_NAMES := {
	"chow": "吃", "pong": "碰", "kong": "明杠", "addedKong": "补杠", "concealedKong": "暗杠",
}
const PRIORITY := {"pass": 0, "chow": 1, "pong": 2, "kong": 2, "win": 3}


static func tile_name(tile: int) -> String:
	if tile < 0 or tile >= TILE_TYPES:
		return ""
	if tile >= NUMBERED:
		return FLOWERS[tile - NUMBERED]
	@warning_ignore("integer_division")
	return RANKS[tile % 9] + SUITS[tile / 9]


static func make_wall(rng: RandomNumberGenerator) -> Array:
	var wall: Array = []
	for tile in range(TILE_TYPES):
		for copy in range(4 if tile < SEASONS else 1):
			wall.append(tile)
	for index in range(wall.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var value = wall[index]
		wall[index] = wall[other]
		wall[other] = value
	return wall


static func gold_tiles(gold: int) -> Array:
	if gold < 0 or gold >= TILE_TYPES:
		return []
	if gold < SEASONS:
		return [gold]
	if gold < PLANTS:
		return range(SEASONS, PLANTS)
	return range(PLANTS, TILE_TYPES)


static func is_gold(tile: int, gold: int) -> bool:
	if tile < 0 or tile >= TILE_TYPES or gold < 0 or gold >= TILE_TYPES:
		return false
	if gold < SEASONS:
		return tile == gold
	if gold < PLANTS:
		return tile >= SEASONS and tile < PLANTS
	return tile >= PLANTS


static func is_flower(tile: int, gold: int) -> bool:
	return tile >= NUMBERED and tile < TILE_TYPES and not is_gold(tile, gold)


static func gold_count(hand: Array, gold: int) -> int:
	var total := 0
	for tile in hand:
		if is_gold(tile, gold):
			total += 1
	return total


static func counts(tiles: Array) -> Array:
	var result: Array = []
	result.resize(NUMBERED)
	result.fill(0)
	for tile in tiles:
		if tile >= 0 and tile < NUMBERED:
			result[tile] += 1
	return result


static func winning(hand: Array, open_count: int, gold: int, gold_pair := false) -> bool:
	if open_count < 0 or open_count > 5 or hand.size() != (5 - open_count) * 3 + 2:
		return false
	if hand.any(func(tile): return tile < 0 or tile >= TILE_TYPES or is_flower(tile, gold)):
		return false
	var wilds := gold_count(hand, gold)
	var natural := counts(hand.filter(func(tile): return not is_gold(tile, gold)))
	var memo := {}
	if wilds >= 2 and groups_fit(natural, wilds - 2, memo):
		return true
	if gold_pair:
		return false
	for tile in range(NUMBERED):
		for used in range(mini(2, natural[tile]), maxi(1, 2 - wilds) - 1, -1):
			natural[tile] -= used
			var works := groups_fit(natural, wilds - (2 - used), memo)
			natural[tile] += used
			if works:
				return true
	return false


static func idle_gold(hand: Array, open_count: int, gold: int) -> bool:
	if open_count < 0 or open_count > 5 or hand.size() != (5 - open_count) * 3 + 1 or gold_count(hand, gold) != 1:
		return false
	if hand.any(func(tile): return tile < 0 or tile >= TILE_TYPES or is_flower(tile, gold)):
		return false
	return groups_fit(counts(hand.filter(func(tile): return not is_gold(tile, gold))), 0, {})


static func gold_gap(hand: Array, open_count: int, gold: int, gap: Array) -> bool:
	if open_count < 0 or open_count >= 5:
		return false
	if gold < 0 or gold >= NUMBERED or gold % 9 in [0, 8] or gap.size() != 2:
		return false
	if not gap.has(gold - 1) or not gap.has(gold + 1):
		return false
	if not hand.has(gold - 1) or not hand.has(gold + 1):
		return false
	var remainder := hand.duplicate()
	remainder.erase(gold - 1)
	remainder.erase(gold + 1)
	return winning(remainder, open_count + 1, gold)


static func groups_fit(natural: Array, wilds: int, memo: Dictionary) -> bool:
	var tile := natural.find_custom(func(count): return count > 0)
	if tile < 0:
		return wilds % 3 == 0
	var key := "%s:%s" % [PackedByteArray(natural).hex_encode(), wilds]
	if memo.has(key):
		return memo[key]
	for used in range(mini(3, natural[tile]), maxi(1, 3 - wilds) - 1, -1):
		natural[tile] -= used
		var works := groups_fit(natural, wilds - (3 - used), memo)
		natural[tile] += used
		if works:
			memo[key] = true
			return true
	var suit_start := tile - tile % 9
	for start in range(maxi(tile - 2, suit_start), mini(tile, suit_start + 6) + 1):
		var others := [start, start + 1, start + 2]
		others.erase(tile)
		natural[tile] -= 1
		var works := sequence_fit(natural, others, 0, wilds, memo)
		natural[tile] += 1
		if works:
			memo[key] = true
			return true
	memo[key] = false
	return false


static func sequence_fit(natural: Array, tiles: Array, index: int, wilds: int, memo: Dictionary) -> bool:
	if index == tiles.size():
		return groups_fit(natural, wilds, memo)
	var tile: int = tiles[index]
	if natural[tile] > 0:
		natural[tile] -= 1
		var works := sequence_fit(natural, tiles, index + 1, wilds, memo)
		natural[tile] += 1
		if works:
			return true
	return wilds > 0 and sequence_fit(natural, tiles, index + 1, wilds - 1, memo)


static func score(winner: int, from: int, method: String, hand: Array, flowers: Array, melds: Array, gold: int, dealer := 0, qualifies_idle := false) -> Dictionary:
	var totals := base_value(hand, flowers, melds, gold, winner, dealer)
	var base: int = totals.base
	var kind := best_pattern(hand, melds, gold, method, base, qualifies_idle)
	var multiplier: int = MULTIPLIERS[kind]
	var offset: int = OFFSETS.get(kind, 0)
	var per_payer := base * multiplier + offset
	var payers := [from] if from >= 0 else [0, 1, 2, 3].filter(func(seat): return seat != winner)
	var deltas := [0, 0, 0, 0]
	for payer in payers:
		deltas[payer] = -per_payer
	deltas[winner] = per_payer * payers.size()
	return {
		"kind": kind, "method": "self" if method == "goldGap" else method,
		"winner": winner, "from": from, "base": base,
		"base_points": totals.base_points, "flower_points": totals.flower_points, "gold_points": totals.gold_points,
		"multiplier": multiplier, "offset": offset,
		"per_payer": per_payer, "payers": payers, "deltas": deltas, "flowers": flowers.size(),
		"golds": totals.total_golds, "normal_golds": totals.total_golds - totals.flower_golds,
		"flower_golds": totals.flower_golds, "exposed": totals.exposed, "concealed": totals.concealed,
	}


static func base_value(hand: Array, flowers: Array, melds: Array, gold: int, winner: int, dealer: int) -> Dictionary:
	var exposed := 0
	var concealed := 0
	for meld in melds:
		if meld.type == "concealedKong":
			concealed += 1
		elif meld.type in ["kong", "addedKong"]:
			exposed += 1
	var total_golds := gold_count(hand, gold)
	var flower_golds := total_golds if gold >= NUMBERED else 0
	var base_points := 3 if winner == dealer else 1
	var flower_points := flowers.size() + exposed + 2 * concealed
	var gold_points := total_golds + flower_golds
	return {
		"base": base_points + flower_points + gold_points,
		"base_points": base_points, "flower_points": flower_points, "gold_points": gold_points,
		"total_golds": total_golds, "flower_golds": flower_golds,
		"exposed": exposed, "concealed": concealed,
	}


static func pattern_candidates(hand: Array, melds: Array, gold: int, method: String, qualifies_idle := false) -> Array[String]:
	var open_count := melds.size()
	var candidates: Array[String] = []
	if method == "self":
		if qualifies_idle and winning(hand, open_count, gold):
			candidates.append("idle")
		if gold_count(hand, gold) >= 3:
			candidates.append("three")
	if gold_count(hand, gold) >= 2 and winning(hand, open_count, gold, true):
		candidates.append("sparrow")
	if gold_count(hand, gold) >= 3 and gold_dragon(hand, open_count, gold):
		candidates.append("dragon")
	if winning(hand, open_count, gold):
		if open_count == 5:
			candidates.append("dandiao")
		if all_triplets(hand, melds, gold):
			candidates.append("pengpeng")
		if pure_suit(hand, melds, gold):
			candidates.append("pure")
	return candidates


static func best_pattern(hand: Array, melds: Array, gold: int, method: String, base: int, qualifies_idle := false) -> String:
	var kind := method
	for candidate in pattern_candidates(hand, melds, gold, method, qualifies_idle):
		if pattern_points(candidate, base) > pattern_points(kind, base):
			kind = candidate
	return kind


static func win_rank(kind: String) -> int:
	return int(MULTIPLIERS.get(kind, 1)) * 1000 + int(OFFSETS.get(kind, 0))


static func all_triplets(hand: Array, melds: Array, gold: int) -> bool:
	var open_count := melds.size()
	if open_count < 0 or open_count > 5 or hand.size() != (5 - open_count) * 3 + 2:
		return false
	for meld in melds:
		if meld.type == "chow":
			return false
	if hand.any(func(tile): return tile < 0 or tile >= TILE_TYPES or is_flower(tile, gold)):
		return false
	var wilds := gold_count(hand, gold)
	var natural := counts(hand.filter(func(tile): return not is_gold(tile, gold)))
	var memo := {}
	if wilds >= 2 and triplets_fit(natural, wilds - 2, memo):
		return true
	for tile in range(NUMBERED):
		for used in range(mini(2, natural[tile]), maxi(1, 2 - wilds) - 1, -1):
			natural[tile] -= used
			var works := triplets_fit(natural, wilds - (2 - used), memo)
			natural[tile] += used
			if works:
				return true
	return false


static func triplets_fit(natural: Array, wilds: int, memo: Dictionary) -> bool:
	var tile := natural.find_custom(func(count): return count > 0)
	if tile < 0:
		return wilds % 3 == 0
	var key := "%s:%s" % [PackedByteArray(natural).hex_encode(), wilds]
	if memo.has(key):
		return memo[key]
	for used in range(mini(3, natural[tile]), maxi(1, 3 - wilds) - 1, -1):
		natural[tile] -= used
		var works := triplets_fit(natural, wilds - (3 - used), memo)
		natural[tile] += used
		if works:
			memo[key] = true
			return true
	memo[key] = false
	return false


static func pattern_points(kind: String, base: int) -> int:
	return MULTIPLIERS[kind] * base + OFFSETS.get(kind, 0)


static func roll_dealer(rng: RandomNumberGenerator, dice_roll := Callable()) -> Dictionary:
	var dice: Array = []
	var sums: Array = []
	for seat in range(4):
		var pair: Array = [roll_die(rng, dice_roll), roll_die(rng, dice_roll)]
		dice.append(pair)
		sums.append(int(pair[0]) + int(pair[1]))
	var rerolls := 0
	while true:
		var best := -1
		for value in sums:
			best = maxi(best, int(value))
		var tied: Array = []
		for seat in range(4):
			if int(sums[seat]) == best:
				tied.append(seat)
		if tied.size() == 1:
			return {"winner": tied[0], "dice": dice, "sums": sums, "rerolls": rerolls}
		rerolls += 1
		for seat in tied:
			var pair: Array = [roll_die(rng, dice_roll), roll_die(rng, dice_roll)]
			dice[seat] = pair
			sums[seat] = int(pair[0]) + int(pair[1])
		if rerolls > 100:
			return {"winner": tied[0], "dice": dice, "sums": sums, "rerolls": rerolls}
	return {}


static func roll_die(rng: RandomNumberGenerator, dice_roll := Callable()) -> int:
	if dice_roll.is_valid():
		return clampi(int(dice_roll.call()), 1, 6)
	return rng.randi_range(1, 6)


static func dealer_roll_state(rng: RandomNumberGenerator) -> Dictionary:
	var start := rng.randi_range(0, 3)
	var order := order_from(start)
	return {
		"start": start, "order": order, "round": 1, "round_seats": order.duplicate(),
		"index": 0, "dice": [[], [], [], []], "sums": [-1, -1, -1, -1],
		"tied": [], "winner": -1, "finished": false,
	}


static func dealer_roll_current(state: Dictionary) -> int:
	if state.get("finished", false):
		return -1
	var seats: Array = state.get("round_seats", [])
	var index := int(state.get("index", 0))
	if index < 0 or index >= seats.size():
		return -1
	return int(seats[index])


static func dealer_roll_apply(state: Dictionary, rng: RandomNumberGenerator, dice_roll := Callable()) -> Dictionary:
	if state.get("finished", false):
		return state
	var seats: Array = state.get("round_seats", [])
	var index := int(state.get("index", 0))
	if index < 0 or index >= seats.size():
		return state
	var seat := int(seats[index])
	var pair: Array = [roll_die(rng, dice_roll), roll_die(rng, dice_roll)]
	state.dice[seat] = pair
	state.sums[seat] = int(pair[0]) + int(pair[1])
	state.index = index + 1
	if int(state.index) >= seats.size():
		var best := -1
		for value in state.sums:
			best = maxi(best, int(value))
		var tied: Array = []
		for seat2 in state.order:
			if int(state.sums[seat2]) == best:
				tied.append(int(seat2))
		state.tied = tied
		if tied.size() == 1:
			state.winner = tied[0]
			state.finished = true
		else:
			state.round = int(state.round) + 1
			state.round_seats = state.order.filter(func(entry): return int(entry) in tied)
			state.index = 0
	return state


static func gold_dragon(hand: Array, open_count: int, gold: int) -> bool:
	var remaining: Array = []
	var removed := 0
	for tile in hand:
		if removed < 3 and is_gold(tile, gold):
			removed += 1
		else:
			remaining.append(tile)
	return removed == 3 and winning(remaining, open_count + 1, gold)


static func pure_suit(hand: Array, melds: Array, gold: int) -> bool:
	var tiles := hand.duplicate()
	for meld in melds:
		tiles.append_array(meld.get("tiles", []))
	var suit := -1
	for tile in tiles:
		if is_gold(tile, gold):
			continue
		if tile < 0 or tile >= NUMBERED:
			return false
		@warning_ignore("integer_division")
		var tile_suit: int = tile / 9
		if suit >= 0 and suit != tile_suit:
			return false
		suit = tile_suit
	return suit >= 0


static func order_from(first: int) -> Array:
	return [first, (first + 1) % 4, (first + 2) % 4, (first + 3) % 4]


static func unique(tiles: Array) -> Array:
	var values := []
	for tile in tiles:
		if not values.has(tile):
			values.append(tile)
	return values
