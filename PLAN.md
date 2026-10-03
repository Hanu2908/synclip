# Synclip — Product, Design & Architecture Plan

> Status: **Draft v1 for review** · Date: 2026-10-03 · Owner: Himanshu
> Product truth lives in [PRODUCT.md](PRODUCT.md). This plan is the build contract. `DESIGN.md` gets written *after* the UI is built, recording what actually shipped (Impeccable workflow).

---

## 0. One-paragraph summary

Synclip is a Flutter app (Android, desktop, web) that syncs clipboard text between devices. Devices meet in a **room**. A **Quick Room** is anonymous, joined with a 6-character code, QR code or link, and expires 10 hours after the last activity. **My Devices** is a permanent room tied to an email or Google account. Supabase provides realtime transport (Broadcast + Presence), encrypted history (Postgres + RLS), auth (anonymous + email OTP + Google) and scheduled cleanup (pg_cron). Every clip is **end-to-end encrypted** with a per-room AES-256-GCM key. A new device gets that key only when an existing device approves it after both screens show matching **emoji verification**, or when it scans a QR code that carries the key directly.

---

## 1. Requirements

### 1.1 Functional

| # | Requirement | Platforms |
|---|---|---|
| F1 | Create a Quick Room → show 6-char code, QR, share link | all |
| F2 | Join by code (needs host approval) or by QR/link (instant) | all (QR scan: Android only; desktop/web show QR) |
| F3 | Sign in (email OTP, Google) → My Devices room; link new devices by approval | all |
| F4 | Send text/URL clips: Android via Quick Settings tile, share sheet, auto-send on app open; desktop via automatic clipboard watching; web via paste box | per platform |
| F5 | Receive: desktop and a foreground app auto-copy; Android while backgrounded (process alive) shows a notification with a Copy action | per platform |
| F6 | History: encrypted, auto-expiring, catch-up on open | all |
| F7 | Presence: show which devices are online in the device ring | all |
| F8 | Sensitive clips: respect OS flags, detect patterns + prompt, never store | Android, desktop |
| F9 | Link previews fetched by the receiving device | Android, desktop |
| F10 | Manage devices: rename self, remove others (rotates the room key), leave room | all |
| F11 | Settings: theme, accent, dynamic color, auto-send, previews, desktop watch/pause, launch at startup | per platform |

### 1.2 Non-functional

| Concern | Target |
|---|---|
| Latency | Copy → other device's list < 1 s at p95 on normal networks |
| Privacy | Server never sees plaintext clip content or room keys |
| Reliability | Survives reconnects with no gaps or duplicates (catch-up + `clip_id` dedupe) |
| Cost | Stays inside Supabase free tier for a portfolio audience |
| Battery | No Android background service; desktop watcher idles cheaply |
| Accessibility | 48 dp targets, 200% text scale, screen-reader labels, reduced motion honoured |

### 1.3 Limits (per mode)

| Limit | Quick Room | My Devices |
|---|---|---|
| Max devices | **5** | **10** |
| Lifetime | Expires **10 h after last activity** (clip or join) | Permanent |
| Max clip size (plaintext) | **50 KB** | **100 KB** |
| History | Last **20** clips, deleted with the room | Last **50** clips, each kept **7 days** |
| Join | Code + host approval, or QR/link instant | Approval from an existing device |
| Wrong-code attempts | **5/min per IP & per user → 60 s lockout**; 20/h → 1 h lockout | n/a |
| Pending join requests | max **3** per room, each expires in **5 min** | same |
| Invite token (QR/link) | **10 min**, single use | same |
| Send rate | **30 clips/min per device** | same |
| Room creation | **10/h per user** | n/a (one vault per account) |

A 100 KB plaintext clip is about 137 KB once encrypted and base64-encoded, which fits under the free tier's 256 KB broadcast limit.

### 1.4 Constraints & known platform limits

- **Android 10+**: the clipboard can only be read by the focused app, so tiles and auto-send must bring an Activity to the front for a moment. There is no background receiving by design (decision: "only when open").
- **Web**: `navigator.clipboard.readText` is permission-gated or unsupported (Firefox), so the web client uses a paste box. Link previews are blocked by CORS.
- **Supabase free tier**:
  - 200 concurrent connections and 100 msgs/s
  - 256 KB broadcast payload
  - **the project pauses after 7 idle days**, so you may need to un-pause it before a demo
- **Linux tray** needs `libayatana-appindicator`. **Desktop Google OAuth** needs a deep-link scheme registered per OS, so email OTP is the reliable sign-in on desktop.

---

## 2. High-level architecture

```
 ┌──────────────── Flutter app (one codebase) ────────────────┐
 │  Android            Desktop (Win/Mac/Linux)      Web        │
 │  • QS tile          • tray + popover             • paste box│
 │  • share target     • clipboard watcher          • copy btn │
 │  • auto-send on open• auto-copy, autostart                  │
 │                                                             │
 │  Presentation (M3 + brand layer, go_router)                 │
 │  Application  (Riverpod controllers / sync engine)          │
 │  Domain       (Room, Device, Clip, Envelope — pure Dart)    │
 │  Data         (Supabase repos, crypto, secure storage,      │
 │                platform clipboard adapters)                 │
 └───────────────┬───────────────────────────┬─────────────────┘
                 │ WSS (Realtime)            │ HTTPS (PostgREST / RPC / Functions)
 ┌───────────────▼───────────────────────────▼─────────────────┐
 │                         Supabase                            │
 │  Realtime: private channels  room:{id}  device:{id}         │
 │            Broadcast (clips, events) + Presence (online)    │
 │  Postgres: rooms, devices, room_members, wrapped_keys,      │
 │            join_requests, invite_tokens, clips (ciphertext) │
 │            RLS everywhere · SECURITY DEFINER RPCs           │
 │            trigger: clips INSERT → realtime.send(room:{id}) │
 │  Edge Functions: join-room (IP rate limit), redeem-invite   │
 │  pg_cron: expire rooms / clips / requests every 10 min      │
 │  Auth: anonymous · email OTP · Google (linkIdentity)        │
 └─────────────────────────────────────────────────────────────┘
```

### 2.1 Unified room model (key simplification)

**My Devices is just a room** of kind `account`, owned by a `user_id`. Creating keys, approving devices, sending, history, presence and removing a device all work the same way in both modes. Only these differ:

