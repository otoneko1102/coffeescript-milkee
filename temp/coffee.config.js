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
  options: {
    // Join all scripts into a single file.
    // join: false,

    // Add a header to the top of the compiled JavaScript.
    // header: false,

    // Compile without the top-level function wrapper.
    // bare: true
  }
};
