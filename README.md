# Godot Pixelorama Importer

Imports `.pxo` files from [Pixelorama](https://orama-interactive.itch.io/pixelorama) to [Godot](https://godotengine.org/) without requiring an export for quicker changes in Godot

## Status

The plugin provides two import types:

**Single Image**: All Cels are overlaid into one image per frame as a `1xN` StreamTexture PNG with the 2D Pixel Texture preset.

**SpriteFrames**: Animation tags are used to create a SpriteFrames resource from the pxo file, which can be used with AnimatedSprite. However, due to a resource reload bug in Godot, any changes to the pxo file are not visible in the editor but by either launching the game or restarting the editor, the edited textures are visible.

There is also an Inspector plugin which lets you open Pixelorama from within the Godot editor. When you have a .pxo file open in the Inspector, click on "Open in Pixelorama" to launch Pixelorama. It requires a one-time configuration of the location of the Pixelorama binary. Linux/BSD and Windows are supported as of now

## Usage

Download the repository, extract to the root of your project and enable the plugin. Drag and drop `.pxo` files to any parameter that takes a `Texure`