| | Quick Room | My Devices (account room) |
|---|---|---|
| Found by | code / invite token | signed-in `user_id` (one per account) |
| Auth | anonymous Supabase user per device | permanent user, shared by all your devices |
| Expiry / limits | 10 h idle, 5 devices, 20 clips, 50 KB | none, 10 devices, 50 clips × 7 d, 100 KB |

A device can be in its account room **and** several Quick Rooms simultaneously. The room switcher in the top app bar picks the one you're viewing. Clips you send go to the **active** room.

**Identity rule:** *RLS authorises users; encryption authorises devices.* In account mode every device signed in to your account passes RLS, but a newly signed-in device still can't read anything until another of your devices approves it and hands over the room key.

---

## 3. Data flows

### 3.1 Send (non-sensitive) — single write path

```
Device A                     Postgres                         Devices B, C
  │ encrypt(clip) → envelope   │                                 │
  │ INSERT clips(row) ───────▶ │ RLS: A active member? size ok?  │
  │                            │ trigger: rate-limit, trim to N, │
  │                            │ bump rooms.last_activity_at,    │
  │                            │ realtime.send('room:{id}',      │
  │                            │   'clip', envelope, private)───▶│ decrypt → list → auto-copy
  │ ◀── 201 (row) ─────────────│                                 │
```
Storing a clip and broadcasting it happen in **one write**: the clip can't be broadcast without being stored, or stored without being broadcast.

### 3.2 Send (sensitive)
The client calls `channel.sendBroadcastMessage(event:'clip', envelope)` directly. RLS on `realtime.messages` checks membership, and nothing is written to `clips`. Receivers show a lock badge and never store it locally either.

### 3.3 Catch-up on open (no gaps, no dupes)
1. Subscribe to `room:{id}` first and buffer incoming events.
2. `SELECT … FROM clips WHERE room_id = ? AND created_at > last_seen_at ORDER BY created_at LIMIT N`.
3. Merge the buffer with the fetched rows, **dedupe by `clip_id`**, sort, then render.
4. Persist `last_seen_at` locally.

### 3.4 Create Quick Room
1. `signInAnonymously()` if there's no session yet. The device generates an X25519 keypair (stored in secure storage) and registers a `devices` row.
2. RPC `create_quick_room(device_id)` returns `{room_id, code}`. The code uses the Crockford base32 alphabet with no `0 O 1 I L U` and is stored as `sha256(code)`.
3. The device generates a random 32-byte **room key K (epoch 1)**, wraps it for itself and uploads it to `wrapped_keys`.
4. The device mints an invite token (RPC), then shows the code, a QR code and a link.

### 3.5 Join with code → host approval (+ emoji verification)
```
Joiner J                Edge fn join-room           Host H (active member)
 │ code, device_id ───▶ │ IP+user rate-limit         │
 │                      │ lookup sha256(code)        │
 │                      │ capacity / pending checks  │
 │                      │ insert member(pending),    │
 │                      │ join_request(J.pubkey)     │
 │                      │ realtime.send(room:{id},   │
 │                      │   'join_request') ───────▶ │ sheet: "Pixel 7 wants to join"
 │ subscribes device:{J} │◀── RPC claim_join(req, H.pubkey) ───────────────│ (first device to open it claims it)
 │◀─ realtime.send(device:{J}, 'claimed', H.pubkey) ─│
 │ shows SAS emojis      │                            │ shows SAS emojis (same 5?)
 │                       │                            │ Allow → wrap K for J.pubkey
 │                      │◀── RPC approve_join(req, wrapped K, H.pubkey) ──│
 │◀─ realtime.send(device:{J}, 'approved') ──────────│
 │ fetch wrapped key → unwrap → K → subscribe room:{id}
```
**Claiming:** several devices may see the request. The first to open the sheet claims it, so the joiner knows whose public key to verify against. Other devices then show "Being approved on MacBook". A claim lapses after 60 s.

**SAS (emoji verification):** `SHA-256("synclip/v1/sas" ‖ room_id ‖ sort(pubH, pubJ))`, first 30 bits → 5 emojis from a fixed 64-emoji list. If a malicious server swapped public keys, the emojis won't match and the user taps Deny. The joiner screen says *"Check these match on the other device"*.

### 3.6 Join with QR / link (instant)
`https://synclip.app/j/{room_id}#t={invite_token}&k={room_key_b64url}`. The **`#fragment` never reaches any server.** The client calls the Edge Function `redeem-invite(room_id, token)`, which checks the token hash is unexpired and unused, then marks it used and activates the member. The device already holds K from the fragment and wraps it for itself. No emojis are needed because the key travelled outside the server.

### 3.7 My Devices
- **First device on an account:** sign in, then `ensure_account_room()` creates the account room. The device generates K and becomes the sole active member.
- **Additional device:** sign in, and the device becomes a pending member. Every other online device of yours gets the approval sheet with emojis, same as 3.5. There's no code because the account itself locates the room.
- **Upgrading an anonymous device:** `linkIdentity(google)` / `updateUser(email)` keeps the same `user_id`, so Quick Room memberships survive. If the account already exists, a plain sign-in replaces the anonymous user and that device's Quick Rooms are dropped. They're ephemeral anyway, and the UI warns about it.
- **All devices lost:** "Reset My Devices" deletes the account room and its history, and a new room with a new key is created. This is the honest consequence of E2EE without a passphrase, so it's stated in Settings.

### 3.8 Remove device → key rotation
The remover generates K′ (epoch+1) and wraps it for every remaining active member, using public keys **from its local pinned cache**: the keys each device verified at approval (trust on first approval). If the server returns a different key for any member, the remover shows a warning. Then it calls RPC `rotate_room_key(room_id, epoch, wrapped[])`, which deletes the removed member's row and broadcasts `key_rotated`. Old clips stay readable under the old epoch key until they expire. New clips use K′.

### 3.9 Desktop clipboard watcher (echo-loop guard)
- When an incoming clip is written to the clipboard, remember `lastRemoteHash = sha256(text)`.
- The watcher ignores any change whose hash equals `lastRemoteHash` or `lastSentHash`.
- Bursts are debounced at 300 ms, and empty or whitespace-only changes are ignored.
- **Pause** stops the watcher entirely; the tray icon shows a paused glyph.

Without this guard, two desktops would bounce the same clip back and forth forever.

---

## 4. Security design

### 4.1 Cryptography (package `cryptography` + `cryptography_flutter`)

