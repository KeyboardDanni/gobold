extends Node

const REFRESH_RATE_AUTO_UPDATE_RATE = 2.0;
const SAVE_WINDOW_UPDATE_RATE = 1.0;

enum VSyncMode {
	OFF,
	ON
}

enum DisplayMode {
	WINDOWED,
	FULLSCREEN
}

enum StretchMode {
	STRETCH_TO_FIT,
	FORCE_INTEGER_SCALE
}

enum PhysicsLerping {
	FORCE_OFF,
	AUTOMATIC,
	FORCE_ON
}

enum LowLatencyMode {
	OFF,
	AUTOMATIC,
	ON
}

var queue_apply_settings := false;
var refresh_rate_update_timer := 0.0;
var save_window_state_timer := 0.0;
var current_refresh_rate := 0.0;

var _best_fit_last_display_mode: int = -1;
var _best_fit_last_window_scale: int = -2;

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS;
	
	GameSettings.define_setting(&"display.vsync", VSyncMode.ON);
	GameSettings.define_setting(&"display.mode", DisplayMode.FULLSCREEN);
	GameSettings.define_setting(&"display.stretch_mode", StretchMode.STRETCH_TO_FIT);
	GameSettings.define_setting(&"display.window_scale", 0);
	GameSettings.define_setting(&"display.maximized", false);
	GameSettings.define_setting(&"display.fps_limit", 0);
	
	GameSettings.define_setting(&"display.physics_lerp", PhysicsLerping.AUTOMATIC, GameSettings.SETTING_FLAG_ADVANCED);
	GameSettings.define_setting(&"display.low_latency", LowLatencyMode.AUTOMATIC, GameSettings.SETTING_FLAG_ADVANCED);
	
	GameSettings.setting_changed.connect(self.setting_changed);
	GameSettings.settings_loaded.connect(self.settings_loaded);
	
	apply_settings();

func _process(_delta):
	if queue_apply_settings:
		queue_apply_settings = false;
		apply_settings();

func _physics_process(delta):
	refresh_rate_update_timer += delta;
	save_window_state_timer += delta;
	
	if refresh_rate_update_timer >= REFRESH_RATE_AUTO_UPDATE_RATE:
		_update_refresh_rate();
		refresh_rate_update_timer -= REFRESH_RATE_AUTO_UPDATE_RATE;
	
	if Input.is_action_just_pressed("system_fullscreen"):
		toggle_fullscreen();
	
	if save_window_state_timer >= SAVE_WINDOW_UPDATE_RATE:
		_save_window_state();
		save_window_state_timer -= SAVE_WINDOW_UPDATE_RATE;

func toggle_fullscreen():
	if GameSettings.get_setting(&"display.mode") != DisplayMode.FULLSCREEN:
		GameSettings.set_setting(&"display.mode", DisplayMode.FULLSCREEN);
	else:
		GameSettings.set_setting(&"display.mode", DisplayMode.WINDOWED);

func setting_changed(keypath: StringName, _new_value):
	if keypath.begins_with("display."):
		queue_apply_settings = true;

func settings_loaded():
	queue_apply_settings = true;

func apply_settings():
	_update_refresh_rate();
	
	match GameSettings.get_setting(&"display.vsync") as VSyncMode:
		VSyncMode.ON:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED);
		VSyncMode.OFF:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);
	
	match GameSettings.get_setting(&"display.mode") as DisplayMode:
		DisplayMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN);
		DisplayMode.WINDOWED:
			var maximized := bool(GameSettings.get_setting(&"display.maximized"));
			
			if maximized:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED);
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);
				adjust_window.call_deferred();
	
	match GameSettings.get_setting(&"display.stretch_mode") as StretchMode:
		StretchMode.STRETCH_TO_FIT:
			get_window().set_content_scale_stretch(Window.ContentScaleStretch.CONTENT_SCALE_STRETCH_FRACTIONAL);
		StretchMode.FORCE_INTEGER_SCALE:
			get_window().set_content_scale_stretch(Window.ContentScaleStretch.CONTENT_SCALE_STRETCH_INTEGER);
	
	var fps_limit := roundi(GameSettings.get_setting(&"display.fps_limit"));
	
	fps_limit = clampi(fps_limit, 20, 1000) if fps_limit > 0 else 0;
	Engine.max_fps = fps_limit;
	
	match GameSettings.get_setting(&"display.physics_lerp") as PhysicsLerping:
		PhysicsLerping.AUTOMATIC:
			_update_auto_physics_lerp();
		PhysicsLerping.FORCE_OFF:
			get_tree().set_physics_interpolation_enabled(false);
		PhysicsLerping.FORCE_ON:
			get_tree().set_physics_interpolation_enabled(true);
	
	match GameSettings.get_setting(&"display.low_latency") as LowLatencyMode:
		LowLatencyMode.AUTOMATIC:
			_update_auto_low_latency();
		LowLatencyMode.ON:
			RenderingServer.set_cpu_gpu_sync_mode(RenderingServer.CPU_GPU_SYNC_SEQUENTIAL);
		LowLatencyMode.OFF:
			RenderingServer.set_cpu_gpu_sync_mode(RenderingServer.CPU_GPU_SYNC_PARALLEL);

