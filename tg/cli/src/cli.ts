import { Cli }           from 'clipanion'

import { GetUrlCommand } from './get-url.command'
import { SendCommand }   from './send.command'

const cli = new Cli({
  binaryLabel: `Telegram cli`,
  binaryName: `tg`,
  binaryVersion: `0.0.0`,
})

cli.register(GetUrlCommand)
cli.register(SendCommand)

cli.runExit(process.argv.slice(2), {
  cwd: process.cwd(),
})
