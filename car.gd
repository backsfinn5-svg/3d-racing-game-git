extends RigidBody3D


class WheelInfo:                        #classen instellen
	var wheel: Node3D
	var mesh: Node3D
	var wheel_rest: Basis
	var mesh_rest: Basis
	var axle: Vector3
	var radius: float
	var steers: bool

@export var nose_points_plus_z := true    #de nose zijn positie bepalen
@export var accel := 42.0                 #
@export var brake_decel := 55.0
@export var reverse_accel := 15.0
@export var max_speed := 65.0
@export var max_reverse_speed := 12.0
@export var turn_speed := 2.2
@export var turn_response := 10.0        
@export var turn_speed_falloff := 0.03   
@export var grip := 7.0                  
@export var coast_drag := 0.5
@export var stick_force := 4.0           
@export var ground_ray_up := 1.0
@export var ground_check := 1.5
@export var debug_print := false

@export_group("Slip")
@export var tire_grip := 30.0            # max zijwaartse versnelling (m/s²). Hoger = later slippen, lager = eerder glijden
@export var slide_grip_ratio := 0.8       # grip die overblijft als je slipt (lager = harder wegglijden)
@export var slide_recover := 0.7          # hoe ver de slip moet afnemen voor de banden weer pakken (lager = langer slippen)
@export var power_slip := 0.3             # gas/rem tijdens het sturen kost grip (0 = geen effect)
@export var max_slip_angle := 35.0       # max driftshoek in graden; daarboven draait de neus niet verder uit
@export var slide_drag := 4.0             # snelheidsverlies (m/s²) als je volledig slipt
@export var corner_scrub := 0.1          # snelheidsverlies door bandkracht in bochten (0 = geen)

@export_group("Gladheid")
@export var throttle_response := 6.0      # hoe snel gas/rem opbouwt (hoger = directer)
@export var steer_speed := 5.0            # hoe snel het stuur insteekt
@export var steer_return_speed := 8.0     # hoe snel het stuur terugveert
@export var ground_grace := 0.12          # tijd (s) dat de auto nog "op de grond" telt na een hobbel
@export var align_strength := 6.0         # hoe snel de auto zich op de weg uitlijnt (0 = uit)
@export var hold_on_slopes := true        # auto blijft stilstaan op een helling
@export var lower_center_of_mass := true  # stabieler in bochten
@export var com_above_axle := 0.15

@export_group("Wielen")
@export var wheel_names: Array[String] = ["RL", "RR", "FL", "FR"]
@export var steer_wheel_names: Array[String] = ["FL", "FR"]
@export var wheel_collider_scale := 1.0   # 1 = bol zo groot als het wiel
@export var max_wheel_steer := 0.45
@export var flip_wheel_spin := false
@export var flip_wheel_steer := false


var is_sliding := false
var slip_angle := 0.0                    

var wheels: Array[WheelInfo] = []
var was_grounded := false
var air_time := 0.0
var ground_normal := Vector3.UP
var spin_distance := 0.0
var yaw_rate := 0.0
var steer_smooth := 0.0
var throttle_smooth := 0.0

func _ready():
	mass = 850.0
	can_sleep = false
	continuous_cd = true
	add_to_group("player")
	angular_damp = 3.0
	linear_damp = 0.0
	var mat := PhysicsMaterial.new()
	mat.friction = 0.0
	mat.bounce = 0.0
	physics_material_override = mat
	_setup_wheels()

func _setup_wheels():
	var to_car := global_transform.affine_inverse()
	var center_sum := Vector3.ZERO
	var center_count := 0

	for wname in wheel_names:
		var w := get_node_or_null(wname) as Node3D
		if w == null:
			push_warning("Wiel niet gevonden: " + wname)
			continue

		
		var meshes: Array = w.find_children("*", "MeshInstance3D", true, false)
		if w is MeshInstance3D:
			meshes.append(w)

		var box := AABB()
		var first := true
		for n in meshes:
			var mi := n as MeshInstance3D
			var b: AABB = (to_car * mi.global_transform) * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		if first:
			push_warning("Geen mesh onder wiel: " + wname)
			continue
		var radius := maxf(box.size.y, box.size.z) * 0.5

		
		var shape := SphereShape3D.new()
		shape.radius = radius * wheel_collider_scale
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = box.get_center()
		add_child(cs)

		center_sum += box.get_center()
		center_count += 1

		
		var m: Node3D = null
		for c in w.get_children():
			if c is Node3D:
				m = c
				break
		if m == null:
			push_warning("Wiel heeft geen kind-node om te draaien: " + wname)
			continue

		var info := WheelInfo.new()
		info.wheel = w
		info.mesh = m
		info.wheel_rest = w.transform.basis
		info.mesh_rest = m.transform.basis
		info.axle = (info.wheel_rest.inverse() * Vector3.RIGHT).normalized()
		info.radius = radius
		info.steers = steer_wheel_names.has(wname)
		wheels.append(info)

	
	if lower_center_of_mass and center_count > 0:
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = center_sum / center_count + Vector3.UP * com_above_axle


func _physics_process(delta):
	var nose := global_transform.basis.z if nose_points_plus_z else -global_transform.basis.z
	var fwd_speed := linear_velocity.dot(nose)

	var dir := 1.0 if nose_points_plus_z else -1.0
	if flip_wheel_spin:
		dir = -dir
	spin_distance += dir * fwd_speed * delta

	var steer_angle := (-steer_smooth if flip_wheel_steer else steer_smooth) * max_wheel_steer

	for info in wheels:
		if info.steers:
			info.wheel.transform.basis = Basis(Vector3.UP, steer_angle) * info.wheel_rest
		var angle := fposmod(spin_distance / info.radius, TAU)
		info.mesh.transform.basis = Basis(info.axle, angle) * info.mesh_rest

