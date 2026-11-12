extends RefCounted

const STAGES := ["deal", "dealer_extra", "dice", "gold", "flowers", "done"]

var stage := "idle"
var deal_round := 0
var seat_counts := [0, 0, 0, 0]
var dealer := 0


func start(dealer_seat: int) -> void:
	stage = "deal"
	deal_round = 0
	seat_counts = [0, 0, 0, 0]
	dealer = posmod(dealer_seat, 4)


func advance() -> String:
	match stage:
		"deal":
			for seat in range(4):
				seat_counts[seat] += 4
			deal_round += 1
			if deal_round >= 4:
				stage = "dealer_extra"
		"dealer_extra":
			seat_counts[dealer] += 1
			stage = "dice"
		"dice":
			stage = "gold"
		"gold":
			stage = "flowers"
		"flowers":
			stage = "done"
	return stage


func skip() -> void:
	stage = "done"


func is_active() -> bool:
	return stage != "idle" and stage != "done"


func visible_count(seat: int, final_count: int) -> int:
	if not is_active():
		return final_count
	return mini(seat_counts[seat], final_count)


func status_text() -> String:
	match stage:
		"deal":
			return "发牌中…"
		"dealer_extra":
			return "庄家补牌"
		"dice":
			return "掷骰开金"
		"gold":
			return "翻金"
		"flowers":
			return "补花"
	return ""
