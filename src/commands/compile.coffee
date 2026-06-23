fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
{ spawn, exec } = require 'child_process'
consola = require 'consola'

{ CWD, CONFIG_PATH, CONFIG_FILE } = require '../lib/constants'
{ checkLatest, checkCoffee } = require '../lib/checks'
{ runPlugins } = require '../lib/plugins'
{ detectPackageManager, getInstallCommand } = require '../lib/package-manager'
confirmContinue = require '../options/confirm'
{ executeRefresh, restoreBackups, clearBackups } = require '../options/refresh'
executeCopy = require '../options/copy'

# async
checkVersion = (config) ->
  cl = await checkLatest()
  if cl
    pm = detectPackageManager CWD, config
    globalCmd = getInstallCommand pm, 'milkee@latest', false, true
    localCmd = getInstallCommand pm, 'milkee@latest', true, false
    action =
      await consola.prompt 'Do you want to update now?',
        type: 'select'
        options: [
          label: 'No (Skip)', value: 'skip', hint: 'Start compiling directly'
        ,
          label: 'Yes (Global)', value: 'global', hint: globalCmd
        ,
          label: 'Yes (Local)', value: 'local', hint: localCmd
        ]
    if action and action isnt 'skip'
      installCmd = if action is 'global' then globalCmd else localCmd
      consola.start 'Updating milkee...'
      await new Promise (resolve) ->
        cp = spawn installCmd, shell: true, stdio: 'inherit'
        cp.on 'close', resolve

      consola.success 'Update finished! Please run the command again.'
      process.exit 0
    else if action is 'skip'
      consola.info 'Skipped!'
    else unless action
      process.exit 1

# async
compile = ->
  checkCoffee()
  unless fs.existsSync CONFIG_PATH
    consola.error "`#{CONFIG_FILE}` not found in this directory: #{CWD}"
    consola.info 'Please run `milkee --setup` to create a configuration file.'
    process.exit 1

  try
    config = require CONFIG_PATH

    unless config.entry and config.output
      consola.error(
        '`entry` and `output` properties are required in your configuration.'
      )
      process.exit 1

    options = { ...(config.options or {}) }
    milkee = config.milkee or {}
    milkeeOptions = config.milkee.options or {}

    unless milkeeOptions.ignoreUpdate
      await checkVersion(config)

    execCommandParts = ['coffee']
    if options.join
      execCommandParts.push '--join'
      execCommandParts.push "\"#{config.output}\""
    else
      execCommandParts.push '--output'
      execCommandParts.push "\"#{config.output}\""

    execOtherOptionStrings = []
    if options.bare
      execOtherOptionStrings.push '--bare'
    if options.map
      execOtherOptionStrings.push '--map'
    if options.inlineMap
      execOtherOptionStrings.push '--inline-map'
    if options.noHeader
      execOtherOptionStrings.push '--no-header'
    if options.transpile
      execOtherOptionStrings.push '--transpile'
    if options.literate
      execOtherOptionStrings.push '--literate'

    if execOtherOptionStrings.length > 0
      execCommandParts.push execOtherOptionStrings.join ' '

    execCommandParts.push '--compile'
    execCommandParts.push "\"#{config.entry}\""

    execCommand = execCommandParts.filter(Boolean).join ' '

    spawnArgs = []
    if options.join
      spawnArgs.push '--join'
      spawnArgs.push config.output
    else
      spawnArgs.push '--output'
      spawnArgs.push config.output

    if options.bare
      spawnArgs.push '--bare'
    if options.map
      spawnArgs.push '--map'
    if options.inlineMap
      spawnArgs.push '--inline-map'
    if options.noHeader
      spawnArgs.push '--no-header'
    if options.transpile
      spawnArgs.push '--transpile'
    if options.literate
      spawnArgs.push '--literate'
    if options.watch
      spawnArgs.push '--watch'

    spawnArgs.push '--compile'
    spawnArgs.push config.entry

    summary = []
    summary.push "Entry: `#{config.entry}`"
    summary.push "Output: `#{config.output}`"
    enabledOptions = Object.keys(options).filter (key) -> options[key]
    if enabledOptions.length > 0
      enabledOptionsList = enabledOptions.join ','
      summary.push "Options: #{enabledOptionsList}"

    consola.box title: 'Milkee Compilation Summary', message: summary.join '\n'

    if milkeeOptions.confirm
      toContinue = await confirmContinue()
      unless toContinue
        return

    delete options.join

    backupFiles = []

    if milkeeOptions.refresh
      try
        await executeRefresh config, backupFiles
      catch error
        restoreBackups backupFiles
        process.exit 1

    if options.watch
      consola.start "Watching for changes in `#{config.entry}`..."
      consola.info "Executing: coffee #{spawnArgs.join ' '}"

      if milkeeOptions.refresh
        consola.warn(
          'Refresh backup is disabled in watch mode (backups are cleared immediately).'
        )
        clearBackups backupFiles

      compilerProcess = spawn 'coffee', spawnArgs, shell: true

      debounceTimeout = null
      lastError = null

      compilerProcess.stderr.on 'data', (data) ->
        errorMsg = data.toString().trim()
        if errorMsg
          consola.error errorMsg
          lastError = errorMsg

      compilerProcess.stdout.on 'data', (data) ->
        stdoutMsg = data.toString().trim()
        if stdoutMsg
          consola.log stdoutMsg

        debounceTimeout = null
        lastError = null

        if debounceTimeout
          clearTimeout debounceTimeout

        debounceTimeout = setTimeout(
          ->
            if milkeeOptions.copy
              try
                await executeCopy config
              catch error
                consola.error 'Failed to copy non-coffee files'
            if lastError
              consola.warn 'Compilation failed, plugins skipped.'
            else
              consola.success 'Compilation successful (watch mode).'
              runPlugins(
                config
                { ...(config.options or {}) }
                '(watch mode)'
                ''
              )

            lastError = null
        ,
          100
        )

      compilerProcess.on 'close', (code) ->
        consola.info "Watch process exited with code #{code}."

      compilerProcess.on 'error', (err) ->
        consola.error 'Failed to start watch process:', err
        process.exit 1
    else
      consola.start "Compiling from `#{config.entry}` to `#{config.output}`..."
      consola.info "Executing: #{execCommand}"

      compilerProcess = exec execCommand, (error, stdout, stderr) ->
        if error
          consola.error 'Compilation failed:', error
          if stderr then consola.error stderr.toString().trim()
          if milkeeOptions.refresh then restoreBackups backupFiles
          process.exit 1
          return

        if stdout then process.stdout.write stdout
        if stderr and not error then process.stderr.write stderr

        setTimeout(
          ->
            if milkeeOptions.refresh
              clearBackups backupFiles
              consola.success 'Backup clearing completed!'

            if milkeeOptions.copy
              try
                await executeCopy config
              catch error
                consola.error 'Failed to copy non-coffee files'
                process.exit 1
                return

            consola.success 'Compilation completed successfully!'

            # Run plugins after all milkee.options are completed
            runPlugins config, { ...(config.options or {}) }, stdout, stderr
        ,
          500
        )

  catch error
    consola.error 'Failed to load or execute configuration:', error
    process.exit 1

module.exports = compile
