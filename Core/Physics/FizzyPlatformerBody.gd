extends FizzyBody

class_name FizzyPlatformerBody;

enum FacingDirection {
	LEFT,
	RIGHT
}

enum WalkDirection {
	NEUTRAL,
	LEFT,
	RIGHT
}

@export var facing_direction: FacingDirection = FacingDirection.RIGHT;

@export_category("Movement Speed")
@export var walk_speed_max: float = 250.0;
@export var walk_speed_max_slope_factor: float = 100.0;
@export var walk_acceleration: float = 680.0;
@export var walk_deceleration: float = 1200.0;
@export var walk_deceleration_air: float = 300.0;
@export var gravity := 800.0;
@export var jump_speed: float = 425.0;
@export var jump_cancel_speed: float = 1000.0;
@export var max_velocity: Vector2 = Vector2(960.0, 960.0);

@export_category("Movement Tweaks")
@export var coyote_time: float = 0.2;
@export var floor_angle_max: float = AngleUtil.ANGLE_60_DEGREES;
@export var floor_snap_distance: float = 12.0;

var input_walk: WalkDirection = WalkDirection.NEUTRAL;
var input_jump: bool = false;
var _input_jump_held: bool = false;
var on_floor: bool = false;
var on_floor_raw: bool = false;
var floor_vector = Vector2.UP;
var air_time := 0.0;

# Defined at node level to avoid creation/deletion costs for every collision check.
var temp_move_result := FizzyMoveResult.new();
var temp_snap_result := FizzySnapResult.new();

var _handle_collision_gravity = _handle_collision.bind(true);

func _physics_process(delta: float) -> void:
	fizzy_move_platformer(delta);

func fizzy_move_platformer(delta: float):
	_update_velocity_walk(delta);
	_update_velocity_air(delta);
	
	_move_and_update_floor(delta);
	
	_update_facing_direction();

func jump(strength: float):
	velocity.y = -strength;
	on_floor_raw = false;
	on_floor = false;
	floor_vector = Vector2.UP
	air_time = 0.0;

func _update_velocity_walk(delta: float):
	# Separate our current velocity into "velocity along floor" and
	#  "velocity away from floor". We use "velocity along floor" as our walking
	#  velocity.
	var walk_velocity := velocity.slide(floor_vector);
	var floor_velocity := velocity - walk_velocity;
	var walk_direction: Vector2;
	var accel := 0.0;
	
	# Handle acceleration/deceleration based on user input, current direction,
	#  and whether we're in the air or not.
	if input_walk == WalkDirection.RIGHT:
		walk_direction = -floor_vector.orthogonal();
		
		if velocity.x >= 0.0:
			accel = walk_acceleration;
		else:
			accel = walk_deceleration;
	elif input_walk == WalkDirection.LEFT:
		walk_direction = floor_vector.orthogonal();
		
		if velocity.x <= 0.0:
			accel = walk_acceleration;
		else:
			accel = walk_deceleration;
	else:
		# We don't set our walk direction here, so it remains a zero vector. This
		#  makes it decelerate to a stop (anything times zero...)
		accel = walk_deceleration if on_floor_raw else walk_deceleration_air;
	
	var walk_speed_max_temp = walk_speed_max + walk_speed_max_slope_factor * walk_direction.y;
	
	# Apply acceleration/deceleration.
	walk_velocity = walk_velocity.move_toward(walk_direction * walk_speed_max_temp, accel * delta);
	velocity = walk_velocity + floor_velocity;

func _update_velocity_air(delta: float):
	# Jumping
	if input_jump:
		if on_floor && !_input_jump_held:
			jump(jump_speed);
		
		_input_jump_held = true;
	else:
		_input_jump_held = false;
	
	# Jump canceling
	if !on_floor_raw && velocity.y < 0.0 && !_input_jump_held:
		velocity.y += jump_cancel_speed * delta;

func _move_and_update_floor(delta: float):
	# Clamp to max velocity.
	velocity.x = clampf(velocity.x, -max_velocity.x, max_velocity.x);
	velocity.y = clampf(velocity.y, -max_velocity.y, max_velocity.y);
	
	var walk_velocity := velocity.slide(floor_vector);
	var was_on_floor_raw = on_floor_raw;
	on_floor_raw = false;
	
	# We move our character twice, once for the horizontal/floor-aligned axis,
	#  and again for the vertical axis (the gravity pass). But we also want to
	#  handle things differently if we're on the floor versus in the air.
	if was_on_floor_raw:
		_move_and_collide_on_floor(walk_velocity, delta);
	else:
		_move_and_collide_in_air(delta);
	
	# If we suddenly left the floor, check if we need to make the character hug
	#  a downward slope. If so, snap to it and adjust the floor vector.
	if was_on_floor_raw && !on_floor_raw:
		var snap_distance: float = floor_snap_distance + walk_velocity.length() * delta;
		var floor_snapped := fizzy_snap_to_floor(Vector2.UP, snap_distance, temp_snap_result);
		on_floor_raw = floor_snapped;
		
		if floor_snapped:
			velocity = temp_snap_result.new_motion;
			floor_vector = temp_snap_result.new_floor_vector;
	
	# For coyote time
	if !on_floor_raw:
		air_time += delta;
	else:
		air_time = 0.0;
	
	on_floor = (on_floor_raw || (on_floor && air_time < coyote_time));
	
	# If we're in the air for long enough, reset the stale floor vector.
	if !on_floor:
		floor_vector = Vector2.UP;

