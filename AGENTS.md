# Repository Guidelines

## Project Structure & Module Organization

Codeck is a Swift Package Manager project for macOS 14+. Source code lives in `Sources/` and is split into three targets: `Codeck` for the native macOS app, `CodeckCore` for shared document and model logic, and `CodeckMCP` for the `codeck-mcp` executable. Tests live in `Tests/CodeckTests`. App and document icons are in `Resources/`, sample `.mdeck` decks are in `Examples/`, and the static site is in `docs/`. Generated build products belong in `.build/` or `dist/` and should not be committed.

## Build, Test, and Development Commands

- `brew bundle`: install local tools (`swiftformat`, `swiftlint`).
- `swift build`: compile all package targets.
- `swift test`: run the XCTest suite.
- `swift run codeck-mcp`: run the file-based MCP server from the repository root.
- `script/format.sh`: format `Package.swift`, `Sources`, and `Tests`.
- `script/lint.sh`: run SwiftFormat lint mode and SwiftLint.
- `script/build_and_run.sh [run|--debug|--logs|--telemetry|--verify]`: build an app bundle in `dist/` and launch or inspect it.

## Coding Style & Naming Conventions

Use Swift 6 conventions and keep code formatted by SwiftFormat. The root `.swiftformat` uses 4-space indentation, `--maxwidth 160`, preserved argument and collection wrapping, trimmed whitespace, and no semicolons. SwiftLint covers `Package.swift`, `Sources`, and `Tests`; notable rules include sorted imports, closure spacing, `first(where:)`/`contains` preferences, and line length warnings at 160 characters. Prefer clear Swift type names in UpperCamelCase and methods/properties in lowerCamelCase. Keep target-specific code inside its target directory.

## Testing Guidelines

Tests use XCTest and are grouped by feature in `Tests/CodeckTests`, usually with filenames ending in `Tests.swift`. Name test methods descriptively, for example `testParsesThemeAndSlideSeparatorsOutsideFences`. Run `swift test` before submitting changes; add or update tests for parser behavior, document mutations, MCP protocol handling, and user-visible model logic.

## Commit & Pull Request Guidelines

Recent history uses short, imperative commit subjects such as `Use four-space Swift indentation` and `Tighten toolbar icon button styling`. Keep commits focused and avoid mixing formatting with behavioral changes. Pull requests should include a concise summary, verification commands run, linked issues when relevant, and screenshots or screen recordings for UI changes.

## Agent-Specific Notes

Respect the existing SwiftPM layout and scripts. Prefer `script/format.sh` over ad hoc formatter invocations. Do not rewrite generated files in `.build/` or `dist/` unless the task explicitly concerns packaging or release output.
