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

/**
 * Módulo principal para a interface D do webview.
 *
 * Este módulo fornece a classe `WebView` que encapsula a funcionalidade
 * da biblioteca `webview` C, permitindo a criação e manipulação de janelas
 * webview em aplicações D.
 */

// --- Contexto e Trampolim para Dispatch ---

/**
 * Estrutura interna utilizada para passar contextos de callback para a função `webview_dispatch`.
 *
 * Contém os delegates D que serão executados no thread da UI do webview.
 */
private struct DispatchContext {
    /// Delegate sem parâmetros para execução.
    void delegate() dg;
    /// Delegate com um parâmetro `WebView` para execução.
    void delegate(WebView) dgWithWebView;
    /// Instância da `WebView` associada, passada para `dgWithWebView`.
    WebView webViewInstance;
}

/**
 * Função trampolim C para callbacks de dispatch.
 *
 * Esta função é chamada pela biblioteca `webview` quando um evento de dispatch
 * ocorre. Ela recupera o `DispatchContext` passado e executa o delegate D
 * apropriado. Garante que a memória alocada para o contexto seja liberada.
 *
 * Params:
 *   w_c = Ponteiro C para a instância `webview_t`.
 *   arg = Ponteiro `void*` para o `DispatchContext` alocado.
 */
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
        // Sempre libera a memória alocada para o contexto.
        free(ctx);
    }
}

// --- Contexto e Trampolim para Bind ---

/**
 * Alias para o tipo de callback usado em funções `bind`.
 *
 * Este delegate é chamado quando uma função JavaScript vinculada é invocada
 * do lado do webview.
 *
 * Params:
 *   seq = A string de sequência da requisição (usada para retorno).
 *   req = A string JSON da requisição (payload enviado do JS).
 *   webView = A instância da `WebView` que recebeu a chamada.
 */
public alias BindCallback = void delegate(string seq, string req, WebView webView); // Tornado público

/**
 * Estrutura interna utilizada para passar contextos de callback para a função `webview_bind`.
 *
 * Contém o delegate `BindCallback` e a instância `WebView` associada.
 */
private struct BindContext {
    /// O delegate `BindCallback` a ser executado.
    BindCallback dg;
    /// A instância da `WebView` associada a este bind.
    WebView webViewInstance;
}

/**
 * Função trampolim C para callbacks de bind.
 *
 * Esta função é chamada pela biblioteca `webview` quando uma função JavaScript
 * vinculada (via `bind`) é invocada. Ela converte os argumentos C para strings D
 * e invoca o delegate `BindCallback` apropriado. Lida com exceções no callback D
 * e tenta retornar um erro para o JavaScript se a webview ainda for válida.
 *
 * Params:
 *   seq_c = Ponteiro C para a string de sequência da requisição.
 *   req_c = Ponteiro C para a string JSON da requisição.
 *   arg = Ponteiro `void*` para o `BindContext` alocado.
 */
extern (C) private void bindTrampoline(const(char)* seq_c, const(char)* req_c, void* arg) {
    BindContext* ctx = cast(BindContext*)arg;
    if (ctx is null || ctx.dg is null || ctx.webViewInstance is null) {
        import std.stdio;
        stderr.writeln("Erro crítico: Contexto de bind inválido no trampolim.");
        return;
    }

    // Converte strings C para strings D.
    string seq = to!string(fromStringz(seq_c));
    string req = to!string(fromStringz(req_c));

    try {
        ctx.dg(seq, req, ctx.webViewInstance);
    } catch (Throwable t) {
        import std.stdio;
        stderr.writeln("Exceção no callback de bind '", seq, "': ", t.toString());
        // Tenta retornar um erro para o JavaScript se a webview ainda estiver ativa.
        if (ctx.webViewInstance !is null && !ctx.webViewInstance.isDisposed() && ctx.webViewInstance.nativeHandleRaw !is null) {
            string errorJson = `{"error":"Exception in D callback"}`; 
            webview_return(ctx.webViewInstance.nativeHandleRaw, seq_c, 1, errorJson.toStringz());
        }
    }
}

