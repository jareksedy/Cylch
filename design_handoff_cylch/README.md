# Handoff: Cylch — Adalight Controller

## Overview
Cylch is a small macOS utility for driving Adalight-protocol LED devices over a serial port. It runs a hard-coded rainbow cycle and exposes three controls: brightness, animation speed, and the number of LEDs in the chain. A serial-port picker and a Connect/Disconnect button live in a footer row, and a status line summarizes the current state.

## About the Design Files
The files in this bundle are **design references created in HTML** — interactive prototypes that show the intended look and behavior, not production code to ship as-is. Recreate this UI in the target codebase's environment (e.g. SwiftUI for a native macOS app, Tauri + React, Electron + React, etc.) using its established patterns. If no environment exists yet, choose the most appropriate one for a small macOS utility — SwiftUI is the natural fit; Tauri + React is a good cross-platform alternative.

The HTML prototype mocks the serial connection — the real implementation must talk to actual hardware over a USB serial port using the Adalight protocol (a `Ada\n` magic header + RGB byte triples per LED, framed per refresh).

## Fidelity
**High-fidelity.** Final colors, typography, spacing, corner radii, and interactions are intentional and should be matched closely. The window chrome targets macOS Tahoe's softer rounding (~22px) and centered titlebar.

## Screens / Views

### Main window
A single window — there are no other screens.

**Purpose:** Configure brightness/speed/port, set the LED count of the connected strip, and toggle the connection.

**Window chrome**
- macOS-style window: `540 × 320` px, `borderRadius: 22px`, `background: #16181d`
- Shadow: `0 0 0 1px rgba(0,0,0,0.6) inset, 0 24px 60px rgba(0,0,0,0.55)`
- Titlebar: 38px tall, traffic lights (12px dots: `#ff736a`, `#febc2e`, `#19c332`) on the left, centered title "Cylch" (13px, weight 600, `rgba(255,255,255,0.85)`), 52px right spacer to balance.
- Bottom border on the titlebar: `0.5px solid rgba(255,255,255,0.06)` with a subtle white-to-transparent gradient overlay.

**App background (outside the window)**
- Body: `radial-gradient(circle at 30% 20%, #1f2230 0%, transparent 55%), radial-gradient(circle at 75% 85%, #221a2c 0%, transparent 55%), linear-gradient(135deg, #0a0b0f 0%, #111218 100%);`

**Content layout**
- Single column, `padding: 18px 22px 20px`, vertical `gap: 18px`.
- Order top to bottom:
  1. Brightness gradient slider
  2. Speed gradient slider
  3. Status line
  4. Flexible spacer (`flex: 1`)
  5. Footer row: Serial Port select + LEDs stepper + spacer + Connect button

### Components

#### Gradient Slider
A custom range slider where the **track is a gradient that visualizes the property**, and the unfilled portion to the right of the thumb is dimmed with a black overlay.

- Label row above track: small caps mono label (10px, JetBrains Mono, `letter-spacing: 0.8px`, `rgba(255,255,255,0.5)`); right-aligned value (12px mono, `rgba(255,255,255,0.92)`, tabular numbers).
- Track height 8px, `border-radius: 4px`, `box-shadow: inset 0 1px 2px rgba(0,0,0,0.6), 0 0 0 0.5px rgba(255,255,255,0.08)`.
- Dim overlay (right of thumb): `background: rgba(0,0,0,0.55)`, same height/radius, `pointer-events: none`.
- Thumb: 18×18px white circle, `box-shadow: 0 1px 3px rgba(0,0,0,0.5), 0 0 0 0.5px rgba(0,0,0,0.4), inset 0 -1px 1px rgba(0,0,0,0.1)`.
- The native `<input type="range">` is overlaid at `opacity: 0` to handle drag.
- **Brightness gradient:** `linear-gradient(90deg, #2a2d36 0%, #ffffff 100%)`. Range `0–100`, unit `%`.
- **Speed gradient:** `linear-gradient(90deg, #2a2d36 0%, #6979ff 100%)`. Range `0–100`, no unit.

#### Status line
Mono, 11px, `rgba(255,255,255,0.55)`, horizontal flex with `gap: 8px`:
- 6px dot, `#34d674` with `box-shadow: 0 0 6px #34d674` when streaming, `#7a7a7a` no glow when idle.
- Label `"Streaming rainbow"` / `"Idle"` (`rgba(255,255,255,0.85)`).
- Middle-dot separators (`·`, `rgba(255,255,255,0.3)`).
- `"{ledCount} LEDs"`, `"{brightness}% bright"`, `"speed {speed}"`.

