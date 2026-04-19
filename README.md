# MeetMute

Mute and unmute any meeting app with a single keyboard shortcut. No more hunting for the mute button.

**⌃ + ⌥ + M** — works from any app, even when your meeting is in the background. Rebind anytime via the menu bar → **Change Hotkey…**.

## How It Works

MeetMute doesn't mute your system microphone. It sends the meeting app's own mute shortcut directly to it, so your teammates see your mute status change in the meeting UI.

## Supported Apps

| App | Shortcut Sent |
|-----|--------------|
| Zoom | Cmd+Shift+A |
| Microsoft Teams | Cmd+Shift+M |
| Slack Huddles | Cmd+Shift+Space |
| Google Meet (Safari, Chrome, Arc, Firefox) | Cmd+D |
| Webex | Ctrl+M |
| Discord | Cmd+Shift+M |
| FaceTime | Cmd+Shift+M |

## Install

Download the latest release from the [Releases](https://github.com/vandot/meetmute/releases/latest) page. Unzip and move `MeetMute.app` to `/Applications`.

Since the app is not signed with an Apple Developer ID, you'll need to right-click and select **Open** the first time, then click **Open** in the dialog.

## Permissions

- **Accessibility** — required for the global hotkey and sending keystrokes
- **Automation (System Events)** — required for sending shortcuts to apps
- **Automation (Safari/Chrome/Arc)** — optional, only for Google Meet tab detection

All permissions are requested at first launch. MeetMute never accesses your microphone, never records anything, and never connects to the internet.

## Troubleshooting

Open the menu bar → **Debug** → **Enable Logging**, reproduce the issue, then **Copy Diagnostics**. The clipboard will contain a paste-ready report with version, permissions, running meeting apps, and recent log entries.

## Build from Source

Requires macOS 13+ and Swift 5.9+.

```
make build        # Build MeetMute.app
make install      # Build and copy to /Applications
make dev          # Build, reset permissions, install, and launch
make clean        # Clean build artifacts
```

## Website

[meetmute.vandot.rs](https://meetmute.vandot.rs)

## License

[MIT](LICENSE)
