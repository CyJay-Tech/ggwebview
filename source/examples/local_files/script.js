document.addEventListener('DOMContentLoaded', function() {
    const messageElement = document.getElementById('message');
    const button = document.getElementById('changeTextButton');

    if (messageElement) {
        messageElement.textContent = 'JavaScript carregado e executado!';
    }

    if (button) {
        button.addEventListener('click', function() {
            if (messageElement) {
                messageElement.textContent = 'O texto foi alterado pelo botão!';
                messageElement.style.color = 'green';
            }
            console.log('Botão clicado, texto alterado.');
        });
    }

    console.log('Script local.js carregado.');
});