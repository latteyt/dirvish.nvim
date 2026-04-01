if exists('b:current_syntax')
  finish
endif
let b:current_syntax = v:true

highlight! link PathHead String
highlight! link PathTail Directory
highlight! link HiddenPath NonText

syntax match PathHead =^.*\/\ze[^/]\+/\?$=
syntax match PathTail =[^/]\+/$=
syntax match HiddenPath =^.*\/\.[^/]\+/\?$= contains=PathHead

