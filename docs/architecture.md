# Architecture

CodexBar is intentionally small: one menu bar UI entry point and one usage model.

CodexBar is an unofficial utility and is not affiliated with, endorsed by, or sponsored by OpenAI.

## Components

- `CodexBar/CodexBarApp.swift`
  - Defines the menu bar extra UI.
  - Renders current limit values, reset times, and last update timestamp.
  - Exposes manual refresh and launch-at-login controls.
- `CodexBar/CodexUsageModel.swift`
  - Owns state for displayed usage values.
  - Loads local ChatGPT Codex auth data.
  - Sends usage requests and maps responses to UI-facing values.
  - Runs automatic refresh on startup and every 5 minutes.

## Data Flow

1. App starts and `CodexUsageModel` initializes.
2. Model loads auth values from local ChatGPT Codex auth JSON.
3. Model sends request to the Codex usage endpoint with required headers.
4. Response is decoded into usage window structures.
5. UI-bound published properties update on the main actor.
6. Menu bar label and dropdown view refresh automatically.

## Refresh Behavior

- Automatic refresh runs immediately on launch, then every 300 seconds.
- Manual refresh triggers the same refresh path.
- On non-200 HTTP or decode/auth errors, a compact error title is shown.

## Notes

- This repository currently prioritizes MVP simplicity over abstraction.
- If complexity grows, a next step is separating networking/auth into dedicated services.