func _integrate_forces(state: PhysicsDirectBodyState3D):
	var dt := state.step
	var b := state.transform.basis.orthonormalized()
	var up := b.y
	var nose := b.z if nose_points_plus_z else -b.z

	
	var steer_in := Input.get_axis("ui_right", "ui_left")
	var steer_rate := steer_speed if absf(steer_in) > 0.01 else steer_return_speed
	steer_smooth = move_toward(steer_smooth, steer_in, steer_rate * dt)
	throttle_smooth = move_toward(throttle_smooth, Input.get_axis("ui_down", "ui_up"), throttle_response * dt)

	
	var origin := state.transform.origin
	var from := origin + up * ground_ray_up
	var to := origin - up * ground_check
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	var hit := state.get_space_state().intersect_ray(query)
	var grounded := not hit.is_empty()
	if grounded:
		air_time = 0.0
		ground_normal = hit.normal
	else:
		air_time += dt
	if debug_print and grounded != was_grounded:
		print("grounded: ", grounded)
	was_grounded = grounded
	if air_time > ground_grace:
		yaw_rate = 0.0
		is_sliding = false
		slip_angle = 0.0
		return


	var n := ground_normal
	var forward := nose - n * nose.dot(n)
	if forward.length_squared() < 0.05:
		n = up
		forward = nose - n * nose.dot(n)
	forward = forward.normalized()
	var right := forward.cross(n).normalized()

	var vel := state.linear_velocity
	var fwd_speed := vel.dot(forward)
	var thr := throttle_smooth
	var mag := absf(thr)
	var long_demand := 0.0   


	if thr > 0.01:
		if fwd_speed < -0.1:
			
			vel += forward * minf(brake_decel * mag * dt, -fwd_speed)
			long_demand = brake_decel * mag
		else:
			var t := clampf(fwd_speed / max_speed, 0.0, 1.0)
			var a := accel * thr * (1.0 - t * t)
			vel += forward * a * dt
			long_demand = a
	elif thr < -0.01:
		if fwd_speed > 0.1:
			vel -= forward * minf(brake_decel * mag * dt, fwd_speed)
			long_demand = brake_decel * mag
		else:
			var t := clampf(-fwd_speed / max_reverse_speed, 0.0, 1.0)
			var a := reverse_accel * mag * (1.0 - t * t)
			vel -= forward * a * dt
			long_demand = a
	else:
		var drag := coast_drag + 3.0 * (1.0 - clampf(absf(fwd_speed) / 2.0, 0.0, 1.0))
		vel -= forward * fwd_speed * minf(drag * dt, 1.0)

	
	if fwd_speed > max_speed:
		vel -= forward * (fwd_speed - max_speed) * 2.0 * dt

	
	if hold_on_slopes and grounded:
		var g := state.total_gravity
		if n.dot(-g.normalized()) > 0.6:
			var slope_g := g - n * g.dot(n)
			var hold := (1.0 - clampf(absf(fwd_speed) / 1.5, 0.0, 1.0)) * (1.0 - mag)
			vel -= slope_g * hold * dt

	
	var side_speed := vel.dot(right)
	var want := side_speed * grip                                 
	var long_frac := clampf(long_demand / maxf(brake_decel, 1.0), 0.0, 1.0)
	var cap_peak := tire_grip * (1.0 - power_slip * long_frac)
	var cap := cap_peak * (slide_grip_ratio if is_sliding else 1.0)

	if not is_sliding and absf(want) > cap_peak:
		is_sliding = true
		cap = cap_peak * slide_grip_ratio
		if debug_print:
			print("slip begint")
	elif is_sliding and absf(want) < cap * slide_recover:
		is_sliding = false
		cap = cap_peak
		if debug_print:
			print("grip terug")

	var lat := clampf(want, -cap, cap)
	var dv_side := clampf(lat * dt, -absf(side_speed), absf(side_speed))
	vel -= right * dv_side
	slip_angle = atan2(absf(side_speed), maxf(absf(fwd_speed), 1.0))


	var lat_used := absf(dv_side) / dt
	if absf(fwd_speed) > 0.5:
		vel -= forward * signf(fwd_speed) * lat_used * corner_scrub * dt
	if is_sliding:
		var sp := vel.length()
		if sp > 0.5:
			vel -= (vel / sp) * slide_drag * clampf(absf(side_speed) / 3.0, 0.0, 1.0) * dt

	
	if grounded:
		vel -= n * stick_force * dt
	state.linear_velocity = vel

	
	var speed_now := vel.dot(forward)
	var steer_factor := clampf(speed_now / 6.0, -1.0, 1.0)
	var falloff := 1.0 / (1.0 + absf(speed_now) * turn_speed_falloff)
	var target_yaw := steer_smooth * turn_speed * steer_factor * falloff

	var max_slip := deg_to_rad(max_slip_angle)
	if target_yaw * side_speed > 0.0:
		var over := clampf((slip_angle - max_slip * 0.6) / (max_slip * 0.4), 0.0, 1.0)
		target_yaw *= 1.0 - over
	yaw_rate = move_toward(yaw_rate, target_yaw, turn_response * dt)

	var ang := state.angular_velocity
	var tilt := ang - up * ang.dot(up)
	if align_strength > 0.0 and grounded and n.dot(up) > 0.5:
		var target_tilt := up.cross(n) * align_strength
		tilt = tilt.lerp(target_tilt, clampf(align_strength * dt, 0.0, 1.0))
	state.angular_velocity = tilt + up * yaw_rate
	
	
	
