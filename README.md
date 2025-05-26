# GGWebView - Biblioteca D para Webview

`ggwebview` é uma biblioteca D que fornece bindings de alto nível para a biblioteca C/C++ [webview](https://github.com/webview/webview). O objetivo é oferecer uma API D idiomática, segura e fácil de usar, simplificando a criação de interfaces gráficas de usuário multiplataforma usando tecnologias web (HTML, CSS, JavaScript).

Esta biblioteca empacota binários pré-compilados da `webview` C/C++ para Linux (x86_64) e Windows (x86, x86_64), eliminando a necessidade do usuário final compilar código C/C++ diretamente.

## Funcionalidades

*   API D orientada a objetos e fácil de usar.
*   Bindings para as principais funcionalidades da `webview`, incluindo:
    *   Criação e gerenciamento de janelas.
    *   Navegação e carregamento de HTML/URLs.
    *   Execução de JavaScript a partir do D.
    *   Binding de funções D para serem chamadas a partir do JavaScript (comunicação bidirecional).
    *   Despacho de funções para execução na thread da UI.
*   Tratamento de erros com exceções D.
*   Simplificação do processo de build através de bibliotecas C/C++ pré-compiladas.

## Licença

`ggwebview` é distribuída sob a licença MIT, assim como a biblioteca `webview` original. Veja o arquivo `LICENSE` para mais detalhes.

## Instalação

Adicione `ggwebview` como uma dependência ao seu arquivo `dub.json` ou `dub.sdl`:

**dub.json:**
```json
"dependencies": {
    "ggwebview": "~>0.1.0" // Use a versão mais recente
}
```

**dub.sdl:**
```sdl
dependency "ggwebview" version="~>0.1.0" // Use a versão mais recente
```

## Dependências de Sistema

Você precisará instalar as dependências de sistema da `webview` para a sua plataforma.

### Linux

Requer GTK3 e WebKitGTK (versão 4.0 ou 4.1 são comumente usadas com `webview`).
Por exemplo, em sistemas baseados em Debian/Ubuntu:

*   **Para WebKitGTK 4.1 (GTK3, libsoup3):**
    ```bash
    sudo apt install libgtk-3-dev libwebkit2gtk-4.1-dev
    ```
*   **Para WebKitGTK 4.0 (GTK3, libsoup2):**
    ```bash
    sudo apt install libgtk-3-dev libwebkit2gtk-4.0-dev
    ```

Consulte o [README da webview original](https://github.com/webview/webview#linux-and-bsd) para mais detalhes e pacotes para outras distribuições.

### Windows

Requer o [WebView2 runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/) instalado. Se não estiver presente (comum em versões do Windows anteriores ao Windows 11), o usuário da sua aplicação precisará instalá-lo.

### macOS (Não focado inicialmente, mas para referência futura)

Requer Cocoa e WebKit (geralmente já presentes no sistema).

## Exemplos de Uso

A biblioteca `ggwebview` vem com vários exemplos localizados em `source/examples/`. Para compilar e executar qualquer um deles, navegue até o diretório raiz do pacote `ggwebview` e use o DUB, especificando a configuração do exemplo.

**Exemplo 1: Aplicação Básica (`example_basic`)**

Este é um exemplo introdutório que demonstra:
*   Criação de uma janela de webview.
*   Definição de título e tamanho.
*   Binding de uma função D simples para ser chamada pelo JavaScript.
*   Carregamento de HTML embutido.

**Código-fonte:** [`source/examples/basic_app.d`](source/examples/basic_app.d:1)

**Para executar:**
```bash
dub run --config=example_basic
```

**Exemplo 2: Carregando Arquivos Locais (`example_local_files`)**

Este exemplo mostra como carregar uma página HTML que referencia arquivos CSS e JavaScript externos, todos localizados no sistema de arquivos local.

*   Cria uma webview.
*   Navega para um arquivo `index.html` local usando uma URL `file://`.
*   O `index.html` carrega um `style.css` e um `script.js`.

**Códigos-fonte:**
*   Aplicação D: [`source/examples/local_files_app.d`](source/examples/local_files_app.d:1)
*   HTML: [`source/examples/local_files/index.html`](source/examples/local_files/index.html:1)
*   CSS: [`source/examples/local_files/style.css`](source/examples/local_files/style.css:1)
*   JS: [`source/examples/local_files/script.js`](source/examples/local_files/script.js:1)

**Para executar:**
```bash
dub run --config=example_local_files
```

**Exemplo 3: Carregando URL Remota (`example_remote_url`)**

Demonstra como carregar o conteúdo de uma URL externa na webview.

*   Cria uma webview.
*   Navega para uma URL como `https://www.google.com`.

**Código-fonte:** [`source/examples/remote_url_app.d`](source/examples/remote_url_app.d:1)

**Para executar:**
```bash
dub run --config=example_remote_url
```

**Exemplo 4: Comunicação Detalhada entre Processos (IPC - `example_ipc_detailed`)**

Este exemplo aprofunda a comunicação bidirecional (IPC) entre o código D e o JavaScript executado na webview.

*   **JS chamando D:**
    *   Funções D são expostas ao JavaScript usando `wv.bind()`.
    *   JavaScript pode chamar essas funções D, passando argumentos (serializados como JSON).
    *   Funções D podem retornar valores (ou erros) para o JavaScript (também como JSON).
*   **D chamando JS:**
    *   `wv.evalScript()`: Executa uma string de código JavaScript no contexto da página atual. Útil para chamadas diretas ou scripts curtos.
    *   `wv.dispatch()`: Enfileira uma função D para ser executada na thread principal da UI. Dentro desta função, você pode chamar `wv.evalScript()` com segurança para interagir com o DOM ou executar JS. Isso é crucial para atualizar a UI a partir de threads de background.

**Código-fonte:** [`source/examples/ipc_detailed_app.d`](source/examples/ipc_detailed_app.d:1)

**Para executar:**
```bash
dub run --config=example_ipc_detailed
```

## Conceitos Chave (Demonstrados nos Exemplos)

### 1. Criação e Configuração da WebView
```d
import ggwebview.webview;

// Habilitar modo debug (ferramentas de desenvolvedor) se desejado
auto wv = new WebView(true); 

wv.setTitle("Minha Aplicação");
wv.setSize(800, 600); // Largura, Altura
```
A classe `WebView` é o ponto central. O construtor aceita um booleano para habilitar o modo de depuração.

### 2. Carregando Conteúdo Web

*   **HTML Embutido:**
    ```d
    wv.setHtml("<h1>Olá Mundo!</h1>");
    ```
*   **URL Local (Arquivo):**
    ```d
    // Supondo que htmlFilePath é o caminho para seu index.html
    string htmlFileUri = "file://" ~ absolutePath(htmlFilePath);
    wv.navigate(htmlFileUri);
    ```
    (Veja [`local_files_app.d`](source/examples/local_files_app.d:1) para um exemplo completo de construção de caminho).
*   **URL Remota:**
    ```d
    wv.navigate("https://example.com");
    ```

### 3. Comunicação JavaScript -> D (`bind`)

Você pode expor funções D para serem chamadas pelo JavaScript.

**No D:**
```d
// Função de callback
void minhaFuncaoD(string seq, string req, WebView instance) {
    import std.stdio : writeln;
    import std.json : parseJSON, JSONValue;
    
    writeln("minhaFuncaoD chamada do JS!");
    writeln("  Seq: ", seq); // ID da chamada, usado para wv.webviewReturn
    writeln("  Req: ", req); // Argumentos do JS como string JSON

    try {
        JSONValue jsonData = parseJSON(req);
        // Processar jsonData.array[0], jsonData.array[1], etc.
        string arg1 = jsonData.array[0].str;
        
        // Retornar sucesso e um resultado JSON
        instance.webviewReturn(seq, true, `{"status": "Sucesso", "d_processed": "` ~ arg1.toUpper() ~ `"}`);
    } catch (Exception e) {
        // Retornar falha e um erro JSON
        instance.webviewReturn(seq, false, `{"error": "Erro no D: ` ~ e.msg ~ `"}`);
    }
}

// No seu main, após criar wv:
import ggwebview.webview : BindCallback; // Importar o tipo do delegate
BindCallback dgMinhaFuncao = &minhaFuncaoD;
wv.bind("nomeDaFuncaoNoJs", dgMinhaFuncao);
```

**No JavaScript:**
```html
<script>
    async function chamarD() {
        try {
            // 'nomeDaFuncaoNoJs' é o mesmo nome usado no wv.bind()
            const resultado = await window.nomeDaFuncaoNoJs("Argumento1", 42);
            console.log("D retornou:", resultado); 
            // resultado será o objeto JSON: {"status": "Sucesso", "d_processed": "ARGUMENTO1"}
        } catch (erro) {
            console.error("Erro ao chamar D:", erro);
            // erro será o objeto JSON: {"error": "..."}
        }
    }
</script>
<button onclick="chamarD()">Chamar Função D</button>
```
O nome da função exposta (`"nomeDaFuncaoNoJs"`) fica disponível globalmente no objeto `window` do JavaScript. As chamadas são assíncronas e retornam Promises.

### 4. Comunicação D -> JavaScript (`evalScript` e `dispatch`)

*   **`evalScript`:** Executa JavaScript diretamente.
    ```d
    wv.evalScript("document.body.style.backgroundColor = 'red';");
    wv.evalScript("minhaFuncaoJs('Olá do D!', 123);"); 
    ```
*   **`dispatch`:** Para executar código (incluindo `evalScript`) a partir de uma thread que não seja a principal da UI (por exemplo, uma thread de background que realiza trabalho e precisa atualizar a interface).
    ```d
    import core.thread : Thread;
    import core.time : seconds;

    new Thread(() {
        Thread.sleep(2.seconds); // Simula trabalho
        string mensagem = "Atualização da Thread!";
        
        // Importante: wv.dispatch para interagir com a UI
        if (!wv.isDisposed) { // Verificar se a webview ainda existe
            wv.dispatch(() {
                try {
                    wv.evalScript("console.log('Mensagem da thread D: " ~ mensagem ~ "');");
                    wv.evalScript("document.getElementById('status').innerText = '" ~ mensagem ~ "';");
                } catch (Exception e) {
                    // Tratar erros se a webview for fechada enquanto a thread executa
                    import std.stdio;
                    stderr.writeln("Erro no dispatch: ", e.msg);
                }
            });
        }
    }).start();
    ```

### 5. Loop Principal e Finalização

*   **`wv.run()`:** Inicia o loop de eventos da webview. Esta chamada é bloqueante e só retorna quando a janela é fechada.
*   **`wv.terminate()`:** Pode ser usado para fechar programaticamente a webview.
*   **`wv.dispose()`:** Libera explicitamente os recursos da webview. É bom chamar em um bloco `finally` ou quando você tem certeza que a webview não será mais usada. O destrutor da classe `WebView` também chama `dispose()`.

```d
// ... configuração ...
try {
    wv.run();
} finally {
    if (wv !is null && !wv.isDisposed) {
        wv.dispose();
    }
}
```

## Referência da API D

(A ser gerada/adicionada. Use `dub build -c library --build=ddox` para gerar documentação se os comentários DDoc estiverem presentes no código).

## TODO

*   Testes mais abrangentes.
*   Melhorar a documentação da API com DDoc.
*   Fornecer binários pré-compilados para macOS (se desejado no futuro).