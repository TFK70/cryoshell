const { readFileSync, writeFileSync } = require('fs')
const { join } = require('path')

const bundle = readFileSync(join(__dirname, '../dist/index.js'))

writeFileSync(join(__dirname, '../bundles/tg'), `#!/usr/bin/env node\n\n${bundle}`)
