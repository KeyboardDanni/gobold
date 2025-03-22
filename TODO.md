# TODO

## Related to this project

### Assets

- [ ] Remove the need to have a copy of Aseprite to load and run the project.

### Movement

- [ ] Moving platforms
- [ ] Wind and conveyor belts
- [ ] Multi-directional gravity
- [ ] Stair-stepping
- [ ] Physics object interaction

### Display

- [ ] Additional pixel snapping where necessary
- [ ] HD graphics as HUD
- [ ] Screen shaders

### Framework

- [ ] Game settings
- [ ] Debug overlay

## Related to Godot Engine

- [ ] Add automatic physics interpolation toggle once existing bugs can be fixed without patching the engine
  - [ ] https://github.com/godotengine/godot/issues/101192
  - [ ] https://github.com/godotengine/godot/issues/101195
- [ ] Add low latency mode and fix other latency issues in RenderingDevice - see https://github.com/KeyboardDanni/godot-latency-tester?tab=readme-ov-file#low-latency-enhancements-tracker
- [ ] DXGI support for OpenGL and Vulkan
- [ ] Make it easy to use screen shaders with the built-in Godot root viewport scaling