| Purpose | Primitive |
|---|---|
| Device identity keypair | **X25519** (stored in `flutter_secure_storage`; on web, IndexedDB, weaker, documented) |
| Room key | 32 random bytes, versioned by `epoch` |
| Clip encryption | **AES-256-GCM**, random 96-bit nonce per clip (WebCrypto on web, native on Android) |
| Associated data (AAD) | `v ‖ room_id ‖ clip_id ‖ sender_device_id ‖ epoch` (binds the ciphertext to its context; stops replays and cross-room swaps) |
| Key wrapping | `X25519(H.priv, J.pub)` → **HKDF-SHA256**(salt=`room_id`, info=`"synclip/v1/wrap" ‖ pubH ‖ pubJ`) → AES-256-GCM(K) |
| Code storage | `sha256(code)`; invite tokens likewise stored hashed |
| SAS | SHA-256 → 30 bits → 5 emojis |

**Wire envelope** (JSON, what the server sees):
```json
{ "v":1, "clip_id":"uuid", "room_id":"uuid", "sender_device_id":"uuid",
  "epoch":1, "nonce":"b64", "ct":"b64", "created_at":"iso8601" }
```
**Plaintext inside `ct`**: `{ "type":"text"|"url", "text":"…", "sensitive":false, "source":"android-tile" }`. The type and sensitivity flags are **inside** the ciphertext, so the server can't see them. (The server can still infer that a broadcast-only clip was sensitive. Accepted.)

### 4.2 Threat model

| Threat | Mitigation | Residual risk |
|---|---|---|
| Network eavesdropper | TLS + E2EE | none |
| Supabase operator / DB leak | Only ciphertext and hashed codes stored | **Metadata visible:** room ids, device names and platforms, timing, sizes. Encrypting device names is a later idea. |
| Code guessing (~1.07 B combos) | Rate limits (IP + user), approval still required, 10 h expiry | A lucky guesser only gets an approval *request*, which the user denies |
| Server MITM during approval | SAS emoji verification | A user who taps Allow without looking |
| Join-request spam | Max 3 pending per room, 5 min TTL, rate limits | Annoyance only |
| Replay / reordering | Unique `clip_id` (PK), AAD binding, dedupe | none |
| Sender spoofing inside a room | RLS insert check: `sender_device_id` belongs to `auth.uid()` | In account mode all devices are yours; per-device signatures (Ed25519) are deferred |
| Removed device keeps reading | Key rotation on removal | It keeps whatever it already received |
| Lost / stolen phone | Remove it from another device (rotation) | Clips already cached on it |
| Malicious clip content | Text only; links are never auto-opened; previews are GET-only with an SSRF guard (block private, loopback and link-local IPs, https only, 5 s timeout, 512 KB cap) | Visiting a link still reveals the receiver's IP to that site (previews can be turned off) |
| Clipboard-reading malware on the device | Out of scope | — |
| Web client key theft (XSS) | Strict CSP, no `innerHTML`/HTML rendering of clip text | Web is the lowest-trust client |

### 4.3 Server-side authorisation (RLS summary)
- **Realtime:** "Allow public access" is **off**, so all channels are private.
  - `room:{id}`: select/insert allowed only if `auth.uid()` owns an **active** membership in that room. Policies use `realtime.topic()` and `extension in ('broadcast','presence')`.
  - `device:{id}`: allowed only for the owner of that device.
- **Tables:** members read their own rooms, members, wrapped keys and clips. `clips` INSERT requires an active membership, `sender_device_id` owned by the caller, `octet_length(ct) <= room limit`, and `epoch = rooms.key_epoch`. Every state change (approve, rotate, leave, create) goes through `SECURITY DEFINER` RPCs that re-check membership. Clients never update `status` directly.
- **pgTAP tests** cover every policy (see §9).

---

## 5. Data model (Postgres)

```sql
create type room_kind     as enum ('quick','account');
create type member_status as enum ('pending','active');
create type device_platform as enum ('android','windows','macos','linux','web');

create table devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null check (char_length(name) <= 40),
  platform device_platform not null,
  public_key bytea not null check (octet_length(public_key) = 32),
  created_at timestamptz default now(), last_seen_at timestamptz
);

create table rooms (
  id uuid primary key default gen_random_uuid(),
  kind room_kind not null,
  owner_user_id uuid references auth.users on delete cascade, -- account rooms only
  code_hash text unique,                                       -- quick rooms only
  key_epoch int not null default 1,
  max_devices int not null, max_clip_bytes int not null,
  history_limit int not null, clip_ttl interval,               -- account: '7 days'
  created_at timestamptz default now(),
  last_activity_at timestamptz default now(),
  unique (owner_user_id)                                       -- one account room per user
);

create table room_members (
  room_id uuid references rooms on delete cascade,
  device_id uuid references devices on delete cascade,
  user_id uuid not null,
  status member_status not null default 'pending',
  joined_at timestamptz default now(),
  primary key (room_id, device_id)
);

create table wrapped_keys (
  room_id uuid, device_id uuid, epoch int,
  wrapped_by uuid references devices, wrapper_public_key bytea,
  nonce bytea, ciphertext bytea,
  primary key (room_id, device_id, epoch),
  foreign key (room_id, device_id) references room_members on delete cascade
);

create table join_requests (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms on delete cascade,
  device_id uuid references devices on delete cascade,
  claimed_by uuid references devices, claimed_at timestamptz,
  created_at timestamptz default now(),
  expires_at timestamptz default now() + interval '5 minutes'
);

create table invite_tokens (
  token_hash text primary key,
  room_id uuid references rooms on delete cascade,
  expires_at timestamptz not null, used_at timestamptz
);

create table clips (
  id uuid primary key,                       -- client-generated clip_id (dedupe)
  room_id uuid references rooms on delete cascade,
  sender_device_id uuid references devices on delete set null,
  epoch int not null, nonce bytea not null, ct bytea not null,
  created_at timestamptz default now(),
  expires_at timestamptz                     -- null for quick (dies with room)
);
create index on clips (room_id, created_at desc);

create table rate_events (key text, at timestamptz default now()); -- e.g. 'join:ip:1.2.3.4'
create index on rate_events (key, at);
```

**RPCs (security definer):** `create_quick_room`, `ensure_account_room`, `mint_invite`, `claim_join`, `approve_join`, `deny_join`, `rotate_room_key`, `leave_room`, `remove_device`, `rename_device`.
**Edge Functions:** `join-room` (needs the client IP for rate limiting), `redeem-invite`.
**Triggers:** `clips_after_insert` (rate limit 30/min/device, trim to `history_limit`, bump `last_activity_at`, `realtime.send`). `members_after_change` broadcasts `member_update`.
**pg_cron (every 10 min):**
- delete quick rooms where `last_activity_at < now() - 10h`
- delete clips past `expires_at`
- delete join requests past `expires_at`
- delete used or expired invite tokens
- delete `rate_events` older than 1 h

