extends Label

# Optioneel: sleep je auto hierin. Laat je dit leeg, dan zoekt hij de auto zelf.
@export var car: RigidBody3D
@export var use_mph := false
@export var font_size := 36
@export var margin := 20

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 8)

	# rechtsonder in de hoek
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -margin
	offset_bottom = -margin

	text = "0 km/h"

func _process(_delta):
	if car == null:
		car = _find_car()
		if car == null:
			text = "geen auto"
			return

	var ms := car.linear_velocity.length()
	if use_mph:
		text = "%d mph" % roundi(ms * 2.23694)
	else:
		text = "%d km/h" % roundi(ms * 3.6)

func _find_car() -> RigidBody3D:
	var root := get_tree().current_scene
	if root == null:
		return null
	for n in root.find_children("*", "RigidBody3D", true, false):
		if "nose_points_plus_z" in n:   # alleen jouw auto-script heeft dit
			return n
	return null
