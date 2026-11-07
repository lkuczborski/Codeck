Codeck v0.8 adds automatic media fitting, full-slide backgrounds, and movie playback to Markdown decks.

- Images, animated GIFs, and movies scale down to fit the slide while preserving their aspect ratio and leaving room for headings, captions, and other media. Smaller assets keep their natural size.
- Add an image or animated GIF background with `![bg](Images/background.gif)` in its own paragraph. Backgrounds fill the slide edge to edge, stay centered, and crop as needed, with foreground content above them.
- Insert movies using image Markdown, such as `![Demo](Movies/demo.mp4)`. MP4, M4V, MOV, and WebM paths show playback controls and preload the first frame; playback starts when you press Play.
- Local movies play in the Mac app with relative or absolute paths. Media paths support spaces, escaped punctuation, and URL fragments.
- Added **Video** and **Background Image** options to the **Insert** menu in the Mac app and Codex workspace.
- Media fitting updates after loading and resizing across editor and hover previews, presentation mode, template previews, and the Codex workspace. Markdown media examples inside code stay literal.

Download `{{ZIP_NAME}}` for Apple silicon and Intel Macs running macOS 14 or later. The archive includes `Codeck.app` and `codeck-mcp`.

Built from commit `{{COMMIT}}`.

SHA-256: `{{SHA256}}`
