# Lightning Room Illumination Design

## Goal

Retain the apartment lightning event while removing the visible hard-edged grey-blue rectangle from the room.

## Current behavior

`scenes/main/environment.gd` renders `RoomFlash` as a low-opacity `ColorRect` over a large mapped artwork rectangle. Its flat opaque color has a rectangular edge, which makes the illumination read as a box rather than lightning.

`WindowFlash` is a separate, window-bounded flash. Lightning timing is randomized to 45–150 seconds and may produce one delayed secondary strike.

## Decision

Keep the existing timing, secondary-strike behavior, window flash, workspace layering, and input behavior. Replace only `RoomFlash` with a `TextureRect` backed by a `GradientTexture2D`:

- radial fill, cool white-blue at the source and fully transparent at its edge;
- source centered on the current residence's mapped window, calculated from its existing `window` and `room_flash` art-space rectangles;
- room-flash alpha remains controlled by the existing lightning tween;
- no new shader, weather controller, scene, configuration, or audio work.

The studio and loft continue to use their existing `room_flash` bounds. Their distinct window positions determine the gradient source, so the illumination originates from the correct exterior location in both artworks.

## Acceptance criteria

1. A lightning strike still raises both `WindowFlash` and `RoomFlash` alphas immediately and fades them back to transparent on the existing timings.
2. `RoomFlash` is a radial `GradientTexture2D`, not a flat `ColorRect`; its terminal gradient color has zero alpha.
3. The gradient source equals the selected residence window center expressed in the selected room-flash rectangle's UV space.
4. `RoomFlash` remains mouse-input-safe and remains mapped to the existing room-flash artwork rectangle after viewport resize and residence changes.
5. The full environment test passes and an interactive run shows a diffuse room response with no visible rectangular edge.

## Alternatives rejected

- **Remove room illumination:** smallest change, but loses the interior reaction the player likes.
- **Full-screen white overlay:** removes the localized box edge but flashes unrelated screen regions and can wash out the scene.
- **New lightning shader/weather system:** disproportionate for one low-frequency visual event.