---

## 6. Flutter app architecture

### 6.1 Stack & packages
Check pub.dev for current versions when scaffolding. Don't pin versions from this doc.

| Concern | Package |
|---|---|
| Backend | `supabase_flutter` |
| State / DI | `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` |
| Routing / deep links | `go_router`, `app_links` |
| Models | `freezed`, `json_serializable` |
| Crypto | `cryptography`, `cryptography_flutter` |
| Secrets | `flutter_secure_storage` |
| QR | `qr_flutter` (show), `mobile_scanner` (scan, Android) |
| Android share target | `receive_sharing_intent` (or `share_handler`) |
| Android tile, sensitive flag, translucent quick-send Activity | **custom Kotlin** via platform channel |
| Desktop | `tray_manager`, `window_manager`, `launch_at_startup`, `clipboard_watcher`, `local_notifier` |
| Android notifications | `flutter_local_notifications` |
| Theming | `dynamic_color`, bundled **Roboto Flex** + **JetBrains Mono** |
| Motion | `flutter_animate` + `CustomPainter` for the device ring |
| Link previews | `http` + `html` (OpenGraph parse) |
| Misc | `uuid`, `device_info_plus`, `shared_preferences` |
| Lints / tests | `very_good_analysis`, `mocktail`, `integration_test` |

### 6.2 Folder structure (feature-first)
```
lib/
  main.dart                     # bootstrap per platform
  app/
    app.dart  router.dart
    theme/   tokens.dart  color_schemes.dart  typography.dart  motion.dart  shapes.dart
  core/
    crypto/      room_key.dart  envelope_codec.dart  key_wrap.dart  sas.dart
    supabase/    client.dart  realtime_channel.dart
    clipboard/   clipboard_port.dart (interface) + android_/desktop_/web_ adapters
    platform/    android_bridge.dart (tile, sensitive flag)  desktop_shell.dart (tray, autostart)
    security/    sensitive_detector.dart  url_guard.dart (SSRF)
    util/        result.dart  logger.dart  hashing.dart
  features/
    onboarding/  presentation/
    auth/        data/ application/ presentation/
    rooms/       data/ domain/ application/ presentation/   # create, switcher, expiry
    join/        data/ application/ presentation/           # code input, QR scan, waiting, approval sheet
    clips/       data/ domain/ application/ presentation/   # sync engine, history, send
    devices/     data/ domain/ application/ presentation/   # ring, members, remove, rotate
    link_preview/ data/ presentation/
    settings/    application/ presentation/
supabase/
  migrations/  functions/join-room/  functions/redeem-invite/  tests/ (pgTAP)
android/app/src/main/kotlin/.../  SynclipTileService.kt  QuickSendActivity.kt  ClipboardBridge.kt
```
**Layer rule:** `presentation → application → domain ← data`. `domain` is pure Dart with no Flutter or Supabase imports. `core/crypto` has **no** Supabase imports, so it can be unit-tested in isolation.

### 6.3 Key modules (deep, small interfaces)
- **`ClipSyncEngine`** (per room): `Stream<List<Clip>> clips`, `Future<void> send(String text, {ClipSource})`, `ConnectionState state`. Internally it handles subscribe-then-fetch, dedupe, encrypt and decrypt, the sensitive split, retries with backoff, and the echo guard hook.
- **`RoomKeyring`**: `Future<SecretKey> keyFor(roomId, epoch)`, `wrapFor(pub)`, `unwrap(row)`, `rotate()`. This is the only place keys exist in memory.
- **`ClipboardPort`**: `Future<ClipRead?> read()` (text + `isSensitive`), `Future<void> write(String)`, `Stream<ClipRead> watch()` (desktop only). There's one adapter per platform, and the UI never touches platform APIs directly.
- **`JoinFlow`** is a state machine: `idle → submitting → awaitingApproval(sas) → unwrapping → joined | denied | expired | rateLimited`.

### 6.4 Android specifics
- **Quick Settings tile:** `TileService.onClick` launches `QuickSendActivity`, a translucent Activity using a pre-warmed `FlutterEngine` on route `/quick-send`. It reads the clipboard once it has focus, sends, shows a 1-second toast-like overlay, and finishes. On Android 14+ it uses `startActivityAndCollapse(PendingIntent)`. On Android 13+ the app offers "Add tile" via `StatusBarManager.requestAddTileService`.
- **Share target:** an `ACTION_SEND text/plain` intent filter, plus a confirm sheet that shows the target room and a Send button.
- **Auto-send on open:** after the first frame has window focus, read the clipboard. If its hash isn't the last sent or received hash and it isn't flagged sensitive, send it with an **Undo** snackbar.
- **Sensitive flag:** `ClipDescription.EXTRA_IS_SENSITIVE` (Android 13+) via `ClipboardBridge.kt`.
- **Receiving while backgrounded** (process alive): a notification with a **Copy** action. Nothing arrives once the process is killed; catch-up happens on the next open.

### 6.5 Desktop specifics
- Tray icon states: live, paused, offline. Left-click opens a **380×560 popover**: status, room switcher, the last 5 clips, a pause toggle and "Open Synclip". The full window has a 720×520 minimum.
- Close-to-tray, launch at startup (on by default after onboarding asks), and auto-copy of incoming clips with a subtle native notification "Copied from Pixel 7".
- **Sensitive formats to skip:**
  - Windows: `ExcludeClipboardContentFromMonitorProcessing` and `CanIncludeInClipboardHistory=0`
  - macOS: `org.nspasteboard.ConcealedType`
  - Linux: `x-kde-passwordManagerHint`

  This needs a small native read beyond Flutter's `Clipboard`. If a format can't be read, fall back to pattern detection.

### 6.6 Web specifics
- A paste box ("Press Ctrl+V or paste here") sends the clip, and each clip has a **Copy** button that writes to the clipboard on the user's gesture.
- No link previews; links show as plain text with the domain highlighted.
- Banner: "Web is the least private client; prefer the app on devices you own."

---

## 7. Design system (Material 3 + Synclip brand layer)

**Visual review canvas:** https://claude.ai/artifact/HgRMv74qQu3xNYGzCifgDG (source in `design/canvas/project/`). It shows every component state below plus the key screens. Change requests go there or in chat; this section is updated to match.

