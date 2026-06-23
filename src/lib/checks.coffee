fs = require 'fs'
path = require 'path'
{ exec } = require 'child_process'
consola = require 'consola'
{ isPackageLatest } = require 'is-package-latest'

{ pkg, CWD } = require './constants'
{ detectPackageManager, getInstallCommand } = require './package-manager'

# async
checkLatest = ->
  try
    res = await isPackageLatest pkg
    if res.success and not res.isLatest
      pm = detectPackageManager CWD
      globalCmd = getInstallCommand pm, 'milkee@latest', false, true
      localCmd = getInstallCommand pm, 'milkee@latest', true, false
      consola.box
        title: 'A new version is now available!'
        message: "#{res.currentVersion} --> `#{
          res.latestVersion
        }`\n\n# global installation\n`#{globalCmd}`\n# or local installation\n`#{localCmd}`"
      return true
    else
      return false
  catch
    return false

checkCoffee = ->
  PKG_PATH = path.join CWD, 'package.json'
  if fs.existsSync PKG_PATH
    try
      pkgFile = fs.readFileSync PKG_PATH, 'utf-8'
      pkgData = JSON.parse pkgFile
      if (
        pkgData.dependencies?.coffeescript or
        pkgData.devDependencies?.coffeescript
      )
        return
    catch error
      consola.warn "Could not parse `package.json`: #{error.message}"

  exec 'coffee --version', (error) ->
    if error
      pm = detectPackageManager CWD
      installCmd = getInstallCommand pm, 'coffeescript', true
      consola.warn(
        'CoffeeScript is not found in local dependencies (`dependencies`, `devDependencies`) or globally.'
      )
      consola.info(
        "Please install it via `#{installCmd}` to continue."
      )

module.exports = {
  checkLatest
  checkCoffee
}
