# Untracker for macOS

Untracker is a small macOS menu bar app that cleans tracking links when they are opened from other apps. It works as a lightweight default-browser proxy: macOS sends clicked `http` and `https` links to Untracker, Untracker cleans the URL, then it opens the result in the browser you choose.

Untracker only receives web URLs opened through macOS's default browser handler.

## How It Works

1. Install and launch Untracker.
2. Choose the browser that should open cleaned links from the Untracker menu.
3. Set Untracker as the default browser in macOS System Settings.
4. Click links in apps such as Mail, Messages, Slack, Notes, PDFs, Terminal, Finder, or Spotlight.
5. Untracker cleans the URL and forwards it to the selected browser.

Links clicked inside an already-open browser are handled by that browser and do not pass through macOS's default browser handler.

## Requirements

- macOS 13 or later
- Xcode command line tools with Swift Package Manager

## Build and Run

```sh
make test
make app
```

`make app` builds and signs the app, creates `build/Untracker.dmg`, and opens a polished drag-to-Applications installer window. Drag `Untracker.app` onto Applications, quit any older running copy, launch the installed app once, then choose `Set as Default Browser` from the Untracker menu. macOS default-browser and login-item settings are user-controlled, so macOS may still require approval.

## Menu Bar Controls

- `Clean Links` enables or disables URL cleaning. When disabled, Untracker still forwards clicked links to the selected browser without changing them.
- `Open Cleaned Links In` lists detected installed browsers automatically.
- `Set as Default Browser` asks macOS to make Untracker the handler for web links.
- `Start at Login` controls whether Untracker starts automatically.

## Privacy Guarantees

- Untracker has no telemetry, analytics, tracking, or background sync.
- Untracker only receives web URLs opened through macOS's default browser handler.
- URL cleaning is local unless the clicked URL is exactly one standalone HTTPS URL with no embedded username or password.
- Remote redirect expansion is opt-in inside the code and only runs after that standalone-HTTPS-URL check passes.
- HTTP URLs, scheme-less URLs, non-web URLs, and URLs containing credentials never trigger remote redirect expansion.
- Known tracking parameters are removed before a remote redirect request is made, so the app does not forward removable trackers to short-link hosts.
- Redirect requests use an ephemeral `URLSession` with cookies, credential storage, and URL cache disabled. The app does not attach app state or stored browser cookies to those requests.
- When a standalone HTTPS short link is resolved, the target server still receives the normal network information required for that request, such as the URL being resolved, IP-level connection metadata, and the app's `User-Agent`.

## Development

- Core URL cleanup lives in `Sources/UntrackerCore`.
- The macOS menu bar and URL-handler app lives in `Sources/UntrackerApp`.
- The app registers `http` and `https` URL schemes in `Packaging/Info.plist`.
- The `.app` bundle is assembled by `make bundle` using `Packaging/Info.plist` and ad-hoc code signing for local testing.
- The drag-to-Applications disk image is assembled, styled, compressed, and opened by `make app`.

## Attribution

The URL cleanup behavior is adapted from the Apache-2.0 licensed Android project [zhanghai/Untracker](https://github.com/zhanghai/Untracker).
