extends CharacterBody3D

@export var look_sensitivity := 0.0025
@export var headbob_move_amount := 0.06
@export var headbob_frequency := 2.4

@export_group("Movement Speed")
@export var speed := 7.0
@export var jump_velocity := 4.5
@export var sprint_speed := 8.5
@export var ground_acceleration := 14.0
@export var ground_deceleration := 10.0
@export var ground_friction := 6.0

@export_group("Air Movement")
@export var air_cap := 0.85
@export var air_acceleration := 800.0
@export var air_move_speed := 500.0

@export_group("Freefly Movement")
@export var freefly_speed: float = 10.0
@export var freefly_sprint_speed: float = 15.0

## Translated direction in which the player wants to move
var direction := Vector3.ZERO
## Used in normal gameplay to disallow sprinting sideways/backwards
var is_sprinting := false
var dev_console := false
var freefly := false
var headbob_time := 0.0


func _ready():
	# Set all cosmetics to not be visible in first-person camera
	for child in %WorldModel.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)


func _unhandled_input(event: InputEvent) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.is_action_just_pressed("toggle_console") and !dev_console:
		$Collider.set_deferred("disabled", true)
		freefly = true
	
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * look_sensitivity)
			%Camera3D.rotate_x(-event.relative.y * look_sensitivity)
			%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, deg_to_rad(-90), deg_to_rad(90))


func headbob_effect(delta):
	headbob_time += delta * velocity.length()
	%Camera3D.transform.origin = Vector3(
		cos(headbob_time * headbob_frequency * 0.5) * headbob_move_amount,
		sin(headbob_time * headbob_frequency) * headbob_move_amount,
		0
	)


func _process(delta: float) -> void:
	pass


func handle_air_physics(delta: float) -> void:
	velocity += get_gravity() * delta
	
	# Quake/Source style air movement
	var current_speed_in_direction = velocity.dot(direction)
	var capped_speed = min((air_move_speed * direction).length(), speed * air_cap)
	var add_speed_til_cap = capped_speed - current_speed_in_direction
	if add_speed_til_cap > 0:
		var accel_speed := air_acceleration * air_move_speed * delta
		accel_speed = min(accel_speed, add_speed_til_cap)
		velocity += (accel_speed * direction).normalized()


func handle_ground_physics(delta: float) -> void:
	var current_speed := 0.0
	if is_sprinting:
		current_speed = sprint_speed
	else:
		current_speed = speed
	
	var current_speed_in_direction = velocity.dot(direction)
	var add_speed_til_cap = current_speed - current_speed_in_direction
	if add_speed_til_cap:
		var accel_speed = ground_acceleration * current_speed * delta
		accel_speed = min(accel_speed, add_speed_til_cap)
		velocity += accel_speed * direction
	
	var control = max(velocity.length(), ground_deceleration)
	var drop = control * ground_friction * delta
	var new_speed = max(velocity.length() - drop, 0.0)
	if velocity.length() > 0:
		new_speed /= velocity.length()
	velocity *= new_speed
	
	#if direction:
		#velocity.x = direction.x * current_speed
		#velocity.z = direction.z * current_speed
	#else:
		#velocity.x = move_toward(velocity.x, 0, current_speed)
		#velocity.z = move_toward(velocity.z, 0, current_speed)
	
	
	if Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	
	headbob_effect(delta)


func handle_freefly() -> void:
	var current_speed = freefly_speed
	var vertical_velocity = 0
	
	if Input.is_action_pressed("sprint"):
		current_speed = freefly_sprint_speed
	if Input.is_action_pressed("jump"):
		vertical_velocity += jump_velocity
	if Input.is_action_pressed("crouch"):
		vertical_velocity -= jump_velocity
	
	velocity = direction * current_speed
	velocity.y = vertical_velocity


func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	direction = (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	is_sprinting = Input.is_action_pressed("sprint") and input_dir.y < 0
	
	if freefly:
		handle_freefly()
	elif is_on_floor():
		handle_ground_physics(delta)
	else: 
		handle_air_physics(delta)
	
	move_and_slide()
