extends FizzyPlatformerBody

@onready var sprite: Sprite2D = $Sprite2D;
@onready var anim_player: AnimationPlayer = $Sprite2D/AnimationPlayer;

var player_input: bool = true;

func _physics_process(delta: float) -> void:
	if player_input:
		_get_player_input();
		
	fizzy_move_platformer(delta);
	_do_animation();

func _get_player_input():
	input_walk = WalkDirection.NEUTRAL;
	
	var left := Input.is_action_pressed("game_left");
	var right := Input.is_action_pressed("game_right");
	
	if left && !right:
		input_walk = WalkDirection.LEFT;
	if right && !left:
		input_walk = WalkDirection.RIGHT;
	
	input_jump = Input.is_action_pressed("game_jump");

func _do_animation():
	sprite.flip_h = (facing_direction == FacingDirection.LEFT);
	
	if on_floor_raw:
		if absf(velocity.x) < 0.0001:
			change_animation("default");
		else:
			change_animation("walk");
	else:
		if velocity.y < 0.0:
			change_animation("jump");
		else:
			change_animation("fall");

func change_animation(animation_name: String):
	if anim_player.assigned_animation != animation_name:
		anim_player.play(animation_name);
