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
Bottom, Left, and Right are part of [georgiansarghi/OmniWM fork PR #1](https://github.com/georgiansarghi/OmniWM/pull/1). Build that fork's `feat/workspace-bar-bottom` branch, not upstream `main` or OmniWM 0.7.0.
:::

```toml
[workspaceBar]
position = "bottom" # also "left" or "right"
```

Edge placement follows display geometry and Dock changes rather than relying on a large offset. X/Y offsets still apply (positive X moves right; positive Y moves upward). **Reserve layout space** reserves the configured bar thickness at the selected edge; offsets do not change that reservation. Visibility toggles, modifier reveal, and **Hide in Native Fullscreen** continue to apply.

Left/right bars stack workspaces, app icons, floating-window groups, and scratchpads vertically, keeping text and icons upright. The `height` setting controls their **width**. Long labels truncate with accessible full names; tall content scrolls vertically. Stats, hidden-icon panels, and the fallback OmniWM status menu open inward from the displayed bar/icon bounds.

Notch modes, including **Fill Left of Notch**, are ignored at bottom/left/right without changing your saved notch preference. Per-display `position` overrides accept the same values.

### Visibility and reveal triggers

:::note[Unreleased]
These controls are part of [georgiansarghi/OmniWM fork PR #1](https://github.com/georgiansarghi/OmniWM/pull/1). Build that fork's `feat/workspace-bar-bottom` branch; they are not available from upstream `main` or OmniWM 0.7.0.
:::

Choose **Visibility** globally or per display:

- **Always Visible** (default) keeps the bar visible, ignoring stored reveal triggers.
- **Show Temporarily** normally hides the bar. Choose any combination of **Pointer Approaches the Bar**, **Briefly Show After Changes**, and **Reveal on Modifier Hold**. With no triggers selected, it stays hidden; the settings show a reminder rather than silently enabling a trigger.

For hover-only behavior:

```toml
[workspaceBar]
visibility = "temporary"
revealOnHover = true
```

When pointer reveal is enabled, the bar appears **immediately** near its hidden location or corresponding edge segment. Only the bar's portion of the edge activates it. Offsets are respected; bottom and side bars use the usable edge beside a visible Dock. A larger keep-open margin prevents flickering while moving across the bar.

When pointer reveal is **off**, approaching the edge or the hidden bar cannot summon it. Once activity or a modifier reveals it, hovering the **displayed bar or fallback icon** can keep it open for interaction; the empty edge corridor cannot. Stats popups, hidden-icon panels, status menus, and grouped-window sheets keep it open with either pointer setting. Leaving hides it immediately if no other reveal reason remains. Activity durations continue counting during interaction, so leaving after expiration adds no extra delay.

Temporary bars are **overlay-only**, even if **Reserve layout space** is checked: tiled and layout-fullscreen windows do not resize on reveal/hide. Disabling the bar, manually hiding it, or native-fullscreen suppression takes precedence over all triggers. Hidden panels are reused and do not poll the mouse. Both hover delays remain **zero**, with no sliding animation.

Visibility, pointer reveal, and activity settings support per-display inheritance and overrides. The modifier combination and its hold delay are global and apply only to temporary displays. Selecting Always Visible disables the scope's reveal controls without clearing preferences; the global modifier controls remain available if another display is configured as temporary. macOS may independently reveal its Dock or menu bar at an edge.

Legacy `autoHide` configurations are upgraded on load: `true` becomes temporary + pointer reveal; modifier-only configurations remain temporary with pointer and activity reveal off. Legacy hover-enabled display overrides retain their previously active activity settings. Otherwise the bar remains always visible. New `visibility`/`revealOnHover` keys take precedence; saves retire the old alias while preserving unrelated settings.

### Briefly show after changes

In Show Temporarily mode, **Briefly Show After Changes** can reveal the bar without moving the pointer—even with pointer reveal off. This is optional and defaults to **Never**:

| Setting | TOML value | Reveals after |
|---|---|---|
| Never | `"off"` | No activity-triggered reveal |
| Workspace Changes | `"workspace"` | The display's active workspace changes, including empty workspaces |
| Workspace and Column Changes | `"workspaceAndColumn"` | A workspace change or a different selected Niri column |
| Any Focused-Window Change | `"focus"` | A workspace change or a newly focused managed window, including floating windows |

```toml
[workspaceBar]
visibility = "temporary"
revealOnHover = false
activityReveal = "workspaceAndColumn"
activityRevealSeconds = 1.0
```

The bar appears immediately on the affected display and stays visible for **Keep Visible After Last Change** (default 1 second; range 0.1–10 seconds). Each qualifying change restarts that duration rather than stacking durations or flashing the bar. Hover and popup interaction can keep it open afterward. This duration is separate from the **zero-delay hover behavior**; it never reserves layout space or activates the bar's window.

Activity follows actual workspace/column/focus state changes, including keyboard, gesture, mouse, and IPC navigation—not command attempts, window-title/icon updates, or animation frames. Focus mode can also react to application-driven focus changes. In non-Niri layouts, the column preset only reacts to workspace changes. A column's identity, not its numeric index, is tracked; rearranging the same selected column does not count as changing columns.

Both settings support per-display overrides with global inheritance. Their UI controls are disabled in Always Visible mode, but saved preferences are preserved. Manual hiding, disabling, fullscreen suppression, and disconnecting a display cancel its pending activity reveal; reopening or enabling it does not replay old activity.

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
