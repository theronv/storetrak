# Storetrak iOS App

## Prerequisites

- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Font files (see below)

## Setup

### 1. Add Fonts

Download and place these font files in `Storetrak/Resources/Fonts/`:

- **Space Mono**: `SpaceMono-Regular.ttf`, `SpaceMono-Bold.ttf`
  → https://fonts.google.com/specimen/Space+Mono
- **Barlow**: `Barlow-Regular.ttf`, `Barlow-Medium.ttf`, `Barlow-SemiBold.ttf`, `Barlow-Bold.ttf`
  → https://fonts.google.com/specimen/Barlow
- **Barlow Condensed**: `BarlowCondensed-Bold.ttf`
  → https://fonts.google.com/specimen/Barlow+Condensed

### 2. Generate the Xcode project

```bash
cd storetrak/ios
xcodegen generate
```

This creates `Storetrak.xcodeproj`.

### 3. Open and run

```bash
open Storetrak.xcodeproj
```

Select your target device/simulator and press ⌘R.

### 4. Set your development team

In Xcode → Storetrak target → Signing & Capabilities → Team: select your Apple ID.

## Architecture

- **`App/`** — App entry point (`StoretrakApp.swift`) and central state (`AppState.swift`)
- **`Models/`** — `Room`, `Tote`, `Item` Codable structs
- **`Services/`** — `APIClient.swift` (URLSession async/await), `AuthManager.swift` (Keychain JWT)
- **`Views/Auth/`** — Login / register screen
- **`Views/Main/`** — Tab bar host
- **`Views/Inbox/`** — Inbox tab (unsorted items, bulk select, long-press haptics)
- **`Views/Totes/`** — Totes tab (room filter strip, tote cards)
- **`Views/Rooms/`** — Rooms tab
- **`Views/Stats/`** — Stats / overview tab
- **`Views/Shared/`** — Theme, sheets, toast, shared components

## API

The app talks to `https://storetrak-api.workers.dev`. JWT is stored in the iOS Keychain.
