# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [Unreleased]

### Changed

- Updated documentation wording to consistently describe local ChatGPT Codex auth usage.
- Added explicit disclaimer text in docs that CodexBar is unofficial and not affiliated with OpenAI.
- Updated app and docs for the weekly-only `rate_limit.primary_window` payload.
- Added silent token refresh from local `~/.codex/auth.json` on 401.

## [0.1.0] - 2026-04-27

### Added

- Initial working MVP for a macOS menu bar Codex usage monitor
- Usage fetch and parsing for short-window and weekly limits
- Menu bar details view with reset times and manual refresh
- Launch at login support