func _move_and_collide_on_floor(walk_velocity: Vector2, delta: float):
	# Move the character along the floor.
	if walk_velocity.length() > COLLISION_MOVE_MIN:
		fizzy_move(walk_velocity, delta, temp_move_result, _handle_collision, 4);
	
		velocity = temp_move_result.new_motion;
	else:
		velocity = walk_velocity;
	
	# If we're moving on the floor and not the air, apply gravity as part of the floor check.
	#  Otherwise it'd interfere with walking on slopes (the gravity would make the character
	#  slide down slowly).
	fizzy_move(Vector2.DOWN * gravity * delta, delta, temp_move_result, _handle_collision_gravity, 4);
	
	velocity += temp_move_result.new_motion;

func _move_and_collide_in_air(delta: float):
	# Downward gravity is only applied if we're currently in the air.
	velocity.y += gravity * delta;
	
	# Here in case we add support for changing the direction of gravity.
	var horizontal_velocity := velocity.slide(Vector2.DOWN);
	var gravity_velocity := velocity.project(Vector2.DOWN);
	
	# Horizontal movement.
	if horizontal_velocity.length() > COLLISION_MOVE_MIN:
		fizzy_move(horizontal_velocity, delta, temp_move_result, _handle_collision, 4);
	
		velocity = temp_move_result.new_motion;
	else:
		velocity = horizontal_velocity;
	
	# Vertical movement (the gravity pass).
	fizzy_move(gravity_velocity, delta, temp_move_result, _handle_collision_gravity, 4);
	
	velocity += temp_move_result.new_motion;

func _handle_collision(motion_step: Vector2, collision: KinematicCollision2D, result: FizzyMoveResult, gravity_pass: bool = false) -> void:
	var normal := collision.get_normal();
	var floor_angle := absf(angle_difference(normal.angle(), AngleUtil.ANGLE_UP));
	
	# Check if this looks like a floor. It's a floor if it's angled close enough to one. Otherwise
	#  we treat it like a wall or ceiling.
	#  This second check fixes not being able to jump up a slope if horizontal speed is high enough.
	#  Otherwise, the character will land on the floor again even though they're going upward.
	#  But we still want to do the floor check if the character has spent more than one frame in the air,
	#  or else they'll fly off when landing on a slope.
	if floor_angle <= floor_angle_max && (motion_step.y >= 0.0001 || air_time > 0.0):
		# If the floor vector was set during the walk pass, don't do it during the
		#  gravity pass unless the gravity pass traveled some distance. Fixes an issue where moving
		#  exactly the right distance into the bottom of a slope causes the bottom floor vector to
		#  get overridden by the slope floor vector, causing the momentum to get heavily canceled
		if !on_floor_raw || !gravity_pass || collision.get_travel().length() > 0.1:
			floor_vector = normal;
		
		on_floor_raw = true;
		
		# If this is the gravity pass, we don't want our character to slide when landing on a slope.
		#  Otherwise, we adjust our sliding result as if we collided with a flat, non-sloped floor.
		#  If you want slopes to act slippery, feel free to gate this whole if/else behind an if
		#  condition of your choosing.
		if gravity_pass:
			result.new_motion = Vector2.ZERO;
			result.remaining = Vector2.ZERO;
		else:
			result.new_motion = result.new_motion.slide(Vector2.UP);
			result.remaining = result.remaining.project(Vector2.UP);

func _update_facing_direction():
	var min_facing_velocity := 0.0001 if on_floor_raw || velocity.y > 0.0 else -100.0;
	
	# When on floor, update facing direction based on movement.
	if on_floor_raw && velocity.x > min_facing_velocity:
		facing_direction = FacingDirection.RIGHT;
	elif on_floor_raw && velocity.x < -min_facing_velocity:
		facing_direction = FacingDirection.LEFT;
	# When in the air, update facing direction based on input and movement.
	elif input_walk == WalkDirection.RIGHT && velocity.x > min_facing_velocity:
		facing_direction = FacingDirection.RIGHT;
	elif input_walk == WalkDirection.LEFT && velocity.x < -min_facing_velocity:
		facing_direction = FacingDirection.LEFT;
