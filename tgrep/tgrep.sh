export $(cat ~/.tgreprc)

curl 'https://api.telegram.org/bot'$BOT_TOKEN'/sendMessage?text='$(grep $1)'&chat_id='$CHAT_ID
