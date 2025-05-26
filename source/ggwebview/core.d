module ggwebview.core;

import ggwebview.types; // Importa os tipos definidos anteriormente

extern (C)
{
    // Funções da API webview.h

    webview_t webview_create(int isDebug, void* window);
    webview_error_t webview_destroy(webview_t w);
    webview_error_t webview_run(webview_t w);
    webview_error_t webview_terminate(webview_t w);

    // Ponteiro de função para webview_dispatch
    alias extern(C) void function(webview_t w, void* arg) webview_dispatch_fn_t;
    webview_error_t webview_dispatch(webview_t w, webview_dispatch_fn_t fn, void* arg);

    void* webview_get_window(webview_t w);
    void* webview_get_native_handle(webview_t w, webview_native_handle_kind_t kind);
    webview_error_t webview_set_title(webview_t w, const(char)* title);
    webview_error_t webview_set_size(webview_t w, int width, int height, webview_hint_t hints);
    webview_error_t webview_navigate(webview_t w, const(char)* url);
    webview_error_t webview_set_html(webview_t w, const(char)* html);
    webview_error_t webview_init(webview_t w, const(char)* js);
    webview_error_t webview_eval(webview_t w, const(char)* js);

    // Ponteiro de função para webview_bind
    alias extern(C) void function(const(char)* seq, const(char)* req, void* arg) webview_bind_fn_t;
    webview_error_t webview_bind(webview_t w, const(char)* name, webview_bind_fn_t fn, void* arg);

    webview_error_t webview_unbind(webview_t w, const(char)* name);
    webview_error_t webview_return(webview_t w, const(char)* seq, int status, const(char)* result);

    // Função de versão
    const(webview_version_info_t)* webview_version();
}