vim9script

# vimhud - statusline HUD: mode colors with fade, pending keys, git, full
# statusline. Requires Vim 9.0 or later. See :help vimhud

# ---------------------------------------------------------------- constants

const DEFAULT_COLORS: dict<string> = {
  n: '#3b82f6',
  i: '#22c55e',
  v: '#f59e0b',
  R: '#ef4444',
  c: '#a855f7',
  t: '#14b8a6',
}

const CTERM_COLORS: dict<number> = {n: 4, i: 2, v: 3, R: 1, c: 5, t: 6}

const KEY_NAMES: dict<string> = {
  '<Esc>': 'Esc',
  '<CR>': 'Enter',
  '<NL>': 'Enter',
  '<Space>': 'Space',
  '<Tab>': 'Tab',
  '<BS>': 'Bksp',
  '<Del>': 'Del',
  '<Up>': '↑',
  '<Down>': '↓',
  '<Left>': '←',
  '<Right>': '→',
  '<Home>': 'Home',
  '<End>': 'End',
  '<PageUp>': 'PgUp',
  '<PageDown>': 'PgDn',
  '<Insert>': 'Ins',
  '<lt>': '<',
  '<Bar>': '|',
}

const MODE_NAMES: dict<string> = {
  n: 'NORMAL',
  i: 'INSERT',
  v: 'VISUAL',
  V: 'V-LINE',
  R: 'REPLACE',
  c: 'COMMAND',
  t: 'TERMINAL',
  s: 'SELECT',
  S: 'S-LINE',
}

# -------------------------------------------------------------------- state

var active = false
var keybox_on = false
var sentinel_id = 0
var keybox_id = 0
var render_timer = -1
var hide_timer = -1
var keys_buf: list<string> = []
var timer = -1
var colors: dict<string> = {}
var git_info: dict<string> = {}
var saved_statusline = ''
var saved_laststatus = 2
var saved_showcmd = false
var saved_showcmdloc = ''
var anim_from: list<number> = [0, 0, 0]
var anim_to: list<number> = [0, 0, 0]
var anim_frame = 0
var anim_frames = 10
var flash = '#ffffff'

# ------------------------------------------------------------------ helpers

def Opt(name: string, fallback: any): any
  return get(g:, 'vimhud_' .. name, fallback)
enddef

def IsHex(s: string): bool
  return s =~# '^#\x\{6}$'
enddef

def ParseHex(hex: string): list<number>
  return [str2nr(hex[1 : 2], 16), str2nr(hex[3 : 4], 16), str2nr(hex[5 : 6], 16)]
enddef

def ToHex(c: list<number>): string
  return printf('#%02x%02x%02x', c[0], c[1], c[2])
enddef

# Blends color a towards color b; pct is the share of b, from 0 to 100.
def Mix(a: string, b: string, pct: number): string
  const x = ParseHex(a)
  const y = ParseHex(b)
  return ToHex(range(3)->mapnew((_, i) => x[i] + (y[i] - x[i]) * pct / 100))
enddef

def Esc(s: string): string
  return substitute(s, '%', '%%', 'g')
enddef

# --------------------------------------------------------------------- mode

# Color key of the current mode: n, i, v, R, c or t.
def ModeKey(): string
  const c = mode()[0]
  if c == 'V' || c == "\<C-v>" || c == 's' || c == 'S' || c == "\<C-s>"
    return 'v'
  endif
  if c == 'r' || c == '!'
    return 'n'
  endif
  return has_key(DEFAULT_COLORS, c) ? c : 'n'
enddef

def ModeName(): string
  const m = mode()
  if m[0] == "\<C-v>"
    return 'V-BLOCK'
  endif
  if m[0] == "\<C-s>"
    return 'S-BLOCK'
  endif
  if m =~# '^no'
    return 'OP'
  endif
  return get(MODE_NAMES, m[0], 'NORMAL')
enddef

def LoadColors()
  colors = copy(DEFAULT_COLORS)
  const user: dict<any> = Opt('colors', {})
  for [k, v] in items(user)
    if type(v) == v:t_string && IsHex(v)
      colors[k] = v
    endif
  endfor
  const f: string = Opt('flash', '#ffffff')
  flash = IsHex(f) ? f : '#ffffff'
  anim_frames = max([1, Opt('frames', 10)])
enddef

def ModeColor(): string
  return get(colors, ModeKey(), DEFAULT_COLORS.n)
