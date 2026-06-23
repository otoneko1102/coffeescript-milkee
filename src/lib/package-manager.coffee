fs = require 'fs'
path = require 'path'

SUPPORTED = ['npm', 'pnpm', 'yarn', 'bun', 'aube', 'nub', 'vlt', 'bower']

detectPackageManager = (cwd, config = null) ->
  if config?.milkee?.packageManager
    pm = config.milkee.packageManager
    return pm if pm in SUPPORTED

  pkgPath = path.join cwd, 'package.json'
  if fs.existsSync pkgPath
    try
      pkg = JSON.parse fs.readFileSync pkgPath, 'utf-8'
      if pkg.packageManager
        name = pkg.packageManager.split('@')[0].trim()
        return name if name in SUPPORTED
    catch

  return 'pnpm' if fs.existsSync path.join cwd, 'pnpm-lock.yaml'
  return 'yarn' if fs.existsSync path.join cwd, 'yarn.lock'
  if (
    fs.existsSync(path.join cwd, 'bun.lockb') or
    fs.existsSync(path.join cwd, 'bun.lock')
  )
    return 'bun'
  return 'vlt' if fs.existsSync path.join cwd, 'vlt-lock.json'
  return 'bower' if fs.existsSync path.join cwd, 'bower.json'
  'npm'

getInstallCommand = (pm, packages, dev = false, global = false) ->
  switch pm
    when 'pnpm'
      flag = if global then ' -g' else if dev then ' -D' else ''
      "pnpm add#{flag} #{packages}"
    when 'yarn'
      if global
        "yarn global add #{packages}"
      else
        flag = if dev then ' -D' else ''
        "yarn add#{flag} #{packages}"
    when 'bun'
      flag = if global then ' -g' else if dev then ' -D' else ''
      "bun add#{flag} #{packages}"
    when 'aube'
      flag = if global then ' -g' else if dev then ' -D' else ''
      "aube add#{flag} #{packages}"
    when 'nub'
      if global
        "npm i -g #{packages}"
      else
        flag = if dev then ' -D' else ''
        "nub add#{flag} #{packages}"
    when 'vlt'
      if global
        "npm i -g #{packages}"
      else
        flag = if dev then ' --save-dev' else ''
        "vlt install#{flag} #{packages}"
    when 'bower'
      if global
        "npm i -g #{packages}"
      else
        flag = if dev then ' --save-dev' else ' --save'
        "bower install #{packages}#{flag}"
    else
      if global
        "npm i -g #{packages}"
      else
        flag = if dev then ' -D' else ''
        "npm install#{flag} #{packages}"

getInitCommand = (pm) ->
  switch pm
    when 'pnpm' then 'pnpm init'
    when 'yarn' then 'yarn init'
    when 'bun' then 'bun init'
    when 'aube' then 'aube init'
    when 'nub' then 'nub install'
    when 'vlt' then 'vlt init'
    when 'bower' then 'bower init'
    else 'npm init'

getRunCommand = (pm, script) ->
  switch pm
    when 'pnpm' then "pnpm #{script}"
    when 'yarn' then "yarn #{script}"
    when 'bun' then "bun run #{script}"
    when 'aube' then "aube run #{script}"
    when 'nub' then "nub run #{script}"
    when 'vlt' then "vlt run #{script}"
    when 'bower' then "npm run #{script}"
    else "npm run #{script}"

getInstallFrozenCommand = (pm) ->
  switch pm
    when 'pnpm' then 'pnpm install --frozen-lockfile'
    when 'yarn' then 'yarn install --frozen-lockfile'
    when 'bun' then 'bun install'
    when 'aube' then 'aube install --frozen-lockfile'
    when 'nub' then 'nub ci'
    when 'vlt' then 'vlt install --frozen-lockfile'
    else 'npm ci'

# Returns an extra YAML step block (with leading newline) for CI setup, or empty string.
getCiSetupStep = (pm) ->
  switch pm
    when 'pnpm'
      """

      - name: Setup pnpm
        uses: pnpm/action-setup@v4
        with:
          run_install: false"""
    when 'bun'
      """

      - name: Setup Bun
        uses: oven-sh/setup-bun@v2"""
    else ''

module.exports = {
  SUPPORTED
  detectPackageManager
  getInstallCommand
  getInitCommand
  getRunCommand
  getInstallFrozenCommand
  getCiSetupStep
}
