
fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'phil'
description 'pet attacks'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
	'config1.lua'
}

client_scripts {
	'client1.lua'
}

server_scripts {
	'server1.lua'
}



dependencies {
    'rsg-core',
    'ox_lib'
}