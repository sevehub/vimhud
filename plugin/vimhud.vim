vim9script

# vimhud - entry point: commands and startup. Logic lives in autoload/vimhud.vim

if exists('g:loaded_vimhud')
  finish
endif
g:loaded_vimhud = 1

import autoload 'vimhud.vim'

def g:HudComplete(ArgLead: string, CmdLine: string, CursorPos: number): list<string>
  return ['on', 'off']->filter((_, v) => stridx(v, ArgLead) == 0)
enddef

command! -bar HudEnable vimhud.Enable()
command! -bar HudDisable vimhud.Disable()
command! -bar HudToggle vimhud.Toggle()
command! -nargs=1 -complete=customlist,g:HudComplete HudAnimation vimhud.Animation(<q-args>)
command! -nargs=1 -complete=customlist,g:HudComplete HudKeybox vimhud.Keybox(<q-args>)

if get(g:, 'vimhud_enabled', 1) != 0
  vimhud.Enable()
endif
