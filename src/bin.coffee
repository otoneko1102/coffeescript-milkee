#!/usr/bin/env node

yargs = require 'yargs'
{ hideBin } = require 'yargs/helpers'
consola = require 'consola'
fs = require 'fs'
path = require 'path'
{ exec } = require 'child_process'

pkg = require '../package.json'
CWD = process.cwd()
CONFIG_FILE = 'coffee.config.js'
CONFIG_PATH = path.join(CWD, CONFIG_FILE)

TEMPLATE_PATH = path.join(__dirname, '..', 'temp', 'coffee.config.js')

setup = () ->
  if fs.existsSync(CONFIG_PATH)
    consola.warn "`#{CONFIG_FILE}` already exists in this directory."
    return

  try
    fs.writeFileSync(CONFIG_PATH, CONFIG_TEMPLATE)
    consola.success "Successfully created `#{CONFIG_FILE}`."
  catch error
    consola.error "Failed to create `#{CONFIG_FILE}`:", error

compile = async () ->
  unless fs.existsSync(CONFIG_PATH)
    consola.error "`#{CONFIG_FILE}` not found."
    consola.info 'Please run `milkee --setup` to create a configuration file.'
    process.exit(1)

  try
    configPathUrl = path.toFileUrl(CONFIG_PATH).href
    { default: config } = await import(configPathUrl)

    unless config.entry and config.output
      consola.error '`entry` and `output` properties are required in your configuration.'
      process.exit(1)

    options = config.options or {}
    commandParts = ['coffee']

    if options.join
      commandParts.push('--join')
      commandParts.push("\"#{config.output}\"")
    else
      commandParts.push('--output')
      commandParts.push("\"#{config.output}\"")

    delete options.join

    otherOptionStrings = []
    for key, value of options
      if value is true
        otherOptionStrings.push("--#{key}")
      else if value isnt false
        otherOptionStrings.push("--#{key} \"#{value}\"")

    if otherOptionStrings.length > 0
        commandParts.push(otherOptionStrings.join(' '))

    commandParts.push('--compile')
    commandParts.push("\"#{config.entry}\"")

    command = commandParts.filter(Boolean).join(' ')

    consola.start "Compiling from `#{config.entry}` to `#{config.output}`..."
    consola.info "Executing: #{command}"

    exec command, (error, stdout, stderr) ->
      if error
        consola.error 'Compilation failed:', error
        if stderr then process.stderr.write stderr
        process.exit(1)
        return

      consola.success 'Compilation completed successfully!'
      if stdout then process.stdout.write stdout
      if stderr then process.stderr.write stderr

  catch error
    consola.error 'Failed to load or execute configuration:', error
    process.exit(1)

argv = yargs(hideBin(process.argv))
  .scriptName('milkee')
  .usage('$0 [command]')
  .option('setup', {
    alias: 's',
    describe: 'Generate a default coffee.config.js',
    type: 'boolean'
  })
  .option('compile', {
    alias: 'c',
    describe: 'Compile CoffeeScript based on coffee.config.js (default)',
    type: 'boolean'
  })
  .version('version', pkg.version)
  .alias('v', 'version')
  .help('help')
  .alias('h', 'help')
  .argv

if argv.setup
  setup()
else
  compile()
