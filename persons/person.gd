extends StaticBody3D

@onready var label = $Label3D
@onready var collision_shape = $CollisionShape3D

var player: CharacterBody3D
var distance :float = 0.0

func _ready() -> void:
  player = get_tree().current_scene.get_node_or_null("Player")
  snap_to_ground()

func snap_to_ground() -> void:
  var bottom_offset = collision_shape.shape.get_height() / 2.0
  var check_position = global_position
  var space_state = get_world_3d().direct_space_state
  
  # Check downward
  var query_down = PhysicsRayQueryParameters3D.create(check_position, check_position + Vector3.DOWN * 100)
  query_down.exclude = [self]
  var result_down = space_state.intersect_ray(query_down)
  
  # Check upward (in case person is below ground)
  var query_up = PhysicsRayQueryParameters3D.create(check_position, check_position + Vector3.UP * 100)
  query_up.exclude = [self]
  var result_up = space_state.intersect_ray(query_up)
  
  if result_down:
    global_position.y = result_down.position.y + bottom_offset
  elif result_up:
    global_position.y = result_up.position.y + bottom_offset

func _process(_delta: float) -> void:  
  if not is_instance_valid(player):
    return
  
  var origin := global_transform.origin
  var target := player.global_transform.origin
  var direction = (target - origin).normalized()
  
  # Calculate pitch toward player (max 15 degrees / ~0.26 radians)
  var pitch = atan2(origin.y - target.y, Vector2(direction.x, direction.z).length())
  pitch = clamp(pitch, 0,0)
  
  target.y = origin.y  # keep upright; rotate only around Y
  look_at(target, Vector3.UP)
  rotate_y(PI)  # flip to face opposite direction (model forward is reversed)
  rotation.x = pitch  # pitch toward the player

  # get distance to player
  distance = origin.distance_to(player.global_transform.origin)
  if is_instance_valid(label):
    label.text = "Distance: %.2f" % distance

  if distance < 2.0:
    player.show_interact_prompt(self)
  if distance >= 2.0 and distance < 3.0:
    player.show_interact_prompt(null)

func get_look_point() -> Vector3:
  # if CollisionShape3D exists, use its extents to find a better look point
  var shape_node = get_node_or_null("CollisionShape3D")
  if shape_node:
    var height = shape_node.shape.get('height')
    return shape_node.global_transform.origin + Vector3(0, height / 4, 0)
  return global_transform.origin
