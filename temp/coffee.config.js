module.exports = {
  // The entry point for compilation.
  // This can be a single file or a directory.
  entry: 'src',
  // The output for the compiled JavaScript files.
  // If 'join' is true, this should be a single file path (e.g., 'dist/app.js').
  // If 'join' is false, this should be a directory (e.g., 'dist').
  output: 'dist',
  // (Optional) Additional options for the CoffeeScript compiler.
  // See `coffee --help` for all available options.
  // Web: https://coffeescript.org/annotated-source/command.html
  options: {
    // The following options are supported:
    // bare: false,
    // join: false,
    // map: false,
    // inlineMap: false,
    // noHeader: false,
    // transpile: false,
    // literate: false,
    // watch: false,
  },
  // (Optional) Additional options/plugins for the Milkee builder.
  milkee: {
    options: {
      // Before compiling, reset the directory.
      // refresh: false,
      // Before compiling, confirm "Do you want to Continue?"
      // confirm: false
    },
    plugins: []
  },
};
