extends CharacterBody3D

const SPEED = 5.0
const SPRINT_MULTIIPLIER = 2
const JUMP_VELOCITY = 4.5

@export var look_sensitivity: float = 0.0025
@export var freefly: bool = false

var direction: Vector3
var dev_console: bool = false

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

func _process(delta: float) -> void:
	pass

func handle_air_physics(delta: float) -> void:
	velocity += get_gravity() * delta

func handle_ground_physics(delta: float) -> void:
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

func handle_freefly(delta: float) -> void:
	var speed_multiplier = 1
	var vertical_velocity = 0
	
	if Input.is_action_pressed("sprint"):
		speed_multiplier = SPRINT_MULTIIPLIER
	if Input.is_action_pressed("jump"):
		vertical_velocity += JUMP_VELOCITY
	if Input.is_action_pressed("crouch"):
		vertical_velocity -= JUMP_VELOCITY
	
	velocity = direction * SPEED * speed_multiplier
	velocity.y = vertical_velocity
		

func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if freefly:
		handle_freefly(delta)
	elif is_on_floor():
		handle_ground_physics(delta)
	else:
		handle_air_physics(delta)
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()
