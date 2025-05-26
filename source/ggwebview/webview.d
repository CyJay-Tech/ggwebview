module ggwebview.webview;

import ggwebview.core;
public import ggwebview.types;
import ggwebview.exception;
import std.string : toStringz, fromStringz;
import std.conv : to;
import core.stdc.stdlib : calloc, free, malloc;
import core.memory : GC; 
import std.container; 
import std.algorithm : filter; 
import std.array : array; 


// --- Contexto e Trampolim para Dispatch ---
private struct DispatchContext {
    void delegate() dg;
    void delegate(WebView) dgWithWebView;
    WebView webViewInstance;
}

extern (C) private void dispatchTrampoline(webview_t w_c, void* arg) {
    DispatchContext* ctx = cast(DispatchContext*)arg;
    try {
        if (ctx.dg !is null) {
            ctx.dg();
        } else if (ctx.dgWithWebView !is null && ctx.webViewInstance !is null) {
            ctx.dgWithWebView(ctx.webViewInstance);
        }
    } catch (Throwable t) {
        import std.stdio;
        stderr.writeln("Exceção no callback de dispatch: ", t.toString());
    } finally {
        free(ctx);
    }
}

// --- Contexto e Trampolim para Bind ---
public alias BindCallback = void delegate(string seq, string req, WebView webView); // Tornado público

private struct BindContext {
    BindCallback dg;
    WebView webViewInstance;
}

extern (C) private void bindTrampoline(const(char)* seq_c, const(char)* req_c, void* arg) {
    BindContext* ctx = cast(BindContext*)arg;
    if (ctx is null || ctx.dg is null || ctx.webViewInstance is null) {
        import std.stdio;
        stderr.writeln("Erro crítico: Contexto de bind inválido no trampolim.");
        return;
    }

    string seq = to!string(fromStringz(seq_c));
    string req = to!string(fromStringz(req_c));

    try {
        ctx.dg(seq, req, ctx.webViewInstance);
    } catch (Throwable t) {
        import std.stdio;
        stderr.writeln("Exceção no callback de bind '", seq, "': ", t.toString());
        if (ctx.webViewInstance !is null && !ctx.webViewInstance.isDisposed() && ctx.webViewInstance.nativeHandleRaw !is null) {
            string errorJson = `{"error":"Exception in D callback"}`; 
            webview_return(ctx.webViewInstance.nativeHandleRaw, seq_c, 1, errorJson.toStringz());
        }
    }
}

class WebView
{
private:
    webview_t _w;
    bool _ownsWindow;
    BindContext*[string] _bindContexts; 
    string[] _activeBindNames; 
    bool _isDisposed = false;

public:
    this(bool isDebug = false, void* windowHandle = null)
    {
        this._w = webview_create(isDebug ? 1 : 0, windowHandle);
        if (this._w is null)
        {
            throw new WebViewException("Falha ao criar a instância da webview.");
        }
        this._ownsWindow = (windowHandle is null);
        this._activeBindNames = []; 
    }

    ~this()
    {
        this.dispose();
    }

    public void dispose()
    {
        if (_isDisposed) return;

        if (_activeBindNames !is null) {
            string[] namesToProcess;
            if (_activeBindNames.length > 0) { 
                try {
                    namesToProcess = _activeBindNames.dup;
                } catch (Error e) { 
                    import std.stdio;
                    stderr.writeln("Falha crítica ao duplicar _activeBindNames no dispose: ", e.toString());
                    namesToProcess = null; 
                }
            }

            if (namesToProcess !is null) {
                foreach (name; namesToProcess) {
                    if (name in _bindContexts) { 
                        BindContext* ctx = _bindContexts[name];
                        if (this._w !is null) { 
                            webview_unbind(this._w, name.toStringz()); 
                        }
                        free(ctx); 
                        _bindContexts.remove(name); 
                    }
                }
            }
        }
        _activeBindNames = null; 

        if (this._w !is null)
        {
            webview_destroy(this._w);
            this._w = null; 
        }

        _isDisposed = true;
    }
    
    public bool isDisposed() const @property {
        return _isDisposed;
    }

    void run()
    {
        if (this.isDisposed) throw new ObjectDestroyedError("WebView instance has been disposed.");
        checkError(webview_run(this._w), "Erro ao executar o loop principal da webview");
    }

    void terminate()
    {
        if (this.isDisposed) return; 
        if (this._w !is null) {
            checkError(webview_terminate(this._w), "Erro ao terminar a webview");
        }
    }

    void dispatch(void delegate() dg)
    {
        if (this.isDisposed) throw new ObjectDestroyedError("WebView instance has been disposed.");
        DispatchContext* ctx = cast(DispatchContext*)malloc(DispatchContext.sizeof);
        if (ctx is null) {
            throw new WebViewException("Falha ao alocar contexto para dispatch.");
        }
        ctx.dg = dg;
        ctx.dgWithWebView = null;
        ctx.webViewInstance = null;

        webview_error_t err = webview_dispatch(this._w, &dispatchTrampoline, cast(void*)ctx);
        if (err != webview_error_t.WEBVIEW_ERROR_OK) {
            free(ctx);
            checkError(err, "Erro ao despachar função para o loop da webview");
        }
    }

