import ggwebview.webview;
import ggwebview.types; // Para webview_hint_t
import ggwebview.exception; // Para WebViewException
import std.stdio;
import std.json; // Para parsear a requisição do JS no bind

void main() {
    bool debugMode = true; // Ativar ferramentas de desenvolvedor (se suportado)
    WebView wv = null; // Inicializar como null

    try {
        writeln("Criando WebView...");
        wv = new WebView(debugMode);

        wv.setTitle("Exemplo Básico GGWebView");
        wv.setSize(800, 600, webview_hint_t.WEBVIEW_HINT_NONE);

        // Binding de uma função D para JavaScript
        wv.bind("myBoundFunction", (string seq, string req, WebView instance) {
            writeln("Função D 'myBoundFunction' chamada do JS!");
            writeln("  Seq: ", seq);
            writeln("  Req: ", req);

            try {
                JSONValue jsonData = parseJSON(req);
                if (jsonData.type == JSONType.array && jsonData.array.length > 0) {
                    string argFromJs = jsonData.array[0].str;
                    writeln("  Argumento do JS: ", argFromJs);

                    string jsResult = `{"message": "Olá de volta do D!", "received": "` ~ argFromJs ~ `"}`;
                    instance.webviewReturn(seq, true, jsResult);
                } else {
                    instance.webviewReturn(seq, false, `{"error": "Payload inválido do JS"}`);
                }
            } catch (JSONException je) {
                stderr.writeln("Erro ao parsear JSON da requisição JS: ", je.msg);
                instance.webviewReturn(seq, false, `{"error": "Erro ao parsear JSON no D"}`);
            }
        });

        // HTML para carregar
        string htmlContent = `
        <!doctype html>
        <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    body { font-family: sans-serif; background-color: #f0f0f0; color: #333; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; }
                    button { padding: 10px 20px; font-size: 16px; margin: 10px; cursor: pointer; }
                </style>
            </head>
            <body>
                <h1>Olá da GGWebView!</h1>
                <p>Este é um exemplo básico.</p>
                <button onclick="callD()">Chamar Função D</button>
                <!-- <button onclick="evalD()">Avaliar JS do D (após 2s)</button> -->
                <div id="result"></div>
                <script>
                    async function callD() {
                        try {
                            const result = await window.myBoundFunction("Olá da página HTML para D!");
                            console.log("Resultado do D:", result);
                            document.getElementById('result').innerText = 'D retornou: ' + JSON.stringify(result);
                        } catch (e) {
                            console.error("Erro ao chamar myBoundFunction:", e);
                            document.getElementById('result').innerText = 'Erro no D: ' + JSON.stringify(e);
                        }
                    }

                    // Função para o D chamar
                    function calledFromD(message) {
                        console.log("calledFromD recebeu:", message);
                        document.getElementById('result').innerText = 'D chamou JS com: ' + message;
                        return "JS recebeu: " + message;
                    }
                </script>
            </body>
        </html>
        `;
        wv.setHtml(htmlContent);

        import core.thread : Thread;
        import core.time : seconds;

        new Thread(() {
            Thread.sleep(2.seconds);
            if (wv !is null && wv.nativeHandleRaw !is null) { 
                wv.dispatch(() { 
                    try {
                        writeln("Tentando avaliar JS do D...");
                        wv.evalScript(`
                            console.log('JS sendo avaliado pelo D!');
                            document.getElementById('result').innerText = 'JS avaliado pelo D às ' + new Date().toLocaleTimeString();
                            calledFromD('Mensagem enviada pelo D via evalScript!');
                        `);
                        writeln("JS avaliado.");
                    } catch (ObjectDestroyedError e) { // Mais específico primeiro
                        stderr.writeln("Erro ao avaliar JS do D (WebView já disposed): ", e.msg);
                    } catch (WebViewException e) { // Base depois
                        stderr.writeln("Erro ao avaliar JS do D: ", e.msg);
                    }
                });
            }
        }).start();

        writeln("Iniciando loop da WebView...");
        wv.run();

    } catch (ObjectDestroyedError e) { // Mais específico primeiro
        stderr.writeln("Erro: Tentativa de usar WebView após dispose: ", e.msg);
        stderr.writeln(e); 
    } catch (WebViewException e) { // Base depois
        stderr.writeln("Erro na aplicação WebView: ", e.msg);
        stderr.writeln(e); 
    } catch (Throwable t) { // Mais geral por último
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