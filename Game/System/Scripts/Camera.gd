extends Camera2D

const PROCESS_PRIORITY = 100;

enum CameraState {
	TARGET_IN_AIR,
	TARGET_ON_FLOOR,
	TARGET_CENTERED
}

@export var target: Node2D;
@export var camera_window_floor: Rect2 = Rect2(-16.0, -24.0, 32.0, 8.0);
@export var camera_window_air: Rect2 = Rect2(-16.0, -24.0, 32.0, 64.0);

var camera_state: CameraState = CameraState.TARGET_IN_AIR;
var auto_camera_state: bool = true;
var camera_window_current: Rect2 = Rect2(camera_window_air);
var camera_window_assigned: Rect2 = Rect2(camera_window_air);
var camera_window_tween: Tween;

func _ready() -> void:
	# Just in case.
	process_priority = PROCESS_PRIORITY;
	process_physics_priority = PROCESS_PRIORITY;
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS;
	
	# Automatically set camera boundaries.
	var parent := get_parent();
	
	var bounds := parent.find_child("LevelBounds");
	
	if is_instance_valid(bounds):
		var bounds_rect := Rect2(bounds.global_position, bounds.size);
		
		limit_left = roundi(bounds_rect.position.x);
		limit_right = roundi(bounds_rect.end.x);
		limit_top = roundi(bounds_rect.position.y);
		limit_bottom = roundi(bounds_rect.end.y);
	
	center_on_target();

func _physics_process(_delta: float) -> void:
	if !is_instance_valid(target):
		return;
	
	_update_camera_state();
	
	var target_window := Rect2(camera_window_current);
	target_window.position += target.global_position;
	
	global_position.x = clampf(global_position.x, target_window.position.x, target_window.end.x);
	global_position.y = clampf(global_position.y, target_window.position.y, target_window.end.y);

func _update_camera_state():
	if !is_instance_valid(target):
		return;
	
	if auto_camera_state && target is FizzyPlatformerBody:
		if target.on_floor_raw:
			camera_state = CameraState.TARGET_ON_FLOOR;
		else:
			camera_state = CameraState.TARGET_IN_AIR;
	
	match camera_state:
		CameraState.TARGET_ON_FLOOR:
			morph_camera_window(camera_window_floor);
		CameraState.TARGET_IN_AIR:
			morph_camera_window(camera_window_air);
		CameraState.TARGET_CENTERED:
			morph_camera_window(Rect2(0.0, 0.0, 0.0, 0.0));

func morph_camera_window(new_window: Rect2):
	if !is_instance_valid(target) || camera_window_assigned.is_equal_approx(new_window):
		return;
	
	camera_window_assigned = Rect2(new_window);

	var target_window_old := Rect2(camera_window_current);
	target_window_old.position += target.global_position;
	
	var target_clamped_old := Vector2(0.0, 0.0);
	target_clamped_old.x = clampf(global_position.x, target_window_old.position.x, target_window_old.end.x);
	target_clamped_old.y = clampf(global_position.y, target_window_old.position.y, target_window_old.end.y);
	
	camera_window_current = camera_window_assigned.expand(target_clamped_old - target.global_position);
	
	if camera_window_tween:
		camera_window_tween.kill();
	
	camera_window_tween = create_tween();
	camera_window_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS);
	camera_window_tween.set_ease(Tween.EASE_IN_OUT);
	camera_window_tween.set_trans(Tween.TRANS_SINE);
	camera_window_tween.tween_property(self, "camera_window_current", camera_window_assigned, 0.5);

func center_on_target():
	if is_instance_valid(target):
		global_position = target.global_position + camera_window_current.get_center();
