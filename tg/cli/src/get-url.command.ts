import { Command } from 'clipanion'
import { Option } from 'clipanion'

import { getUrl } from './utils'

export class GetUrlCommand extends Command {
  static paths = [['get', 'url']]

  text = Option.String()

  async execute() {
    this.context.stdout.write(getUrl(this.text))
  }
}
