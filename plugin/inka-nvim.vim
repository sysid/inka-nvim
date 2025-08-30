" inka-nvim - Neovim plugin for editing inka2 flashcards
" Maintainer: inka-nvim contributors
" Version: 0.1.0

if exists('g:loaded_inka_nvim') || &compatible
  finish
endif
let g:loaded_inka_nvim = 1

" Default configuration
if !exists('g:inka_nvim_config')
  let g:inka_nvim_config = {}
endif

" Commands will be registered by the Lua module
" This file just ensures the plugin is loaded properly