enddef

def ApplyMode(hex: string)
  const cterm = get(CTERM_COLORS, ModeKey(), 4)
  execute $'highlight HudMode guibg={hex} guifg=#111111 ctermbg={cterm} ctermfg=0 gui=bold cterm=bold'
  execute $'highlight HudPos guibg={hex} guifg=#111111 ctermbg={cterm} ctermfg=0'
  execute $'highlight HudKeyCap guibg={hex} guifg=#111111 ctermbg={cterm} ctermfg=0 gui=bold cterm=bold'
  execute $'highlight HudKeyOld guibg={Mix(hex, "#1c1f27", 55)} guifg=#e5e7eb ctermbg=238 ctermfg=252'
  execute $'highlight HudKeyBorder guibg=#1c1f27 guifg={hex} ctermbg=234 ctermfg={cterm}'
enddef

def DefineGroups()
  highlight default HudFill guibg=#1c1f27 guifg=#d0d4e0 ctermbg=234 ctermfg=252
  highlight default HudFile guibg=#2a2e3a guifg=#d0d4e0 ctermbg=236 ctermfg=252
  highlight default HudGit guibg=#353a4a guifg=#a8c7fa ctermbg=238 ctermfg=111
  highlight default HudKeys guibg=#2a2e3a guifg=#f5d76e ctermbg=236 ctermfg=221 gui=bold cterm=bold
  highlight default HudPending guibg=#f5d76e guifg=#111111 ctermbg=221 ctermfg=0 gui=bold cterm=bold
  highlight default HudInfo guibg=#353a4a guifg=#b0b6c8 ctermbg=238 ctermfg=250
  highlight default HudAlert guibg=#ef4444 guifg=#ffffff ctermbg=1 ctermfg=15 gui=bold cterm=bold
  highlight default HudInactive guibg=#1c1f27 guifg=#6b7280 ctermbg=234 ctermfg=243
  highlight default HudKeyBox guibg=#1c1f27 guifg=#d0d4e0 ctermbg=234 ctermfg=252
enddef

# ---------------------------------------------------------------- animation

def Fade(): bool
  return Opt('animation', 1) != 0 && (&termguicolors || has('gui_running'))
enddef

def StopTimer()
  if timer != -1
    timer_stop(timer)
    timer = -1
  endif
enddef

def Tick(id: number)
  anim_frame += 1
  var col: list<number> = []
  for i in range(3)
    col->add(anim_from[i] + (anim_to[i] - anim_from[i]) * anim_frame / anim_frames)
  endfor
  ApplyMode(ToHex(col))
  redrawstatus
  if anim_frame >= anim_frames
    timer = -1
  endif
enddef

def OnModeChanged()
  if !active
    return
  endif
  const target = ModeColor()
  StopTimer()
  if !Fade()
    ApplyMode(target)
    redrawstatus
    return
  endif
  anim_frame = 0
  anim_from = ParseHex(flash)
  anim_to = ParseHex(target)
  ApplyMode(flash)
  timer = timer_start(Opt('interval', 30), Tick, {repeat: anim_frames})
  redrawstatus
enddef

# ---------------------------------------------------------------------- git

# Parses the output of: git status --porcelain=v1 -b --untracked-files=no
def ParseGit(lines: list<string>): string
  if empty(lines) || lines[0][0 : 1] != '##'
    return ''
  endif
  const head = lines[0][3 :]
  var branch = ''
  if head =~# '^No commits yet on '
    branch = substitute(head, '^No commits yet on ', '', '')
  elseif head =~# '^HEAD (no branch)'
    branch = 'detached'
  else
    branch = matchstr(head, '^.\{-}\ze\(\.\.\.\| \[\|$\)')
  endif
  const ahead = matchstr(head, 'ahead \zs\d\+')
  const behind = matchstr(head, 'behind \zs\d\+')
  const sym: string = Opt('git_symbol', '')
  var out = (sym == '' ? '' : sym .. ' ') .. branch
  if len(lines) > 1
    out ..= '*'
  endif
  if ahead != ''
    out ..= ' ↑' .. ahead
  endif
  if behind != ''
    out ..= ' ↓' .. behind
  endif
  return out
enddef

def GitDone(dir: string, lines: list<string>)
  git_info[dir] = ParseGit(lines)
  redrawstatus!
enddef

