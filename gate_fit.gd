@tool
extends Node3D
## Scales this node (and the gate model inside it) so the gate is as wide as the baseplate.
## Put the gate .glb as a child of this node, then pick the baseplate in the Inspector.

## The baseplate to match (a CSGBox3D or any MeshInstance3D).
@export var baseplate: VisualInstance3D:
	set(v):
		baseplate = v
		t()
## Width of the gate model at scale 1 (the .glb files are 6 m wide).
@export var model_width: float = 6.0
## On: height and depth scale along with the width, so the gate keeps its shape.
## Off: only the width is stretched.
@export var keep_proportions: bool = true:
	set(v):
		keep_proportions = v
		_fit()
## Move the gate to the middle of the plate (sideways only).
@export var center_on_plate: bool = true


func _ready() -> void:
	# CSG shapes need a frame before their size is known.
	await get_tree().process_frame
	_fit()


func _fit() -> void:
	if not is_inside_tree() or baseplate == null or not baseplate.is_inside_tree():
		return

	var box := baseplate.get_aabb()
	var plate_width := box.size.x * baseplate.global_transform.basis.get_scale().x
	if plate_width <= 0.0 or model_width <= 0.0:
		return

	var f := plate_width / model_width
	scale = Vector3(f, f, f) if keep_proportions else Vector3(f, 1.0, 1.0)

	if center_on_plate:
		var middle := baseplate.global_transform * box.get_center()
		global_position.x = middle.x
