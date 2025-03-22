
Steps on how to configure your Godot project for best results in pixel games:

- Use Compatibility renderer for best latency (at least for now, until things improve in RenderingDevice).
- Pick a good base resolution for your game in **Project Settings -> Display -> Window -> Viewport Width/Height**.
  - Optionally, feel free to set **Window Width/Height Override** so your game window pixel-doubles by default.
- Also under **Display -> Window**, set **Stretch Mode** to **Viewport**.
- Under **Rendering -> 2D**, enable **Snap 2D Transforms to Pixel**.
- Under **Render -> Textures -> Canvas Textures**, set **Default Texture Filter** to **Nearest**.
- Optional: Install **Aseprite Wizard** from AssetLib for easy importing of pixel art.

For the Camera2D:

- Make sure **Process Callback** is **Physics** (assuming the target also moves during physics step).
- Set **Process Priority** and **Process Physics Priority** to a high enough number, like **100**, so it happens after everything else has moved.
- Move the camera itself manually via script. Don't parent it to a moving node.

For AnimationPlayers:

- Make sure **Callback Mode Process** is **Physics**.

For scripts:

- Unless you have specific needs, put all your code in **_physics_process** and avoid **_process**.
