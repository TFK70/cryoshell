import { Command } from 'clipanion'
import { Option } from 'clipanion'
import fetch from 'node-fetch'

import { getUrl } from './utils'

export class SendCommand extends Command {
  static paths = [['send']]

  text = Option.String()

  async execute() {
    const res = await fetch(getUrl(this.text))

    this.context.stdout.write(`Sent ${this.text}`)
  }
}
