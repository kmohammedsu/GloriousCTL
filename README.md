# GloriousCTL

A native macOS configuration app for the wired **Glorious Model O**, covering the
settings the Windows-only Glorious software exposes: button remapping, DPI
stages, polling rate, RGB lighting, macros, and profiles.

Everything is written to the mouse's **onboard memory**, so settings persist
across reboots and follow the mouse to other computers.

---

## What was verified against the hardware

This was built by reading the device directly rather than guessing. Your mouse
enumerates as:

```
VID 0x258A (SINOWEALTH)   PID 0x0036   "Wired Gaming Mouse"
```

with two HID interfaces:

| usagePage | usage | feature report | role                        |
|-----------|-------|----------------|-----------------------------|
| 0x01      | 0x02  | 0              | mouse input (movement/clicks) |
| 0x01      | 0x06  | **520**        | configuration                 |

The configuration interface's own HID report descriptor confirms the transport:

```
06 00 FF  09 01  A1 01  85 04 ... 96 07 02  B1 02  C0   Report 0x04, FEATURE, 519+1 bytes
06 00 FF  09 01  A1 01  85 05 ... 95 05     B1 02  C0   Report 0x05, FEATURE, 5+1 bytes
06 00 FF  09 01  A1 01  85 07 ... 95 07     81 00  C0   Report 0x07, INPUT,   7+1 bytes
```

### Report 0x04 is multiplexed

There is no single 520-byte config blob. 519 bytes is the maximum the descriptor
advertises; what the device actually returns depends on the command latched on
report 0x05 first, and the response echoes that command in byte 1:

| Latch | Response | Length | Contents |
|-------|----------|--------|----------|
| `05 11` | `04 11 00 …` | **131 B** | DPI stages, stage colours, lighting |
| `05 12` | `04 12 00 …` | **88 B** | button map |

Each block opens with an 8-byte header (report ID, command, six zeros). A read
that returns fewer bytes than requested is a normal USB short packet, not an
error.

### Confirmed fields

Read off the attached device and decoded to values that cannot plausibly be
coincidence:

| Block | Offset | Field | Evidence |
|-------|--------|-------|----------|
| 0x11 | `0x09` | DPI stage count | reads 6, matching six DPI values |
| 0x11 | `0x0A` | active stage | reads 4 |
| 0x11 | `0x0D`–`0x12` | DPI, 1 byte/stage | `03 07 0F 1F 31 63` → 400/800/1600/3200/5000/10000 via `(raw+1)×100` |
| 0x11 | `0x1D`–`0x2E` | stage colours, 3 B each | six exact primaries: yellow, blue, red, green, magenta, white |
| 0x11 | `0x35` | lighting effect | `01` = Glorious Mode, the stock effect |
| 0x11 | `0x36` | brightness / speed | `0x43` → brightness 4/4, speed 3/3 |
| 0x12 | `0x08`+ | buttons, 4 B × 20 | decodes to Left / Right / Middle / Ctrl+V / Ctrl+C / DPI-cycle |

Button action classes are confirmed as `0x11` mouse, `0x21` keyboard
(`[class, modifiers, HID usage, 0]`), `0x41` DPI, `0x50` macro.

### Still unknown

`0x08` (reads `0x64`), `0x0B` (`0x44`), `0x0C` (`0xF0`), and the per-effect
parameter region from `0x37`. **Polling rate, lift-off distance and debounce
have not been located**, so the app does not expose them for editing — writing a
guessed offset would change something else. Use **Snapshot & Diff** in the
Protocol Inspector to identify them: capture a baseline, change one setting on
the device, capture again, and the byte that moved is the field.

---

## The one thing you must do first

macOS refuses to open this device until you grant permission. `IOHIDDeviceOpen`
returns `0xE00002E2` (`kIOReturnNotPermitted`) otherwise. This happens because
the configuration interface also declares a **keyboard** usage, which puts it
behind the Input Monitoring privacy gate — the same one Karabiner asks for.

