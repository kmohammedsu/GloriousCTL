# GloriousCTL

[![Latest release](https://img.shields.io/github/v/release/kmohammedsu/GloriousCTL?style=flat-square&color=e8a33d)](https://github.com/kmohammedsu/GloriousCTL/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/kmohammedsu/GloriousCTL/total?style=flat-square&color=e8a33d)](https://github.com/kmohammedsu/GloriousCTL/releases)
[![Release build](https://img.shields.io/github/actions/workflow/status/kmohammedsu/GloriousCTL/release.yml?style=flat-square&label=release%20build)](https://github.com/kmohammedsu/GloriousCTL/actions/workflows/release.yml)
[![Signed and notarized](https://img.shields.io/badge/signed%20%26%20notarized-Apple-4c9a4c?style=flat-square&logo=apple&logoColor=white)](#is-this-safe-to-install)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-555?style=flat-square&logo=apple&logoColor=white)](#step-1-check-you-have-the-right-setup)
[![Universal](https://img.shields.io/badge/universal-arm64%20%2B%20x86__64-555?style=flat-square)](#step-1-check-you-have-the-right-setup)
[![License: MIT](https://img.shields.io/badge/license-MIT-informational?style=flat-square)](LICENSE)

**Configure your Glorious Model O mouse on a Mac.**

Glorious only ships configuration software for Windows. This app does the same job
natively on macOS: remap the buttons, set DPI stages, change the RGB lighting, record
macros, and add Mac-specific extras like gesture controls and radial shortcut menus.

Your settings are saved **onto the mouse itself**, not just to your Mac. They survive
restarts, and they follow the mouse if you plug it into a different computer.

![The GloriousCTL main window: a sidebar of configuration sections on the left, an
interactive picture of the Model O with numbered buttons in the middle, and an
inspector panel for the selected button on the right](Assets/GloriousCTL-1.4-preview.png)

---

## Contents

**Getting started**
- [Step 1: Check you have the right setup](#step-1-check-you-have-the-right-setup)
- [Step 2: Download and install](#step-2-download-and-install)
- [Step 3: Give it permission (required)](#step-3-give-it-permission-required)
- [Step 4: Change your first setting](#step-4-change-your-first-setting)
- [Is this safe to install?](#is-this-safe-to-install)
- [Can this break my mouse?](#can-this-break-my-mouse)

**When something goes wrong**
- [Troubleshooting](#troubleshooting)

**What it can do**
- [Features](#features)
- [Gestures and Action Rings](#gestures-and-action-rings)
- [Profiles](#profiles)
- [What is not supported yet](#what-is-not-supported-yet)

**For developers**
- [Building from source](#building-from-source)
- [How the mouse protocol was decoded](#how-the-mouse-protocol-was-decoded)
- [Project layout](#project-layout)
- [Publishing a release](#publishing-a-release)

---

# Getting started

## Step 1: Check you have the right setup

You need three things:

| | |
|---|---|
| **A Mac** | running macOS 13 (Ventura) or newer. Apple silicon and Intel both work. |
| **The wired Glorious Model O** | The original wired Model O or Model O-. |
| **A USB connection** | Plug the mouse directly into your Mac. |

**How to check your macOS version:** click the  menu in the top-left corner →
**About This Mac**. If it says macOS 13 or higher, you're fine.

**About other Glorious models:** this app was built and tested against the wired
Model O, which identifies itself to the computer as `VID 0x258A, PID 0x0036`. The
Model O 2, Model O Wireless, and Model O Pro use different hardware and are **not
supported** — the app will simply not detect them. It will not try to write to a
device it does not recognise.

---

## Step 2: Download and install

1. Go to the **[latest release page](https://github.com/kmohammedsu/GloriousCTL/releases/latest)**.
2. Under **Assets**, click **`GloriousCTL-1.0.0.zip`** to download it.
3. Open your **Downloads** folder and double-click the zip to unzip it. You'll get
   **GloriousCTL.app**.
4. Drag **GloriousCTL.app** into your **Applications** folder.
5. Double-click it to open.

**You should not see any security warning.** No "unidentified developer", no
"damaged and can't be opened", and no right-click trickery. If you do see one,
jump to [Troubleshooting](#the-app-wont-open-or-says-its-damaged).

---

## Step 3: Give it permission (required)

**The app cannot see your mouse until you do this.** This is the single most common
reason people think the app is broken.

macOS blocks apps from talking to this mouse until you allow it. That is not the app
being greedy: the Model O's configuration channel also announces itself as a keyboard,
so macOS puts it behind the **Input Monitoring** privacy setting — the same one
Karabiner and similar tools require. (Technically: `IOHIDDeviceOpen` returns
`0xE00002E2`, `kIOReturnNotPermitted`, until the permission is granted.)

1. Open **System Settings** (the  menu → System Settings).
2. Go to **Privacy & Security** in the sidebar.
3. Scroll down and click **Input Monitoring**.
4. Find **GloriousCTL** in the list and turn the switch **on**.
   - Not listed? Click the **+** button, then choose **GloriousCTL** from your
     Applications folder.
   - You'll be asked for your Mac password or Touch ID. That's macOS confirming
     the change, and it's expected.
5. **Quit GloriousCTL completely and open it again.**

> **Step 5 is not optional.** macOS only checks this permission when an app starts
> up. If you leave the app running while you flip the switch, it will keep behaving
> as though permission was never granted. Quit it fully (**⌘Q**, or GloriousCTL menu →
> Quit) and reopen.

The app detects this situation and walks you through it on the Overview tab, so you
don't have to remember the steps.

**Doing more than basic button remapping?** Gestures and Action Rings need a *second,
separate* permission called **Accessibility**, in the same Privacy & Security section.
The app prompts you for it only when you turn those features on.

---

## Step 4: Change your first setting

A quick walkthrough so you can see how the app works:

1. Open GloriousCTL. The top-right should say **Model O connected**.
2. Click **Buttons** in the left sidebar.
3. Click any numbered circle on the mouse picture — for example **6**, the DPI button
   underneath the scroll wheel.
4. In the panel on the right, click **Change assignment…** and pick something new.
5. Click **Apply to mouse** in the bottom-right corner.

That last click is the important one. **Nothing is written to your mouse until you
press Apply to mouse.** Until then you're only editing a preview on your Mac. The
status text at the bottom-left tells you which state you're in — *"Settings match the
mouse"* means everything is saved.

To undo everything and go back to how the mouse came out of the box, use
**Profiles → Restore Original Config**.

---

## Is this safe to install?

Yes, and you can verify it yourself rather than taking anyone's word for it.

The app is **code-signed with an Apple Developer ID certificate** and **notarized by
Apple** — meaning Apple scanned the exact file you download for malware and issued it
a pass. That's why it opens without warnings, and why **you do not need an Apple
Developer account** to run it.

To check the signature yourself, open **Terminal** (Applications → Utilities) and
paste:

```bash
spctl --assess --type execute --verbose=2 /Applications/GloriousCTL.app
```

You should see:

```
/Applications/GloriousCTL.app: accepted
source=Notarized Developer ID
```

If you get anything else, do not run the app — [file an issue](https://github.com/kmohammedsu/GloriousCTL/issues).

The full source code is in this repository, and every release is built automatically
from it by GitHub Actions, so you can read exactly what you're running.

---

## Can this break my mouse?

**No, and this was designed for deliberately.**

The app talks to the mouse using a settings map that was worked out by observing the
real hardware rather than from official documentation. That means a mistake is
possible in principle, so the app is built so that any mistake is a small, reversible
one instead of a broken mouse:

- **It never overwrites settings it doesn't understand.** The app reads the mouse's
  current settings, changes only the specific bytes for the setting you edited, and
  writes everything else back exactly as it found it. It never builds a fresh
  configuration from scratch.
- **Every write is checked.** Only the parts you actually changed get written, and
  each write is read back and compared. Anything that didn't land is reported.
- **Nonsense values are refused.** Values that couldn't plausibly be right are flagged
  as warnings instead of being sent to the mouse.
- **Your original settings are backed up permanently.** The very first configuration
  the app ever reads from your mouse is saved forever, and a timestamped snapshot is
  taken before every write (the last 20 are kept). They live in
  `~/Library/Application Support/GloriousCTL/backups/`.

**Profiles → Restore Original Config** always brings you back to how your mouse was
before you ever ran this app.

---

# Troubleshooting

## The app won't open, or says it's "damaged"

You shouldn't see this — the release is notarized specifically to prevent it. If you
do, the usual cause is an **incomplete or corrupted download**, not a security
problem.

1. Delete the app and the zip.
2. Download it again from the [releases page](https://github.com/kmohammedsu/GloriousCTL/releases/latest),
   letting it finish completely.
3. Unzip, move to Applications, and open.

Then confirm it's genuine with the [signature check above](#is-this-safe-to-install).

**Don't** work around the warning with `xattr -cr` or by right-click → Open. If a
build ever genuinely fails its signature check, that's something to report, not to
bypass.

## The app opens but says no mouse is connected

Work through these in order — the first two fix almost every case.

**1. Did you grant Input Monitoring *and* restart the app?**
This is the answer the overwhelming majority of the time. Go back to
[Step 3](#step-3-give-it-permission-required). Granting the permission while the app
is running does nothing until you quit and reopen it.

**2. Is the switch actually on?**
Open **System Settings → Privacy & Security → Input Monitoring** and look at
GloriousCTL. If it's listed but switched off, switch it on and restart the app.

**3. Try removing and re-adding the permission.**
macOS sometimes holds a stale entry, especially after replacing the app with a newer
version:

- Select **GloriousCTL** in the Input Monitoring list, click **−** to remove it
- Click **+**, add it again from your Applications folder
- Quit and reopen the app

**4. Check it's a supported mouse.**
Only the original **wired** Model O / O- is supported. Wireless, Model O 2 and Model
O Pro are different hardware and won't be detected.

**5. Check macOS sees the mouse at all.**
Hold **Option** and click the  menu → **System Information** → **USB**. If
"Wired Gaming Mouse" doesn't appear there, the problem is the cable, the port, or the
mouse — not this app. Try another USB port and avoid hubs.

## Permission was working, then stopped after an update

macOS ties this permission to the app's exact identity. Replacing the app can
occasionally cause macOS to treat it as a different app.

Fix it by removing and re-adding the entry as described in step 3 above, then quitting
and reopening.

## My settings don't stick

**Did you click "Apply to mouse"?** Edits are only a preview until you press it.
The bottom-left status tells you: *"Settings match the mouse"* means saved.

If you clicked Apply and the settings still revert, the app will have reported a
verification failure — every write is read back and compared. Please
[open an issue](https://github.com/kmohammedsu/GloriousCTL/issues) with what you
changed.

## Gestures or Action Rings do nothing

These need the **Accessibility** permission, which is separate from Input Monitoring:

**System Settings → Privacy & Security → Accessibility** → enable **GloriousCTL**.

Also check the feature is switched on in its panel. The middle-button ring is on by
default; the two side-button rings are opt-in.

## An Action Ring item does nothing when I pick it

If it's a built-in Mac action such as Mission Control or Spotlight, its keyboard
shortcut may be **disabled** in **System Settings → Keyboard → Keyboard Shortcuts**.
GloriousCTL reads your current shortcut assignments rather than assuming Apple's
defaults, and flags disabled ones in the Gestures panel so they don't fail silently.

## I can't find polling rate, lift-off distance, or debounce

These genuinely aren't available yet — see
[What is not supported yet](#what-is-not-supported-yet). Their panels are shown as
*unavailable* on purpose, so you can see the gap rather than wonder if you missed a
menu.

## I want to undo everything

**Profiles → Restore Original Config.** This restores the exact configuration your
mouse had the first time the app read it, byte for byte.

## Nothing here helped

Run the built-in diagnostic and include its output when you
[open an issue](https://github.com/kmohammedsu/GloriousCTL/issues):

```bash
/Applications/GloriousCTL.app/Contents/MacOS/gloriousctl-probe
```

It prints what the app can see of the mouse, the raw configuration, and a
field-by-field validation table. Please also say which Mac and macOS version you're
on, and which Model O variant you have.

---

# What it can do

## Features

### Remap every button

Click a numbered control on the mouse diagram and reassign it — to another mouse
button, a keyboard shortcut, a DPI action, or a recorded macro. All six controls are
remappable, and the assignment is written to the mouse's own memory.

*(Shown in the screenshot at the top of this page.)*

### DPI stages and sensor

Six DPI stages from 400 to 10,000, each with its own indicator colour so you can see
at a glance which stage you're on. The currently active stage is marked, and the live
value is shown at the bottom.

![The DPI & sensor panel: six DPI stages with per-stage colour swatches, the active
stage marked, and a slider for the selected stage](Assets/feature-dpi.jpg)

### RGB lighting

Pick an effect, then set brightness and speed. Changes are written to the mouse, so
the lighting stays the same on any computer you plug it into.

![The Lighting panel: an effect dropdown set to Glorious Mode, with brightness and
speed sliders](Assets/feature-lighting.jpg)

### Action Rings

Hold a button and a radial menu appears over whatever app you're in. Each ring holds
up to eight slots, and a slot can run a built-in Mac action, open an app, file or
folder, open a URL, or trigger a macOS Shortcuts workflow.

![An Action Ring open over the desktop: eight labelled shortcuts arranged
radially — Mission Control, Application Windows, Show Desktop, Launchpad,
Spotlight, Screenshot Selection, Lock Screen and Play/Pause — with the hovered
item highlighted](Assets/ActionRing-preview.png)

![The Actions Ring editor: a list of configurable slots with action dropdowns,
optional labels, and a hold-delay slider](Assets/feature-actionring.jpg)

### Gestures

Reserve the middle or side buttons for directional actions: hold, drag, and release.
A quick click without dragging still does its normal job, so you don't lose the
button.

![The Gestures panel: checkboxes to reserve Side Back, Side Forward and Middle Click
for directional actions](Assets/feature-gestures.jpg)

### Scroll direction, fixed properly

macOS applies one scroll direction to everything. This flips the mouse wheel **without**
inverting your trackpad — trackpad gestures pass through untouched, and only discrete
wheel steps are reversed.

![The Scrolling panel: a Fix mouse wheel direction toggle, with a note that trackpad
gestures pass through unchanged](Assets/feature-scrolling.jpg)

### Honest about what isn't decoded

Lift-off distance, debounce, motion sync, and USB polling rate haven't been safely
located in the mouse's memory yet, so the app refuses to touch them rather than
guessing. The Protocol Inspector lets you help find them.

![The Advanced panel: lift-off distance, debounce time, motion sync and USB polling
rate listed as not safely decoded, with a button to open the Protocol
Inspector](Assets/feature-advanced.jpg)

### Also included

- **Macros** — record and assign to any button
- **Profiles** — save configurations and switch between them
- **App profiles** — switch automatically depending on which app is in front

## Gestures and Action Rings

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

## Profiles

The mouse stores a single configuration onboard, so profiles live on the Mac
(`~/Library/Application Support/GloriousCTL/profiles.json`) and are applied to
the device on demand. Each profile keeps the full 520-byte blob, so loading one
is byte-exact.

## What is not supported yet

**Polling rate, lift-off distance, and debounce cannot be changed.**

These settings exist in the Windows software, but where the mouse stores them hasn't
been identified yet. Writing to a guessed location would change something else
unpredictably, so the app deliberately doesn't offer them. Their panels appear as
*unavailable* rather than being hidden, so the gap is visible instead of silently
missing.

If you'd like to help find them, see
[Finding the remaining fields](#finding-the-remaining-fields).

## Interface

The window follows the layout of the Glorious Windows configurator: remappable
buttons numbered down the left, a mouse schematic with matching callouts in the
middle, collapsible setting panels on the right, and profile / Restore / Apply
along the bottom. Dark panels with amber accents, same as the original.

None of Glorious's artwork is used — the lion mark, wordmark and product
photography are theirs. The mouse is drawn as vector art in `MouseDiagram.swift`.

---

# For developers

## Building from source

```bash
./Scripts/build-app.sh release
open /Applications/GloriousCTL.app
```

The build script signs with a real code-signing identity from your keychain,
preferring `Developer ID Application` and falling back to `Apple Development` for
non-release builds, or ad-hoc if neither exists. This matters: macOS ties the Input
Monitoring grant to the code signature, and an ad-hoc signature is just a hash of the
binary — every rebuild would look like a new app and silently lose the permission.
With a real identity the Designated Requirement is stable:

```
identifier "io.github.kmohammedsu.gloriousctl" and anchor apple generic
    and certificate leaf[subject.CN] = "Developer ID Application: ..."
```

so the grant survives rebuilds. Override with `CODESIGN_IDENTITY=... ./Scripts/build-app.sh`.

The app installs to `/Applications/GloriousCTL.app` when that directory is
writable and otherwise uses `~/Applications/GloriousCTL.app`. Set
`GLORIOUSCTL_INSTALL=0` to produce the bundle without installing it. Release
builds are universal and support both Apple silicon and Intel Macs.

### Command-line diagnostic

```bash
./build/GloriousCTL.app/Contents/MacOS/gloriousctl-probe [output.bin]
```

Prints the HID topology, the raw report descriptor, a hex dump of the live
configuration, and the field-by-field validation table.

## How the mouse protocol was decoded

This was built by reading the device directly rather than guessing. The mouse
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
guessed offset would change something else.

### Finding the remaining fields

Settings are stored **on the mouse**, so a Windows machine is a decoding oracle
even without packet capture:

1. In GloriousCTL on the Mac, Inspector → **Take Snapshot**
2. Plug the mouse into Windows, change **one** setting in the Glorious software
3. Back on the Mac, Inspector → **Diff Against Snapshot**

Whatever byte moved is that field. **Scan Blocks** in the same panel probes latch
commands `0x10`–`0x20` for blocks this app has not found, which is the most
likely home of the polling rate.

If the Protocol Inspector flags a field, correcting it is a one-line change in
`ConfigLayout.swift`; nothing else moves.

## Project layout

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

## Publishing a release

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
git tag v1.0.0
git push origin v1.0.0
```

The workflow publishes `GloriousCTL-1.0.0.zip`. Gatekeeper can verify the
Developer ID signature and stapled Apple notarization ticket without requiring
anything from the person installing it.

---

## Contributing

Issues and pull requests are welcome — particularly if you can help locate the
[remaining unknown fields](#finding-the-remaining-fields), or if you have a Model O
variant that behaves differently.

## License

MIT — see [LICENSE](LICENSE).

Unofficial and not affiliated with, endorsed by, or supported by Glorious.
