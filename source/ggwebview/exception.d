module ggwebview.exception;

import std.exception;

class WebViewException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

class ObjectDestroyedError : WebViewException // Pode herdar de WebViewException ou diretamente de Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

// Poderíamos adicionar exceções mais específicas que herdem de WebViewException
// à medida que identificamos diferentes tipos de erro da API C.
// Ex: WebViewCreationException, WebViewBindingException, etc.