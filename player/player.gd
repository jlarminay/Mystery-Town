extends CharacterBody3D

@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var notices = $Notices
@onready var dialogue = $Dialogue

@export var move_speed :float = 8.0
@export var jump_force :float = 4.5
@export var gravity :float = 12.0
@export var mouse_sens :float = 0.1

enum PlayerMode { PLAY, DIALOGUE }
var mode: PlayerMode = PlayerMode.PLAY

var interact_target :StaticBody3D = null
var y_velocity :float = 0.0
var pitch :float = 0.0
var camera_original_pos :Vector3 = Vector3.ZERO
var camera_original_rot :Vector3 = Vector3.ZERO

func _ready() -> void:
  _set_play_mode()
  notices.hide_interact_prompt()
  dialogue.hide_dialogue()

func _unhandled_input(event: InputEvent) -> void:
  if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    return

  if event is InputEventMouseMotion and mode == PlayerMode.PLAY:
    rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
    pitch = clamp(pitch - (event.relative.y * mouse_sens), -89.0, 89.0)
    if camera:
      camera.rotation_degrees.x = pitch

func _physics_process(delta: float) -> void:
  if mode == PlayerMode.PLAY:
    _move_player(delta)

  if mode == PlayerMode.DIALOGUE:
    # E key to continue linear dialogue (only if no responses)
    if Input.is_action_just_pressed("interact") and dialogue.current_responses.size() == 0:
      dialogue.advance()
  elif Input.is_action_just_pressed("interact") and interact_target != null:
    _start_interaction()

func _start_interaction() -> void:
  mode = PlayerMode.DIALOGUE
  Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

  # Align view toward target
  move_camera(true)

  # Hide prompt and start dialogue
  notices.hide_interact_prompt()
  var dialogue_node = interact_target.get_node_or_null("DialogueNode")
  if dialogue_node:
    dialogue.begin(dialogue_node, {}, interact_target)
  if interact_target.has_method("start_dialogue"):
    interact_target.start_dialogue()

func _end_interaction() -> void:
  mode = PlayerMode.PLAY
  dialogue.hide_dialogue()
  move_camera(false)
  Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
  # Re-check if still near interact target to restore prompt
  if interact_target != null:
    notices.show_interact_prompt()
  else:
    notices.hide_interact_prompt()

func _on_dialogue_ended() -> void:
  # Called when dialogue ends naturally (graph termination)
  _end_interaction()

func _move_player(delta: float) -> void:
  var input_dir = Vector3.ZERO
  if Input.is_action_pressed("forward"):
    input_dir -= transform.basis.z
  if Input.is_action_pressed("backward"):
    input_dir += transform.basis.z
  if Input.is_action_pressed("left"):
    input_dir -= transform.basis.x
  if Input.is_action_pressed("right"):
    input_dir += transform.basis.x

  input_dir.y = 0
  input_dir = input_dir.normalized() * move_speed

  if is_on_floor():
    if Input.is_action_just_pressed("jump"):
      y_velocity = jump_force
    else:
      y_velocity = 0.0
  else:
    y_velocity -= gravity * delta

  velocity = Vector3(input_dir.x, y_velocity, input_dir.z)
  move_and_slide()

func _set_play_mode() -> void:
  mode = PlayerMode.PLAY
  Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func show_interact_prompt(target: StaticBody3D) -> void:
  # Do not show prompts while in dialogue mode
  if mode != PlayerMode.PLAY:
    return
  if target != null:
    notices.show_interact_prompt()
    interact_target = target
  else:
    notices.hide_interact_prompt()
    interact_target = null

func move_camera(dialogue_mode: bool) -> void:
  if dialogue_mode:
    # Store original camera position and rotation
    camera_original_pos = camera.global_position
    camera_original_rot = camera.rotation_degrees
    
    # Get target center point
    var target_center :Vector3 = interact_target.get_look_point()
    
    # Place camera 1 unit away from target along its current approach direction
    var direction := camera_original_pos - target_center
    if direction.length_squared() < 0.0001:
      direction = global_transform.origin - target_center
    if direction.length_squared() < 0.0001:
      direction = Vector3.BACK
    direction = direction.normalized()
    
    var camera_pos = target_center + direction * 1.2
    camera_pos.y = target_center.y
    camera.global_position = camera_pos
    
    # Face the target
    camera.look_at(target_center, Vector3.UP)
  else:
    # Restore camera to original position and rotation
    camera.global_position = camera_original_pos
    camera.rotation_degrees = camera_original_rot
    pitch = camera_original_rot.x
