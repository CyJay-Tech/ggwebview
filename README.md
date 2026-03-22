# GGWebView - D Library for Webview

[Português](README.pt-BR.md) | **English**

`ggwebview` is a D library that provides high-level bindings for the C/C++ [webview](https://github.com/webview/webview) library. The goal is to offer an idiomatic, safe, and easy-to-use D API, simplifying the creation of cross-platform graphical user interfaces using web technologies (HTML, CSS, JavaScript).

This library packages pre-compiled binaries of the C/C++ `webview` for Linux (x86_64) and Windows (x86, x86_64), eliminating the need for the end user to compile C/C++ code directly.

## Features

- Object-oriented and easy-to-use D API.
- Bindings for the main functionalities of `webview`, including:
  - Window creation and management.
  - Navigation and loading of HTML/URLs.
  - Executing JavaScript from D.
  - Binding D functions to be called from JavaScript (two-way communication).
  - Dispatching functions for execution on the UI thread.
- Error handling with D exceptions.
- Simplification of the build process through pre-compiled C/C++ libraries.

## License

`ggwebview` is distributed under the MIT license, just like the original `webview` library. See the `LICENSE` file for more details.

## Installation

Add `ggwebview` as a dependency to your `dub.json` or `dub.sdl` file:

**dub.json:**

```json
"dependencies": {
    "ggwebview": "~>0.1.0" // Use the latest version
}
```

**dub.sdl:**

```sdl
dependency "ggwebview" version="~>0.1.0" // Use the latest version
```

## System Dependencies

You will need to install the `webview` system dependencies for your platform.

### Linux

Requires GTK3 and WebKitGTK (version 4.0 or 4.1 are commonly used with `webview`).
For example, on Debian/Ubuntu-based systems:

- **For WebKitGTK 4.1 (GTK3, libsoup3):**
  ```bash
  sudo apt install libgtk-3-dev libwebkit2gtk-4.1-dev
  ```
- **For WebKitGTK 4.0 (GTK3, libsoup2):**
  ```bash
  sudo apt install libgtk-3-dev libwebkit2gtk-4.0-dev
  ```

Refer to the [original webview README](https://github.com/webview/webview#linux-and-bsd) for more details and packages for other distributions.

### Windows

Requires the [WebView2 runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/) installed. If not present (common in versions of Windows prior to Windows 11), the user of your application will need to install it.

### macOS (Not initially focused, but for future reference)

Requires Cocoa and WebKit (usually already present on the system).

## Usage Examples

The `ggwebview` library comes with several examples located in `source/examples/`. To compile and run any of them, navigate to the root directory of the `ggwebview` package and use DUB, specifying the example configuration.

**Example 1: Basic Application (`example_basic`)**

This is an introductory example that demonstrates:

- Creating a webview window.
- Setting title and size.
- Binding a simple D function to be called by JavaScript.
- Loading embedded HTML.

**Source code:** [`source/examples/basic_app.d`](source/examples/basic_app.d)

**To run:**

```bash
dub run --config=example_basic
```

**Example 2: Loading Local Files (`example_local_files`)**

This example shows how to load an HTML page that references external CSS and JavaScript files, all located on the local file system.

- Creates a webview.
- Navigates to a local `index.html` file using a `file://` URL.
- The `index.html` loads a `style.css` and a `script.js`.

**Source codes:**

- D Application: [`source/examples/local_files_app.d`](source/examples/local_files_app.d)
- HTML: `source/examples/local_files/index.html`
- CSS: `source/examples/local_files/style.css`
- JS: `source/examples/local_files/script.js`

**To run:**

```bash
dub run --config=example_local_files
```

**Example 3: Loading Remote URL (`example_remote_url`)**

Demonstrates how to load the content of an external URL in the webview.

- Creates a webview.
- Navigates to a URL like `https://www.google.com`.

**Source code:** [`source/examples/remote_url_app.d`](source/examples/remote_url_app.d)

**To run:**

```bash
dub run --config=example_remote_url
```

**Example 4: Detailed Inter-Process Communication (IPC - `example_ipc_detailed`)**

This example delves deeper into the two-way communication (IPC) between D code and JavaScript running in the webview.

- **JS calling D:**
  - D functions are exposed to JavaScript using `wv.bind()`.
  - JavaScript can call these D functions, passing arguments (serialized as JSON).
  - D functions can return values (or errors) to JavaScript (also as JSON).
- **D calling JS:**
  - `wv.evalScript()`: Executes a string of JavaScript code in the current page context. Useful for direct calls or short scripts.
  - `wv.dispatch()`: Enqueues a D function to be executed on the main UI thread. Within this function, you can safely call `wv.evalScript()` to interact with the DOM or execute JS. This is crucial for updating the UI from background threads.

**Source code:** [`source/examples/ipc_detailed_app.d`](source/examples/ipc_detailed_app.d)

**To run:**

```bash
dub run --config=example_ipc_detailed
```

## Key Concepts (Demonstrated in Examples)

### 1. Creating and Configuring the WebView

```d
import ggwebview.webview;

// Enable debug mode (developer tools) if desired
auto wv = new WebView(true);

wv.setTitle("My Application");
wv.setSize(800, 600); // Width, Height
```

The `WebView` class is the central point. The constructor accepts a boolean to enable debug mode.

### 2. Loading Web Content

- **Embedded HTML:**
  ```d
  wv.setHtml("<h1>Hello World!</h1>");
  ```
- **Local URL (File):**
  ```d
  // Assuming htmlFilePath is the path to your index.html
  string htmlFileUri = "file://" ~ absolutePath(htmlFilePath);
  wv.navigate(htmlFileUri);
  ```
  (See [`local_files_app.d`](source/examples/local_files_app.d) for a complete example of path construction).
- **Remote URL:**
  ```d
  wv.navigate("https://example.com");
  ```

### 3. JavaScript -> D Communication (`bind`)

You can expose D functions to be called by JavaScript.

**In D:**

```d
// Callback function
void myDFunction(string seq, string req, WebView instance) {
    import std.stdio : writeln;
    import std.json : parseJSON, JSONValue;

    writeln("myDFunction called from JS!");
    writeln("  Seq: ", seq); // Call ID, used for wv.webviewReturn
    writeln("  Req: ", req); // JS arguments as JSON string

    try {
        JSONValue jsonData = parseJSON(req);
        // Process jsonData.array[0], jsonData.array[1], etc.
        string arg1 = jsonData.array[0].str;

        // Return success and a JSON result
        instance.webviewReturn(seq, true, `{"status": "Success", "d_processed": "` ~ arg1.toUpper() ~ `"}`);
    } catch (Exception e) {
        // Return failure and a JSON error
        instance.webviewReturn(seq, false, `{"error": "Error in D: ` ~ e.msg ~ `"}`);
    }
}

// In your main, after creating wv:
import ggwebview.webview : BindCallback; // Import delegate type
BindCallback dgMyFunction = &myDFunction;
wv.bind("nameOfTheFunctionInJs", dgMyFunction);
```

**In JavaScript:**

```html
<script>
  async function callD() {
    try {
      // 'nameOfTheFunctionInJs' is the same name used in wv.bind()
      const result = await window.nameOfTheFunctionInJs("Argument1", 42);
      console.log("D returned:", result);
      // result will be the JSON object: {"status": "Success", "d_processed": "ARGUMENT1"}
    } catch (error) {
      console.error("Error calling D:", error);
      // error will be the JSON object: {"error": "..."}
    }
  }
</script>
<button onclick="callD()">Call D Function</button>
```

The name of the exposed function (`"nameOfTheFunctionInJs"`) becomes available globally in the JavaScript `window` object. The calls are asynchronous and return Promises.

### 4. D -> JavaScript Communication (`evalScript` and `dispatch`)

- **`evalScript`:** Directly executes JavaScript.
  ```d
  wv.evalScript("document.body.style.backgroundColor = 'red';");
  wv.evalScript("myJsFunction('Hello from D!', 123);");
  ```
- **`dispatch`:** To execute code (including `evalScript`) from a thread other than the main UI thread (e.g., a background thread that performs work and needs to update the interface).

  ```d
  import core.thread : Thread;
  import core.time : seconds;

  new Thread(() {
      Thread.sleep(2.seconds); // Simulate work
      string message = "Thread Update!";

      // Important: wv.dispatch to interact with the UI
      if (!wv.isDisposed) { // Check if webview still exists
          wv.dispatch(() {
              try {
                  wv.evalScript("console.log('Message from thread D: " ~ message ~ "');");
                  wv.evalScript("document.getElementById('status').innerText = '" ~ message ~ "';");
              } catch (Exception e) {
                  // Handle errors if webview is closed while thread runs
                  import std.stdio;
                  stderr.writeln("Error in dispatch: ", e.msg);
              }
          });
      }
  }).start();
  ```

### 5. Main Loop and Termination

- **`wv.run()`:** Starts the webview event loop. This call is blocking and only returns when the window is closed.
- **`wv.terminate()`:** Can be used to programmatically close the webview.
- **`wv.dispose()`:** Explicitly releases webview resources. It's good to call in a `finally` block or when you are certain the webview will no longer be used. The `WebView` class destructor also calls `dispose()`.

```d
// ... configuration ...
try {
    wv.run();
} finally {
    if (wv !is null && !wv.isDisposed) {
        wv.dispose();
    }
}
```

## D API Reference

(To be generated/added. Use `dub build -c library --build=ddox` to generate documentation if DDoc comments are present in the code).

## TODO

- More comprehensive tests.
- Improve API documentation with DDoc.
- Provide pre-compiled binaries for macOS (if desired in the future).
