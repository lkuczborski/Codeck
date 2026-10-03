Codeck v0.7 has been refreshed for macOS 27, with native Liquid Glass controls and a more consistent workspace.

- Refreshed the title bar, editor toolbar, slide sidebar, settings, and assistant with native controls, compact sizing, and consistent spacing. The appearance picker clearly highlights its selected mode.
- Integrated the assistant's Use Web checkbox and circular Send button into the composer.
- Unified the slide canvas across the editor preview, hover preview, and presentation mode so typography, images, and layout match at different sizes.
- Added padding and a subtle shadow to the editor preview, and fixed preview resizing glitches and crashes.
- Improved the hover preview's sizing and native animation, and made Present respond to the first click while the hover preview is open.
- Built against the macOS 27 SDK to enable the current system UI, while retaining macOS 14 and later support.

Also included in v0.7:

- Changed the default model for new decks and Codex cards without overrides to GPT-6.1 Sol with Light reasoning.
- The model picker uses the current models and reasoning levels available through Codex, and keeps the last successful list when a refresh fails.
- Preserved saved deck model and reasoning settings when refreshing the model list.
- Added support for the Codex executable bundled with the desktop app for live cards and model discovery, without requiring a separate CLI installation.
- The Mac app is Developer ID signed and notarized by Apple for distribution.

Download `{{ZIP_NAME}}` for Apple silicon and Intel Macs running macOS 14 or later. The archive includes `Codeck.app` and `codeck-mcp`. This refresh keeps the version at v0.7.

Built from commit `{{COMMIT}}`. The app has a stapled Apple notarization ticket; signing, Gatekeeper, and extracted archive checks passed. The test suite completed with 183 tests, one skipped, and no failures.

SHA-256: `{{SHA256}}`
