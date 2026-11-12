extends RefCounted


static func local_seat(seat: int, viewer: int) -> int:
	return posmod(seat - viewer, 4) if seat >= 0 else -1


static func rotate_seats(values: Array, viewer: int) -> Array:
	return values.slice(viewer) + values.slice(0, viewer)


static func from_room(state: Dictionary) -> Dictionary:
	var viewer: int = state.my_seat
	var view: Dictionary = state.view.duplicate(true)
	view.seat = 0
	view.current = local_seat(view.current, viewer)
	view.dealer = local_seat(view.dealer, viewer)
	view.actor = local_seat(state.get("actor", -1), viewer)
	view.players = rotate_seats(view.players, viewer)
	view.scores = rotate_seats(view.scores, viewer)
	view.seat_info = rotate_seats(state.seats, viewer)
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
		var roll: Dictionary = view.dealer_rolls.duplicate(true)
		roll.dice = rotate_seats(roll.dice, viewer)
		roll.sums = rotate_seats(roll.sums, viewer)
		roll.winner = local_seat(roll.winner, viewer)
		view.dealer_rolls = roll
	return view
