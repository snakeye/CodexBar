# Troubleshooting

CodexBar is an unofficial utility and is not affiliated with, endorsed by, or sponsored by OpenAI.

## App shows error immediately

Check that local ChatGPT Codex auth at `~/.codex/auth.json` exists and is readable for your current macOS user.

## Unauthorized or 401 responses

Your token may be expired or invalid. Re-authenticate with your Codex/ChatGPT tooling to refresh local tokens, then use Refresh in the app.

## Values look wrong for your account

Ensure `tokens.account_id` in `~/.codex/auth.json` matches the account you expect to monitor.

## No updates after network changes

The app refreshes every 5 minutes. Use the Refresh button for immediate update and verify your network can access ChatGPT backend endpoints.

## Stale UI values

Quit and reopen the app from Xcode to reset state, then refresh again.
