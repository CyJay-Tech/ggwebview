import ggwebview.webview;
import ggwebview.types; // Para webview_hint_t
import ggwebview.exception;
import std.stdio;

void main() {
    bool debugMode = true;
    WebView wv = null;

    try {
        writeln("Criando WebView para carregar URL remota...");
        wv = new WebView(debugMode);

        wv.setTitle("Exemplo com URL Remota");
        wv.setSize(1024, 768, webview_hint_t.WEBVIEW_HINT_NONE);

        string remoteUrl = "https://www.google.com";
        // string remoteUrl = "https://bing.com"; // Alternativa para teste
        // string remoteUrl = "https://duckduckgo.com"; // Alternativa para teste

        writeln("Navegando para: ", remoteUrl);
        wv.navigate(remoteUrl);

        writeln("Iniciando loop da WebView...");
        wv.run();

    } catch (ObjectDestroyedError e) {
        stderr.writeln("Erro: Tentativa de usar WebView após dispose: ", e.msg);
        stderr.writeln(e);
    } catch (WebViewException e) {
        stderr.writeln("Erro na aplicação WebView: ", e.msg);
        stderr.writeln(e);
    } catch (Throwable t) {
        stderr.writeln("Erro inesperado na aplicação: ", t.toString());
        stderr.writeln(t);
    } finally {
        if (wv !is null) {
            writeln("Chamando dispose da WebView...");
            wv.dispose();
        }
        writeln("Loop da WebView terminado. Saindo.");
    }
}