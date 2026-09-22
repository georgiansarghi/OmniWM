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
- **Visibility** — keep the bar always visible, or show it temporarily using independent pointer, activity, and modifier triggers. See [Visibility and reveal triggers](#visibility-and-reveal-triggers).
- **Reveal on modifier hold** — reveal temporary bars while holding a chosen modifier, independently of pointer or activity reveal.
- **Hide empty workspaces** — omit chips for workspaces with no windows.
- **Reserve layout space** — reserve room for the bar so tiled windows never sit underneath it.
- **Hide in Native Fullscreen** — hide the bar on a monitor while that monitor shows a macOS native fullscreen window, and bring it back on exit; reserved tiled layout space is left untouched so windows do not shuffle around the fullscreen session.
- **Custom accent and text colors**.
- **Per-monitor overrides** — change an individual display's bar independently.

### Bottom and side placement

:::note[Unreleased]
Edge placement and temporary visibility require a source build containing these changes.
:::

Set `position = "bottom"`, `"left"`, or `"right"` in `[workspaceBar]` or a per-display override. Placement follows the usable display edge, avoiding a visible Dock. X/Y offsets still apply; **Reserve layout space** reserves the configured thickness at that edge, regardless of offsets.

Side bars keep labels and icons upright and scroll vertically when needed. `height` controls their width. Popups open inward from the displayed bar. Bottom and side positions ignore notch modes without changing the saved preference.

### Visibility and reveal triggers

Choose **Visibility** globally or per display:

- **Always Visible** (default) ignores reveal triggers without clearing preferences.
- **Show Temporarily** hides the bar until a selected trigger reveals it. Temporary bars never reserve layout space or resize tiled/layout-fullscreen windows.

Triggers are independent and can be combined:

- **Pointer Approaches the Bar** (`revealOnHover`, default `true`) reveals immediately near the hidden bar or its edge segment, not the entire display edge.
- **Briefly Show After Changes** (`activityReveal`, default `"off"`) reveals after workspace changes (`"workspace"`), workspace or selected Niri column changes (`"workspaceAndColumn"`), or workspace/focused-window changes (`"focus"`). No-op commands and animation frames do not count.
- **Reveal on Modifier Hold** (`revealModifier`) applies globally to temporary displays, using the configured hold delay.

For an activity-only bar:

```toml
[workspaceBar]
visibility = "temporary"
revealOnHover = false
activityReveal = "workspaceAndColumn"
activityRevealSeconds = 1.0
revealModifier = "off"
```

Each qualifying change restarts **Keep Visible After Last Change** (default 1 second; range 0.1–10 seconds) on the affected display. Pointer and activity settings support per-display overrides.

Even with pointer reveal disabled, hovering the displayed bar/fallback icon or using a related popup keeps it open. Leaving hides it immediately once no trigger remains; the activity timer continues during interaction. Manual hiding, disabling, and native-fullscreen suppression take precedence. With no triggers selected, the bar stays hidden and Settings shows a reminder.

Existing modifier-only configurations load as temporary bars with pointer reveal disabled. Explicit `visibility` and `revealOnHover` values take precedence.

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