def UpdateGit()
  if Opt('git', 1) == 0 || !executable('git') || &buftype != ''
    return
  endif
  const dir = expand('%:p:h')
  if dir == '' || !isdirectory(dir)
    return
  endif
  var lines: list<string> = []
  job_start(['git', '--no-optional-locks', '-C', dir, 'status', '--porcelain=v1', '-b', '--untracked-files=no'], {
    out_cb: (ch, msg) => add(lines, msg),
    close_cb: (ch) => GitDone(dir, lines),
    in_io: 'null',
    err_io: 'null',
  })
enddef

# --------------------------------------------------------------- components

def FileName(buf: number): string
  const name = bufname(buf)
  if name == ''
    return '[No Name]'
  endif
  return Esc(fnamemodify(name, ':~:.'))
enddef

def CompMode(): string
  return '%#HudMode# ' .. ModeName() .. ' %*'
enddef

def CompGit(buf: number): string
  if Opt('git', 1) == 0
    return ''
  endif
  const dir = fnamemodify(bufname(buf), ':p:h')
  const info = get(git_info, dir, '')
  return info == '' ? '' : '%#HudGit# ' .. Esc(info) .. ' %*'
enddef

def CompFile(buf: number): string
  var s = '%#HudFile# %<' .. FileName(buf)
  if getbufvar(buf, '&modified') != false
    s ..= ' %#HudAlert#[+]%#HudFile#'
  endif
  if getbufvar(buf, '&readonly') != false
    s ..= ' [RO]'
  endif
  return s .. ' %*'
enddef

def CompKeys(): string
  if keybox_on || Opt('show_keys', 1) == 0 || !exists('+showcmdloc') || eval('&showcmdloc') != 'statusline'
    return ''
  endif
  const pending = state('m') != '' || mode() =~# '^no'
  return $'%#{pending ? "HudPending" : "HudKeys"}# %-10S %*'
enddef

def CompRecording(): string
  const reg = reg_recording()
  return reg == '' ? '' : $'%#HudAlert# REC @{reg} %*'
enddef

def CompSearch(): string
  if v:hlsearch == 0
    return ''
  endif
  const sc: dict<any> = searchcount({maxcount: 99, timeout: 20})
  if empty(sc) || sc.total == 0
    return ''
  endif
  const cur = sc.current > sc.maxcount ? $'>{sc.maxcount}' : string(sc.current)
  var total = string(sc.total)
  if sc.incomplete == 1
    total = '?'
  elseif sc.incomplete == 2
    total = $'>{sc.maxcount}'
  endif
  return $'%#HudInfo# [{cur}/{total}] %*'
enddef

def CompFiletype(buf: number): string
  const ft: string = getbufvar(buf, '&filetype')
  return ft == '' ? '' : '%#HudInfo# ' .. Esc(ft) .. ' %*'
enddef

def CompEncoding(buf: number): string
  var enc: string = getbufvar(buf, '&fileencoding')
  if enc == ''
    enc = &encoding
  endif
  const ff: string = getbufvar(buf, '&fileformat')
  return '%#HudInfo# ' .. enc .. '[' .. ff .. '] %*'
enddef

def CompPosition(): string
  return '%#HudPos# %l:%v  %p%% %*'
enddef

def Component(name: string, buf: number): string
  if name == 'mode'
    return CompMode()
  elseif name == 'git'
    return CompGit(buf)
  elseif name == 'file'
    return CompFile(buf)
  elseif name == 'keys'
    return CompKeys()
  elseif name == 'recording'
    return CompRecording()
  elseif name == 'search'
    return CompSearch()
  elseif name == 'filetype'
    return CompFiletype(buf)
  elseif name == 'encoding'
    return CompEncoding(buf)
  elseif name == 'position'
    return CompPosition()
  endif
  return ''
enddef

def Side(names: list<string>, buf: number): string
  return names->mapnew((_, n) => Component(n, buf))->join('')
enddef

# Evaluated by 'statusline' through %!g:HudLine(); it must be global.
def g:HudLine(): string
  const win: number = get(g:, 'statusline_winid', win_getid())
  const buf = winbufnr(win)
  if win != win_getid()
    return '%#HudInactive# %<%f%m%=%l:%v '
  endif
  const left: list<string> = Opt('left', ['mode', 'git', 'file'])
  const right: list<string> = Opt('right', ['keys', 'recording', 'search', 'filetype', 'encoding', 'position'])
  return Side(left, buf) .. '%#HudFill#%=' .. Side(right, buf)
