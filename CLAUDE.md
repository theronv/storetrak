# Storetrak — Claude Instructions

This is a personal inventory web + iOS app. Read ARCHITECTURE.md for the full technical overview.

## Project Structure

```
storetrak/
├── index.html               # Entire web app (HTML + CSS + JS, no build step)
├── ARCHITECTURE.md          # Full technical architecture reference
├── api/                     # Cloudflare Workers backend
│   ├── src/
│   │   ├── index.ts         # Hono app entry, mounts all routers
│   │   ├── auth.ts          # PBKDF2 hashing + JWT sign/verify + jwtMiddleware
│   │   ├── db.ts            # Turso libsql singleton client
│   │   ├── types.ts         # Env, User, Room, Tote, Item, JWTPayload interfaces
│   │   └── routes/
│   │       ├── auth.ts      # /auth/* — register, login, forgot/reset/change password
│   │       ├── rooms.ts     # /rooms CRUD
│   │       ├── totes.ts     # /totes CRUD
│   │       └── items.ts     # /items CRUD + bulk PATCH
│   └── wrangler.toml
└── ios/
    ├── project.yml          # xcodegen config (run xcodegen generate to rebuild .xcodeproj)
    └── Storetrak/
        ├── App/
        │   ├── AppState.swift       # Central ObservableObject — all data + API methods
        │   └── StoretrakApp.swift   # App entry point
        ├── Services/
        │   ├── APIClient.swift      # URLSession async/await wrapper
        │   └── AuthManager.swift    # Keychain JWT storage
        ├── Models/                  # Item.swift, Tote.swift, Room.swift (Codable structs)
        └── Views/
            ├── Inbox/InboxView.swift
            ├── Totes/TotesView.swift
            ├── Rooms/RoomsView.swift
            ├── Stats/StatsView.swift
            ├── Auth/LoginView.swift
            └── Shared/              # ItemDetailSheet, BulkMoveSheet, Theme, ToastView, etc.
```

## Key Constants

- **API base URL:** `https://storetrak-api.theronv.workers.dev`
  - Set in `index.html` (top of `<script>` as `API_BASE`)
  - Set in `ios/Storetrak/Services/APIClient.swift` as `static let base`
- **Database:** Turso at `https://app.turso.tech/theronv/databases/storetrack`
- **JWT expiry:** 7 days

## Design System

- **Colors:** `--bg: #0f0f0f`, `--accent: #f0a500` (amber), `--surface: #181818`, `--surface2: #1e1e1e`
- **Fonts:** Space Mono (monospace badges), Barlow (body), Barlow Condensed (headings, always uppercase)
- iOS colors are in `Views/Shared/Theme.swift` as `Color` extensions, matching the web values

## Development Patterns

### Web (`index.html`)
- All state lives in three arrays: `rooms`, `totes`, `items`
- `renderAll()` re-renders everything — always call after mutating state
- `api(method, path, body)` is the fetch wrapper — handles auth headers and 401 logout
- Inbox = items where `tote_id` is null or falsy

### iOS
- All data mutations go through `AppState` methods — never call `APIClient` directly from a View
- Views use `@EnvironmentObject var appState: AppState`
- `AppState` is `@MainActor` — all published property updates are safe on main thread
- Use `@FocusState` for keyboard management in input-heavy views
- Bulk operations use `withTaskGroup` for parallel API calls
- `APIClient.request<T>` — use when you need a decoded response body
- `APIClient.send` — use for DELETE and other calls where the response body is ignored

### API
- All data routes require JWT via `jwtMiddleware` — sets `userId` and `userEmail` in Hono context
- All queries filter by `user_id` — users are fully isolated
- Tote ownership is verified via JOIN through rooms before assigning items

## Platform Parity Rule

**Any user-facing feature built on one platform must be implemented on the other before the task is complete.** This applies to both new features and changes to existing behaviour. When a task touches only one platform, always check the parity table below and implement the equivalent change on the other platform in the same session.

### Feature Parity Table

| Feature | Web (`index.html`) | iOS |
|---------|-------------------|-----|
| Login / Register | ✅ | ✅ |
| Forgot / Reset password | ✅ | ✅ |
| Change password | ✅ | ✅ |
| Inbox — view unsorted items | ✅ | ✅ |
| Inbox — add item (type + category) | ✅ | ✅ |
| Inbox — quick-add auto-refocus after submit | ✅ | ✅ |
| Inbox — tap item to edit detail | ✅ | ✅ |
| Inbox — long-press to multi-select | ✅ | ✅ |
| Inbox — bulk move to tote | ✅ | ✅ |
| Inbox — bulk delete with confirmation | ✅ | ✅ |
| Totes — view by room | ✅ | ✅ |
| Totes — add item directly to tote | ✅ | ✅ |
| Totes — add / edit / delete tote | ✅ | ✅ |
| Rooms — add / delete room | ✅ | ✅ |
| Item detail — edit all fields | ✅ | ✅ |
| Item detail — move to tote / inbox | ✅ | ✅ |
| Item detail — delete item | ✅ | ✅ |
| Stats overview | ✅ | ✅ |
| Pull-to-refresh | ✅ (page reload) | ✅ |

When adding a new feature, add a row to this table. Mark ✅ when implemented, ❌ when missing.

## Common Tasks

**Add a new field to Item:**
1. Add column to Turso schema
2. Update `types.ts` `Item` interface
3. Update `items.ts` INSERT/PATCH allowed fields list
4. Update `ios/Storetrak/Models/Item.swift` struct
5. Update `AppState.saveItem()` body struct
6. Update `ItemDetailSheet.swift` UI

**Add a new API route:**
1. Create `api/src/routes/newroute.ts`
2. Mount in `api/src/index.ts` with `app.route('/path', newRoutes)`
3. Add corresponding method to `AppState.swift`
4. Add corresponding `APIClient` call if needed

**Deploy API changes:**
```bash
cd api && wrangler deploy
```

**Regenerate iOS project after adding files:**
```bash
cd ios && xcodegen generate
```

## Secrets (never commit these)

Set via `wrangler secret put <NAME>`:
- `JWT_SECRET` — HMAC signing key
- `TURSO_URL` — libsql connection string
- `TURSO_AUTH_TOKEN` — Turso auth token
- `RESEND_API_KEY` — transactional email for password reset
- `RESEND_FROM` — (optional) from address
