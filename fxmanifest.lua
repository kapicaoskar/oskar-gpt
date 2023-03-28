fx_version 'adamant'

game 'gta5'

lua54 'yes'

author 'ExperienceStudio - Tirex,Kekv'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/main.lua'
}

client_scripts {
    'config.lua',
    'client/main.lua'
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/public/css/style.css',
    'html/public/js/locale.js',
    'html/public/js/config.js',
    'html/public/js/script.js',
    'html/public/img/logo.png',
    'html/public/img/search-icon.png',
    'html/public/img/citizen-picture-none.png',
}

dependencies {
    'es_extended',
	'oxmysql',
}



escrow_ignore {
    'config.lua',
    'stream/prop_cs_tablet.ydr',
    'stream/prop_cs_tablet.ytd'
}