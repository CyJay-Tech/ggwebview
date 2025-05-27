# Introdução ao GGWebView

O **GGWebView** é uma biblioteca para a linguagem D que permite criar aplicações desktop com interfaces gráficas baseadas em tecnologias web (HTML, CSS, JavaScript), utilizando o componente WebView de forma simples e poderosa.

## Recursos principais

- Criação de janelas nativas com conteúdo web.
- Carregamento de HTML local ou remoto.
- Comunicação bidirecional entre D e JavaScript (binding de funções).
- Execução de scripts JavaScript a partir do D.
- Suporte a múltiplas plataformas.

## Fluxo básico de uso

1. Crie uma instância de `WebView`.
2. Defina título, tamanho e conteúdo (HTML ou URL).
3. Faça o binding de funções D para o JavaScript.
4. Execute scripts JS a partir do D, se necessário.
5. Inicie o loop da WebView com `run()`.

## Exemplo mínimo

```d
import ggwebview.webview;

void main() {
    auto wv = new WebView(true); // true = modo debug
    wv.setTitle("Minha App GGWebView");
    wv.setSize(800, 600);
    wv.setHtml("<h1>Olá, GGWebView!</h1>");
    wv.run();
    wv.dispose();
}
```

Veja exemplos completos em [`source/examples/basic_app.d`](source/examples/basic_app.d).