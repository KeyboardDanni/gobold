extends Node

signal settings_loaded();
signal settings_changed();
signal setting_changed(keypath, new_value);

const GAME_SETTINGS_FILENAME = "user://GameSettings.json";
const TRUTHY_BOOL_STRINGS: PackedStringArray = [
	"1",
	"true",
	"t",
	"on",
	"yes",
	"y",
	"enabled"
];
const FALSY_BOOL_STRINGS: PackedStringArray = [
	"0",
	"false",
	"f",
	"off",
	"no",
	"n",
	"disabled"
];

var _settings_tree: Dictionary[StringName, Variant];
var _definition_dict: Dictionary[StringName, _GameSettingDefinition];
var _lookup_dict: Dictionary[StringName, _GameSettingLookup];

const SETTING_FLAG_ADVANCED: int = 1;

func _enter_tree():
	load_settings();

func _exit_tree():
	save_settings();

func is_setting_defined(keypath: StringName) -> bool:
	return _definition_dict.has(keypath);

func define_setting(keypath: StringName, default_value, flags: int = 0):
	if keypath.length() <= 0:
		push_error("Tried to define GameSetting with empty keypath");
		return;
	
	if _definition_dict.has(keypath):
		push_error("Duplicate GameSetting definition at keypath \"" + keypath + "\"");
		return;
	
	var definition := _GameSettingDefinition.new();
	
	definition.default_value = default_value;
	
	if flags & SETTING_FLAG_ADVANCED:
		definition.advanced = true;
	
	_definition_dict[keypath] = definition;
	
	# Apply default if setting is not currently present in the tree
	_add_setting_to_tree(keypath, default_value);

func _add_setting_to_tree(keypath: StringName, value_if_missing):
	if keypath.length() <= 0:
		return;
	
	# If it's in the lookup table it's already in the tree, so skip all this.
	if !_lookup_dict.has(keypath):
		var parts := keypath.split(".");
		var lookup := _GameSettingLookup.new();
		lookup.dict_ref = _settings_tree;
		lookup.dict_key = parts[parts.size() - 1];
		
		# Add any missing branches to the tree
		for i in range(parts.size() - 1):
			var part_name := StringName(parts[i]);
			
			if !lookup.dict_ref.has(part_name):
				var new_dict: Dictionary[StringName, Variant];
				lookup.dict_ref[part_name] = new_dict;
			
			lookup.dict_ref = lookup.dict_ref[part_name];
		
		if !lookup.dict_ref.has(lookup.dict_key):
			lookup.dict_ref[lookup.dict_key] = value_if_missing;
		
		_lookup_dict[keypath] = lookup;
	
	_sanitize_setting(keypath);

func _sanitize_setting(keypath: StringName):
	if !_lookup_dict.has(keypath) || !_definition_dict.has(keypath):
		return;
	
	var lookup := _lookup_dict[keypath];
	var definition := _definition_dict[keypath];
	var existing = lookup.dict_ref[lookup.dict_key];
	
	match typeof(definition.default_value):
		TYPE_BOOL:
			if existing is bool:
				pass;
			elif existing is int:
				existing = true if existing > 0 else false;
			elif existing is float:
				existing = true if existing >= 0.5 else false;
			elif existing is String:
				existing = true if TRUTHY_BOOL_STRINGS.has(existing.to_lower()) else false;
			else:
				existing = false;
		TYPE_INT:
			existing = int(existing);
		TYPE_FLOAT:
			existing = float(existing);
		TYPE_STRING:
			existing = str(existing);
	
	lookup.dict_ref[lookup.dict_key] = existing;

func get_setting(keypath: StringName):
	var lookup = _lookup_dict.get(keypath);
	
	if !lookup:
		push_error("Unknown keypath \"" + keypath + "\"");
		return;
	
	return lookup.dict_ref.get(lookup.dict_key);

func has_setting(keypath: StringName) -> bool:
	return _lookup_dict.get(keypath) != null;