**Mode: Operate.** People open Synclip to get a clip from A to B, so the interface stays out of the way and brand expression is saved for three moments. Material 3 governs structure, navigation and components. The brand comes through M3 theming (colour roles, type scale, shape, motion) plus one signature component, the **device ring**.

**Physical scene:** a phone glanced at mid-task in any light, and a laptop on a desk, often at night. Both light and dark are first-class and follow the system, with a manual override.

### 7.1 Colour
- **Strategy: Restrained.** Tonal neutrals plus one accent. The accent appears only on primary actions, the live/connected state, the selected room and the newest clip's edge.
- **Brand seed: Synclip Tangerine `#FF7A1A`**, using `DynamicSchemeVariant.fidelity` so the primary stays recognisably tangerine. M3 derives contrast-safe roles for light and dark. Tangerine is unusual in utility apps and reads as "signal / live".
- **Accent picker presets (seeds):** Tangerine (default), Cobalt `#2F5BEA`, Jade `#12A07A`, Grape `#8A4FD8`, Rose `#E0447C`, Graphite `#5F6B7A`, and **Wallpaper** (Dynamic Color, Android 12+ only; falls back to Tangerine elsewhere).
- **Device colours:** each device gets one of 8 hues, chosen deterministically from its `device_id` and `harmonizeWith(primary)`. They're used only on the device's ring node and its chip on clip cards, to help answer "which device sent this?" at a glance.
- **Semantic:** M3 `error`, plus custom `success`, `warning` and `info` roles generated from fixed seeds and harmonised. Expiring soon = warning, live = primary, offline = outline.
- **Rule:** components use only roles such as `colorScheme.primary` or `surfaceContainerHigh`. Raw hex values appear only in `tokens.dart`.

### 7.2 Typography
- **One family, Roboto Flex** (variable, bundled so it looks the same on Android, desktop and web), mapped onto the **M3 type scale in sp**. The brand character comes from its axes rather than a second display face:

| Role | Use | Spec |
|---|---|---|
| headlineSmall | screen titles, wordmark | 24 sp, wght 700, **wdth 120** |
| titleMedium | clip card first line, sheet titles | 16 sp, wght 600 |
| bodyLarge / bodyMedium | clip text, descriptions | 16 / 14 sp, wght 400 |
| labelLarge / labelSmall | buttons, chips, timestamps | 14 / 11 sp, wght 500 |

- **JetBrains Mono** is used only for the **room code** (32 sp, wght 600, tracking +0.12 em, shown as `K7P·Q2X`) and for clips detected as code or commands.
- Scale ratio stays M3's (≈1.125–1.25). Sizes are never hand-picked per screen.

### 7.3 Shape, spacing, elevation
- **Spacing:** 4 dp base. Common steps are 4, 8, 12, 16, 24 and 32. Screen gutter: 16 dp on compact, 24 dp on medium and larger.
- **Shape (M3 scale):** chips 8, buttons full, cards **20**, sheets 28 (top corners).
- **Brand detail:** the newest clip (**hero clip**) has a 4 dp leading **source edge** in the sender's device colour.
- **Elevation:** tonal only (`surfaceContainer*` levels). Shadows are limited to FAB and dragged items.

### 7.4 Layout by window size class
| Width | Navigation | Layout |
|---|---|---|
| Compact < 600 dp (phones) | Bottom **NavigationBar**: Clips · Devices · Settings | single column, FAB "Send clipboard" |
| Medium 600–839 | **NavigationRail** | single column, max width 640 |
| Expanded ≥ 840 (desktop window) | NavigationRail | two-pane: clips list on the left, clip detail or devices on the right |
| Tray popover 380×560 | none | compact status + last 5 clips |

The room switcher lives in the top app bar title (a dropdown listing My Devices and any Quick Rooms, plus "Join or create").

### 7.5 Components (each with every state)

| Component | States |
|---|---|
| **DeviceRing** (signature) | nodes for each device, online (filled), offline (outlined), joining (pulse), self (centre). Sizes: 120 dp header, 40 dp compact |
| **ClipCard** (hero / compact; text / url / code / sensitive) | sending (60% opacity + linear progress), sent, failed (error tonal + Retry), new (accent edge for 2 s, then fades), copied (check morph), sensitive (lock badge, "not saved") |
| **LinkPreview** | loading skeleton, loaded (favicon, title, domain, optional 16:9 image), failed (plain link), disabled |
| **RoomCodeDisplay** | code, Copy, Show QR, Share link, expiring-soon chip "Expires in 52 m" |
| **CodeInput** | 6 cells, auto-advance, paste fills all, uppercase, Crockford-safe (O→0 mapping), error shake (reduced motion: colour only), rate-limited countdown |
| **ApprovalSheet** | requester device + platform icon, **5 emojis + their names**, Deny (outlined) / Allow (filled), expired |
| **WaitingForApproval** | the same emojis, "Check these match on the other device", cancel, denied, expired |
| **ConnectionPill** | Live · Connecting · Reconnecting · Offline (last sync 2 m ago) · Paused (desktop) |
| **SendFab** | idle, reading, sending, sent (check, 600 ms), nothing-to-send (snackbar) |
| **SensitivePrompt** (the one justified dialog) | "This looks like a card number. Send anyway? It won't be saved to history." |
| **EmptyState** | teaches the next action: e.g. "Copy something on another device, it lands here" + an add-tile button on Android |
| Snackbars | Sent to 2 devices · Copied · Undo (auto-send) · errors with actions |

### 7.6 Screens
1. **Welcome:** wordmark, one line ("Your clipboard, on every device."), then **Create Quick Room** (filled), **Join with code or QR** (tonal), **Sign in for My Devices** (text).
2. **Android setup** (once): add the Quick Settings tile, notification permission, auto-send toggle. Every step is skippable.
3. **Room · Clips** (home): compact ring + ConnectionPill, then the hero clip, then history. Uses the FAB on Android/web and the watcher state on desktop.
4. **Room · Devices:** large ring, RoomCodeDisplay + QR (Quick Room), member list with remove, pending requests, Leave room.
5. **Create Quick Room:** big code + QR, "Waiting for devices…" with the ring idling.
6. **Join:** tabs Code | Scan QR, then WaitingForApproval, then a success transition into the room.
7. **Approval sheet:** appears on every active device.
8. **Sign in:** email OTP code (all platforms) and Google (Android/web; desktop via browser deep link where supported). Then either "Link this device" (emoji wait) or "Created My Devices".
9. **Settings:**
   - Appearance: theme, accent, wallpaper colour
   - Sync: auto-send on open, link previews, sensitive detection
   - Desktop: watch clipboard, pause, launch at startup
   - Account, Security explainer ("What the server can see"), About