    void dispatch(void delegate(WebView) dgWithWebView)
    {
        if (this.isDisposed) throw new ObjectDestroyedError("WebView instance has been disposed.");
        DispatchContext* ctx = cast(DispatchContext*)malloc(DispatchContext.sizeof);
        if (ctx is null) {
            throw new WebViewException("Falha ao alocar contexto para dispatch.");
        }
        ctx.dg = null;
        ctx.dgWithWebView = dgWithWebView;
        ctx.webViewInstance = this;

        webview_error_t err = webview_dispatch(this._w, &dispatchTrampoline, cast(void*)ctx);
        if (err != webview_error_t.WEBVIEW_ERROR_OK) {
            free(ctx);
            checkError(err, "Erro ao despachar função (com WebView) para o loop da webview");
        }
    }

    void bind(string name, BindCallback callback)
    {
        if (this.isDisposed) throw new ObjectDestroyedError("WebView instance has been disposed.");
        string nameKey = name.idup; 

        if (nameKey in _bindContexts) {
            throw new WebViewException("Binding com o nome '" ~ nameKey ~ "' já existe.");
        }

        BindContext* ctx = cast(BindContext*)malloc(BindContext.sizeof);
        if (ctx is null) {
            throw new WebViewException("Falha ao alocar contexto para bind.");
        }
        ctx.dg = callback;
        ctx.webViewInstance = this;

        webview_error_t err = webview_bind(this._w, nameKey.toStringz(), &bindTrampoline, cast(void*)ctx);
        
        if (err != webview_error_t.WEBVIEW_ERROR_OK) {
            free(ctx); 
            checkError(err, "Erro ao fazer bind da função '" ~ nameKey ~ "'");
        } else {
            _bindContexts[nameKey] = ctx; 
            _activeBindNames ~= nameKey; 
        }
    }

    void unbind(string name)
    {
        if (this.isDisposed) return; 

        string nameKey = name.idup; 
        if (nameKey !in _bindContexts) {
            if (!this.isDisposed) {
                throw new WebViewException("Binding com o nome '" ~ nameKey ~ "' não encontrado para unbind.");
            }
            return; 
        }

        if (this._w !is null) {
            webview_unbind(this._w, nameKey.toStringz());
        }
        
        BindContext* ctx = _bindContexts[nameKey];
        _bindContexts.remove(nameKey);
        free(ctx); 

        if (_activeBindNames !is null) { 
            _activeBindNames = _activeBindNames.filter!(a => a != nameKey).array;
        }
    }

    void webviewReturn(string seq, bool success, string resultJson) {
        if (this.isDisposed || this._w is null) return;
        const(char)* cSeq = seq.toStringz();
        const(char)* cResult = resultJson.toStringz();
        int status = success ? 0 : 1; 

        webview_return(this._w, cSeq, status, cResult);
    }


    void setTitle(string title)
    {
        if (this.isDisposed || this._w is null) return;
        const(char)* cTitle = title.toStringz();
        checkError(webview_set_title(this._w, cTitle), "Erro ao definir o título da webview");
    }

    void setSize(int width, int height, webview_hint_t hint = webview_hint_t.WEBVIEW_HINT_NONE)
    {
        if (this.isDisposed || this._w is null) return;
        checkError(webview_set_size(this._w, width, height, hint), "Erro ao definir o tamanho da webview");
    }

    void navigate(string url)
    {
        if (this.isDisposed || this._w is null) return;
        const(char)* cUrl = url.toStringz();
        checkError(webview_navigate(this._w, cUrl), "Erro ao navegar na webview");
    }

    void setHtml(string html)
    {
        if (this.isDisposed || this._w is null) return;
        const(char)* cHtml = html.toStringz();
        checkError(webview_set_html(this._w, cHtml), "Erro ao definir HTML na webview");
    }

    void initScript(string js)
    {
        if (this.isDisposed || this._w is null) return;
        const(char)* cJs = js.toStringz();
        checkError(webview_init(this._w, cJs), "Erro ao injetar script de inicialização");
    }

    void evalScript(string js)
    {
        if (this.isDisposed || this._w is null) return;
        const(char)* cJs = js.toStringz();
        checkError(webview_eval(this._w, cJs), "Erro ao avaliar script na webview");
    }

    void* getWindowHandle()
    {
        if (this.isDisposed || this._w is null) return null;
        return webview_get_window(this._w);
    }
    
    void* getNativeHandle(webview_native_handle_kind_t kind)
    {
        if (this.isDisposed || this._w is null) return null;
        return webview_get_native_handle(this._w, kind);
    }
    
    @property webview_t nativeHandleRaw() { 
        if (this.isDisposed) return null;
        return _w; 
    }

}

private void checkError(webview_error_t err, string messagePrefix)
{
    if (err != webview_error_t.WEBVIEW_ERROR_OK)
    {
        throw new WebViewException(messagePrefix ~ " (código: " ~ to!string(err) ~ ")");
    }
}