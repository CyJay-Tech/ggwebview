import ggwebview.webview; 
import ggwebview.types;
import ggwebview.exception;
import std.stdio;
import std.json;
import std.conv : to;
import core.thread : Thread;
import core.time : seconds;
import std.string : toUpper;
import std.format : format;

void doubleNumberCallback(string seq, string req, WebView wv) {
    writeln("IPC: doubleNumberCallback chamada do JS.");
    try {
        JSONValue jsonData = parseJSON(req);
        if (jsonData.type == JSONType.array && jsonData.array.length == 1 && jsonData.array[0].type == JSONType.integer) {
            long num = jsonData.array[0].integer;
            long result = num * 2;
            wv.webviewReturn(seq, true, `{"original": ` ~ to!string(num) ~ `, "doubled": ` ~ to!string(result) ~ `}`);
            writeln("  > JS enviou: ", num, ", D retornou: ", result);
        } else {
            wv.webviewReturn(seq, false, `{"error": "Payload inválido: esperado um array com um número."}`);
        }
    } catch (JSONException e) {
        wv.webviewReturn(seq, false, `{"error": "Erro ao parsear JSON no D: ` ~ e.msg ~ `"}`);
    }
}

void toUpperCaseCallback(string seq, string req, WebView wv) {
    writeln("IPC: toUpperCaseCallback chamada do JS.");
    try {
        JSONValue jsonData = parseJSON(req);
        if (jsonData.type == JSONType.array && jsonData.array.length == 1 && jsonData.array[0].type == JSONType.string) {
            string str = jsonData.array[0].str;
            string result = str.toUpper();
            wv.webviewReturn(seq, true, `{"original": "` ~ str ~ `", "upper": "` ~ result ~ `"}`);
            writeln("  > JS enviou: '", str, "', D retornou: '", result, "'");
        } else {
            wv.webviewReturn(seq, false, `{"error": "Payload inválido: esperado um array com uma string."}`);
        }
    } catch (JSONException e) {
        wv.webviewReturn(seq, false, `{"error": "Erro ao parsear JSON no D: ` ~ e.msg ~ `"}`);
    }
}

void logFromJsCallback(string seq, string req, WebView wv) {
    writeln("IPC: logFromJsCallback chamada do JS. Payload: ", req);
    wv.webviewReturn(seq, true, `{"status": "Log recebido no D com sucesso!"}`);
}