10. **Tray popover** (desktop).
11. **Web:** the same app with a paste-box hero.

### 7.7 Motion
Signature moments are rich. Everything else is M3 standard (short 150–200 ms, medium 250–300 ms, emphasized easing).

| Moment | Choreography | Duration |
|---|---|---|
| **Clip arrives** | a dot leaves the sender's ring node, travels a short arc to the top of the list and expands into the hero card (container-transform feel); older cards shift down; *light haptic* | 450 ms, emphasized-decelerate |
| **Clip sent** | the card compresses into a dot that flies to the ring's centre, then the other nodes blink once in sequence; *light haptic* | 350 ms (exit faster than entrance) |
| **Device joins** | the new node fades and scales in on the ring, its connection line draws, and a ripple ring expands once | 600 ms |
| **Approval sheet** | the sheet rises on a spring (damping ratio ≈ 0.85, no bounce reflex) and the emojis stagger in, 40 ms apart; *medium haptic* on Allow | 400 ms + stagger |

- **Haptics:** light on send and receive, selection click on copy, medium on Allow. Respect the system haptics setting.
- **Reduced motion** (`MediaQuery.disableAnimations` or the OS setting): signature moments become a 150 ms crossfade plus colour change, the error shake becomes a colour-only change, and the ring pulse becomes a static badge.
- **Budget:** only the ring uses `CustomPainter`, and it repaints only during an animation. Lists use implicit animations, and there's no load-sequence choreography.

### 7.8 Voice & copy
Plain, short, honest. "Sent to 2 devices." "Copied from MacBook." "Waiting for approval…" "This device can't read clips yet — approve it from another device." Never "military-grade", never "100% secure". The Security explainer lists exactly what the server can see.

### 7.9 Accessibility
- 48×48 dp targets with 8 dp gaps
- text scales to 200% (cards wrap, never clip)
- the DeviceRing has a semantic label ("3 devices online: Pixel 7, MacBook, this device")
- incoming clips are announced via `SemanticsService.announce`
- emojis are paired with their names in semantics
- status never relies on colour alone (icon + text)
- focus order and keyboard shortcuts on desktop and web (`Ctrl+V` send on web, `Esc` closes sheets)

---

## 8. Architecture Decision Records

### ADR-001: Supabase Realtime instead of a custom WebSocket server
**Status:** Accepted · **Context:** first Flutter project, solo developer, free hosting, needs presence and auth.

| | Custom WS (Node/Dart) | **Supabase Realtime** | Firebase RTDB |
|---|---|---|---|
| Complexity | High (hosting, reconnects, presence, auth) | Low | Low |
| Cost | VPS / free tier with sleeps | Free tier | Free tier |
| Fit for E2EE + SQL history | DIY | Postgres + RLS + triggers | Weaker querying, no SQL |
| Learning value | Backend depth | SQL/RLS depth | — |

**Decision:** Supabase. **Consequences:**
- Easier: presence, auth, stored history, a single write path.
- Harder: free-tier limits and project pausing; metadata visible to Supabase.
- **Revisit** if over 200 concurrent devices, or if adding LAN-direct mode.

### ADR-002: E2EE with a per-room key, X25519 wrapping, and SAS-verified approval
**Context:** the user chose E2EE and a 6-character code, but the code is too weak to be the key.

| Option | Verdict |
|---|---|
| Code = key | Rejected: brute-forceable offline from captured ciphertext |
| PAKE (SPAKE2) on the code | Rejected for v1: no mature Dart implementation, complex |
| **Room key + approval + emoji SAS; QR/link carries the key in the URL fragment** | **Accepted** |

**Consequences:** strong confidentiality and an approval UX that people already know from WhatsApp and Signal. Approval needs another device online. Losing every device loses My Devices history (stated in the UI).

### ADR-003: Single write path (INSERT → trigger → `realtime.send`)
**Alternatives:**
- The client broadcasts and inserts separately: two failure points, and storage and broadcast can diverge.
- Postgres Changes: heavier, and the docs steer toward Broadcast.

**Decision:** non-sensitive clips are only ever inserted, and the trigger broadcasts. Sensitive clips are only ever broadcast. **Consequences:**
- Server-side limits get enforced in one place.
- A slightly higher latency (one DB write) is acceptable.

### ADR-004: Riverpod + feature-first layering
**Alternatives:**
- Bloc: more boilerplate.
- Provider: you'd outgrow it.

**Decision:** Riverpod with code generation, using `domain/data/application/presentation` per feature. **Consequences:** testable controllers and compile-time-safe dependency injection, at the cost of learning code generation. Keep `build_runner` in watch mode.

### ADR-005: One room model for both modes
**Decision:** My Devices = a room of kind `account`. **Consequences:** one join/approve/rotate/sync implementation, with mode differences reduced to a row of limits. The cost is that account-level RLS can't tell your devices apart, which is solved by encryption (§2.1).

