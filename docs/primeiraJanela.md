# Criando sua Primeira Janela

Veja como criar uma janela básica com GGWebView, carregar HTML e interagir com o JavaScript.

## Passos principais

1. Importe o módulo principal:
    ```d
    import ggwebview.webview;
    ```
2. Crie a instância da WebView:
    ```d
    auto wv = new WebView(true); // true ativa modo debug
    ```
3. Configure título e tamanho:
    ```d
    wv.setTitle("Minha Primeira Janela");
    wv.setSize(800, 600);
    ```
4. Carregue o HTML:
    ```d
    wv.setHtml("<h1>Bem-vindo ao GGWebView!</h1>");
    ```
5. Inicie o loop principal:
    ```d
    wv.run();
    wv.dispose();
    ```

## Exemplo completo

Veja um exemplo mais avançado em [`source/examples/basic_app.d`](source/examples/basic_app.d), incluindo binding de funções D para o JS e execução de scripts JavaScript a partir do D.