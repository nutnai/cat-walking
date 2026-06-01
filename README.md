# CatWalking

A macOS desktop pet app written in Swift using a SwiftUI + AppKit hybrid.

The app creates a transparent, click-through overlay window pinned to the bottom of the primary screen and renders an animated pixel-art calico cat from a 6x4 sprite sheet.

## Project structure

- `Package.swift`: Swift Package manifest.
- `Sources/CatWalking/CatWalkingApp.swift`: app entry point, menu bar extra, and app lifecycle.
- `Sources/CatWalking/OverlayWindowController.swift`: transparent overlay window management.
- `Sources/CatWalking/PetEngine.swift`: animation loop, movement loop, and random behavior state machine.
- `Sources/CatWalking/SpriteSheet.swift`: dynamic sprite-sheet slicing.
- `Sources/CatWalking/SettingsView.swift`: settings UI.
- `Sources/CatWalking/AppSettings.swift`: persisted user settings.

## Sprite sheet placement

Place your sprite sheet file here:

`Sources/CatWalking/Resources/cat-sprite-sheet.png`

Expected sheet layout:

- 6 rows x 4 columns
- all frames are the same size
- row 1: walk down
- row 2: walk right
- row 3: walk up
- row 4: walk left
- row 5: idle / sit
- row 6: groom / play

The app calculates frame size automatically from the full image dimensions.

## Run in Xcode

1. Open `Package.swift` in Xcode.
2. Let Xcode resolve the Swift package.
3. Select the `CatWalking` scheme.
4. Run the app.
5. Click the cat icon in the macOS menu bar.
6. Click `Open Settings...`.
7. Change scale, speed, or enabled animations in the Settings window.

## Run from Terminal

````bash
cd /Users/nutnai/code/temp/CatWalking
swift run

## Export Installer

Build an app bundle and installer package with:

```bash
./scripts/export-installer.sh
````

That creates:

- `dist/CatWalking-<version>.app`
- `dist/CatWalking-<version>-Installer.pkg`

The package is unsigned. On another Mac, Gatekeeper may require the user to right-click and open it, or allow it from System Settings.

```

## Behavior and settings

The cat randomly alternates between:

- walking left
- walking right
- sitting idle
- grooming

## How To Configure

1. Start the app with `swift run` or from Xcode.
2. Look for the cat icon in the macOS menu bar at the top of the screen.
3. Click the cat icon.
4. Choose `Open Settings...`.
5. In the Settings window:
6. Use `Cat Scale` to make the cat larger or smaller.
7. Use `Animation Speed` to change frame rate.
8. Use `Movement Speed` to change walking speed.
9. Turn animation toggles on or off in `Enabled Animations`.

The app saves these settings automatically.

Available settings:

- cat scale
- animation speed
- movement speed
- stay on top

## Adjusting frame logic later

If you want to change how slicing works, update `SpriteSheetConfiguration.default` in `Sources/CatWalking/SpriteSheet.swift`.

If you later decide to use pre-sliced frames instead of a sheet, the cleanest change is to replace the `SpriteSheet.load(...)` implementation while keeping the `framesByRow` API the same.
```