enddef

# ------------------------------------------------------------------ control

# ------------------------------------------------------------------ key box

# Readable label for a typed key, or '' for keys that are not shown.
def KeyLabel(raw: string): string
  const k = keytrans(raw)
  if k == ''
    return ''
  endif
  if k =~# 'Mouse\|Drag\|Release\|ScrollWheel\|Focus\|CursorHold\|Ignore\|Plug\|SNR\|Paste\|Cmd>'
    return ''
  endif
  if has_key(KEY_NAMES, k)
    return KEY_NAMES[k]
  endif
  var m = matchlist(k, '^<C-\(.\)>$')
  if !empty(m)
    return 'Ctrl-' .. tolower(m[1])
  endif
  m = matchlist(k, '^<[MA]-\(.\)>$')
  if !empty(m)
    return 'Alt-' .. m[1]
  endif
  if k =~# '^<.*>$'
    return k[1 : -2]
  endif
  return k
enddef

def HideKeyBox()
  hide_timer = -1
  keys_buf = []
  if keybox_id != 0 && !empty(popup_getpos(keybox_id))
    popup_hide(keybox_id)
  endif
enddef

def KeyBoxCol(width: number): number
  const where: string = Opt('keybox_pos', 'center')
  if where == 'left'
    return 1
  elseif where == 'right'
    return max([1, &columns - width + 1])
  endif
  return max([1, (&columns - width) / 2 + 1])
enddef

def RenderKeyBox()
  render_timer = -1
  if !keybox_on || empty(keys_buf)
    return
  endif
  const large = Opt('keybox_size', 'large') != 'small'
  const n = len(keys_buf)
  var r1 = ''
  var r2 = ''
  var r3 = ''
  var p1: list<dict<any>> = []
  var p2: list<dict<any>> = []
  var p3: list<dict<any>> = []
  for i in range(n)
    const cell = large ? '  ' .. keys_buf[i] .. '  ' : ' ' .. keys_buf[i] .. ' '
    const w = strdisplaywidth(cell)
    const kind = i == n - 1 ? 'HudKeyCap' : 'HudKeyOld'
    if i > 0
      r1 ..= ' '
      r2 ..= ' '
      r3 ..= ' '
    endif
    p1->add({col: strlen(r1) + 1, length: w, type: kind})
    p2->add({col: strlen(r2) + 1, length: strlen(cell), type: kind})
    p3->add({col: strlen(r3) + 1, length: w, type: kind})
    r1 ..= repeat(' ', w)
    r2 ..= cell
    r3 ..= repeat(' ', w)
  endfor
  var rows: list<dict<any>> = [{text: r2, props: p2}]
  if large
    rows = [{text: r1, props: p1}, {text: r2, props: p2}, {text: r3, props: p3}]
  endif
  const width = strdisplaywidth(r2) + 4
  const where = {pos: 'botleft', line: &lines - &cmdheight - 1, col: KeyBoxCol(width)}
  if keybox_id == 0 || empty(popup_getpos(keybox_id))
    var opts: dict<any> = {
      pos: 'botleft',
      line: where.line,
      col: where.col,
      padding: [0, 1, 0, 1],
      border: [1, 1, 1, 1],
      highlight: 'HudKeyBox',
      borderhighlight: ['HudKeyBorder'],
      zindex: 300,
      wrap: false,
    }
    if &encoding == 'utf-8'
      opts.borderchars = ['─', '│', '─', '│', '╭', '╮', '╯', '╰']
    endif
    keybox_id = popup_create(rows, opts)
  else
    popup_settext(keybox_id, rows)
    popup_move(keybox_id, where)
    popup_show(keybox_id)
  endif
  if hide_timer != -1
    timer_stop(hide_timer)
  endif
  hide_timer = timer_start(Opt('keybox_timeout', 2000), (_) => HideKeyBox())
enddef

# Records one typed key. The key is what remains after mappings, because it
# comes from a popup filter.
def Capture(raw: string)
  if !keybox_on || getcmdtype() == '@'
    return
  endif
  const label = KeyLabel(raw)
  if label == ''
    return
  endif
  keys_buf->add(label)
  const most: number = Opt('keybox_max', 8)
  if len(keys_buf) > most
    keys_buf->remove(0, len(keys_buf) - most - 1)
  endif
  if render_timer == -1
    render_timer = timer_start(0, (_) => RenderKeyBox())
  endif
enddef

