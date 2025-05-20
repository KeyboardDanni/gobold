extends CanvasLayer

var command_edit_size_min: float = 64.0;
var command_edit_size_max: float = 256.0;
var command_edit_size_text_padding: float = 16.0;

var _commands: Dictionary[String, Callable];
var _autocompleters: Dictionary[String, Callable];
var _descriptions: Dictionary[String, String];
var _groups: Dictionary[String, Array];
var _queued_command = null;
var _last_run_command: String;
var _last_command: String;

enum TextColor {
	WHITE,
	GRAY,
	RED,
	YELLOW,
	GREEN,
	BLUE,
	PURPLE,
}

func _ready() -> void:
	add_command("set", "settings", "View or modify a game setting", command_set, autocomplete_set);
	add_command("reset", "settings", "Revert a game setting to default", command_reset, autocomplete_reset);
	add_command("reset_advanced", "settings", "Revert all advanced game settings to defaults", command_reset_advanced);
	add_command("load_settings", "settings", "Load game settings from disk", command_load_settings);
	add_command("save_settings", "settings", "Save game settings to disk", command_save_settings);
	
	add_command("adjust_window", "display", "Re-center and scale window based on display.window_scale", command_adjust_window);
	
	add_command("help", "core", "Show help", command_help);
	add_command("system_info", "core", "Print basic hardware and system information", command_system_info);
	add_command("quit", "core", "Quit the game", command_quit);
	
	_on_command_edit_text_changed("");
	
	visible = false;

func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		return;
	
	if _queued_command is String:
		var result := run_command(_queued_command);
		
		if result:
			_last_command = _queued_command;
			_last_run_command = _queued_command;
		
		_queued_command = null;

func _input(event: InputEvent) -> void:
	if event.is_released():
		return;
	
	if event.is_action("system_devcommand"):
		if !event.is_echo():
			visible = !visible;
			
			if visible:
				%CommandEdit.grab_focus.call_deferred();
			
		get_viewport().set_input_as_handled();
	
	if visible:
		if event.is_action("ui_text_submit") && !Input.is_key_pressed(KEY_ALT):
			_queued_command = %CommandEdit.text;
			%CommandEdit.clear();
		if event.is_action("ui_cancel"):
			visible = false;
			
			get_viewport().set_input_as_handled();
		
		if %CommandEdit.is_editing():
			if event.is_action("ui_page_up"):
				%ResultLabel.get_v_scroll_bar().value -= %ResultLabel.size.y * 0.25;
				get_viewport().set_input_as_handled();
			
			if event.is_action("ui_page_down"):
				%ResultLabel.get_v_scroll_bar().value += %ResultLabel.size.y * 0.25;
				get_viewport().set_input_as_handled();
			
			if event.is_action("ui_focus_next"):
				if !event.is_echo():
					autocomplete();
					%CommandEdit.grab_focus.call_deferred();
				
				get_viewport().set_input_as_handled();
			if event.is_action_pressed("ui_up"):
				%CommandEdit.text = _last_command;
				update_box_width.call_deferred();
				%CommandEdit.caret_column = %CommandEdit.text.length();
				%CommandEdit.grab_focus.call_deferred();
				
				get_viewport().set_input_as_handled();
			if event.is_action_pressed("ui_down") && %CommandEdit.text.length() > 0:
				_last_command = %CommandEdit.text;
				%CommandEdit.text = "";
				update_box_width.call_deferred();
				%CommandEdit.grab_focus.call_deferred();
				
				get_viewport().set_input_as_handled();

func _on_command_edit_text_changed(_new_text: String) -> void:
	update_box_width.call_deferred();

func update_box_width():
	var font: Font = %CommandEdit.get_theme_font("font");
	var font_size: int = %CommandEdit.get_theme_font_size("font_size");
	var text_size := font.get_string_size(%CommandEdit.text, HORIZONTAL_ALIGNMENT_LEFT, command_edit_size_max, font_size);
	
	var padded := text_size.x + command_edit_size_text_padding;
	
	%CommandEdit.custom_minimum_size.x = clampf(padded, command_edit_size_min, command_edit_size_max);

func _on_close_button_pressed() -> void:
	visible = false;

func _on_command_edit_focus_exited() -> void:
	check_lost_focus.call_deferred();

func _on_result_label_focus_exited() -> void:
	check_lost_focus.call_deferred();

func _on_close_button_focus_exited() -> void:
	check_lost_focus.call_deferred();

func _on_command_edit_editing_toggled(toggled_on: bool) -> void:
	if !toggled_on:
		check_lost_focus.call_deferred();

func check_lost_focus():
	if (!%CommandEdit.has_focus() || !%CommandEdit.is_editing()) && !%CloseButton.has_focus() && \
			!%ResultLabel.has_focus():
		visible = false;

