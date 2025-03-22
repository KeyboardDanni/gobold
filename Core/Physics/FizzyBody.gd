extends CharacterBody2D

class_name FizzyBody;

const COLLISION_MOVE_MIN = 0.0001;
const DEFAULT_MAX_CHECKS = 4;

## Replacement for Godot's built-in move_and_slide, allowing more control over the collision.
##  Callback signature is (motion_step: Vector2, collision: KinematicCollision2D, result: FizzyMoveResult) -> void
##  The remaining distance and resulting motion can be customized by editing the FizzyMoveResult object directly.
func fizzy_move(motion: Vector2, delta: float, result: FizzyMoveResult, handler: Callable = Callable(), max_checks: int = DEFAULT_MAX_CHECKS) -> void:
	var initial := motion * delta;
	result.new_motion = motion;
	result.remaining = initial;
	
	for i in max_checks:
		var motion_step := result.remaining;
		
		var collision := move_and_collide(result.remaining);
		
		if (!collision):
			break;
		
		var normal := collision.get_normal();
		
		result.remaining = collision.get_remainder().slide(normal);
		result.new_motion = result.new_motion.slide(normal);
		
		if handler.is_valid():
			handler.call(motion_step, collision, result);
		
		if result.remaining.length() <= COLLISION_MOVE_MIN:
			break;

## Ensures the body is flush with the floor. Useful for downward slope correction.
##  Returns true if a floor snap occurred. Otherwise returns false.
##  Callback signature is (motion_step: Vector2, collision: KinematicCollision2D, result: FizzySnapResult) -> bool
func fizzy_snap_to_floor(floor_normal: Vector2, max_distance: float, result: FizzySnapResult, handler: Callable = Callable()) -> bool:
	if max_distance <= 0.0:
		return false;
	
	var motion := -floor_normal * max_distance;
	var collision := move_and_collide(motion, true);
	
	if collision:
		var normal = collision.get_normal();
		
		result.new_motion = velocity.slide(normal);
		result.new_floor_vector = normal;
		
		if handler.is_valid():
			if !handler.call(motion, collision, result):
				return false;
		
		position += collision.get_travel();
		
		return true;
	
	return false;
