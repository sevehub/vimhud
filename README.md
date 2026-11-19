# vimhud

A statusline HUD for Vim, written entirely in vim9script. The current mode is shown as a colored block, the pending key sequence (including the leader key) is displayed on the right side of the statusline, and every mode change triggers a short color fade.

It provides complete configuration of the statusline, besides the mode block it contains the git branch with a dirty flag, the file name with modified and read-only flags, the macro recording state, the search count, the file type, the encoding and the cursor position. Every component can be reordered or removed. The plugin is part of the SeveTech toolbox ("Tools for Productivity Enthusiasts").


## Requirements

Vim 9.0 or later is required, and Vim 9.1 is recommended. Neovim is not supported, because it does not implement vim9script. The fade animation requires `termguicolors` and a terminal with true color support; without it the mode colors are still applied, but the fade is disabled automatically. Showing the pending keys inside the statusline depends on the `'showcmdloc'` option, which is checked at startup, and the display falls back to the command line when the option is missing.

## Installation

Use [Vim9-plum]() plugin manager.

With the SeveTech plugin manager Vim9-plum, one line is added to `~/.vimplugins`

```vim
{url: 'sevehub/vimhud'},
```


## Usage

The HUD is enabled automatically at startup. No mappings are defined. Four commands control the behavior at runtime.

| Command | Effect |
| --- | --- |
| `:HudEnable` | Installs the HUD statusline |
| `:HudDisable` | Restores the previous `'statusline'` value |
| `:HudToggle` | Switches between the two states |
| `:HudAnimation {on\|off}` | Enables or disables the mode fade |

The previous value of `'statusline'` is stored on enabling and restored on disabling, so the plugin can be toggled without a loss of configuration.

## Configuration

All settings are global variables and are read when the HUD is enabled. They can be placed in the `.vimrc` before the plugin is loaded, or changed at runtime followed by `:HudDisable` and `:HudEnable`.

| Variable | Default | Meaning |
| --- | --- | --- |
| `g:vimhud_enabled` | `1` | Enables the HUD at startup |
| `g:vimhud_animation` | `1` | Enables the fade on mode change |
| `g:vimhud_frames` | `10` | Number of animation frames |
| `g:vimhud_interval` | `30` | Milliseconds between frames |
| `g:vimhud_flash` | `'#ffffff'` | Color from which the fade starts |
| `g:vimhud_show_keys` | `1` | Shows the pending key sequence |
| `g:vimhud_colors` | see below | Background color per mode |
| `g:vimhud_left` | `['mode', 'git', 'file']` | Components of the left side |
| `g:vimhud_right` | `['keys', 'recording', 'search', 'filetype', 'encoding', 'position']` | Components of the right side |
| `g:vimhud_git` | `1` | Enables the git component |
| `g:vimhud_git_symbol` | `''` | Text placed before the branch name, for example a Nerd Font branch glyph |

The default colors can be overridden per mode with a dictionary. Missing keys keep their default value.

```vim
g:vimhud_colors = {n: '#3b82f6', i: '#22c55e', v: '#f59e0b', R: '#ef4444', c: '#a855f7', t: '#14b8a6'}
```

The default frame settings produce a fade of about 300 ms. Setting `g:vimhud_animation` to `0` removes all timers and is recommended over slow SSH connections, where frequent redraws can cause flicker.

## Components

The two lists `g:vimhud_left` and `g:vimhud_right` select and order the components of each side. Unknown names are ignored, and a component without content, such as the git branch outside a repository, is omitted.

| Name | Content |
| --- | --- |
| `mode` | Mode block (NORMAL, INSERT, VISUAL, V-LINE, V-BLOCK, REPLACE, COMMAND, TERMINAL, SELECT, OP while an operator is pending) |
| `git` | Branch, `*` when tracked files are modified, `↑n` and `↓n` for commits ahead of or behind the upstream |
| `file` | Path relative to the working directory, `[+]` when modified, `[RO]` when read-only |
| `keys` | Pending key sequence, shown through `%S` |
| `recording` | `REC @q` while a macro is recorded |
| `search` | `[current/total]` while search highlighting is active |
| `filetype` | Value of `'filetype'` |
| `encoding` | File encoding and format, for example `utf-8[unix]` |
| `position` | Line, virtual column and percentage |

A minimal HUD with only the mode and the keys is obtained with the following lines.

```vim
g:vimhud_left = ['mode', 'file']
g:vimhud_right = ['keys', 'position']
```

The git state is determined asynchronously with `git status --porcelain=v1 -b --untracked-files=no`, started on `BufEnter`, `BufWritePost`, `FocusGained`, `DirChanged` and `ShellCmdPost`. Untracked files are excluded so that the call stays fast in large repositories, which means that the `*` flag reflects tracked files only. The `--no-optional-locks` flag prevents interference with other git commands running in the same repository.

## Highlight groups

| Group | Used for |
| --- | --- |
| `HudMode` | Mode block, updated dynamically |
| `HudPos` | Position block, follows the color of `HudMode` |
| `HudFill` | Empty space between the left and the right side |
| `HudFile` | File name segment |
| `HudGit` | Git segment |
| `HudInfo` | Search count, file type and encoding |
| `HudAlert` | Modified flag and macro recording |
| `HudKeys` | Pending key sequence |
| `HudPending` | Key segment while a mapping or an operator is incomplete |
| `HudInactive` | Statusline of non-current windows |

The groups are defined with `default`, so a colorscheme or a user configuration can override any of them. `HudMode` is rewritten by the plugin on every animation frame, which means that a static override of this group is replaced; the `g:vimhud_colors` variable is the supported way of changing mode colors.

## How it works

The statusline is set to `%!g:HudLine()`, which evaluates a global function on every redraw. The function must be global because the statusline cannot resolve script-local names. It returns a string in which `%#Group#` selects the highlight group, and it distinguishes the active window from inactive ones through `g:statusline_winid`. The function itself has no side effects.

Animation is handled outside the statusline function. A `ModeChanged` autocommand starts a repeating timer, and each tick interpolates the RGB channels between the flash color and the target mode color, applies the result to `HudMode`, and calls `redrawstatus`. The timer is cancelled when a new mode change arrives, so rapid switching does not produce overlapping fades.

## Limitations

Timer callbacks run only while Vim waits for input, so the animation stalls during blocking operations. Without true color support the fade is quantized into visible steps, which is the reason for the automatic fallback. The plugin replaces the statusline of all windows, so it conflicts with other plugins that set `'statusline'`; in this case `:HudDisable` or `g:vimhud_enabled = 0` should be used. The pending-state highlight relies on `state()` and may behave differently between Vim versions. The git component needs the `git` executable and is hidden when it is not found. The arrows in the git segment are UTF-8 characters, so `'encoding'` should be `utf-8`. Windows that define a local `'statusline'` are not affected by the HUD.

## Repository layout

```
plugin/vimhud.vim     commands, startup, option checks
autoload/vimhud.vim   statusline function, animation, color handling
doc/vimhud.txt        help file, available through :help vimhud
```

After installation, `:helptags ALL` generates the help tags when a manager does not do it automatically.

## License

MIT.
