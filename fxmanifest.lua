fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'
name 'lk-inventory'
provide 'ox_inventory'
author 'Overextended / LK Inventory'
version '2.48.0'
repository 'https://github.com/overextended/ox_inventory'
description 'LK Inventory - ox_inventory backend with Svelte NUI'

dependencies {
    '/server:6116',
    '/onesync',
    'oxmysql',
    'ox_lib',
}

shared_script '@ox_lib/init.lua'

ox_libs {
    'locale',
    'table',
    'math',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'init.lua'
}

client_script 'init.lua'

ui_page 'web/build/index.html'

files {
    'client.lua',
    'server.lua',
    'locales/*.json',
  'web/build/index.html',
  'web/build/assets/*',
  'web/build/assets/*.js',
  'web/build/assets/*.css',
  'web/build/images/*.png',
  'web/build/*.svg',
    'web/images/*.png',
    'web/assets/*',
    'web/fonts/*',
    'modules/**/shared.lua',
    'modules/**/client.lua',
    'modules/bridge/**/client.lua',
    'data/*.lua',
}
