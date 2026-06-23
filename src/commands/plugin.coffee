fs = require 'fs'
path = require 'path'
{ execSync } = require 'child_process'
consola = require 'consola'

{ CWD, CONFIG_FILE } = require '../lib/constants'
{ detectPackageManager, getInstallCommand, getInitCommand, getRunCommand, getInstallFrozenCommand, getCiSetupStep } = require '../lib/package-manager'
confirmContinue = require '../options/confirm'

TEMPLATE_DIR = path.join __dirname, '..', '..', 'temp', 'plugin'
DOCS_DIR = path.join __dirname, '..', '..', 'docs'

TEMPLATES = [
  src: 'main.coffee', dest: 'src/main.coffee'
,
  src: 'coffee.config.cjs', dest: CONFIG_FILE
,
  src: 'publish.yml', dest: '.github/workflows/publish.yml'
,
  src: '_gitignore', dest: '.gitignore'
,
  src: '_gitattributes', dest: '.gitattributes'
,
  src: '_npmignore', dest: '.npmignore'
]

DOCS = [
  src: 'PLUGIN.md', dest: 'docs/PLUGIN.md'
,
  src: 'PLUGIN-ja.md', dest: 'docs/PLUGIN-ja.md'
]

# Create directory if not exists
ensureDir = (filePath) ->
  dir = path.dirname filePath
  unless fs.existsSync dir
    fs.mkdirSync dir, recursive: true

# Copy template file
copyTemplate = (src, dest, replacements = {}) ->
  srcPath = path.join TEMPLATE_DIR, src
  destPath = path.join CWD, dest

  unless fs.existsSync srcPath
    consola.error "Template file not found: #{srcPath}"
    return false

  ensureDir destPath
  content = fs.readFileSync srcPath, 'utf-8'
  for key, value of replacements
    content = content.replace new RegExp("\\{\\{#{key}\\}\\}", 'g'), value
  fs.writeFileSync destPath, content
  consola.success "Created `#{dest}`"
  return true

# Copy docs file
copyDocs = (src, dest) ->
  srcPath = path.join DOCS_DIR, src
  destPath = path.join CWD, dest

  unless fs.existsSync srcPath
    consola.error "Docs file not found: #{srcPath}"
    return false

  ensureDir destPath
  content = fs.readFileSync srcPath, 'utf-8'
  fs.writeFileSync destPath, content
  consola.success "Created `#{dest}`"
  return true

PLUGIN_KEYWORDS = [
  'milkee'
  'coffeescript'
  'coffee'
  'plugin'
  'milkee-plugin'
]

# Update package.json
updatePackageJson = ->
  pkgPath = path.join CWD, 'package.json'

  try
    pkg = JSON.parse fs.readFileSync pkgPath, 'utf-8'

    # Update main
    pkg.main = 'dist/main.js'

    # Update scripts
    pkg.scripts ?= {}
    pkg.scripts.test ?= 'echo "Error: no test specified" && exit 0'
    pkg.scripts.build = 'milkee'

    # Update keywords
    pkg.keywords ?= []
    for keyword in PLUGIN_KEYWORDS
      unless keyword in pkg.keywords
        pkg.keywords.push keyword

    fs.writeFileSync pkgPath, JSON.stringify(pkg, null, 2) + '\n'
    consola.success 'Updated `package.json`'
    return true
  catch error
    consola.error 'Failed to update package.json:', error
    return false

# Initialize package.json if not exists
initPackageJson = (pm) ->
  pkgPath = path.join CWD, 'package.json'

  unless fs.existsSync pkgPath
    consola.start 'Initializing package.json...'
    try
      execSync getInitCommand(pm), cwd: CWD, stdio: 'inherit'
      consola.success 'Created `package.json`'
    catch error
      consola.error 'Failed to create package.json:', error
      return false
  return true

