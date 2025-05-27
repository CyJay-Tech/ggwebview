# Processo de Renderização (Render Process)

O processo de renderização corresponde ao código JavaScript/HTML executado dentro da WebView.

## Comunicação com o D

- O JS pode chamar funções D que foram expostas via `wv.bind`.
- O D pode executar scripts JS usando `evalScript`.

## Exemplo de chamada do JS para o D

```js
// Supondo que 'myBoundFunction' foi bindada no D
async function callD() {
    const result = await window.myBoundFunction("Mensagem do JS para o D!");
    console.log("Resposta do D:", result);
}
```

## Exemplo de função chamada pelo D

```js
function calledFromD(message) {
    console.log("Recebido do D:", message);
    return "JS recebeu: " + message;
}
```

Veja exemplos de HTML e JS em [`source/examples/basic_app.d`](source/examples/basic_app.d).