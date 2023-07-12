## Terrain Autotiler

Terrain Autotiler is a replacement terrain tile matching algorithm for Godot 4. It was designed for accurate, deterministic results in player-facing situations such as procedural generation and tile-based games. It is fully compatible with Godot 4 TileSets without any additional setup, but also brings back optional features from Godot 3, such as ignore bits and merging autotiles.

***This is an early testing release. There may be frequent updates and changes to core features. Feedback and bug reports are greatly appreciated.***

![Painting with the editor](https://raw.githubusercontent.com/wiki/dandeliondino/terrain-autotiler/media/intro/intro_01_paint_with_editor.gif)

![Update Button](https://raw.githubusercontent.com/wiki/dandeliondino/terrain-autotiler/media/intro/intro_02_update_button.gif)

![Toggle on Terrain Autotiler Tools](https://raw.githubusercontent.com/wiki/dandeliondino/terrain-autotiler/media/intro/intro_03_toggle_on_tools.gif)

![Draw mode](https://raw.githubusercontent.com/wiki/dandeliondino/terrain-autotiler/media/intro/intro_04_draw_mode.gif)

### Features
#### Core
- A more accurate and deterministic terrain tile matching algorithm. It fixes [multiple open issues](https://github.com/dandeliondino/terrain-autotiler/wiki/Godot-4-Issues-and-Proposals). (And it is also [faster](https://github.com/dandeliondino/terrain-autotiler/wiki/Performance-vs-Engine).)
- Fully compatible with the Godot 4 terrains system. No additional setup is required.
- Brings back compatible Godot 3 features:
    - [Corners and Sides "Full" 256-tile mode](https://github.com/dandeliondino/terrain-autotiler/wiki/Additional-Features#corners-and-sides-match-modes) to match individual diagonal connections.
    - [@ignore terrain bits](https://github.com/dandeliondino/terrain-autotiler/wiki/Additional-Features#ignore-terrain) to allow users to reuse tiles and transitions with a more flexible interface than alternative tiles.
    - [Custom primary peering terrains](https://github.com/dandeliondino/terrain-autotiler/wiki/Additional-Features#primary-peering-terrains) to allow merging tiles of different terrains.
    - Ability to recalculate and update all terrain tiles in a TileMap layer.

#### Scripting
- Create a new Autotiler object using `Autotiler.new(tile_map)`, then use it to access terrain tile placement functions. Contains [complete in-editor documentation](https://github.com/dandeliondino/terrain-autotiler/wiki/Scripting).
    - `set_cells_terrain_connect` and `set_cells_terrain_path` work the same as their base TileMap functions, but provide more accurate, reproducible results.
    - `set_cells_terrains` places multiple terrains by providing dictionary of `{coords (Vector2i) : terrain (int)}`. This makes bulk updates in procedural generation faster and simpler.
    - `update_terrain_tiles` recalculates and updates all the terrain tiles in a layer.

#### Editor Plugin
- TileMap editor: Toggle seamlessly between Godot 4 and Terrain Autotiler painting tools in the Terrains tab.
    - Paint in real time with a more accurate Draw mode.
    - Lock individual cells to prevent tiles from being updated (useful for preserving Path mode painting).
    - Error notifications appear in real-time while painting to assist in identifying issues such as missing tiles.
    - Open the debug panel to view detailed data for troubleshooting and bug reports.
    - *Note: The editor plugin is a work in progress. Notably, as of v0.2.0, it is missing the option to paint specific individual tiles as well as non-contiguous mode for bucket fill. Toggle off the Terrain Autotiler tools to access these base Godot 4 editor features instead.*
- TileSet inspector: Set up advanced features such as "Full" Corners and Sides matching mode, @ignore terrains and custom primary peering terrains.
- Includes minor editor bug fixes and UX improvements
    - Selecting a TileMap in the scene tree always opens the bottom TileMap editor (rather than sometimes opening the TileSet editor instead)
    - Coordinates and current tool information appear when hovering over cells
    - More obvious visual feedback when painting with terrain tools
    - Bucket tool fills all adjacent tiles of the same terrain, even if the tiles are not identical.


### Installation
#### Github
1. Download the latest version from Releases.
2. Unzip and move the `addons/terrain_autotiler` folder to the project.
3. Go to **Project Settings** -> **Plugins** and enable *Terrain Autotiler*.

### Uninstallation
1. Go to **Project Settings** -> **Plugins** and disable *Terrain Autotiler*.
2. Delete the `addons/terrain_autotiler` folder from the project.
3. (optional) Open the TileMap and TileSet inspectors for your scenes and delete the "terrain_autotiler" metadata.


### Acknowledgements
- [GUT (Godot Unit Test)](https://github.com/bitwes/Gut)
- [Godot Editor Theme Explorer](https://github.com/YuriSizov/godot-editor-theme-explorer)
- [Editor Debugger](https://github.com/Zylann/godot_editor_debugger_plugin)

### License
- Terrain Autotiler is Copyright (c) 2023 dandeliondino ([MIT license](https://github.com/dandeliondino/terrain-autotiler/blob/main/LICENSE))
- Godot Engine is Copyright (c) 2014-present Godot Engine contributors ([MIT license](https://github.com/godotengine/godot/blob/master/LICENSE.txt))
