extends Node

const REFRESH_RATE_AUTO_UPDATE_RATE = 2.0;

enum VSyncMode {
	Off,
	On
}

enum DisplayMode {
	Windowed,
	Fullscreen
}

enum ScaleMode {
	StretchToFit,
	ForceIntegerScale
}

enum PhysicsLerping {
	ForceOff,
	Automatic,
	ForceOn
}

enum LowLatencyMode {
	Off,
	Automatic,
	On
}

var queue_apply_settings := false;
var refresh_rate_update_timer := 0.0;
var current_refresh_rate := 0.0;
var window_needs_best_fit := true;

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS;
	
	GameSettings.define_setting(&"display.vsync", VSyncMode.On);
	GameSettings.define_setting(&"display.mode", DisplayMode.Fullscreen);
	GameSettings.define_setting(&"display.scale_mode", ScaleMode.StretchToFit);
	GameSettings.define_setting(&"display.fps_limit", 0);
	
	GameSettings.define_setting(&"display.physics_lerp", PhysicsLerping.Automatic);
	GameSettings.define_setting(&"display.low_latency", LowLatencyMode.Automatic);
	
	GameSettings.setting_changed.connect(self.setting_changed);
	
	apply_settings();

func _process(_delta):
	if queue_apply_settings:
		queue_apply_settings = false;
		apply_settings();

func _physics_process(delta):
	refresh_rate_update_timer += delta;
	
	if refresh_rate_update_timer >= REFRESH_RATE_AUTO_UPDATE_RATE:
		_update_refresh_rate();
		refresh_rate_update_timer -= REFRESH_RATE_AUTO_UPDATE_RATE;
	
	if Input.is_action_just_pressed("system_fullscreen"):
		toggle_fullscreen();

func toggle_fullscreen():
	if GameSettings.get_setting(&"display.mode") != DisplayManager.DisplayMode.Fullscreen:
		GameSettings.set_setting(&"display.mode", DisplayManager.DisplayMode.Fullscreen);
	else:
		GameSettings.set_setting(&"display.mode", DisplayManager.DisplayMode.Windowed);

func setting_changed(keypath: StringName, _new_value):
	if keypath.begins_with("display."):
		queue_apply_settings = true;

func apply_settings():
	_update_refresh_rate();
	
	var old_mode := DisplayServer.window_get_mode();
	
	if old_mode != DisplayServer.WINDOW_MODE_WINDOWED:
		window_needs_best_fit = true;
	
	match GameSettings.get_setting(&"display.vsync") as VSyncMode:
		VSyncMode.On:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED);
		VSyncMode.Off:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);
	
	match GameSettings.get_setting(&"display.mode") as DisplayMode:
		DisplayMode.Fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN);
		DisplayMode.Windowed:
			if old_mode != DisplayServer.WINDOW_MODE_MAXIMIZED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);
				
				if window_needs_best_fit:
					best_fit_window.call_deferred();
	
	match GameSettings.get_setting(&"display.scale_mode") as ScaleMode:
		ScaleMode.StretchToFit:
			get_window().set_content_scale_stretch(Window.ContentScaleStretch.CONTENT_SCALE_STRETCH_FRACTIONAL);
		ScaleMode.ForceIntegerScale:
			get_window().set_content_scale_stretch(Window.ContentScaleStretch.CONTENT_SCALE_STRETCH_INTEGER);
	
	var fps_limit := roundi(GameSettings.get_setting(&"display.fps_limit"));
	
	fps_limit = clampi(fps_limit, 20, 1000) if fps_limit > 0 else 0;
	Engine.max_fps = fps_limit;
	
	match GameSettings.get_setting(&"display.physics_lerp") as PhysicsLerping:
		PhysicsLerping.Automatic:
			_update_auto_physics_lerp();
		PhysicsLerping.ForceOff:
			get_tree().set_physics_interpolation_enabled(false);
		PhysicsLerping.ForceOn:
			get_tree().set_physics_interpolation_enabled(true);
	
	match GameSettings.get_setting(&"display.low_latency") as LowLatencyMode:
		LowLatencyMode.Automatic:
			_update_auto_low_latency();
		LowLatencyMode.On:
			RenderingServer.set_cpu_gpu_sync_mode(RenderingServer.CPU_GPU_SYNC_SEQUENTIAL);
		LowLatencyMode.Off:
			RenderingServer.set_cpu_gpu_sync_mode(RenderingServer.CPU_GPU_SYNC_PARALLEL);

func _update_refresh_rate():
	current_refresh_rate = DisplayServer.screen_get_refresh_rate();
	
	if GameSettings.get_setting(&"display.physics_lerp") == PhysicsLerping.Automatic:
		_update_auto_physics_lerp();
	if GameSettings.get_setting(&"display.low_latency") == LowLatencyMode.Automatic:
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

func best_fit_window():
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return;
	
	var window := get_tree().root;
	var decoration_size := window.get_size_with_decorations() - window.size;
	var game_size := window.content_scale_size;
	var desktop_rect := DisplayServer.get_display_safe_area();
	@warning_ignore("integer_division")
	var max_scale_x := (desktop_rect.size.x - decoration_size.x) / game_size.x;
	@warning_ignore("integer_division")
	var max_scale_y := (desktop_rect.size.y - decoration_size.y) / game_size.y;
	var max_scale := mini(max_scale_x, max_scale_y);
	var new_size := Vector2i(game_size.x * max_scale, game_size.y * max_scale);
	
	DisplayServer.window_set_position(desktop_rect.get_center() - (new_size / 2));
	DisplayServer.window_set_size(new_size);
	
	window_needs_best_fit = false;
