# AZ Zikr

A small zikr shows next to the mouse (or in a fixed spot on screen) with each click. Light and calm, for Mac and Windows.
Idea by Sherif Tolba · design and build by Abdelrahman Ahmed (AZ Creative).

## Structure
| Folder | Contents |
|---|---|
| `web/` | The shared settings UI (`settings.html`) and the bubble design reference (`bubble.css`), used by both Mac and Windows |
| `mac/` | The Mac app (Swift, no Xcode needed) |
| `windows/` | The Windows app (C# · .NET Framework 4.8 · WebView2 for the settings window only) |
| `brand/` | Official AZ logo and icon |
| `prototype/` | The first interactive prototype |

## Lightness
- The bubble is drawn natively (SwiftUI on Mac / GDI+ on Windows), in a tiny window that exists only while it's showing.
- The web engine only runs while the settings window is open, and is fully released when it closes.
- Measured on Mac: ~19MB RAM and 0% CPU when idle.

## Mac
```bash
cd mac
./build.sh            # dist/AZ Zikr.app
./build.sh --install  # and copy it to /Applications
./build.sh --dmg      # dist/AZ-Zikr-<version>.dmg ← this is the file you send to people
```

## Windows
You don't need a Windows machine: GitHub Actions builds it (`.github/workflows/windows.yml`).
- Any push to `main` → the build is under the run's **Artifacts** (`AZ-Zikr-Windows`).
- Push a tag like `v1.0.0` → `AZ-Zikr-Setup-1.0.0.exe` and the portable zip are attached to the release automatically.

The installer is a single file, needs no admin rights, installs in one click, and starts with Windows.
