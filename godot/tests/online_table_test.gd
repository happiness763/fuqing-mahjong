extends SceneTree

const TableView = preload("res://scripts/online_table_view.gd")
const Game = preload("res://scripts/game.gd")


func _initialize() -> void:
	var game = Game.new(43)
	game.current = 2
	game.players[2].melds = [{"type": "chow", "tiles": [1, 2, 3], "from": 1, "claimed": 1}]
	game.last_discard = {"seat": 3, "tile": 14}
	game.scores = [8, -4, -8, 4]
	var seats := [{"name": "甲"}, {"name": "乙"}, {"name": "丙"}, {"name": "丁"}]
	var state := {"view": game.view(2), "my_seat": 2, "actor": 2, "seats": seats}
	var view := TableView.from_room(state)
	var valid: bool = (
		view.seat == 0 and view.current == 0 and view.dealer == 2 and view.actor == 0
		and view.scores == [-8, 4, 8, -4] and view.seat_info[0].name == "丙"
		and view.players[0].has("hand") and not view.players[1].has("hand")
		and view.players[0].melds[0].from == 3 and view.last_discard.seat == 1
		and state.view.players[2].melds[0].from == 1
	)
	game.finish({"kind": "discard", "winner": 1, "from": 0, "payers": [0], "deltas": [-3, 3, 0, 0]})
	state.view = game.view(2)
	state.view.latest.previous = {"type": "discard", "seat": 0, "tile": 14, "revision": 1}
	state.standings = game.standings()
	state.actor = -1
	view = TableView.from_room(state)
	valid = valid and (
		view.actor == -1 and view.result.winner == 3 and view.result.from == 2
		and view.result.payers == [2] and view.result.deltas == [0, 0, -3, 3]
		and view.latest.previous.seat == 2 and state.view.latest.previous.seat == 0
		and view.standings[0].seat == 2
	)
	if valid:
		print("Online view preserves private information and rotates seats, melds and scores.")
	else:
		printerr("FAIL: online view mapping")
	quit(0 if valid else 1)
