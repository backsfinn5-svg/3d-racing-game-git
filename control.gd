extends Control
class_name Speedometer

# Sleep hier je auto (RigidBody3D) in via de Inspector
@export var car: RigidBody3D

@export var use_mph := false
@export var max_display_speed := 180.0     # hoogste waarde op de meter (km/h of mph)
@export var major_step := 20.0             # afstand tussen de cijfers
@export var needle_smoothing := 8.0        # hoger = naald volgt directer
@export var units_per_meter := 1.0         # 1 Godot-eenheid = 1 meter. Pas aan als jouw wereld anders is

@export_group("Uiterlijk")
@export var gauge_radius := 100.0
@export var redline_start := 0.85          # vanaf dit deel van de meter wordt het rood (0-1)
@export var color_dial := Color(1, 1, 1, 0.85)
@export var color_redline := Color(1, 0.25, 0.2)
@export var color_needle := Color(1, 0.35, 0.2)
@export var color_text := Color.WHITE

const START_ANGLE := deg_to_rad(135.0)
const SWEEP := deg_to_rad(270.0)

var shown_speed := 0.0
var real_speed := 0.0
var reversing := false

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side := gauge_radius * 2.0 + 30.0
	custom_minimum_size = Vector2(side, side)

func _process(delta):
	if car == null:
		return

	var vel := car.linear_velocity
	var nose_plus = car.get("nose_points_plus_z")
	if nose_plus == null:
		nose_plus = true
	var basis := car.global_transform.basis
	var forward: Vector3 = basis.z if nose_plus else -basis.z

	reversing = vel.dot(forward) < -0.5

	# m/s -> km/h of mph
	var ms := vel.length() / units_per_meter
	real_speed = ms * (2.23694 if use_mph else 3.6)

	# naald gladder laten lopen, onafhankelijk van framerate
	shown_speed = lerpf(shown_speed, real_speed, 1.0 - exp(-needle_smoothing * delta))
	queue_redraw()

func _draw():
	var center := size * 0.5
	var font := ThemeDB.fallback_font

	# basisboog
	var red_from := START_ANGLE + SWEEP * redline_start
	draw_arc(center, gauge_radius, START_ANGLE, red_from, 48, color_dial, 4.0, true)
	draw_arc(center, gauge_radius, red_from, START_ANGLE + SWEEP, 16, color_redline, 4.0, true)

	# streepjes en cijfers
	var steps := int(round(max_display_speed / major_step))
	for i in range(steps + 1):
		var ratio := float(i) / float(steps)
		var a := START_ANGLE + SWEEP * ratio
		var dir := Vector2.from_angle(a)
		var col := color_redline if ratio >= redline_start else color_dial
		draw_line(center + dir * (gauge_radius - 12.0), center + dir * gauge_radius, col, 2.0, true)

		var label := str(int(i * major_step))
		var tsize := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var tpos := center + dir * (gauge_radius - 26.0) - Vector2(tsize.x * 0.5, -tsize.y * 0.3)
		draw_string(font, tpos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)

	# naald
	var ratio_now := clampf(shown_speed / max_display_speed, 0.0, 1.0)
	var needle_dir := Vector2.from_angle(START_ANGLE + SWEEP * ratio_now)
	draw_line(center - needle_dir * 10.0, center + needle_dir * (gauge_radius - 16.0), color_needle, 3.0, true)
	draw_circle(center, 6.0, color_needle)

	# digitale snelheid
	var speed_text := str(int(round(real_speed)))
	var big := font.get_string_size(speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
	draw_string(font, center + Vector2(-big.x * 0.5, 48.0), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, color_text)

	var unit_text := "mph" if use_mph else "km/h"
	var usize := font.get_string_size(unit_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, center + Vector2(-usize.x * 0.5, 64.0), unit_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color_dial)

	# achteruit-indicator
	if reversing:
		var rsize := font.get_string_size("R", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_string(font, center + Vector2(-rsize.x * 0.5, -30.0), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color_redline)