#### Field (label + control)
Stacked: 10px JetBrains Mono uppercase label (`letter-spacing: 0.8px`, `rgba(255,255,255,0.5)`), 7px gap, then the control.

#### Serial Port select
- 32px tall, 200px wide, `padding: 0 30px 0 12px`.
- `background: rgba(255,255,255,0.05)`, `border: 0.5px solid rgba(255,255,255,0.1)`, `border-radius: 8px`, `box-shadow: inset 0 1px 0 rgba(255,255,255,0.03)`.
- Value text 12px JetBrains Mono, `rgba(255,255,255,0.92)`, ellipsis on overflow.
- Chevron SVG on the right (9×9, 1.2px stroke, `rgba(255,255,255,0.55)`).
- Native `<select>` overlaid at `opacity: 0`.
- Mock options: `/dev/cu.usbserial-A50285BI`, `/dev/cu.usbmodem14201`, `/dev/cu.SLAB_USBtoUART`. **In production, enumerate real ports.**

#### LED Count stepper
- 32px × 96px, same surface treatment as the select.
- Layout: `display: flex; justify-content: space-between` — `−` button on the left, centered numeric input, `+` button on the right.
- Buttons: 22×22px, `background: rgba(255,255,255,0.06)`, 5px radius, system font 13px, `rgba(255,255,255,0.78)`.
- Input: `flex: 1`, transparent background, 13px JetBrains Mono weight 500, centered, tabular numerals, `rgba(255,255,255,0.95)`. Native spinner buttons hidden via `::-webkit-inner-spin-button { -webkit-appearance: none }` and `appearance: textfield`.
- Range `1–300`, default `65`.

#### Connect button
- 32px tall, `padding: 0 16px`, `border-radius: 8px`, white text 12px weight 600 system font.
- **Connected (red) state** — currently connected, label `"Disconnect"`: `linear-gradient(180deg, #ff5b5b 0%, #d63838 100%)`, white indicator dot with `box-shadow: 0 0 6px #fff`.
- **Disconnected (green) state** — label `"Connect"`: `linear-gradient(180deg, #3ed47a 0%, #1fa84e 100%)`, white indicator dot, no glow.
- `box-shadow: 0 1px 2px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.25), inset 0 -1px 0 rgba(0,0,0,0.2)`.

## Interactions & Behavior
- **Brightness slider**: 0–100. Scales LED output linearly. Persist last value.
- **Speed slider**: 0–100. Drives rainbow cycle rate. The HTML prototype maps it as `hue = i / count - t * speed * 0.0004` per LED — port that ratio or pick a comparable mapping for hardware.
- **LED Count stepper**: clamp to `[1, 300]`. Must match the physical strip; the protocol writes exactly this many RGB triples per frame.
- **Serial Port select**: enumerate available ports at launch and on change events. Refresh when the user opens the dropdown.
- **Connect button**: toggles serial connection. While connected, label is "Disconnect" and button is red; while disconnected, label is "Connect" and button is green. Connection failures should revert the state and surface an error (toast or inline) — not in the current prototype, please add.
- **Status line**: live readout of current settings; updates immediately as sliders/stepper change.
- No keyboard shortcuts in the prototype, but ⌘W to close, ⌘Q to quit, and ⌘, for preferences are expected on macOS.

## State Management
- `brightness: number` (0–100, default 80)
- `speed: number` (0–100, default 60)
- `ledCount: number` (1–300, default 65)
- `port: string` (selected serial port path)
- `connected: boolean` (default false in production; the prototype starts true for demo purposes)
- `availablePorts: string[]` (enumerated at runtime)

Persist `brightness`, `speed`, `ledCount`, and last-used `port` between sessions (UserDefaults / electron-store / similar).

## Adalight Protocol (for the implementation)
Cylch is a controller, so the renderer logic lives client-side and frames are pushed over serial:
1. Open serial port at `115200` baud, 8N1.
2. Per frame:
   - Header: `Ada` (3 bytes ASCII) + count high byte + count low byte + checksum (`hi XOR lo XOR 0x55`). Count is `ledCount - 1`.
   - Body: `ledCount × 3` bytes — R, G, B per LED in chain order.
