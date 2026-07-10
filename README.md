# Untracker for macOS

Untracker is a small macOS menu bar app that cleans tracking links when they are opened from other apps. It works as a lightweight default-browser proxy: macOS sends clicked `http` and `https` links to Untracker, Untracker cleans the URL, then it opens the result in the browser you choose.

Untracker only receives web URLs opened through macOS's default browser handler.

## How It Works

1. Install and launch Untracker.
2. Choose the browser that should open cleaned links from the Untracker menu.
3. Choose `Set as Default Browser` from the Untracker menu.
4. Click links in apps such as Mail, Messages, Slack, Notes, PDFs, Terminal, Finder, or Spotlight.
5. Untracker cleans the URL and forwards it to the selected browser.

Links clicked inside an already-open browser are handled by that browser and do not pass through macOS's default browser handler.

## Requirements

- macOS 13 or later
- Xcode command line tools with Swift Package Manager

## Install and Run From Source

```sh
git clone git@github.com:tdenisenko/Untracker.git
cd Untracker
make test
make app
```

`make app` builds and signs the app, creates `build/Untracker.dmg`, and opens the installer window automatically.

Install the app from the window that opens:

1. Quit any older running copy of Untracker from the menu bar.
2. Drag `Untracker.app` onto the `Applications` icon in the installer window.
3. If Finder asks whether to replace an existing copy, choose `Replace`.
4. Eject the `Untracker` installer volume.
5. Open the installed app from `/Applications/Untracker.app`, not from the build folder or installer volume.
6. If macOS asks for confirmation because the app was built locally, choose `Open`.

Finish setup from the Untracker menu bar icon:

1. Choose `Open Cleaned Links In`, then select the browser that should open cleaned links.
2. Leave `Clean Links` enabled.
3. Choose `Set as Default Browser`.
4. Approve any macOS prompt to make Untracker the default browser.
5. Keep Untracker running in the menu bar. `Start at Login` is enabled by default.

After setup, links opened through macOS's default browser handler go to Untracker first, then Untracker forwards the cleaned URL to the selected browser. macOS default-browser and login-item settings are user-controlled, so macOS may still require approval.

## Menu Bar Controls

- `Clean Links` enables or disables URL cleaning. When disabled, Untracker still forwards clicked links to the selected browser without changing them.
- `Open Cleaned Links In` lists detected installed browsers automatically.
- `Set as Default Browser` asks macOS to make Untracker the handler for web links. When Untracker is already the default browser, selecting the checked item asks macOS to restore the browser selected in `Open Cleaned Links In`.
- The menu bar uses the application logo with green accents only while link cleaning is enabled and Untracker is the default browser. It uses red accents whenever cleaning is disabled or another default browser is selected.
- `Start at Login` controls whether Untracker starts automatically.

## Privacy Guarantees

- Untracker has no telemetry, analytics, tracking, or background sync.
- Untracker only receives web URLs opened through macOS's default browser handler.
- URL cleaning is local unless the clicked URL is exactly one standalone HTTPS URL with no embedded username or password.
- Remote redirect expansion is opt-in inside the code and only runs after that standalone-HTTPS-URL check passes.
- HTTP URLs, scheme-less URLs, non-web URLs, and URLs containing credentials never trigger remote redirect expansion.
- Login, authentication, challenge, return, redirect, and local callback URLs are forwarded unchanged and never trigger remote redirect expansion.
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