### ADR-006: No Android background service
**Decision:** receive only while the process is alive, and catch up from history on open (user's choice). **Consequences:**
- Battery-friendly and works on Xiaomi/Oppo devices that kill services.
- Clips aren't instant on a closed phone.
- **Revisit:** FCM data push carrying the encrypted envelope (fits in 4 KB for short clips).

---

## 9. Testing strategy

| Layer | What | Tool |
|---|---|---|
| Crypto | round-trip, tamper (flip a byte in ct / AAD / nonce → fails), wrong epoch, wrap/unwrap, SAS determinism + symmetry | `test` (pure Dart, run on VM **and** `--platform chrome` for WebCrypto) |
| Domain | code generator alphabet, sensitive detector (Luhn cards, 4–8 digit OTPs, `sk-`/`ghp_`/`AKIA`/JWT/PEM), URL guard (private IP ranges), echo guard, dedupe merge | `test` |
| Application | ClipSyncEngine with a fake channel: reconnect gap, duplicate events, send retry; JoinFlow state machine | `test` + `mocktail` |
| Database | every RLS policy and RPC: non-member can't read/insert, pending can't subscribe, size/epoch checks, rate limits, cron expiry | **pgTAP** via `supabase test db` on local Supabase (Docker) |
| Widgets | ClipCard states, CodeInput paste/validation, ApprovalSheet, 200% text scale, dark theme goldens | `flutter_test` + golden files |
| End-to-end | two clients against local Supabase: create → join → approve → send → receive → remove → rotation | `integration_test` |
| Manual matrix | Android phone + Windows + browser: tile, share, auto-send, tray, watcher echo, reduced motion, TalkBack | checklist in `docs/qa.md` |

---

## 10. Build plan (milestones)

Each milestone is a **series of small PRs** (§11), and ends with a demo plus a `ponytail-debt` sweep. It's ordered so you learn Flutter fundamentals before the hard parts. `e2e.yml` joins CI at M2, `deploy-staging.yml` at M3, and `release.yml` at M8.

| # | Milestone | Done when |
|---|---|---|
| **M0** | **Setup & pipeline:**<br>• Flutter SDK, Android SDK, local Supabase (Docker), staging + prod Supabase projects<br>• GitHub repo with branch protection, PR template, `.coderabbit.yaml`, Dependabot, lefthook, gitleaks, release-please<br>• `ci.yml` + `security.yml` skeletons<br>• `very_good_analysis`, folder skeleton, theme tokens | First PR (Welcome screen, light/dark) passes CI, gets a CodeRabbit review, and you merge it. App runs on Android + Windows + Chrome |
| **M1** | **Plain realtime:** anonymous auth, create/join a room by code (dev-only, no approval), broadcast **plaintext** text, presence list | Two devices exchange text live; you understand Riverpod providers + streams |
| **M2** | **Security core:**<br>• `core/crypto` + tests<br>• device keys, room key, envelope<br>• QR/link join, code + approval + emoji SAS<br>• private channels + RLS + pgTAP | M1 plaintext path deleted; server shows ciphertext only; pgTAP green |
| **M3** | **History & limits:**<br>• `clips` table + trigger broadcast<br>• catch-up + dedupe<br>• per-mode limits, rate limits, Edge Function `join-room`<br>• pg_cron expiry | Close app → send → reopen catches up; 10 h expiry verified with a shortened interval |
| **M4** | **Android integration:** share target, Quick Settings tile + QuickSendActivity, auto-send on open + Undo, sensitive flag, foreground notification Copy action | Send from any app in ≤ 2 taps |
| **M5** | **Desktop:** tray + popover, clipboard watcher + echo guard + pause, auto-copy, autostart, sensitive formats | Copy on Windows → appears on phone with no clicks; no echo loops between two desktops |
| **M6** | **My Devices:** email OTP + Google, account room, link device by approval, remove device + key rotation, anonymous→account upgrade | Remove a device → it can't decrypt new clips |
| **M7** | **Design polish** (run `/impeccable` for this): signature motions, DeviceRing, link previews + SSRF guard, accent picker + Dynamic Color, empty states, reduced motion, a11y pass, then Impeccable critique/audit and **write DESIGN.md** | Impeccable finish review passes; golden tests updated |
| **M8** | **Web + ship portfolio:**<br>• web paste box, CSP<br>• `release.yml` (signed builds, SBOM, web deploy to Cloudflare Pages, prod migrations behind approval)<br>• `ponytail-audit` of the whole repo<br>• README with architecture diagram, threat model, demo GIF | Tagged `v1.0.0` release with downloadable builds + live web demo, all shipped through the pipeline |

---

## 11. Engineering practices (non-negotiable)

These apply to **every** change, by a human or an AI agent. [AGENTS.md](AGENTS.md) is the short operational version for agents.

### 11.1 Git workflow — PR-only, reviewed by CodeRabbit
- **GitHub repo, `main` is protected:**
  - no direct pushes or force pushes
  - a PR is required
  - required status checks must pass
  - all review conversations must be resolved
  - linear history (squash merge only)
- **Every change is a PR from a short-lived branch:** `feat/…`, `fix/…`, `test/…`, `refactor/…`, `chore/…`, `docs/…`, `ci/…` + a short slug (`feat/join-by-code`). Aim for one task per PR and under ~400 changed lines; split bigger work.
- **Conventional Commits** for commit messages and PR titles (`feat(join): approve with emoji SAS`), enforced in CI. These drive the changelog.
- **CodeRabbit reviews every PR** (GitHub app + `.coderabbit.yaml`, profile `assertive`). Path instructions mark these as security-critical:
  - `lib/core/crypto/**`, `lib/core/security/**`
  - `supabase/migrations/**`, `supabase/functions/**`

  Every CodeRabbit comment is either fixed or answered with a reason before merge.
- **The AI agent never merges.** Claude creates the branch, commits, opens the PR, fixes CI and CodeRabbit findings, and stops. **The owner reviews and merges.**
- **PR template** (`.github/pull_request_template.md`): what/why, milestone, test evidence, screenshots (light + dark) for UI, and the security checklist (§11.6).
- **Releases:** semver tags `vX.Y.Z` cut by **release-please** from Conventional Commits, which updates `CHANGELOG.md`.

### 11.2 CI/CD — GitHub Actions
| Workflow | Trigger | Jobs |
|---|---|---|
| `ci.yml` | every PR, push to `main` | **Flutter:** `dart format --set-exit-if-changed`; `flutter analyze` (very_good_analysis, infos fatal); `build_runner` codegen; `flutter test --coverage` (unit + widget + golden on Linux); crypto tests again with `--platform chrome`; coverage gate.<br>**Supabase:** `supabase start` → `supabase db reset` → `supabase test db` (pgTAP) → `supabase db lint`.<br>**Edge Functions:** `deno fmt --check`, `deno lint`, `deno test`.<br>**Builds:** `flutter build apk --debug`, `build web`, `build windows` (windows runner), `build linux`.<br>**Commits:** Conventional Commit title check. |
| `security.yml` | every PR + weekly | gitleaks, OSV-Scanner (`pubspec.lock`, Deno), Semgrep (secrets + custom Synclip rules), RLS-coverage pgTAP test, Supabase security advisors |
| `e2e.yml` | nightly, PR label `e2e`, before release | Android emulator (`android-emulator-runner`) + local Supabase: two-client `integration_test` flow (create → join → approve → send → receive → remove → rotation) |
| `preview.yml` | every PR | web build deployed to a preview URL (Cloudflare Pages) and linked in the PR |
| `deploy-staging.yml` | merge to `main` | `supabase db push` + function deploy to the **staging** Supabase project; web to the staging URL |
| `release.yml` | tag `v*` | signed AAB/APK (keystore from secrets), Windows zip/MSIX, Linux tarball, web → production; SBOM (Syft) attached; `supabase db push` to **production** behind a GitHub Environment that needs the owner's approval |

- **Coverage gates:** at least 80% overall; **at least 95% for `lib/core/crypto` and `lib/core/security`.**
- **Two Supabase projects** (the free tier allows two): `synclip-staging` and `synclip-prod`. Migrations are the only way to change the schema; never click-ops in the dashboard.
- Generated files (`*.g.dart`, `*.freezed.dart`) are **not committed**; CI regenerates them.
- Workflows declare least-privilege `permissions:` and pin third-party actions to a commit SHA.

### 11.3 Automated testing (expands §9)
- **Test pyramid:**
  - many fast pure-Dart unit tests
  - widget and golden tests for every component state on the design canvas
  - pgTAP for every table, policy and RPC
  - Deno tests for Edge Functions
  - a few two-client integration tests
  - a manual device matrix only for what can't be automated (QS tile, tray, TalkBack)
- **Test-first for logic:** use the `tdd` skill (red → green → refactor) for crypto, the sync engine, the join state machine, sensitive detection, the URL guard and the echo guard. A bug fix starts with a failing test that reproduces it.
- **Local hooks (lefthook):**
  - pre-commit: `dart format`, `flutter analyze` on staged files, gitleaks
  - pre-push: unit tests

  CI is the source of truth; hooks are only a fast early warning.
- **Flaky tests are bugs:** quarantine within a day with a linked issue; never retry them silently.

### 11.4 Code quality — DRY, simple, small
- **DRY, one source of truth:**
  - design tokens only in `app/theme/tokens.dart`
  - per-mode limits only in the `rooms` row (clients read them from the room, so the numbers are never duplicated)
  - one `EnvelopeCodec` and one `ClipboardPort`
  - SQL policies call helper functions (`is_active_member(room_id)`) instead of repeating `EXISTS` clauses
  - shared widgets live in `lib/shared/widgets/`
- **Rule of three:** extract an abstraction only at the third real duplicate, not the first.
- **Ponytail for every feature.** The plugin is installed; enable it in Claude Code if it isn't loaded.
  - Build with the **`ponytail`** skill: question whether the code needs to exist (YAGNI); prefer the Dart/Flutter SDK and platform features over new packages; write the shortest correct version.
  - Run **`ponytail-review`** on the diff before opening each PR.
  - Run **`ponytail-debt`** at the end of each milestone to turn deliberate shortcuts into `docs/debt.md`.
  - Run **`ponytail-audit`** at M8.
  - **Guard rail:** ponytail never deletes tests, security checks, RLS policies or accessibility semantics. "Simplest" means the simplest code that keeps the tests and the threat model intact.
- **Layer rules** from §6.2 are enforced by review and by a custom lint (no `supabase_flutter` import under `domain/` or `core/crypto/`).
- **New architectural decisions** become `docs/adr/NNN-title.md` using the ADR format in §8.

### 11.5 Documentation that stays true
`README` (setup, architecture diagram, threat-model summary), `PLAN.md`, `PRODUCT.md`, `AGENTS.md`, `SECURITY.md`, `docs/adr/`, `docs/debt.md`, `docs/qa.md`. A PR that changes behaviour updates the doc that describes it, and CodeRabbit is told to flag drift.

### 11.6 DevSecOps
- **Secrets:**
  - none in the repo; `.env` is gitignored, with `.env.example` committed
  - gitleaks runs in pre-commit and CI
  - the Supabase **anon** key is public by design; the **service-role** key exists only as an Edge Function secret and a CI secret, never in the app
  - Android keystore and deploy tokens live in GitHub Environments
- **Dependencies:** Dependabot (pub, GitHub Actions, Deno) weekly; OSV-Scanner blocks a PR that adds a known-vulnerable version. Each new dependency must be justified in its PR (ponytail asks first).
- **Static analysis:** `flutter analyze` + Semgrep custom rules:
  - no logging of clip text or keys
  - no `Clipboard` API outside `core/clipboard/`
  - no `http://` URLs
  - no `dart:math` `Random()` in crypto code (use `Random.secure`)

  For SQL: `supabase db lint` + security advisors (RLS disabled, `SECURITY DEFINER` without a fixed `search_path`).
- **Database security as tests:** a pgTAP test fails CI if any `public` table has RLS disabled. Every new policy or RPC ships with allow **and** deny tests.
- **Security review gate:** a PR touching `core/crypto`, `core/security`, auth, `supabase/migrations` or `supabase/functions` gets the `security` label, the `/security-review` skill run on it, and the threat model (§4.2) updated if anything changed.
- **Release hardening:**
  - Android: R8 + `--obfuscate --split-debug-info`, cleartext traffic disabled, `allowBackup=false` (protects device keys), `FLAG_SECURE` while a sensitive clip is revealed
  - web: strict CSP and no `innerHTML`
  - every release ships an SBOM
- **Supply chain:** actions pinned by SHA, least-privilege tokens, and a protected `production` environment needing the owner's approval. Signed tags are recommended.
- **`SECURITY.md`** gives a private disclosure address and the supported versions.

### 11.7 Definition of Done (every PR)
- [ ] Branch from `main`; Conventional Commit title; one focused change
- [ ] Built with `ponytail`; `ponytail-review` run and findings handled
- [ ] Tests written first for logic; CI green; coverage gates met
- [ ] Security checklist done (label + `/security-review` + pgTAP when crypto/auth/DB is touched)
- [ ] UI: matches the design canvas; light + dark screenshots; goldens updated; 200% text and TalkBack checked
- [ ] Docs/ADR updated if behaviour or a decision changed
- [ ] All CodeRabbit comments resolved
- [ ] **Owner approved and merged**

---

## 12. Open questions & risks

| Item | Plan |
|---|---|
| Domain for links (`synclip.app` is a placeholder) | Use the deployed web URL until you buy a domain; Android App Links need `assetlinks.json` on it |
| QuickSendActivity cold-start latency (Flutter engine) | Pre-warm a cached engine in `Application`; if still slow, do read + encrypt + insert natively in Kotlin |
| Desktop Google sign-in deep link on Windows/Linux | Ship email OTP first; add Google desktop if `app_links` scheme registration works |
| Device names visible to the server | Accept for v1; consider encrypting names under the room key later |
| Per-device signatures (Ed25519) against an insider spoofing a sender | Deferred; only matters for Quick Rooms with others |
| Supabase free project pausing | Document it in the README; a scheduled GitHub Action ping is a possible workaround |
| Sensitive detection false positives (e.g., a 6-digit order number) | The prompt is one tap and "Don't ask for this kind" goes in Settings |
