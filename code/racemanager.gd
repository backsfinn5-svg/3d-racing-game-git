
extends Node

@export var checkpoint_order: Array[Area3D] = []
@export var total_laps: int = 3
@export var status_label: Label
@export var finish_gate: Area3D

var next_checkpoint_index: int = 0
var current_lap: int = 1
var race_finished: bool = false


func _ready() -> void:
	add_to_group("race_manager")
	update_ui()


func pass_checkpoint(checkpoint: Area3D) -> void:
	if race_finished:
		return

	if next_checkpoint_index >= checkpoint_order.size():
		return

	if checkpoint != checkpoint_order[next_checkpoint_index]:
		print("Verkeerd checkpoint!")
		return

	next_checkpoint_index += 1
	print("Checkpoint bereikt: ", checkpoint.name)
	update_ui()


func update_ui() -> void:
	if status_label == null:
		print("FOUT: Status Label niet gekoppeld!")
		return

	var message = "RONDE: %d / %d\n" % [current_lap, total_laps]
	message += "CHECKPOINT: %d / %d" % [
		next_checkpoint_index,
		checkpoint_order.size()
	]

	if race_finished:
		message += "\nRACE AFGELOPEN!"

	status_label.text = message


func cross_finish() -> void:
	if race_finished:
		return

	print("Finish geraakt!")

	if next_checkpoint_index < checkpoint_order.size():
		print("Passeer eerst alle checkpoints!")
		update_ui()
		return

	if current_lap < total_laps:
		current_lap += 1
		next_checkpoint_index = 0

		print("Nieuwe ronde: ", current_lap)
		update_ui()
	else:
		race_finished = true
		print("RACE AFGELOPEN!")
		update_ui()
