---
title: Workspace Bar
description: A floating per-display island that shows your workspaces and their windows at a glance.
sidebar:
  order: 4
---

The workspace bar is a floating island on each display, centered along its selected edge. It shows a chip per workspace — with the workspace's name, emoji-friendly — and the icons of the apps open there.

## Clicking the bar

- Click a workspace chip to switch to that workspace.
- Click an app icon to focus that window directly.
- When **Deduplicate App Icons** is enabled, multiple windows from one app share a single grouped icon with a count badge; click a grouped icon to open their window list, while a single-window icon focuses that window directly.
- macOS-hidden windows are marked with an eye-slash badge; selecting a hidden window unhides its app and focuses that exact window.
- Non-empty [scratchpad](/features/scratchpads/) slots appear as pills; clicking a pill toggles that scratchpad.

## System Stats

Optionally show a System Stats button that opens a CPU, memory, GPU, disk, and uptime popup. The `Toggle System Stats` hotkey and `omniwmctl command toggle-system-stats` drive the same popup, and both do nothing unless a monitor currently shows that workspace-bar button. See the [CLI reference](/reference/cli/overview/).

## Layout and appearance options

Configure position, height, and appearance in Settings:

- **Position** — overlap the menu bar, sit below it, or dock at **Bottom**, **Left**, or **Right** along the display's usable edge, avoiding a visible Dock. Available globally and per display.
- **Notch handling** — `Off`, `Move Below Menu Bar`, or a split layout (`Split — Active Left` / `Split — Active Right`) that flows the bar around the notch with your chosen side for the active workspace.
- **Auto-hide** — reveal when the pointer approaches the bar; hide after it leaves. See [Auto-hide](#auto-hide).
- **Reveal on modifier hold** — keep the bar hidden until you hold a chosen modifier, or use it as an alternative to hovering when auto-hide is enabled.
- **Hide empty workspaces** — omit chips for workspaces with no windows.
- **Reserve layout space** — reserve room for the bar so tiled windows never sit underneath it.
- **Hide in Native Fullscreen** — hide the bar on a monitor while that monitor shows a macOS native fullscreen window, and bring it back on exit; reserved tiled layout space is left untouched so windows do not shuffle around the fullscreen session.
- **Custom accent and text colors**.
- **Per-monitor overrides** — change an individual display's bar independently.

### Bottom and side placement

:::note[Unreleased]
Bottom, Left, and Right are available when building from `main`, not in OmniWM 0.7.0.
:::

```toml
[workspaceBar]
position = "bottom" # also "left" or "right"
```

Edge placement follows display geometry and Dock changes rather than relying on a large offset. X/Y offsets still apply (positive X moves right; positive Y moves upward). **Reserve layout space** reserves the configured bar thickness at the selected edge; offsets do not change that reservation. Visibility toggles, modifier reveal, and **Hide in Native Fullscreen** continue to apply.

Left/right bars stack workspaces, app icons, floating-window groups, and scratchpads vertically, keeping text and icons upright. The `height` setting controls their **width**. Long labels truncate with accessible full names; tall content scrolls vertically. Stats, hidden-icon panels, and the fallback OmniWM status menu open inward from the displayed bar/icon bounds.

Notch modes, including **Fill Left of Notch**, are ignored at bottom/left/right without changing your saved notch preference. Per-display `position` overrides accept the same values.

### Auto-hide

:::note[Unreleased]
Available when building from `main`, not in OmniWM 0.7.0.
:::

Enable **Auto-Hide on Pointer Leave** globally or in a display's workspace-bar settings:

```toml
[workspaceBar]
autoHide = true
```

The bar appears after the pointer stays near its hidden location or the corresponding edge segment for **150 ms**. Only the bar's portion of the edge activates it, not the entire display edge. Offsets are respected; the activation region connects the bar to its display edge. Bottom and side bars use the usable edge above/beside a visible Dock.

After revealing, a larger keep-open margin and a **400 ms** hide delay prevent flickering while moving across the bar. The bar stays visible while using its stats popup, hidden-icon panel, status menu, or grouped-window sheet. Moving between displays reveals each bar independently. Hidden panels are reused; an idle hidden bar does not poll the mouse.

Auto-hide is **overlay-only**, even if **Reserve layout space** is checked: tiled and layout-fullscreen windows do not resize on reveal/hide. An optional reveal modifier is an alternative way to show the bar. Disabling the bar, manually toggling its visibility off, or suppressing it in native fullscreen takes precedence over both hover and modifier reveal.

These delays and margins are fixed in this first version. Reveal/hide is immediate after the delay, without a sliding animation. macOS may also reveal its own Dock or menu bar when the pointer reaches the same edge.

### Additional appearance controls

- **Fill Left of Notch** — an additional notch mode that fills the menu-bar area left of the notch, covering application menus. Without a notch it uses the left half of the menu bar. When effective at a top position, this mode always hides in native fullscreen, regardless of **Hide in Native Fullscreen**. Bottom/left/right ignore the mode and follow the fullscreen visibility setting.
- **Inactive Icon Opacity** — adjust unfocused app icons from 0–100%; **Reset to System Default** clears the override.
- **Transparent Background** — hide the bar material, tint, and border while keeping its contents interactive.
- **Solid Black Background** — use an opaque black bar; **Transparent Background** takes precedence when both are enabled.
- **Show Item Backgrounds** — show or hide backgrounds behind workspace groups, floating windows, scratchpads, and stats.
- **Show Accent Highlights** — show or hide the focused-workspace outline and focused-icon glow.

These options also support per-monitor overrides. See the [Settings Reference](/config/settings-reference/#workspacebar) for keys and defaults.

## Excluding apps and overriding icons

Exclude individual apps or choose alternate app icons across all monitors in Settings. Icon overrides can also be configured in `settings.toml` (see [Configuration](/config/configuration/)). Quote bundle IDs so TOML treats each dotted identifier as one key:

```toml
[workspaceBar.iconOverrides]
"com.example.App" = "icons/custom.icns"
"com.cmuxterm.app" = "bundle-resource:AppIconDark"
```

`bundle-resource:` loads a named image packaged inside the selected app. The Settings picker discovers likely app-icon resources on demand; runtime-generated or downloaded Dock icons may not be available. Absolute paths are used as written, `~` expands to your home directory, and relative paths are resolved from the directory containing `settings.toml`.

:::note
Overrides affect only the workspace bar. A valid override takes precedence over the app's standard icon; an unavailable or invalid image falls back to the standard icon, then the dashed placeholder when no app icon is available. OmniWM does not watch image files; use Replace to reload a file changed in place.
:::