func add_command(command_name: String, group: String, description: String, function: Callable, autocompleter: Callable = Callable()):
	if _commands.has(command_name):
		push_error("Command \"" + command_name + "\" already added.");
		return;
	
	_commands[command_name] = function;
	_autocompleters[command_name] = autocompleter;
	_descriptions[command_name] = description;
	
	if !_groups.has(group):
		_groups[group] = [];
	
	_groups[group].append(command_name);

func autocomplete():
	var possibilities: PackedStringArray;
	var first_space: int = %CommandEdit.text.find(" ");
	
	if first_space >= 0:
		var command_name: String = %CommandEdit.text.left(first_space);
		var autocompleter = _autocompleters.get(command_name);
		
		if autocompleter != null:
			possibilities = autocompleter.call(%CommandEdit.text);
	else:
		possibilities = _commands.keys();
	possibilities = _filter_possibilities(%CommandEdit.text, possibilities);
	
	clear_output();
	
	if possibilities.size() == 1:
		%CommandEdit.text = possibilities[0] + " ";
	elif possibilities.size() > 0:
		%CommandEdit.text = _find_common_prefix(%CommandEdit.text, possibilities);
		output_text("\n".join(possibilities));
	
	%CommandEdit.caret_column = %CommandEdit.text.length();
	update_box_width.call_deferred();

func _filter_possibilities(typed: String, possibilities: PackedStringArray) -> PackedStringArray:
	var filtered: PackedStringArray;
	
	# TODO maybe make this faster
	for item in possibilities:
		if item.begins_with(typed):
			filtered.append(item);
	
	filtered.sort();
	
	return filtered;

func _find_common_prefix(typed: String, possibilities: PackedStringArray) -> String:
	if possibilities.size() <= 0:
		return "";
	
	var prefix := possibilities[0];
	
	# TODO maybe make this faster too
	for item in possibilities:
		while !item.begins_with(prefix):
			prefix = prefix.left(-1);
			if prefix.length() <= typed.length():
				return typed;
	
	return prefix;

func run_command(command: String) -> bool:
	clear_output();
	
	var stripped := command.strip_edges();
	if stripped.is_empty():
		return false;
	
	output_text("> " + _queued_command, TextColor.YELLOW);
	
	var parts := stripped.split(" ");
	
	var command_name := parts[0];
	var function = _commands.get(command_name);
	
	if function != null:
		function.call(parts);
	else:
		output_text("Unknown command \"" + command_name + "\"", TextColor.RED);
	
	return true;

func command_adjust_window(_parts: PackedStringArray):
	var success := DisplayManager.adjust_window(true);
	
	if !success:
		output_text("Window cannot be adjusted in this state.", TextColor.RED);

func command_set(parts: PackedStringArray):
	if parts.size() < 2:
		output_text("set: Missing settings keypath.", TextColor.RED);
		return;
	
	var setting_name := parts[1];
	
	if !GameSettings.has_setting(setting_name):
		output_text("set: Unknown setting \"" + setting_name + "\".", TextColor.RED);
		return;
	
	var advanced := GameSettings.is_advanced_setting(setting_name);
	
	if parts.size() < 3:
		var current = GameSettings.get_setting(setting_name);
		var default = GameSettings.get_default(setting_name);
		output_text("Current: " + str(current) + "\nDefault: " + str(default));
		
		if advanced:
			output_text("This is an advanced setting.\nYou should only change it if you know what you're doing.", TextColor.RED);
	else:
		var other_parts := parts.slice(2);
		var new_value := " ".join(other_parts);
		var new_is_default := GameSettings.matches_default(setting_name, new_value);
		
		if advanced && _queued_command != _last_run_command && !new_is_default:
			output_text("\"" + setting_name + "\" is an advanced setting." +
				"\nIf you know what you're doing, run this command again." +
				"\nOtherwise you should leave this setting alone.", TextColor.RED);
			return;
		
		var current = GameSettings.get_setting(setting_name);
		var result := GameSettings.set_setting_from_string(setting_name, new_value);
		var effective_value = GameSettings.get_setting(setting_name);
		
		if !result:
			output_text("Failed.", TextColor.RED);
		output_text("New: " + str(effective_value));
		output_text("Old: " + str(current), TextColor.GRAY);
		
		if advanced && !new_is_default:
			output_text("If you have problems, run\n    reset_advanced");

func command_reset(parts: PackedStringArray):
	if parts.size() < 2:
		output_text("reset: Missing settings keypath.", TextColor.RED);
		return;
	
	var split_setting := parts[1];
	
	if !GameSettings.has_setting(split_setting):
		output_text("reset: Unknown setting \"" + split_setting + "\".", TextColor.RED);
		return;
	
	var default = GameSettings.get_default(split_setting);
	var current = GameSettings.get_setting(split_setting);
	var result := GameSettings.set_setting(split_setting, default);
	var effective_value = GameSettings.get_setting(split_setting);
	
	if !result:
		output_text("Failed.", TextColor.RED);
	output_text("New: " + str(effective_value));
	output_text("Old: " + str(current), TextColor.GRAY);

