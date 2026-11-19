extends RefCounted

const WINDS := ["东", "南", "西", "北"]


static func local_seat(seat: int, viewer: int) -> int:
	return posmod(seat - viewer, 4) if seat >= 0 else -1


static func rotate_seats(values: Array, viewer: int) -> Array:
	return values.slice(viewer) + values.slice(0, viewer)


static func rotate_roll(roll: Dictionary, viewer: int) -> Dictionary:
	var result: Dictionary = roll.duplicate(true)
	result.start = local_seat(int(result.get("start", 0)), viewer)
	result.order = Array(result.get("order", [])).map(func(seat): return local_seat(int(seat), viewer))
	result.round_seats = Array(result.get("round_seats", [])).map(func(seat): return local_seat(int(seat), viewer))
	result.tied = Array(result.get("tied", [])).map(func(seat): return local_seat(int(seat), viewer))
	result.winner = local_seat(int(result.get("winner", -1)), viewer)
	result.dice = rotate_seats(result.get("dice", []), viewer)
	result.sums = rotate_seats(result.get("sums", []), viewer)
	var seats: Array = result.round_seats
	var index := int(result.get("index", 0))
	result.current = -1 if bool(result.get("finished", false)) or index >= seats.size() else int(seats[index])
	return result


static func from_room(state: Dictionary) -> Dictionary:
	var viewer: int = state.my_seat
	var view: Dictionary = state.view.duplicate(true)
	view.seat = 0
	view.winds = rotate_seats(WINDS, viewer)
	view.current = local_seat(view.current, viewer)
	view.dealer = local_seat(view.dealer, viewer)
	view.actor = local_seat(state.get("actor", -1), viewer)
	var first_cycle: Dictionary = view.get("first_cycle", {})
	if not first_cycle.is_empty():
		first_cycle.next_seat = local_seat(first_cycle.next_seat, viewer)
	view.players = rotate_seats(view.players, viewer)
	view.scores = rotate_seats(view.scores, viewer)
	view.seat_info = rotate_seats(state.seats, viewer)
	view.result_votes = rotate_seats(Array(state.get("result_votes", [false, false, false, false])), viewer)
	if not view.get("sea", {}).is_empty():
		view.sea.seat = local_seat(view.sea.seat, viewer)
	for key in ["deal_flowers", "deal_draws", "last_flowers"]:
		for event in view.get(key, []):
			event.seat = local_seat(event.seat, viewer)
	for key in ["opening", "takes"]:
		for event in view.get("wall", {}).get(key, []):
			event.seat = local_seat(event.seat, viewer)
	view.latest.seat = local_seat(view.latest.seat, viewer)
	if view.latest.has("previous"):
		view.latest.previous.seat = local_seat(view.latest.previous.seat, viewer)
	if not view.last_discard.is_empty():
		view.last_discard.seat = local_seat(view.last_discard.seat, viewer)
	for player in view.players:
		for meld in player.melds:
			meld.from = local_seat(meld.from, viewer)
	view.standings = state.get("standings", []).duplicate(true)
	for row in view.standings:
		row.seat = local_seat(row.seat, viewer)
	if not view.result.is_empty():
		view.result.winner = local_seat(view.result.winner, viewer)
		view.result.from = local_seat(view.result.from, viewer)
		view.result.deltas = rotate_seats(view.result.deltas, viewer)
		if view.result.has("payers"):
			view.result.payers = view.result.payers.map(func(seat): return local_seat(seat, viewer))
	if view.get("dealer_rolls", {}).size() > 0:
		view.dealer_rolls = rotate_roll(view.dealer_rolls, viewer)
	return view