func _update_refresh_rate():
	current_refresh_rate = DisplayServer.screen_get_refresh_rate();
	
	if GameSettings.get_setting(&"display.physics_lerp") == PhysicsLerping.AUTOMATIC:
		_update_auto_physics_lerp();
	if GameSettings.get_setting(&"display.low_latency") == LowLatencyMode.AUTOMATIC:
		_update_auto_low_latency();

func _update_auto_physics_lerp():
	var physics_rate := Engine.physics_ticks_per_second;
	var fps_limit := Engine.max_fps;
	
	if fps_limit > 0:
		current_refresh_rate = minf(current_refresh_rate, fps_limit);
	
	var refresh_rate_different := (absf(physics_rate - current_refresh_rate) > 1.0);
	var was_enabled := get_tree().is_physics_interpolation_enabled();
	
	if refresh_rate_different != was_enabled:
		get_tree().set_physics_interpolation_enabled(refresh_rate_different);

func _update_auto_low_latency():
	if current_refresh_rate >= 118.0:
		RenderingServer.set_cpu_gpu_sync_mode(RenderingServer.CPU_GPU_SYNC_PARALLEL);
	else:
		RenderingServer.set_cpu_gpu_sync_mode(RenderingServer.CPU_GPU_SYNC_SEQUENTIAL);

func _save_window_state():
	var display_mode := DisplayServer.window_get_mode();
	
	if display_mode != DisplayServer.WINDOW_MODE_WINDOWED \
			&& display_mode != DisplayServer.WINDOW_MODE_MAXIMIZED:
		return;
	
	var is_maximized := display_mode == DisplayServer.WINDOW_MODE_MAXIMIZED;
	var maximized_setting := bool(GameSettings.get_setting(&"display.maximized"));
	
	if maximized_setting != is_maximized:
		GameSettings.set_setting(&"display.maximized", is_maximized);

func adjust_window(force: bool = false) -> bool:
	var display_mode := DisplayServer.window_get_mode();
	var window_scale := int(GameSettings.get_setting(&"display.window_scale"));
	
	if display_mode != DisplayServer.WINDOW_MODE_WINDOWED:
		return false;
	
	if !force && _best_fit_last_display_mode == display_mode && _best_fit_last_window_scale == window_scale:
		return true;
	
	_best_fit_last_display_mode = display_mode;
	_best_fit_last_window_scale = window_scale;
	
	var window := get_tree().root;
	var decoration_size := window.get_size_with_decorations() - window.size;
	var game_size := window.content_scale_size;
	var desktop_rect := DisplayServer.get_display_safe_area();
	@warning_ignore("integer_division")
	var max_scale_x := (desktop_rect.size.x - decoration_size.x) / game_size.x;
	@warning_ignore("integer_division")
	var max_scale_y := (desktop_rect.size.y - decoration_size.y) / game_size.y;
	var max_scale := mini(max_scale_x, max_scale_y);
	
	if window_scale > 0:
		max_scale = mini(max_scale, window_scale);
	
	var new_size := Vector2i(game_size.x * max_scale, game_size.y * max_scale);
	
	DisplayServer.window_set_position(desktop_rect.get_center() - (new_size / 2));
	DisplayServer.window_set_size(new_size);
	
	return true;