func set_setting(keypath: StringName, new_value) -> bool:
	var definition = _definition_dict.get(keypath);
	var lookup = _lookup_dict.get(keypath);
	
	if !lookup || !definition:
		push_error("Unknown keypath \"" + keypath + "\"");
		return false;
	
	var new_type := typeof(new_value);
	var default_type := typeof(definition.default_value);
	
	if new_type != default_type:
		push_error("Type mismatch for keypath \"" + keypath + "\": expected " + str(default_type) + ", got " + str(new_type));
		return false;
	
	lookup.dict_ref[lookup.dict_key] = new_value;
	
	settings_changed.emit();
	setting_changed.emit(keypath, new_value);
	
	return true;

func set_setting_from_string(keypath: StringName, new_value: String) -> bool:
	var definition = _definition_dict.get(keypath);
	var lookup = _lookup_dict.get(keypath);
	
	if !lookup || !definition:
		push_error("Unknown keypath \"" + keypath + "\"");
		return false;
	
	var default_type := typeof(definition.default_value);
	var converted = convert_string_to_type(new_value, default_type);
	var new_type := typeof(converted);
	
	if new_type != default_type:
		push_error("Type mismatch for keypath \"" + keypath + "\": expected " + str(default_type) + ", got " + str(new_type));
		return false;
	
	lookup.dict_ref[lookup.dict_key] = converted;
	
	settings_changed.emit();
	setting_changed.emit(keypath, converted);
	
	return true;

func get_default(keypath: StringName):
	var definition = _definition_dict.get(keypath);
	
	if !definition:
		push_error("Unknown keypath \"" + keypath + "\"");
		return;
	
	return definition.default_value;

func is_advanced_setting(keypath: StringName) -> bool:
	var definition = _definition_dict.get(keypath);
	
	if !definition:
		push_error("Unknown keypath \"" + keypath + "\"");
		return false;
	
	return definition.advanced;

func reset_advanced_settings():
	for keypath in _definition_dict:
		var definition := _definition_dict[keypath];
		
		if definition.advanced:
			set_setting(keypath, definition.default_value);

func keys() -> PackedStringArray:
	return _definition_dict.keys();

func _handle_loaded_tree(plain_dict: Dictionary):
	# Reset the existing settings store
	_settings_tree.clear();
	_lookup_dict.clear();
	
	_recurse_input_dict("", plain_dict);
	
	# Apply defaults on top of loaded settings where those settings were not
	#  present in the input.
	for keypath in _definition_dict:
		var definition := _definition_dict[keypath];
		_add_setting_to_tree(keypath, definition.default_value);

func _recurse_input_dict(keypath: String, plain_dict: Dictionary):
	for key in plain_dict:
		var item = plain_dict[key];
		
		if item is Dictionary:
			_recurse_input_dict(keypath + key + ".", item);
		else:
			_add_setting_to_tree(StringName(keypath + key), item);

func matches_default(keypath: StringName, new_value: String) -> bool:
	var definition = _definition_dict.get(keypath);
	
	if !definition:
		push_error("Unknown keypath \"" + keypath + "\"");
		return false;
	
	var default_type := typeof(definition.default_value);
	var new_converted = convert_string_to_type(new_value, default_type);
	
	return typeof(new_converted) == default_type && new_converted == definition.default_value;

func convert_string_to_type(new_value: String, target_type: int) -> Variant:
	match target_type:
		TYPE_BOOL:
			var lowercase := new_value.to_lower();
			
			if TRUTHY_BOOL_STRINGS.has(lowercase):
				return true;
			elif FALSY_BOOL_STRINGS.has(lowercase):
				return false;
		TYPE_INT:
			return int(new_value);
		TYPE_FLOAT:
			return float(new_value);
		TYPE_STRING:
			return new_value;
	
	return new_value;

func load_settings():
	if FileAccess.file_exists(GAME_SETTINGS_FILENAME):
		var file := FileAccess.open(GAME_SETTINGS_FILENAME, FileAccess.READ);
		var parsed = JSON.parse_string(file.get_as_text());
		
		if parsed is Dictionary:
			_handle_loaded_tree(parsed);
			settings_loaded.emit();
		else:
			push_warning("Could not load game settings");
		
		file.close();

func save_settings():
	var file := FileAccess.open(GAME_SETTINGS_FILENAME, FileAccess.WRITE);
	file.store_string(JSON.stringify(_settings_tree, "    ", true, true));
	file.close();
