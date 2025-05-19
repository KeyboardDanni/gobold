# Gobold, a pixel platformer example and framework for Godot

Gobold is an example project that demonstrates how I approach making "pixel-perfect" games in Godot. Many new developers looking to make pixel-style games don't know where to start, and often run into problems such as pixel jitter and shimmering. Thankfully, there are several techniques (many of which are built into Godot) that can address these issues.

Gobold also intends to be a framework for useful game functionality such as game settings and character movement, as well as a testbed for new Godot features as they relate to 2D games.

This project's motto is "frame-perfect detail, down to the pixel".

![Screenshot of Gobold](https://raw.githubusercontent.com/KeyboardDanni/gobold/main/screenshot.png)

## Features

- Character controller with specialized slope handling.
- Clean pixel-perfect camera movement.
- Game settings framework.
- Display manager with automatic pixel scaling options and Alt + Enter shortcut for fullscreen.
- Automatic physics interpolation toggle for the smoothest physics motion at any refresh rate.
- Low latency mode enabled for refresh rates below 120hz.
- In-game developer command interface (Tilde key) with support for autocomplete and custom commands.

## Prerequisites

- Godot 4.4 stable (might change in the future)
    - **Important**: Some features rely on [Godot for Sidescrollers](https://github.com/KeyboardDanni/godot-for-sidescrollers).
- A copy of Aseprite (for graphics import)
- Aseprite Wizard configured to point to the Aseprite binary in **Editor Settings -> Aseprite -> General** (may require Advanced Settings toggle).

## Who's that critter?

That's Gobold the Godot Kobold, my unofficial take on a Godot mascot. True to the modern kobold mythos, they're a scrappy tinkerer who's excited to experiment, with big aspirations of one day taking on the big guys.

## Licensing

Code is licensed under the MIT License.

Assets are licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