# Generate README.md
generateReadme = (pm) ->
  pkgPath = path.join CWD, 'package.json'
  readmePath = path.join CWD, 'README.md'
  templatePath = path.join TEMPLATE_DIR, 'README.md'

  try
    unless fs.existsSync templatePath
      consola.error "Template file not found: #{templatePath}"
      return false

    pkg = JSON.parse fs.readFileSync pkgPath, 'utf-8'
    name = pkg.name or 'your-plugin-name'
    description = pkg.description or 'A Milkee plugin.'

    readme = fs.readFileSync templatePath, 'utf-8'
    readme = readme.replace /\{\{name\}\}/g, name
    readme = readme.replace /\{\{description\}\}/g, description

    fs.writeFileSync readmePath, readme
    consola.success 'Created `README.md`'
    return true
  catch error
    consola.error 'Failed to create README.md:', error
    return false

# Main plugin setup function
plugin = ->
  pm = detectPackageManager CWD
  consola.box 'Milkee Plugin Setup'
  consola.info 'This will set up your project as a Milkee plugin.'
  consola.info ''
  consola.info 'The following actions will be performed:'
  pkgPath = path.join CWD, 'package.json'
  unless fs.existsSync pkgPath
    consola.info "  0. Initialize package.json (#{getInitCommand pm})"
  consola.info '  1. Install dependencies (consola, coffeescript, milkee)'
  consola.info '  2. Create template files:'
  for template in TEMPLATES
    consola.info "     - #{template.dest}"
  consola.info '  3. Copy docs:'
  for doc in DOCS
    consola.info "     - #{doc.dest}"
  consola.info '  4. Update package.json (main, scripts, keywords)'
  consola.info '  5. Generate README.md'
  consola.info ''

  # Confirm before proceeding
  confirmed = await confirmContinue()
  unless confirmed
    return

  consola.info ''

  # Initialize package.json if not exists
  unless initPackageJson(pm)
    return

  # Install dependencies
  try
    consola.start 'Installing dependencies...'
    execSync getInstallCommand(pm, 'consola'), cwd: CWD, stdio: 'inherit'
    execSync getInstallCommand(pm, 'coffeescript milkee', true), cwd: CWD, stdio: 'inherit'
    consola.success 'Dependencies installed!'
  catch error
    consola.error 'Failed to install dependencies:', error
    return

  consola.info ''

  # Create template files
  consola.start 'Creating template files...'
  for template in TEMPLATES
    destPath = path.join CWD, template.dest
    if fs.existsSync destPath
      overwrite =
        await consola.prompt "#{template.dest} already exists. Overwrite?",
          type: 'confirm'
      unless overwrite
        consola.info "Skipped `#{template.dest}`"
        continue
    replacements = switch template.src
      when 'coffee.config.cjs'
        { packageManager: pm }
      when 'publish.yml'
        {
          setupPmStep: getCiSetupStep pm
          installFrozen: getInstallFrozenCommand pm
          runBuild: getRunCommand pm, 'build'
          runTest: getRunCommand pm, 'test'
        }
      else {}
    copyTemplate template.src, template.dest, replacements

  consola.info ''

  # Copy docs
  consola.start 'Copying docs...'
  for doc in DOCS
    destPath = path.join CWD, doc.dest
    if fs.existsSync destPath
      overwrite =
        await consola.prompt "#{doc.dest} already exists. Overwrite?",
          type: 'confirm'
      unless overwrite
        consola.info "Skipped `#{doc.dest}`"
        continue
    copyDocs doc.src, doc.dest

  consola.info ''

  # Update package.json
  consola.start 'Updating package.json...'
  updatePackageJson()

  consola.info ''

  # Generate README.md
  readmePath = path.join CWD, 'README.md'
  if fs.existsSync readmePath
    overwrite =
      await consola.prompt 'README.md already exists. Overwrite?',
        type: 'confirm'
    if overwrite
      generateReadme(pm)
    else
      consola.info 'Skipped `README.md`'
  else
    generateReadme(pm)

  consola.info ''
  consola.success 'Milkee plugin setup complete!'
  consola.info ''
  consola.info 'Next steps:'
  consola.info '  1. Edit `src/main.coffee` to implement your plugin'
  consola.info "  2. Run `#{getRunCommand pm, 'build'}` to compile"
  consola.info '  3. Test your plugin locally'

module.exports = plugin
