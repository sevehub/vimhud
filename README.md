# vimhud

A statusline HUD for Vim, written entirely in vim9script. The current mode is shown as a colored block, the pending key sequence (including the leader key) is displayed on the right side of the statusline, and every mode change triggers a short color fade. The strip is a complete statusline: besides the mode block it contains the git branch with a dirty flag, the file name with modified and read-only flags, the macro recording state, the search count, the file type, the encoding and the cursor position. Every component can be reordered or removed. The plugin is part of the SeveTech toolbox ("Tools for Productivity Enthusiasts") and is intended to serve as a compact, readable example of the language.

## Motivation

The default mode indicator is a single line of text at the bottom of the screen, and the pending keys of a multi-key command are shown in a separate area that is easily overlooked. For screencasts and for learning vim motions, a single strip with a clear mode color and a visible key buffer is more useful. The plugin provides this strip without replacing the statusline of other plugins wholesale, since every part can be switched off.

## Requirements

Vim 9.0 or later is required, and Vim 9.1 is recommended. Neovim is not supported, because it does not implement vim9script. The fade animation requires `termguicolors` and a terminal with true color support; without it the mode colors are still applied, but the fade is disabled automatically. Showing the pending keys inside the statusline depends on the `'showcmdloc'` option, which is checked at startup, and the display falls back to the command line when the option is missing. The key box requires popup windows (`+popupwin`), which any Vim 9 provides.

## Installation

