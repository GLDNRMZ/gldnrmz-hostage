fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'gldnrmz-hostage'
author 'rubbertoe98, GLDNRMZ'
description 'Take players or NPCs hostage at gunpoint'
version '2.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client/main.lua'
server_script 'server/main.lua'

files {
    'locales/*.json',
}

dependencies {
    '/onesync',
    'ox_lib',
    'community_bridge',
}