3. Compute the rainbow per-frame at a refresh rate driven by `speed` (e.g. map 0→0fps to 100→60fps, or 30fps base × `0.5 + speed/100 × 1.5`).
4. Apply `brightness` as a linear multiplier on each channel before writing.

## Design Tokens

### Colors
| Token | Value |
| --- | --- |
| Window background | `#16181d` |
| App backdrop layer 1 | `radial-gradient(circle at 30% 20%, #1f2230, transparent 55%)` |
| App backdrop layer 2 | `radial-gradient(circle at 75% 85%, #221a2c, transparent 55%)` |
| App backdrop base | `linear-gradient(135deg, #0a0b0f 0%, #111218 100%)` |
| Surface | `rgba(255,255,255,0.05)` |
| Surface border | `0.5px solid rgba(255,255,255,0.1)` |
| Inset highlight | `inset 0 1px 0 rgba(255,255,255,0.03)` |
| Text primary | `rgba(255,255,255,0.92)` |
| Text bright | `rgba(255,255,255,0.95)` |
| Text secondary | `rgba(255,255,255,0.85)` |
| Text muted | `rgba(255,255,255,0.55)` |
| Text dim | `rgba(255,255,255,0.5)` |
| Separator | `rgba(255,255,255,0.3)` |
| Status green | `#34d674` (with `0 0 6px` glow when active) |
| Status idle | `#7a7a7a` |
| Connect (green) | `linear-gradient(180deg, #3ed47a 0%, #1fa84e 100%)` |
| Disconnect (red) | `linear-gradient(180deg, #ff5b5b 0%, #d63838 100%)` |
| Brightness gradient | `linear-gradient(90deg, #2a2d36 0%, #ffffff 100%)` |
| Speed gradient | `linear-gradient(90deg, #2a2d36 0%, #6979ff 100%)` |
| Slider dim overlay | `rgba(0,0,0,0.55)` |
| Traffic light red | `#ff736a` |
| Traffic light yellow | `#febc2e` |
| Traffic light green | `#19c332` |

### Typography
- **System UI**: `-apple-system, BlinkMacSystemFont, "SF Pro", "Helvetica Neue", sans-serif`
- **Mono**: `"JetBrains Mono", ui-monospace, "SF Mono", Menlo, monospace`
- Title: 13px / weight 600
- Labels (control captions): 10px mono, uppercase, `letter-spacing: 0.8px`
- Values: 12–13px mono, tabular numerals
- Status line: 11px mono
- Buttons: 12px system, weight 600

### Spacing
- Window padding: `18px 22px 20px`
- Vertical gap (rows): 18px
- Footer gap: 12px
- Field internal gap: 7px

### Radii
- Window: 22px
- Surface controls (select, stepper, button): 8px
- Inner buttons (− / +): 5px
- Slider track: 4px

### Shadows
- Window outer: `0 0 0 1px rgba(0,0,0,0.6), 0 24px 60px rgba(0,0,0,0.55)`
- Connect button: `0 1px 2px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.25), inset 0 -1px 0 rgba(0,0,0,0.2)`
- Slider track: `inset 0 1px 2px rgba(0,0,0,0.6), 0 0 0 0.5px rgba(255,255,255,0.08)`
- Slider thumb: `0 1px 3px rgba(0,0,0,0.5), 0 0 0 0.5px rgba(0,0,0,0.4), inset 0 -1px 1px rgba(0,0,0,0.1)`

## Assets
None — no bitmaps or icons. The chevron and traffic lights are inline SVG / div circles.

## Files in this bundle
- `screenshots/cylch-connected.png` — main window in the connected (streaming) state.
- `screenshots/cylch-disconnected.png` — main window in the disconnected (idle) state, showing the green Connect button.
- `Cylch.html` — top-level prototype, wires everything together. Holds the `App` component, default values, port list, slider gradients.
- `macos-window.jsx` — `MacWindow`, `MacToolbar`, `MacTrafficLights` (dark Tahoe-style chrome).
- `cylch-app.jsx` — `GradientSlider`, `Field`, `Select`, `NumberInput`, `ConnectButton`. All control primitives live here.
- `tweaks-panel.jsx` — design-time tweak panel, **not part of the shipped UI**. Ignore for production.
