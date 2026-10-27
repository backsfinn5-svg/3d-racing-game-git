
extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	print("FinishDetector gestart")


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	print("Finish gedetecteerd!")

	var manager = get_tree().get_first_node_in_group("race_manager")

	if manager:
		manager.cross_finish()
	else:
		print("RaceManager niet gevonden!")
