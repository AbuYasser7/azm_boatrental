fx_version 'cerulean'
game 'gta5'

name 'azm_boatrental'
author 'abuyasser'
description 'Al Azm Boat Rental'
version '1.1.0'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_lib'
}