/**
 * Representa uma instância de uma janela WebView.
 *
 * Esta classe encapsula a funcionalidade da biblioteca `webview` C,
 * fornecendo uma interface orientada a objetos para criar, manipular e
 * interagir com uma janela webview.
 */
class WebView
{
private:
    /// O ponteiro opaco para a instância C `webview_t`.
    webview_t _w;
    /// Indica se esta instância `WebView` é proprietária da janela subjacente.
    /// Se `true`, `webview_destroy` liberará a janela.
    bool _ownsWindow;
    /// Um mapa de nomes de bind para seus respectivos contextos.
    /// Usado para gerenciar a memória dos contextos de bind.
    BindContext*[string] _bindContexts; 
    /// Uma lista de nomes de bind ativos, para facilitar a limpeza.
    string[] _activeBindNames; 
    /// Sinalizador que indica se a instância da webview foi descartada.
    bool _isDisposed = false;

public:
    /**
     * Constrói uma nova instância `WebView`.
     *
     * Params:
     *   isDebug = Se `true`, ativa o modo de depuração (por exemplo, dev tools).
     *   windowHandle = Um ponteiro opaco para um handle de janela existente.
     *                  Se `null`, uma nova janela será criada.
     * Throws:
     *   WebViewException se a criação da webview falhar.
     */
    this(bool isDebug = false, void* windowHandle = null)
    {
        this._w = webview_create(isDebug ? 1 : 0, windowHandle);
        if (this._w is null)
        {
            throw new WebViewException("Falha ao criar a instância da webview.");
        }
        this._ownsWindow = (windowHandle is null);
        this._activeBindNames = []; 
        this._bindContexts = null; // Inicializa como null, será alocado na primeira inserção.
    }

    /**
     * Destrutor para a classe `WebView`.
     *
     * Garante que os recursos nativos sejam liberados quando o objeto D
     * é coletado pelo coletor de lixo. Chama `dispose()` para a limpeza.
     */
    ~this()
    {
        this.dispose();
    }

