import ggwebview.webview;
import ggwebview.types; // Para webview_hint_t
import ggwebview.exception;
import std.stdio;
import std.file : getcwd;
import std.path : buildPath, absolutePath, dirSeparator;
import std.string; // Para o método 'replace'

void main() {
    bool debugMode = true;
    WebView wv = null;

    try {
        writeln("Criando WebView para carregar arquivos locais...");
        wv = new WebView(debugMode);

        wv.setTitle("Exemplo com Arquivos Locais");
        wv.setSize(800, 600, webview_hint_t.WEBVIEW_HINT_NONE);

        // Montar o caminho absoluto para o index.html
        // DUB geralmente executa a partir do diretório raiz do projeto.
        string projectRoot = getcwd();
        string htmlFilePath = buildPath(projectRoot, "source", "examples", "local_files", "index.html");
        
        // Para URLs file://, é melhor usar caminhos absolutos.
        // E garantir que esteja no formato correto para um URI.
        string htmlFileUri = "file://" ~ absolutePath(htmlFilePath);
        
        // Em Windows, absolutePath pode usar '\', mas URIs file:// preferem '/'.
        // webview_navigate deve lidar com isso, mas para garantir:
        if (dirSeparator == "\\") { // Corrigido: Comparar string com string
            htmlFileUri = htmlFileUri.replace("\\", "/"); // Corrigido: replace é de std.string
        }
        
        writeln("Navegando para: ", htmlFileUri);
        wv.navigate(htmlFileUri);

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