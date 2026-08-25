# Rain Speed Tuning

**Date:** 2026-08-25
**Status:** Approved

## Goal

Make the existing layered rain feel subtly slower and calmer without changing its density, length, brightness, slant, or depth ordering.

## Design

Scale each layer's speed base and variation by 0.75:

- Near: `2.2, 0.8` -> `1.65, 0.6`
- Mid: `1.4, 0.8` -> `1.05, 0.6`
- Far: `0.8, 0.8` -> `0.6, 0.6`

The existing three summed O(1) evaluations remain unchanged apart from these speed parameters. No new uniform, state, scene, or dependency is needed.

## Verification

Run the Godot project and confirm there are no shader compilation or runtime errors. The effect should remain visibly moving, but calmer than the current version.
