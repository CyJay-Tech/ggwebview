# Processo Principal (Main Process)

O processo principal é o código D responsável por criar e controlar a janela WebView, além de gerenciar a comunicação com o JavaScript.

## Responsabilidades

- Instanciar e configurar a WebView.
- Carregar HTML ou URL.
- Fazer binding de funções D para o JS.
- Executar scripts JS a partir do D.
- Tratar eventos e ciclo de vida (run/dispose).

## Exemplo de binding

```d
wv.bind("myBoundFunction", (string seq, string req, WebView instance) {
    // Parseia argumentos vindos do JS (em JSON)
    // Retorna resposta para o JS usando instance.webviewReturn
});
```

## Executando scripts JS

```d
wv.evalScript("console.log('Mensagem do D!');");
```

Veja exemplos completos em [`source/examples/basic_app.d`](source/examples/basic_app.d).