void main() {
    bool debugMode = true;
    WebView wv = null;

    try {
        writeln("Criando WebView para exemplo de IPC detalhado...");
        wv = new WebView(debugMode);
        wv.setTitle("Exemplo Detalhado de IPC");
        wv.setSize(900, 700, webview_hint_t.WEBVIEW_HINT_NONE);

        // Bind das funções D - usando literais de função para criar delegates
        BindCallback doubleNumberDg = (string seq, string req, WebView webview) { doubleNumberCallback(seq, req, webview); };
        BindCallback toUpperCaseDg = (string seq, string req, WebView webview) { toUpperCaseCallback(seq, req, webview); };
        BindCallback logFromJsDg = (string seq, string req, WebView webview) { logFromJsCallback(seq, req, webview); };

        wv.bind("doubleNumberD", doubleNumberDg);
        wv.bind("toUpperCaseD", toUpperCaseDg);
        wv.bind("logFromJsD", logFromJsDg);

        string htmlContent = `
<!doctype html>
<html>
<head>
    <meta charset="UTF-8">
    <title>IPC Detalhado</title>
    <style>
        body { font-family: sans-serif; margin: 20px; background-color: #f4f4f4; }
        .container { background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        button { padding: 8px 15px; margin: 5px; cursor: pointer; background-color: #5cb85c; color: white; border: none; border-radius: 4px; }
        button:hover { background-color: #4cae4c; }
        .danger { background-color: #d9534f; } .danger:hover { background-color: #c9302c; }
        #results div { border: 1px solid #ddd; padding: 10px; margin-top: 10px; background-color: #f9f9f9; border-radius: 4px; }
        input[type="text"], input[type="number"] { padding: 8px; margin-right: 10px; border: 1px solid #ccc; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Teste de Comunicação D <-> JS</h1>
        
        <h2>JS para D</h2>
        <div>
            <input type="number" id="numInput" value="10">
            <button onclick="callDoubleNumber()">Dobrar Número (D)</button>
        </div>
        <div>
            <input type="text" id="strInput" value="Olá Mundo">
            <button onclick="callToUpperCase()">Converter para Maiúsculas (D)</button>
        </div>
        <div>
            <button onclick="callLogFromJs()">Enviar Log para D</button>
        </div>

        <h2>D para JS</h2>
        <div>
            <button onclick="triggerDEval()">D Avaliar JS (muda cor de fundo)</button>
            <button onclick="triggerDDispatch()">D Despachar JS (atualiza relógio)</button>
        </div>
        <p>Relógio (atualizado pelo D): <span id="clock">--:--:--</span></p>

        <h2>Resultados</h2>
        <div id="results"></div>
    </div>

    <script>
        const resultsDiv = document.getElementById('results');
        function displayResult(operation, data) {
            const resEl = document.createElement('div');
            resEl.innerHTML = '<strong>' + operation + ':</strong><pre>' + JSON.stringify(data, null, 2) + '</pre>';
            resultsDiv.appendChild(resEl);
        }

        async function callDoubleNumber() {
            const num = parseInt(document.getElementById('numInput').value);
            try {
                const result = await window.doubleNumberD(num);
                displayResult('doubleNumberD', result);
            } catch (e) { displayResult('doubleNumberD ERROR', e); }
        }

        async function callToUpperCase() {
            const str = document.getElementById('strInput').value;
            try {
                const result = await window.toUpperCaseD(str);
                displayResult('toUpperCaseD', result);
            } catch (e) { displayResult('toUpperCaseD ERROR', e); }
        }

        async function callLogFromJs() {
            try {
                const result = await window.logFromJsD("Um log simples do JS", {detail: "mais detalhes"});
                displayResult('logFromJsD', result);
            } catch (e) { displayResult('logFromJsD ERROR', e); }
        }

        function changeBackgroundColor(color) {
            document.body.style.backgroundColor = color;
            console.log('Cor de fundo alterada para: ' + color + ' pelo D.');
            return "Cor de fundo alterada para " + color;
        }

        function updateClock(timeString) {
            document.getElementById('clock').innerText = timeString;
            console.log('Relógio atualizado para: ' + timeString + ' pelo D.');
        }

        async function triggerDEval() {
            console.log("Botão 'D Avaliar JS' clicado. O D deve chamar changeBackgroundColor em breve.");
             try {
                await window.logFromJsD("Botão triggerDEval clicado no JS.");
            } catch (e) { console.error("Erro ao notificar D sobre clique triggerDEval:", e); }
        }
         async function triggerDDispatch() {
            console.log("Botão 'D Despachar JS' clicado. O D deve chamar updateClock em breve.");
             try {
                await window.logFromJsD("Botão triggerDDispatch clicado no JS.");
            } catch (e) { console.error("Erro ao notificar D sobre clique triggerDDispatch:", e); }
        }

    </script>
</body>
</html>`;
        wv.setHtml(htmlContent);

        new Thread(() {
            Thread.sleep(3.seconds);
            if (wv is null || wv.isDisposed) return;
            wv.dispatch(() {
                try {
                    writeln("IPC: D tentando chamar JS changeBackgroundColor via evalScript...");
                    wv.evalScript(`changeBackgroundColor('lightblue');`);
                } catch (ObjectDestroyedError e) {
                    stderr.writeln("IPC eval: WebView já disposed: ", e.msg);
                } catch (WebViewException e) {
                    stderr.writeln("IPC eval: Erro ao avaliar JS: ", e.msg);
                }
            });
        }).start();

        bool stopClock = false;
        new Thread(() {
            while(!stopClock && wv !is null && !wv.isDisposed) {
                Thread.sleep(1.seconds);
                if (wv is null || wv.isDisposed) break;
                
                import std.datetime.systime : Clock;
                import std.datetime.timezone : LocalTime;
                auto currentTime = Clock.currTime(LocalTime());
                
                string timeStr = format("%02d:%02d:%02d", currentTime.hour, currentTime.minute, currentTime.second);

                wv.dispatch(() {
                    try {
                        wv.evalScript(`updateClock('` ~ timeStr ~ `');`);
                    } catch (ObjectDestroyedError e) {
                        stderr.writeln("IPC dispatch: WebView já disposed: ", e.msg);
                        stopClock = true;
                    } catch (WebViewException e) {
                        stderr.writeln("IPC dispatch: Erro ao avaliar JS: ", e.msg);
                    }
                });
            }
            writeln("Thread do relógio terminando.");
        }).start();

        writeln("Iniciando loop da WebView...");
        wv.run();
        stopClock = true; 

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