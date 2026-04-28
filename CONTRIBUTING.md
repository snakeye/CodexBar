# Contributing

Thanks for your interest in improving CodexBar.

CodexBar is an unofficial utility and is not affiliated with, endorsed by, or sponsored by OpenAI.

## Local Setup

1. Open `CodexBar.xcodeproj` in Xcode.
2. Build and run the `CodexBar` target.
3. Ensure local ChatGPT Codex auth exists at `~/.codex/auth.json`.

## Guidelines

- Keep changes focused and minimal.
- Follow existing Swift and SwiftUI style in the repository.
- Do not commit secrets, tokens, or local credential files.
- Update docs when behavior or setup changes.

## Pull Request Checklist

- App builds successfully in Xcode.
- Changes are tested manually for the touched behavior.
- `README.md` and `CHANGELOG.md` are updated when relevant.
- No sensitive data is introduced in code, logs, or docs.
