import fetch       from 'node-fetch'
import { Command } from 'clipanion'
import { Option }  from 'clipanion'

import { getUrl }  from './utils'

export class SendCommand extends Command {
  static paths = [['send']]

  text = Option.String()

  async execute() {
    await fetch(getUrl(this.text))

    this.context.stdout.write(`Sent ${this.text}`)
  }
}