# Popup filter of the sentinel window. It sees every typed key and never
# consumes one, so typing is not affected.
def KeyFilter(id: number, key: string): bool
  Capture(key)
  return false
enddef

# The sentinel is a one-cell popup on the last cell of the statusline row. A
# popup filter is called only while a popup is visible, so the sentinel has to
# stay on the screen for as long as the key box is enabled.
def PlaceSentinel()
  if sentinel_id != 0 && !empty(popup_getpos(sentinel_id))
    popup_move(sentinel_id, {line: &lines - &cmdheight, col: &columns})
  endif
enddef

def OpenSentinel()
  if sentinel_id != 0 && !empty(popup_getpos(sentinel_id))
    return
  endif
  sentinel_id = popup_create(' ', {
    pos: 'topleft',
    line: &lines - &cmdheight,
    col: &columns,
    minwidth: 1,
    maxwidth: 1,
    minheight: 1,
    maxheight: 1,
    highlight: 'HudPos',
    filter: KeyFilter,
    zindex: 1,
    wrap: false,
  })
enddef

def EnsurePropTypes()
  for t in ['HudKeyCap', 'HudKeyOld']
    if empty(prop_type_get(t))
      prop_type_add(t, {highlight: t})
    endif
  endfor
enddef

def StartKeyBox()
  if !has('popupwin')
    return
  endif
  EnsurePropTypes()
  keybox_on = true
  OpenSentinel()
enddef

def StopKeyBox()
  keybox_on = false
  if render_timer != -1
    timer_stop(render_timer)
    render_timer = -1
  endif
  if hide_timer != -1
    timer_stop(hide_timer)
    hide_timer = -1
  endif
  keys_buf = []
  if keybox_id != 0
    popup_close(keybox_id)
    keybox_id = 0
  endif
  if sentinel_id != 0
    popup_close(sentinel_id)
    sentinel_id = 0
  endif
enddef

def Recolor()
  DefineGroups()
  ApplyMode(ModeColor())
enddef

def SetupAutocmds()
  augroup VimHud
    autocmd!
    autocmd ModeChanged * OnModeChanged()
    autocmd BufEnter,BufWritePost,FocusGained,DirChanged,ShellCmdPost * UpdateGit()
    autocmd ColorScheme * Recolor()
    autocmd VimResized * PlaceSentinel()
    autocmd OptionSet cmdheight,laststatus PlaceSentinel()
  augroup END
enddef

export def Enable()
  if active
    return
  endif
  LoadColors()
  saved_statusline = &statusline
  saved_laststatus = &laststatus
  saved_showcmd = &showcmd
  if exists('+showcmdloc')
    saved_showcmdloc = eval('&showcmdloc')
    if Opt('show_keys', 1) != 0
      execute 'set showcmdloc=statusline'
      &showcmd = true
    endif
  endif
  &statusline = '%!g:HudLine()'
  if &laststatus < 2
    &laststatus = 2
  endif
  DefineGroups()
  ApplyMode(ModeColor())
  SetupAutocmds()
  active = true
  if Opt('keybox', 1) != 0
    StartKeyBox()
  endif
  UpdateGit()
  redrawstatus!
enddef

export def Disable()
  if !active
    return
  endif
  active = false
  StopTimer()
  StopKeyBox()
  augroup VimHud
    autocmd!
  augroup END
  &statusline = saved_statusline
  &laststatus = saved_laststatus
  &showcmd = saved_showcmd
  if exists('+showcmdloc')
    execute $'set showcmdloc={saved_showcmdloc}'
  endif
  redrawstatus!
enddef

export def Toggle()
  if active
    Disable()
  else
    Enable()
  endif
enddef

export def Animation(arg: string)
  if arg == 'on'
    g:vimhud_animation = 1
  elseif arg == 'off'
    g:vimhud_animation = 0
    StopTimer()
  else
    echoerr $'vimhud: expected "on" or "off", got "{arg}"'
  endif
enddef

export def Keybox(arg: string)
  if arg == 'on'
    g:vimhud_keybox = 1
    if active && !has('popupwin')
      echomsg 'vimhud: the key box requires popup windows, which this Vim does not provide'
    elseif active
      StartKeyBox()
    endif
  elseif arg == 'off'
    g:vimhud_keybox = 0
    StopKeyBox()
  else
    echoerr $'vimhud: expected "on" or "off", got "{arg}"'
  endif
enddef