Vimhud is installed with [vim9-plum](https://github.com/sevehub/vim9-plum), which is the only supported and recommended method. Plum is a vim9script plugin manager that keeps the plugin list in a single file, `~/.vimplugins`, and clones every plugin into the native package directory. When Plum is not yet installed, the setup instructions in its README cover Linux (bash) and Windows (PowerShell).

With Plum in place, one line is added to the list in `~/.vimplugins`.

```vim
vim9script

g:vimhud_keybox_pos = 'center'

g:plum_plugins = [
  {url: 'sevehub/vimhud'},
]
```

Settings of the plugin go into the same file, above the list, so the `.vimrc` stays free of plugin configuration.

Running `:PlumInstall` inside Vim, or `plum install` from the shell, clones the plugin. After the next start of Vim the HUD is active. Plum also generates the help tags, so `:help vimhud` works without further steps. Updates are applied with `:PlumUpdate`, and a plugin can be fixed to an exact commit with `:PlumPin vimhud`.

## Usage

The HUD is enabled automatically at startup. No mappings are defined. Four commands control the behavior at runtime.

| Command | Effect |
| --- | --- |
| `:HudEnable` | Installs the HUD statusline |
| `:HudDisable` | Restores the previous `'statusline'` value |
| `:HudToggle` | Switches between the two states |
| `:HudAnimation {on\|off}` | Enables or disables the mode fade |
| `:HudKeybox {on\|off}` | Shows or hides the key box |

The previous value of `'statusline'` is stored on enabling and restored on disabling, so the plugin can be toggled without a loss of configuration.

## Configuration

All settings are global variables and are read when the HUD is enabled. They are placed in `~/.vimplugins`, above the plugin list, which Plum sources before it loads any plugin, or changed at runtime followed by `:HudDisable` and `:HudEnable`.

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
| `g:vimhud_keybox` | `1` | Enables the key box |
| `g:vimhud_keybox_timeout` | `2000` | Milliseconds the box stays after the last key |
| `g:vimhud_keybox_max` | `8` | Maximum number of keys shown at once |
| `g:vimhud_keybox_pos` | `'center'` | Horizontal position: `'left'`, `'center'` or `'right'` |
| `g:vimhud_keybox_size` | `'large'` | `'large'` for three-row key caps, `'small'` for one row |

The default colors can be overridden per mode with a dictionary. Missing keys keep their default value.

```vim
g:vimhud_colors = {n: '#3b82f6', i: '#22c55e', v: '#f59e0b', R: '#ef4444', c: '#a855f7', t: '#14b8a6'}
```

The default frame settings produce a fade of about 300 ms. Setting `g:vimhud_animation` to `0` removes all timers and is recommended over slow SSH connections, where frequent redraws can cause flicker.

## Key box

Typed keys are shown in a separate box at the bottom of the screen, which is intended for screencasts and for learning motions. Each key is drawn as a three-row key cap, the newest key is highlighted, and older keys are dimmed. The box and its frame take the color of the current mode and fade together with the mode block, so a switch from NORMAL to INSERT is visible in the box as well. The box stays on the screen for two seconds after the last key, and the timer restarts with every key.

Keys have readable names: `Esc`, `Enter`, `Space`, `Tab`, `Bksp`, arrow symbols, `Ctrl-w` and `Alt-x`. Mouse events and focus events are not shown. Keys typed at a prompt of `input()` or `inputsecret()` are never recorded, but a toggle is available for other sensitive moments.

```vim
:HudKeybox off
:HudKeybox on
```

Vim has no built-in function that reports typed keys, so the box uses a popup filter. A one-cell popup, called the sentinel, sits on the last cell of the statusline row, and its filter sees every typed key without consuming it. Without popup support the plugin falls back to the small pending-key display in the statusline. Keys are shown after mappings have been applied, so a leader mapping appears as the keys it expands to and not as the leader key itself. The size of a character cell is set by the terminal and cannot be changed from inside Vim, so the box is made more prominent with key caps, padding and bold type instead of a larger font. Setting `g:vimhud_keybox_size` to `'small'` returns to a single row.

## Components

The two lists `g:vimhud_left` and `g:vimhud_right` select and order the components of each side. Unknown names are ignored, and a component without content, such as the git branch outside a repository, is omitted.

| Name | Content |
| --- | --- |
| `mode` | Mode block (NORMAL, INSERT, VISUAL, V-LINE, V-BLOCK, REPLACE, COMMAND, TERMINAL, SELECT, OP while an operator is pending) |
| `git` | Branch, `*` when tracked files are modified, `↑n` and `↓n` for commits ahead of or behind the upstream |
| `file` | Path relative to the working directory, `[+]` when modified, `[RO]` when read-only |
| `keys` | Pending key sequence, shown through `%S`; hidden while the key box is active |
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
| `HudKeyBox` | Background of the key box |
| `HudKeyCap` | Newest key, in the color of the current mode |
| `HudKeyOld` | Older keys, a dimmed variant of the mode color |
| `HudKeyBorder` | Frame of the key box, in the color of the current mode |

The groups are defined with `default`, so a colorscheme or a user configuration can override any of them. `HudMode` is rewritten by the plugin on every animation frame, which means that a static override of this group is replaced; the `g:vimhud_colors` variable is the supported way of changing mode colors.

## How it works

The statusline is set to `%!g:HudLine()`, which evaluates a global function on every redraw. The function must be global because the statusline cannot resolve script-local names. It returns a string in which `%#Group#` selects the highlight group, and it distinguishes the active window from inactive ones through `g:statusline_winid`. The function itself has no side effects.

Animation is handled outside the statusline function. A `ModeChanged` autocommand starts a repeating timer, and each tick interpolates the RGB channels between the flash color and the target mode color, applies the result to `HudMode`, and calls `redrawstatus`. The timer is cancelled when a new mode change arrives, so rapid switching does not produce overlapping fades.

## Limitations

Timer callbacks run only while Vim waits for input, so the animation stalls during blocking operations. Without true color support the fade is quantized into visible steps, which is the reason for the automatic fallback. The plugin replaces the statusline of all windows, so it conflicts with other plugins that set `'statusline'`; in this case `:HudDisable` or `g:vimhud_enabled = 0` should be used. The pending-state highlight relies on `state()` and may behave differently between Vim versions. The git component needs the `git` executable and is hidden when it is not found. The arrows in the git segment are UTF-8 characters, so `'encoding'` should be `utf-8`. Windows that define a local `'statusline'` are not affected by the HUD. A popup filter is not called for keys that a popup with a higher priority consumes, for example the keys used in a popup menu. Escape sequences can delay the recognition of the Esc key, and `:set ttimeoutlen=100` avoids the delay. Some versions of Vim are reported to swallow CTRL-C when a visible popup has a filter, so `:HudKeybox off` is the first thing to try when an interrupt does not work.

## Repository layout

```
plugin/vimhud.vim     commands, startup, option checks
autoload/vimhud.vim   statusline function, animation, color handling
doc/vimhud.txt        help file, available through :help vimhud
```

The help tags are generated by Plum after the installation.

## License

MIT.
