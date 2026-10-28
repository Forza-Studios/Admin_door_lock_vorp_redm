fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game "rdr3"

name "Admin Door Lock"
author '_forza'
lua54 'yes'
description 'Admin-only door open/close prompt'

shared_scripts {
    'config.lua',
    'door_hashes.lua' -- shared so the server can store door coords/model in the DB
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
