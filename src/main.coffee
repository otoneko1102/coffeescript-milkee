yargs = require 'yargs'
{ hideBin } = require 'yargs/helpers'
consola = require 'consola'
fs = require 'fs'
path = require 'path'
{ exec } = require 'child_process'

pkg = require '../package.json'
CWD = process.cwd()
CONFIG_FILE = 'coffee.config.js'
CONFIG_PATH = path.join CWD, CONFIG_FILE

# async
setup = () ->
  pstat = "created"
  stat = "create"
  if fs.existsSync CONFIG_PATH
    consola.warn "`#{CONFIG_FILE}` already exists in this directory."
    check = await consola.prompt "Do you want to reset `coffee.config.js`?", type: "confirm"
    if check isnt true
      consola.info "Cancelled."
      return
    else
      fs.rmSync CONFIG_PATH, recursive: true, force: true
      pstat = "reset"
      stat = "reset"

  try
    TEMPLATE_PATH = path.join __dirname, '..', 'temp', 'coffee.config.js'
    CONFIG_TEMPLATE = fs.readFileSync TEMPLATE_PATH, 'utf-8'
    fs.writeFileSync CONFIG_PATH, CONFIG_TEMPLATE
    consola.success "Successfully #{pstat} `#{CONFIG_FILE}`!"
  catch error
    consola.error "Failed to #{stat} `#{CONFIG_FILE}`:", error
    consola.info "Template file may be missing from the package installation at `#{TEMPLATE_PATH}`"

compile = () ->
  unless fs.existsSync CONFIG_PATH
    consola.error "`#{CONFIG_FILE}` not found in this directory: #{CWD}"
    consola.info 'Please run `milkee --setup` to create a configuration file.'
    process.exit 1

  try
    config = require CONFIG_PATH

    unless config.entry and config.output
      consola.error '`entry` and `output` properties are required in your configuration.'
      process.exit 1

    options = config.options or {}
    milkee = config.milkee or {}
    milkeeOptions = config.milkee.options or {}
    commandParts = ['coffee']

    if options.join
      commandParts.push '--join'
      commandParts.push "\"#{config.output}\""
    else
      commandParts.push '--output'
      commandParts.push "\"#{config.output}\""

    otherOptionStrings = []

    if milkeeOptions.refresh
      targetDir = path.join CWD, config.output
      unless fs.existsSync targetDir
        consola.info "Refresh skipped."
      else
        consola.info "Executing: Refresh"

        # Refresh
        items = fs.readdirSync targetDir
        for item in items
          itemPath = path.join targetDir, item
          fs.rmSync itemPath, recursive: true, force: true
        consola.success "Refreshed!"

    if options.bare
      otherOptionStrings.push "--bare"
      consola.info "Option `bare` is selected."
    if options.map
      otherOptionStrings.push '--map'
      consola.info "Option `map` is selected."
    if options.inlineMap
      otherOptionStrings.push '--inline-map'
      consola.info "Option `inline-map` is selected."
    if options.noHeader
      otherOptionStrings.push '--no-header'
      consola.info "Option `no-header` is selected."
    if options.transpile
      otherOptionStrings.push '--transpile'
      consola.info "Option `transpile` is selected."
    if options.literate
      otherOptionStrings.push '--literate'
      consola.info "Option `literate` is selected."
    if options.watch
      consola.info "Option `watch` is selected."
      otherOptionStrings.push '--watch'

    if otherOptionStrings.length > 0
        commandParts.push otherOptionStrings.join ' '

    commandParts.push '--compile'
    commandParts.push "\"#{config.entry}\""

    command = commandParts
      .filter Boolean
      .join ' '

    if milkeeOptions.confirm
      toContinue = await consola.prompt "Do you want to continue?"
      if toContinue isnt true
        return

    if options.watch
      consola.start "Watching for changes in `#{config.entry}`..."
    else
      consola.start "Compiling from `#{config.entry}` to `#{config.output}`..."

    consola.info "Executing: #{command}"

    compilerProcess = exec command, (error, stdout, stderr) ->
      unless options.watch
        if error
          consola.error 'Compilation failed:', error
          if stderr then process.stderr.write stderr
          process.exit 1
          return

      consola.success 'Compilation completed successfully!'
      if stdout then process.stdout.write stdout
      if stderr and not error then process.stderr.write stderr

    if options.watch
      compilerProcess.stdout.pipe process.stdout
      compilerProcess.stderr.pipe process.stderr

  catch error
    consola.error 'Failed to load or execute configuration:', error
    process.exit 1

argv = yargs hideBin process.argv
  .scriptName 'milkee'
  .usage '$0 [command]'
  .option 'setup', {
    alias: 's',
    describe: 'Generate a default coffee.config.js',
    type: 'boolean'
  }
  .option 'compile', {
    alias: 'c',
    describe: 'Compile CoffeeScript based on coffee.config.js (default)',
    type: 'boolean'
  }
  .version 'version', pkg.version
  .alias 'v', 'version'
  .help 'help'
  .alias 'h', 'help'
  .argv

if argv.setup
  setup()
else
  compile()