    /**
     * Libera explicitamente os recursos nativos associados a esta instância `WebView`.
     *
     * É seguro chamar este método várias vezes. Ele garante que os binds sejam desvinculados
     * e a instância nativa do webview seja destruída.
     */
    public void dispose()
    {
        if (_isDisposed) return;

        // Limpa todos os contextos de bind ativos.
        if (_activeBindNames !is null) {
            string[] namesToProcess;
            if (_activeBindNames.length > 0) { 
                try {
                    // Duplica a lista para evitar modificação durante a iteração.
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
                            // Desvincula a função no lado C.
                            webview_unbind(this._w, name.toStringz()); 
                        }
                        // Libera a memória do contexto de bind.
                        free(ctx); 
                        _bindContexts.remove(name); 
                    }
                }
            }
        }
        _activeBindNames = null; 
        _bindContexts = null; // Garante que o mapa seja limpo.

        // Destrói a instância nativa do webview.
        if (this._w !is null)
        {
            webview_destroy(this._w);
            this._w = null; 
        }

        _isDisposed = true;
    }
    
    /**
     * Obtém um valor que indica se esta instância `WebView` foi descartada.
     *
     * Returns:
     *   `true` se a instância foi descartada, `false` caso contrário.
     */
    public bool isDisposed() const @property {
        return _isDisposed;
    }

    /**
     * Inicia o loop principal da webview.
     *
     * Este método bloqueia o thread atual e executa o loop de eventos da UI
     * da webview.
     * Throws:
     *   ObjectDestroyedError se a instância foi descartada.
     *   WebViewException se ocorrer um erro durante a execução.
     */
    void run()
    {
        if (this.isDisposed) throw new ObjectDestroyedError("WebView instance has been disposed.");
        checkError(webview_run(this._w), "Erro ao executar o loop principal da webview");
    }

    /**
     * Termina o loop principal da webview.
     *
     * Este método sinaliza o loop principal para sair, permitindo que a
     * função `run()` retorne.
     * Throws:
     *   WebViewException se ocorrer um erro ao terminar.
     */
    void terminate()
    {
        if (this.isDisposed) return; // Não lança erro se já descartado, apenas ignora.
        if (this._w !is null) {
            checkError(webview_terminate(this._w), "Erro ao terminar a webview");
        }
    }

    /**
     * Despacha uma função para ser executada no thread principal da UI da webview.
     *
     * Este método permite que você execute código D com segurança no thread
     * da UI, o que é necessário para interagir com a webview a partir de outros threads.
     *
     * Params:
     *   dg = O delegate sem parâmetros a ser executado no thread da UI.
     * Throws:
     *   ObjectDestroyedError se a instância foi descartada.
     *   WebViewException se falhar a alocação de memória ou o dispatch.
     */
    void dispatch(void delegate() dg)
    {
        if (this.isDisposed) throw new ObjectDestroyedError("WebView instance has been disposed.");
        DispatchContext* ctx = cast(DispatchContext*)malloc(DispatchContext.sizeof);
        if (ctx is null) {
            throw new WebViewException("Falha ao alocar contexto para dispatch.");
        }
        ctx.dg = dg;
        ctx.dgWithWebView = null;
        ctx.webViewInstance = null; // Não necessário neste caso.

        webview_error_t err = webview_dispatch(this._w, &dispatchTrampoline, cast(void*)ctx);
        if (err != webview_error_t.WEBVIEW_ERROR_OK) {
            free(ctx); // Libera o contexto em caso de erro de dispatch.
            checkError(err, "Erro ao despachar função para o loop da webview");
        }
    }

    /**
     * Despacha uma função para ser executada no thread principal da UI da webview,
     * passando a própria instância `WebView` como argumento.
     *
     * Útil para delegates que precisam interagir com a instância da webview.
     *
     * Params:
     *   dgWithWebView = O delegate com um parâmetro `WebView` a ser executado no thread da UI.
     * Throws:
     *   ObjectDestroyedError se a instância foi descartada.
     *   WebViewException se falhar a alocação de memória ou o dispatch.
     */
    void dispatch(void delegate(WebView) dgWithWebView)
    {
        if (this.isDisposed) throw new ObjectDestroyedError("WebView instance has been disposed.");
        DispatchContext* ctx = cast(DispatchContext*)malloc(DispatchContext.sizeof);
        if (ctx is null) {
            throw new WebViewException("Falha ao alocar contexto para dispatch.");
        }
        ctx.dg = null;
        ctx.dgWithWebView = dgWithWebView;
        ctx.webViewInstance = this; // Passa a instância atual.

        webview_error_t err = webview_dispatch(this._w, &dispatchTrampoline, cast(void*)ctx);
        if (err != webview_error_t.WEBVIEW_ERROR_OK) {
            free(ctx); // Libera o contexto em caso de erro de dispatch.
            checkError(err, "Erro ao despachar função (com WebView) para o loop da webview");
        }
    }

    /**
     * Vincula uma função D a um nome JavaScript, tornando-a acessível do lado do webview.
     *
     * A função JavaScript pode ser invocada usando `window.external.invoke(name, requestJson)`.
     * O `callback` D receberá a string de sequência e a string JSON da requisição.
     *
     * Params:
     *   name = O nome da função a ser exposta no JavaScript.
     *   callback = O delegate `BindCallback` a ser invocado quando a função JavaScript for chamada.
     * Throws:
     *   ObjectDestroyedError se a instância foi descartada.
     *   WebViewException se o nome do bind já existir ou se ocorrer um erro na vinculação.
     */
    void bind(string name, BindCallback callback)
    {
        if (this.isDisposed) throw new ObjectDestroyedError("WebView instance has been disposed.");
        string nameKey = name.idup; // Duplica a string para garantir que a chave persista.

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
            free(ctx); // Libera o contexto em caso de erro de bind.
            checkError(err, "Erro ao fazer bind da função '" ~ nameKey ~ "'");
        } else {
            _bindContexts[nameKey] = ctx; // Armazena o contexto para gerenciamento de memória.
            _activeBindNames ~= nameKey; // Adiciona o nome à lista de binds ativos.
        }
    }

    /**
     * Desvincula uma função JavaScript previamente vinculada.
     *
     * Libera os recursos associados ao bind e remove a função do escopo JavaScript.
     *
     * Params:
     *   name = O nome da função a ser desvinculada.
     * Throws:
     *   WebViewException se o nome do bind não for encontrado e a webview não estiver descartada.
     */
    void unbind(string name)
    {
        if (this.isDisposed) return; // Não lança erro se já descartado, apenas ignora.

        string nameKey = name.idup; 
        if (nameKey !in _bindContexts) {
            if (!this.isDisposed) { // Só lança se a webview ainda estiver ativa.
                throw new WebViewException("Binding com o nome '" ~ nameKey ~ "' não encontrado para unbind.");
            }
            return; 
        }

        if (this._w !is null) {
            webview_unbind(this._w, nameKey.toStringz());
        }
        
        BindContext* ctx = _bindContexts[nameKey];
        _bindContexts.remove(nameKey); // Remove do mapa.
        free(ctx); // Libera a memória do contexto.

        if (_activeBindNames !is null) { 
            // Remove o nome da lista de binds ativos.
            _activeBindNames = _activeBindNames.filter!(a => a != nameKey).array;
        }
    }

    /**
     * Retorna um valor para uma chamada JavaScript vinculada (bind).
     *
     * Este método é usado para responder a chamadas JavaScript feitas via `window.external.invoke`.
     *
     * Params:
     *   seq = A string de sequência recebida no callback de bind.
     *   success = `true` para indicar sucesso, `false` para indicar falha.
     *   resultJson = A string JSON contendo o resultado ou uma mensagem de erro.
     */
    void webviewReturn(string seq, bool success, string resultJson) {
        if (this.isDisposed || this._w is null) return;
        const(char)* cSeq = seq.toStringz();
        const(char)* cResult = resultJson.toStringz();
        int status = success ? 0 : 1; 

        webview_return(this._w, cSeq, status, cResult);
    }

    /**
     * Define o título da janela da webview.
     *
     * Params:
     *   title = A nova string de título.
     * Throws:
     *   WebViewException se ocorrer um erro ao definir o título.
     */
    void setTitle(string title)
    {
        if (this.isDisposed || this._w is null) return;
        const(char)* cTitle = title.toStringz();
        checkError(webview_set_title(this._w, cTitle), "Erro ao definir o título da webview");
    }

    /**
     * Define o tamanho da janela da webview.
     *
     * Params:
     *   width = A nova largura da janela.
     *   height = A nova altura da janela.
     *   hint = Uma dica sobre como o tamanho deve ser tratado (redimensionável, fixo, etc.).
     * Throws:
     *   WebViewException se ocorrer um erro ao definir o tamanho.
     */
    void setSize(int width, int height, webview_hint_t hint = webview_hint_t.WEBVIEW_HINT_NONE)
    {
        if (this.isDisposed || this._w is null) return;
        checkError(webview_set_size(this._w, width, height, hint), "Erro ao definir o tamanho da webview");
    }

    /**
     * Navega a webview para uma URL especificada.
     *
     * Params:
     *   url = A URL para onde navegar. Pode ser um caminho de arquivo local ou uma URL web.
     * Throws:
     *   WebViewException se ocorrer um erro durante a navegação.
     */
    void navigate(string url)
    {
        if (this.isDisposed || this._w is null) return;
        const(char)* cUrl = url.toStringz();
        checkError(webview_navigate(this._w, cUrl), "Erro ao navegar na webview");
    }

    /**
     * Define o conteúdo HTML da webview diretamente.
     *
     * Params:
     *   html = A string contendo o HTML a ser exibido.
     * Throws:
     *   WebViewException se ocorrer um erro ao definir o HTML.
     */
    void setHtml(string html)
    {
        if (this.isDisposed || this._w is null) return;
        const(char)* cHtml = html.toStringz();
        checkError(webview_set_html(this._w, cHtml), "Erro ao definir HTML na webview");
    }

    /**
     * Injeta um script JavaScript que será executado assim que o conteúdo
     * da página for carregado.
     *
     * Este script é executado antes de qualquer script da própria página.
     *
     * Params:
     *   js = A string contendo o código JavaScript a ser injetado.
     * Throws:
     *   WebViewException se ocorrer um erro ao injetar o script.
     */
    void initScript(string js)
    {
        if (this.isDisposed || this._w is null) return;
        const(char)* cJs = js.toStringz();
        checkError(webview_init(this._w, cJs), "Erro ao injetar script de inicialização");
    }

    /**
     * Avalia um script JavaScript no contexto da página atual da webview.
     *
     * Params:
     *   js = A string contendo o código JavaScript a ser avaliado.
     * Throws:
     *   WebViewException se ocorrer um erro ao avaliar o script.
     */
    void evalScript(string js)
    {
        if (this.isDisposed || this._w is null) return;
        const(char)* cJs = js.toStringz();
        checkError(webview_eval(this._w, cJs), "Erro ao avaliar script na webview");
    }

    /**
     * Obtém o handle nativo da janela associada à webview.
     *
     * O tipo exato do handle depende do backend da webview (por exemplo, `HWND` no Windows,
     * `NSWindow*` no macOS, `GtkWidget*` no Linux).
     *
     * Returns:
     *   Um ponteiro `void*` para o handle da janela, ou `null` se a webview for descartada.
     */
    void* getWindowHandle()
    {
        if (this.isDisposed || this._w is null) return null;
        return webview_get_window(this._w);
    }
    
    /**
     * Obtém um handle nativo específico do controle da webview.
     *
     * Permite acessar componentes internos do controle da webview (por exemplo, `WKWebView` no macOS,
     * `GtkWebKitWebView` no Linux).
     *
     * Params:
     *   kind = O tipo de handle nativo a ser recuperado.
     * Returns:
     *   Um ponteiro `void*` para o handle nativo, ou `null` se a webview for descartada
     *   ou o tipo de handle não for suportado.
     */
    void* getNativeHandle(webview_native_handle_kind_t kind)
    {
        if (this.isDisposed || this._w is null) return null;
        return webview_get_native_handle(this._w, kind);
    }
    
    /**
     * Obtém o ponteiro opaco bruto para a instância `webview_t` C.
     *
     * Isso deve ser usado com cautela e apenas se você precisar interagir
     * diretamente com a API C de baixo nível.
     *
     * Returns:
     *   O ponteiro `webview_t` ou `null` se a instância foi descartada.
     */
    @property webview_t nativeHandleRaw() { 
        if (this.isDisposed) return null;
        return _w; 
    }

}

/**
 * Função utilitária para verificar e lançar exceções com base em códigos de erro da webview.
 *
 * Params:
 *   err = O código de erro retornado por uma função `webview_`.
 *   messagePrefix = Uma string de prefixo para a mensagem da exceção.
 * Throws:
 *   WebViewException se o `err` não for `WEBVIEW_ERROR_OK`.
 */
private void checkError(webview_error_t err, string messagePrefix)
{
    if (err != webview_error_t.WEBVIEW_ERROR_OK)
    {
        throw new WebViewException(messagePrefix ~ " (código: " ~ to!string(err) ~ ")");
    }
}