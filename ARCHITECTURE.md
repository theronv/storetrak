# Storetrak — Architecture

Storetrak is a personal inventory management app. It lets users track physical items across rooms and storage totes (bins/boxes). Items without a tote assignment live in an "Inbox" for later sorting.

---

## High-Level Overview

```
┌─────────────────────┐     HTTPS/JSON      ┌──────────────────────────────┐
│   Web App           │ ──────────────────► │  Cloudflare Workers API      │
│   (index.html)      │                     │  storetrak-api.theronv       │
│                     │                     │  .workers.dev                │
│   iOS App           │ ──────────────────► │                              │
│   (SwiftUI)         │                     └──────────────┬───────────────┘
└─────────────────────┘                                    │ libsql
                                                           ▼
                                                  ┌─────────────────┐
                                                  │  Turso Database │
                                                  │  (SQLite edge)  │
                                                  └─────────────────┘
```

Both clients are feature-equivalent. The web app is a single HTML file with no build step; the iOS app is a SwiftUI app targeting iOS 17+.

---

## Data Model

Four tables in Turso (SQLite):

```
users
  id            TEXT PRIMARY KEY   (UUID)
  email         TEXT UNIQUE
  password_hash TEXT               (PBKDF2, format: "salthex:hashhex")
  reset_token   TEXT               (8-char hex, nullable)
  reset_token_exp INTEGER          (Unix timestamp, nullable)

rooms
  id      TEXT PRIMARY KEY   (UUID)
  user_id TEXT               (FK → users.id)
  name    TEXT
  code    TEXT               (short label, e.g. "GAR", "LR")

totes
  id      TEXT PRIMARY KEY   (user-chosen, e.g. "GAR-01")
  room_id TEXT               (FK → rooms.id)
  name    TEXT
  shelf   TEXT               (optional location label)

items
  id        TEXT PRIMARY KEY   (UUID)
  user_id   TEXT               (FK → users.id)
  tote_id   TEXT               (FK → totes.id, NULL = inbox)
  name      TEXT
  category  TEXT               (default: "other")
  qty       INTEGER            (default: 1)
  value     REAL               (nullable)
  make      TEXT               (nullable)
  model     TEXT               (nullable)
  year      TEXT               (nullable)
  serial    TEXT               (nullable)
  notes     TEXT               (nullable)
  image_url TEXT               (nullable)
```

**Key relationship:** `tote_id = NULL` on an item means it is unsorted — this is the "Inbox". No separate inbox table exists.

Tote IDs are human-readable and user-defined (e.g. `GAR-01`, `LR-03`). The API auto-suggests the next number per room but the user can override.

---

## Backend — Cloudflare Workers API