1. Open **System Settings › Privacy & Security › Input Monitoring**
2. Enable **GloriousCTL** (use **+** to add it if it isn't listed)
3. **Quit and reopen the app** — macOS only re-checks at launch

The app detects this state and walks you through it on the Overview tab.

---

## Building

```bash
./Scripts/build-app.sh release
open /Applications/GloriousCTL.app
```

The build script signs with a real code-signing identity from your keychain
(`Apple Development` or `Developer ID`), falling back to ad-hoc only if none
exists. This matters: macOS ties the Input Monitoring grant to the code
signature, and an ad-hoc signature is just a hash of the binary — every rebuild
would look like a new app and silently lose the permission. With a real
identity the Designated Requirement is stable:

```
identifier "io.github.kmohammedsu.gloriousctl" and anchor apple generic
    and certificate leaf[subject.CN] = "Apple Development: ..."
```

so the grant survives rebuilds. Override with `CODESIGN_IDENTITY=... ./Scripts/build-app.sh`.

The app installs to `/Applications/GloriousCTL.app` when that directory is
writable and otherwise uses `~/Applications/GloriousCTL.app`. Set
`GLORIOUSCTL_INSTALL=0` to produce the bundle without installing it. Release
builds are universal and support both Apple silicon and Intel Macs.

## GitHub releases

People downloading GloriousCTL do not need an Apple Developer account. Tagged
releases are signed with the maintainer's Developer ID Application certificate,
submitted to Apple's notary service, stapled, and published as a ZIP by
`.github/workflows/release.yml`.

Configure these GitHub Actions repository secrets before pushing a version tag:

| Secret | Value |
|--------|-------|
| `DEVELOPER_ID_APPLICATION_P12_BASE64` | Base64-encoded Developer ID Application certificate and private key exported as `.p12` |
| `DEVELOPER_ID_APPLICATION_P12_PASSWORD` | Password used when exporting the `.p12` |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64-encoded App Store Connect API private key (`.p8`) |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer ID |

Create a release by pushing a semantic version tag:

```bash
git tag v1.5.0
git push origin v1.5.0
```

The workflow publishes `GloriousCTL-1.5.0.zip`. Gatekeeper can verify the
Developer ID signature and stapled Apple notarization ticket without requiring
anything from the person installing it.

### Command-line diagnostic

```bash
./build/GloriousCTL.app/Contents/MacOS/gloriousctl-probe [output.bin]
```

Prints the HID topology, the raw report descriptor, a hex dump of the live
configuration, and the field-by-field validation table.

---

## Safety

The offset map is reverse-engineered, so the app is built so that a wrong offset
is a recoverable one-byte mistake instead of a bricked mouse:

- **Read–modify–write.** `MouseConfig` wraps the *actual* bytes read from the
  device, per block. Editing a setting patches only the bytes that field owns; every byte
  the app does not understand is written back byte-for-byte unchanged. The app
  never synthesises a configuration from scratch.
- **Runtime validation.** `LayoutValidator` checks each mapped field against what
  the hardware could plausibly mean — a polling byte must be 1/2/4/8, a DPI byte
  must decode inside the PMW3360's 100–12000 range, a button entry must start
  with a known action class. Failures surface in the **Protocol Inspector** as
  warnings instead of silently corrupting settings.
- **Write verification.** Only blocks the user actually changed are written, at
  exactly the length the device produced. Each write is read back and compared;
  any byte that did not land is reported.
- **Backups.** The first configuration ever read is saved permanently to
  `~/Library/Application Support/GloriousCTL/backups/`, and a timestamped
  snapshot is taken before each write (last 20 kept).
  **Profiles › Restore Original Config** always gets you back.

If the Protocol Inspector flags a field, correcting it is a one-line change in
`ConfigLayout.swift`; nothing else moves.

---

## Interface

The window follows the layout of the Glorious Windows configurator: remappable
buttons numbered down the left, a mouse schematic with matching callouts in the
middle, collapsible setting panels on the right, and profile / Restore / Apply
along the bottom. Dark panels with amber accents, same as the original.

None of Glorious's artwork is used — the lion mark, wordmark and product
photography are theirs. The mouse is drawn as vector art in `MouseDiagram.swift`.

Panels for settings that exist in the Windows app but are not yet decoded
(polling rate, lift-off distance, debounce) are shown as unavailable rather than
hidden, so the gap is visible instead of silently missing.

### Gestures and Action Rings

GloriousCTL can claim the middle, side-back, and side-forward buttons in macOS.
A quick press is re-emitted as the normal click, while a drag can perform one of
the five gesture actions. Holding still for the configured delay opens a radial
**Action Ring** above any app; move onto an item and release to run it. Releasing
in the centre leaves the ring open so an item can instead be hovered and clicked.

Each button has its own ring with up to eight slots. A slot can perform any
built-in Mac action, open an application/file/folder, open a URL, or run a named
workflow from the macOS Shortcuts app. Rings and gestures can coexist on the
side buttons. The middle ring is enabled by default; the two side rings are
opt-in. These features require the separate **Accessibility** permission shown
in their panels.

Shortcut-backed actions now read the current key assignment from macOS rather
than assuming Apple's default. An action whose shortcut is disabled is called
out in the Gestures panel so it no longer fails silently.

### Finding the remaining fields

Settings are stored **on the mouse**, so a Windows machine is a decoding oracle
even without packet capture:

1. In GloriousCTL on the Mac, Inspector → **Take Snapshot**
2. Plug the mouse into Windows, change **one** setting in the Glorious software
3. Back on the Mac, Inspector → **Diff Against Snapshot**

Whatever byte moved is that field. **Scan Blocks** in the same panel probes latch
commands `0x10`–`0x20` for blocks this app has not found, which is the most
likely home of the polling rate.

## Layout

```
Sources/GloriousCore/          # device layer, no UI
  HIDTransport.swift           # IOHIDManager: discovery, open, feature reports
  DeviceProtocol.swift         # report IDs and sizes (verified from descriptor)
  ConfigLayout.swift           # byte offsets — the single place to correct
  MouseConfig.swift            # typed read-modify-write view over the 520 bytes
  ButtonAction.swift           # 4-byte button encoding + HID keycodes
  Enums.swift                  # polling, effects, brightness, LOD, debounce
  Macro.swift / Profile.swift  # macros, profile storage, backups
  LayoutValidator.swift        # plausibility checks against a live dump
  DeviceController.swift       # observable state, apply/verify/restore
Sources/GloriousCTL/           # SwiftUI app
Sources/gloriousctl-probe/     # CLI diagnostic
```

## Profiles

The mouse stores a single configuration onboard, so profiles live on the Mac
(`~/Library/Application Support/GloriousCTL/profiles.json`) and are applied to
the device on demand. Each profile keeps the full 520-byte blob, so loading one
is byte-exact.
