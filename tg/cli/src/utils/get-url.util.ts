import { execSync }     from 'child_process'
import { readFileSync } from 'fs'

export const getUrl = (text: string) => {
  const user = execSync('whoami').toString('utf-8').replaceAll('\n', '')
  const tgrc = readFileSync(`/Users/${user}/.tgrc`).toString('utf-8')

  const values = tgrc.split('\n').map((pair) => pair.split('='))
  const map = new Map()

  for (const pair of values) {
    map.set(pair[0], pair[1])
  }

  const url = `https://api.telegram.org/bot${map.get(
    'BOT_TOKEN'
  )}/sendMessage?text=${text}&chat_id=${map.get('CHAT_ID')}`

  return url
}