**Stack:** TypeScript · [Hono](https://hono.dev) · `@libsql/client` · Cloudflare Workers runtime

**Entry point:** `api/src/index.ts`
**Deploy:** `cd api && wrangler deploy`
**Local dev:** `wrangler dev`

### Routes

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register` | — | Create account, returns JWT |
| POST | `/auth/login` | — | Returns JWT |
| POST | `/auth/forgot-password` | — | Sends reset code via Resend |
| POST | `/auth/reset-password` | — | Validates code, sets new password |
| POST | `/auth/change-password` | JWT | Changes password for logged-in user |
| GET | `/rooms` | JWT | List user's rooms |
| POST | `/rooms` | JWT | Create room |
| DELETE | `/rooms/:id` | JWT | Delete room (cascades in app state) |
| GET | `/totes` | JWT | List user's totes |
| POST | `/totes` | JWT | Create tote |
| PATCH | `/totes/:id` | JWT | Update tote |
| DELETE | `/totes/:id` | JWT | Delete tote |
| GET | `/items` | JWT | List all user's items (ordered by name) |
| POST | `/items` | JWT | Create item |
| PATCH | `/items` | JWT | Bulk move — body: `{ ids, tote_id }` |
| PATCH | `/items/:id` | JWT | Update single item |
| DELETE | `/items/:id` | JWT | Delete item |

### Authentication

- Passwords hashed with **PBKDF2-SHA256** (100,000 iterations, 32-byte key, random 16-byte salt). Stored as `salthex:hashhex`.
- **JWT** tokens are HS256, signed/verified manually using the Web Crypto API (no third-party JWT lib). Payload: `{ sub, email, iat, exp }`. Expiry: 7 days.
- All data routes use `jwtMiddleware` which reads the `Authorization: Bearer <token>` header and injects `userId`/`userEmail` into Hono context variables.
- All DB queries filter by `user_id` — users can only access their own data.
- Password reset uses a random 8-char hex code (4 random bytes) stored in the users table with a 30-minute expiry. Delivered via **Resend** email API.

### Database Client

`api/src/db.ts` — singleton `@libsql/client` instance created lazily from Wrangler environment secrets (`TURSO_URL`, `TURSO_AUTH_TOKEN`).

### Environment Secrets (set via `wrangler secret put`)

| Secret | Purpose |
|--------|---------|
| `JWT_SECRET` | HMAC signing key for JWTs |
| `TURSO_URL` | libsql connection URL |
| `TURSO_AUTH_TOKEN` | Turso auth token |
| `RESEND_API_KEY` | Resend transactional email |
| `RESEND_FROM` | (optional) From address override |

### CORS

Allowed origins: `https://storetrak.pages.dev`, `https://theronv.github.io`, `http://localhost:3000`, `http://localhost:8080`.

---

## Web Frontend — `index.html`

A single self-contained HTML file. No build step, no framework, no dependencies beyond Google Fonts.

- **Vanilla JS** — all logic in `<script>` at bottom of file
- **No bundler** — can be opened directly or served as a static file
- **Auth** — JWT stored in `localStorage` under key `token`
- **State** — three in-memory arrays: `rooms`, `totes`, `items`. Loaded on login via three parallel `fetch` calls. Mutated optimistically after each API call.
- **Routing** — single-page, tab-based. Four tabs: Inbox, Totes, Rooms, Stats. Controlled by `switchTab()`.

### Key JS Functions

| Function | Description |
|----------|-------------|
| `api(method, path, body)` | Fetch wrapper — adds Bearer token, handles 401 logout |
| `addInboxItem()` | Creates item with `tote_id: null`, refocuses input for quick successive entry |
| `addItemToTote(toteId)` | Creates item assigned to a specific tote |
| `renderAll()` | Re-renders inbox, totes, rooms, stats, and badge counts |
| `openDetail(id)` | Opens item detail modal |
| `bulkMove()` | Moves all `selectedInboxIds` to chosen tote via bulk PATCH |

### Design System

- **Colors:** `--bg: #0f0f0f`, `--accent: #f0a500` (amber), `--surface: #181818`, `--surface2: #1e1e1e`
- **Fonts:** Space Mono (monospace badges/labels), Barlow (body), Barlow Condensed (headings — always uppercase)
- **Pattern:** Dark surfaces, amber accent borders, all-caps condensed headings

---

## iOS App — `ios/`

**Stack:** Swift · SwiftUI · iOS 17+ · MVVM-lite
**Project generation:** `cd ios && xcodegen generate` (reads `project.yml`)

### Architecture

Single `AppState` class owns all data. Views read from it via `@EnvironmentObject`. Mutations go through `AppState` async methods which call the API and update local state in place.

```
StoretrakApp
└── MainTabView
    ├── InboxView          — unsorted items (tote_id == nil)
    ├── TotesView          — rooms + totes + items-per-tote
    ├── RoomsView          — room management
    └── StatsView          — counts summary
```

### Key Files

| File | Purpose |
|------|---------|
| `App/AppState.swift` | Central `@MainActor ObservableObject` — all data arrays, all API-mutating methods, toast state |
| `Services/APIClient.swift` | `URLSession` async/await wrapper — `request<T>` (returns decoded), `send` (fire-and-forget) |
| `Services/AuthManager.swift` | Keychain singleton — stores/reads/deletes JWT under service `"storetrak"`, account `"jwt"` |
| `Views/Inbox/InboxView.swift` | Inbox tab — quick-add input with auto-refocus, chip grid, bulk select/move/delete |
| `Views/Totes/TotesView.swift` | Totes tab — collapsible room sections, per-tote item lists, inline add |
| `Views/Shared/ItemDetailSheet.swift` | Full item edit sheet |
| `Views/Shared/BulkMoveSheet.swift` | Sheet for moving multiple selected inbox items to a tote |
| `Views/Shared/Theme.swift` | `Color` extensions matching the web design system |

### AppState Methods

| Method | Description |
|--------|-------------|
| `loadAll()` | Parallel fetch of rooms, totes, items — handles 401 by logging out |
| `addItem(name:category:toteId:)` | POST /items |
| `saveItem(_:)` | PATCH /items/:id |
| `deleteItem(_:)` | DELETE /items/:id |
| `deleteItems(_:)` | Parallel DELETE for a Set of ids (bulk delete) |
| `moveItems(_:to:)` | PATCH /items bulk — moves Set of ids to a tote or inbox |
| `addRoom/deleteRoom` | POST/DELETE /rooms |
| `addTote/saveTote/deleteTote` | POST/PATCH/DELETE /totes |

### Keychain Token Storage

`AuthManager` uses `SecItemAdd`/`SecItemUpdate`/`SecItemCopyMatching`/`SecItemDelete` directly — no third-party wrapper. Token is stored as UTF-8 data under `kSecClassGenericPassword`.

### Inbox Bulk Select

- Long-press a chip → enters selection mode, adds item to `appState.selectedInboxIds: Set<String>`
- Bulk bar appears at top showing count + CANCEL / MOVE TO TOTE / trash icon
- Trash triggers `confirmationDialog` → calls `appState.deleteItems(ids)` which runs parallel DELETEs

### Quick-Add (Inbox)

After `addItem()` resolves, `inputFocused = true` is set on a `@FocusState` bound to the text field. This keeps the keyboard up and cursor in the field for rapid successive entry.

---

## Deployment

### API

```bash
cd api
npm install
wrangler secret put JWT_SECRET
wrangler secret put TURSO_URL
wrangler secret put TURSO_AUTH_TOKEN
wrangler secret put RESEND_API_KEY
wrangler deploy
```

### Web

Deploy `index.html` as a static file to Cloudflare Pages, GitHub Pages, or any static host. The API base URL is hardcoded at the top of the `<script>` block as `API_BASE`.

### iOS

```bash
cd ios
xcodegen generate
open Storetrak.xcodeproj
```

Add font files to `Resources/Fonts/` (Space Mono, Barlow, Barlow Condensed from Google Fonts) before building. The API base URL is in `APIClient.swift` as `static let base`.

---

## Migration History

The app was originally built against Supabase (PostgREST + Supabase Auth). It was migrated to Turso + Cloudflare Workers in early 2026. The migration script at `api/src/migrate.ts` handled the one-time data transfer from the old Supabase instance. The old Supabase URL was `https://kwhawubarlocjluujurq.supabase.co`.
