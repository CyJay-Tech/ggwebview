module ggwebview.types;

alias webview_t = void*;

/// Native handle kind. The actual type depends on the backend.
enum webview_native_handle_kind_t
{
    /// Top-level window. @c GtkWindow pointer (GTK), @c NSWindow pointer (Cocoa)
    /// or @c HWND (Win32).
    WEBVIEW_NATIVE_HANDLE_KIND_UI_WINDOW,
    /// Browser widget. @c GtkWidget pointer (GTK), @c NSView pointer (Cocoa) or
    /// @c HWND (Win32).
    WEBVIEW_NATIVE_HANDLE_KIND_UI_WIDGET,
    /// Browser controller. @c WebKitWebView pointer (WebKitGTK), @c WKWebView
    /// pointer (Cocoa/WebKit) or @c ICoreWebView2Controller pointer
    /// (Win32/WebView2).
    WEBVIEW_NATIVE_HANDLE_KIND_BROWSER_CONTROLLER
}

/// Window size hints
enum webview_hint_t
{
    /// Width and height are default size.
    WEBVIEW_HINT_NONE,
    /// Width and height are minimum bounds.
    WEBVIEW_HINT_MIN,
    /// Width and height are maximum bounds.
    WEBVIEW_HINT_MAX,
    /// Window size can not be changed by a user.
    WEBVIEW_HINT_FIXED
}

/// Holds the elements of a MAJOR.MINOR.PATCH version number.
struct webview_version_t
{
    /// Major version.
    uint major;
    /// Minor version.
    uint minor;
    /// Patch version.
    uint patch;
}

/// Holds the library's version information.
struct webview_version_info_t
{
    /// The elements of the version number.
    webview_version_t version_;
    /// SemVer 2.0.0 version number in MAJOR.MINOR.PATCH format.
    char[32] version_number;
    /// SemVer 2.0.0 pre-release labels prefixed with "-" if specified, otherwise
    /// an empty string.
    char[48] pre_release;
    /// SemVer 2.0.0 build metadata prefixed with "+", otherwise an empty string.
    char[48] build_metadata;
}

/**
 * @brief Error codes returned to callers of the API.
 *
 * The following codes are commonly used in the library:
 * - @c WEBVIEW_ERROR_OK
 * - @c WEBVIEW_ERROR_UNSPECIFIED
 * - @c WEBVIEW_ERROR_INVALID_ARGUMENT
 * - @c WEBVIEW_ERROR_INVALID_STATE
 *
 * With the exception of @c WEBVIEW_ERROR_OK which is normally expected,
 * the other common codes do not normally need to be handled specifically.
 * Refer to specific functions regarding handling of other codes.
 */
enum webview_error_t : int
{
    /// Missing dependency.
    WEBVIEW_ERROR_MISSING_DEPENDENCY = -5,
    /// Operation canceled.
    WEBVIEW_ERROR_CANCELED = -4,
    /// Invalid state detected.
    WEBVIEW_ERROR_INVALID_STATE = -3,
    /// One or more invalid arguments have been specified e.g. in a function call.
    WEBVIEW_ERROR_INVALID_ARGUMENT = -2,
    /// An unspecified error occurred. A more specific error code may be needed.
    WEBVIEW_ERROR_UNSPECIFIED = -1,
    /// OK/Success. Functions that return error codes will typically return this
    /// to signify successful operations.
    WEBVIEW_ERROR_OK = 0,
    /// Signifies that something already exists.
    WEBVIEW_ERROR_DUPLICATE = 1,
    /// Signifies that something does not exist.
    WEBVIEW_ERROR_NOT_FOUND = 2
}