func command_reset_advanced(_parts: PackedStringArray):
	GameSettings.reset_advanced_settings();
	output_text("Advanced settings reset to defaults.", TextColor.BLUE);

func command_load_settings(_parts: PackedStringArray):
	GameSettings.load_settings();

func command_save_settings(_parts: PackedStringArray):
	GameSettings.save_settings();

func command_help(_parts: PackedStringArray):
	output_text("Dev command keyboard help:\n", TextColor.PURPLE);
	output_text("Tilde (`):\topen/close dev command overlay");
	output_text("Tab:\tautocomplete");
	output_text("Up:\trecall last command");
	output_text("Down:\tclear command");
	output_text("PgUp/PgDown:\tscroll output");
	
	output_text("\nCommand list by group:", TextColor.PURPLE);
	
	for group in _groups:
		output_text("\n" + group + " group:", TextColor.BLUE);
		
		for command_name in _groups[group]:
			output_text("    " + command_name + "\t  " + _descriptions[command_name]);

func command_system_info(_parts: PackedStringArray):
	var info_text := "";
	
	var cpu_name := OS.get_processor_name();
	var cpu_threads := OS.get_processor_count();
	
	info_text += "CPU: " + cpu_name + "\nThreads: " + str(cpu_threads);
	
	var device_name := RenderingServer.get_video_adapter_name();
	var backend := "OpenGL";
	var api_version := RenderingServer.get_video_adapter_api_version();
	
	var rendering_device := RenderingServer.get_rendering_device();
	
	if rendering_device:
		backend = "RenderingDevice";
		device_name = rendering_device.get_device_name();
	
	info_text += "\n\nRenderer: " + device_name + "\n" + backend + " " + api_version;
	
	var window_size := DisplayServer.window_get_size();
	var screen_size := DisplayServer.screen_get_size();
	var screen_scale := DisplayServer.screen_get_scale();
	var refresh_rate := roundf(DisplayServer.screen_get_refresh_rate() * 100.0) / 100.0;
	
	info_text += "\n\nWindow: " + str(window_size.x) + "x" + str(window_size.y) + \
		"\nDisplay: " + str(screen_size.x) + "x" + str(screen_size.y) + " " + str(refresh_rate) + " hz" + \
		"\nDPI scale: " + str(screen_scale) + "x";
	
	var audio_device_name := AudioServer.output_device;
	var driver_name := AudioServer.get_driver_name();
	var mix_rate := AudioServer.get_mix_rate();
	
	info_text += "\n\nAudio device: " + audio_device_name + " - " + driver_name + "\nMix rate: " + str(mix_rate) + " hz";
	
	var joypad_ids := Input.get_connected_joypads();
	
	info_text += "\n\nGamepads: " + str(joypad_ids.size()) + " connected";
	
	for id in joypad_ids:
		info_text += "\nPad " + str(id) + ": " + Input.get_joy_name(id);
	
	DisplayServer.clipboard_set(info_text);
	output_text(info_text + "\n\n(Copied to clipboard)");

func command_quit(_parts: PackedStringArray):
	get_tree().quit();

func autocomplete_set(_command: String) -> PackedStringArray:
	var keys := GameSettings.keys();
	var possibilities: PackedStringArray;
	
	for item in keys:
		possibilities.append("set " + item);
	
	return possibilities;

func autocomplete_reset(_command: String) -> PackedStringArray:
	var keys := GameSettings.keys();
	var possibilities: PackedStringArray;
	
	for item in keys:
		possibilities.append("reset " + item);
	
	return possibilities;

func output_text(output: String, color: TextColor = TextColor.WHITE, strip_bbcode: bool = true):
	if strip_bbcode:
		output = escape_bbcode(output);
	
	var color_code: String;
	
	match color:
		TextColor.WHITE:
			color_code = "#ffffff";
		TextColor.GRAY:
			color_code = "#cacaca";
		TextColor.RED:
			color_code = "#ffafbc";
		TextColor.YELLOW:
			color_code = "#f2e7a0";
		TextColor.GREEN:
			color_code = "#a1dca2";
		TextColor.BLUE:
			color_code = "#9eceff";
		TextColor.PURPLE:
			color_code = "#d4bcff";

	%ResultLabel.text += "[color=" + color_code + "]" + output + "[/color]\n";

func clear_output():
	%ResultLabel.text = "";

func escape_bbcode(bbcode_text: String):
	return bbcode_text.replace("[", "[lb]");
