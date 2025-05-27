# Comunicação Entre Processos

A comunicação entre D e JavaScript no GGWebView é feita via binding de funções e execução de scripts.

## Do JavaScript para o D

O D expõe funções usando `wv.bind`. O JS pode chamar essas funções como promessas:

```js
const result = await window.myBoundFunction("mensagem do JS");
```

No D, a função recebe os argumentos, processa e responde usando `webviewReturn`.

## Do D para o JavaScript

O D pode executar scripts JS a qualquer momento:

```d
wv.evalScript("calledFromD('Mensagem do D!');");
```

## Exemplo de ciclo completo

1. JS chama função D via binding.
2. D processa e responde.
3. D pode também disparar funções JS via `evalScript`.

Veja exemplos detalhados em [`source/examples/basic_app.d`](source/examples/basic_app.d).