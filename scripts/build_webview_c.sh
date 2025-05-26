#!/bin/bash
set -e

# Diretório base do projeto ggwebview (onde este script está em scripts/)
GGWEBVIEW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Diretório da biblioteca webview C/C++ original
WEBVIEW_SRC_DIR="${GGWEBVIEW_DIR}/../webview"
# Diretório para os artefatos pré-compilados dentro de ggwebview
PRECOMPILED_DIR="${GGWEBVIEW_DIR}/precompiled"

echo "Diretório ggwebview: ${GGWEBVIEW_DIR}"
echo "Diretório fonte webview C: ${WEBVIEW_SRC_DIR}"
echo "Diretório precompiled: ${PRECOMPILED_DIR}"

# Limpar diretórios de build anteriores (opcional, mas bom para builds limpas)
rm -rf "${WEBVIEW_SRC_DIR}/build_linux_x86_64"
rm -rf "${WEBVIEW_SRC_DIR}/build_windows_x86"
rm -rf "${WEBVIEW_SRC_DIR}/build_windows_x64"

# --- Compilação para Linux x86_64 ---
echo "Compilando para Linux x86_64..."
BUILD_DIR_LINUX="${WEBVIEW_SRC_DIR}/build_linux_x86_64"
OUTPUT_DIR_LINUX="${PRECOMPILED_DIR}/linux-x86_64"
mkdir -p "${BUILD_DIR_LINUX}"
mkdir -p "${OUTPUT_DIR_LINUX}"

cmake -S "${WEBVIEW_SRC_DIR}" -B "${BUILD_DIR_LINUX}" \
    -D CMAKE_BUILD_TYPE=Release \
    -D WEBVIEW_BUILD_STATIC_LIBRARY=ON \
    -D WEBVIEW_BUILD_SHARED_LIBRARY=OFF \
    -D WEBVIEW_BUILD_EXAMPLES=OFF \
    -D WEBVIEW_BUILD_TESTS=OFF
cmake --build "${BUILD_DIR_LINUX}" --target webview_core_static --config Release

echo "Conteúdo do diretório de build Linux (${BUILD_DIR_LINUX}):"
ls -la "${BUILD_DIR_LINUX}"
# Se a biblioteca estiver em um subdiretório como 'core', liste-o também
if [ -d "${BUILD_DIR_LINUX}/core" ]; then
    echo "Conteúdo de ${BUILD_DIR_LINUX}/core:"
    ls -la "${BUILD_DIR_LINUX}/core"
fi

# A saída do build indicou "Linking CXX static library libwebview.a"
# Vamos priorizar esse nome.
COPIED_LINUX=false
if [ -f "${BUILD_DIR_LINUX}/libwebview.a" ]; then
    echo "Encontrado ${BUILD_DIR_LINUX}/libwebview.a"
    cp "${BUILD_DIR_LINUX}/libwebview.a" "${OUTPUT_DIR_LINUX}/libwebview.a"
    COPIED_LINUX=true
elif [ -f "${BUILD_DIR_LINUX}/libwebview_core_static.a" ]; then
    echo "Encontrado ${BUILD_DIR_LINUX}/libwebview_core_static.a"
    cp "${BUILD_DIR_LINUX}/libwebview_core_static.a" "${OUTPUT_DIR_LINUX}/libwebview.a"
    COPIED_LINUX=true
elif [ -d "${BUILD_DIR_LINUX}/core" ] && [ -f "${BUILD_DIR_LINUX}/core/libwebview.a" ]; then # Verificar subdiretório 'core'
    echo "Encontrado ${BUILD_DIR_LINUX}/core/libwebview.a"
    cp "${BUILD_DIR_LINUX}/core/libwebview.a" "${OUTPUT_DIR_LINUX}/libwebview.a"
    COPIED_LINUX=true
elif [ -d "${BUILD_DIR_LINUX}/core" ] && [ -f "${BUILD_DIR_LINUX}/core/libwebview_core_static.a" ]; then
    echo "Encontrado ${BUILD_DIR_LINUX}/core/libwebview_core_static.a"
    cp "${BUILD_DIR_LINUX}/core/libwebview_core_static.a" "${OUTPUT_DIR_LINUX}/libwebview.a"
    COPIED_LINUX=true
fi

if [ "$COPIED_LINUX" = false ]; then
    echo "ERRO: Artefato estático libwebview.a ou libwebview_core_static.a não encontrado para Linux nos locais esperados."
    exit 1
fi
echo "Compilação Linux x86_64 concluída. Artefato em ${OUTPUT_DIR_LINUX}/libwebview.a"


# --- Compilação para Windows x86 (MinGW) ---
echo "Compilando para Windows x86 (MinGW)..."
BUILD_DIR_WIN32="${WEBVIEW_SRC_DIR}/build_windows_x86"
OUTPUT_DIR_WIN32="${PRECOMPILED_DIR}/windows-x86"
TOOLCHAIN_FILE_WIN32="${WEBVIEW_SRC_DIR}/cmake/toolchains/i686-w64-mingw32.cmake"
mkdir -p "${BUILD_DIR_WIN32}"
mkdir -p "${OUTPUT_DIR_WIN32}"

if [ ! -f "${TOOLCHAIN_FILE_WIN32}" ]; then
    echo "AVISO: Arquivo de toolchain MinGW x86 não encontrado em ${TOOLCHAIN_FILE_WIN32}"
    echo "A compilação para Windows x86 pode falhar se o toolchain não for especificado corretamente ou não estiver instalado."
fi

cmake -S "${WEBVIEW_SRC_DIR}" -B "${BUILD_DIR_WIN32}" \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE_WIN32}" \
    -D WEBVIEW_BUILD_STATIC_LIBRARY=ON \
    -D WEBVIEW_BUILD_SHARED_LIBRARY=OFF \
    -D WEBVIEW_BUILD_EXAMPLES=OFF \
    -D WEBVIEW_BUILD_TESTS=OFF
cmake --build "${BUILD_DIR_WIN32}" --target webview_core_static --config Release

echo "Conteúdo do diretório de build Windows x86 (${BUILD_DIR_WIN32}):"
ls -la "${BUILD_DIR_WIN32}"
if [ -d "${BUILD_DIR_WIN32}/core" ]; then
    echo "Conteúdo de ${BUILD_DIR_WIN32}/core:"
    ls -la "${BUILD_DIR_WIN32}/core"
fi

COPIED_WIN32=false
# O nome do arquivo pode ser libwebview_core_static.a ou webview.lib/libwebview.a
if [ -f "${BUILD_DIR_WIN32}/libwebview.a" ]; then # MinGW geralmente produz .a
    echo "Encontrado ${BUILD_DIR_WIN32}/libwebview.a"
    cp "${BUILD_DIR_WIN32}/libwebview.a" "${OUTPUT_DIR_WIN32}/webview.lib" # DUB espera .lib para windows
    COPIED_WIN32=true
elif [ -f "${BUILD_DIR_WIN32}/libwebview_core_static.a" ]; then
    echo "Encontrado ${BUILD_DIR_WIN32}/libwebview_core_static.a"
    cp "${BUILD_DIR_WIN32}/libwebview_core_static.a" "${OUTPUT_DIR_WIN32}/webview.lib"
    COPIED_WIN32=true
elif [ -f "${BUILD_DIR_WIN32}/webview_core_static.lib" ]; then # Menos provável com MinGW, mas verificar
    echo "Encontrado ${BUILD_DIR_WIN32}/webview_core_static.lib"
    cp "${BUILD_DIR_WIN32}/webview_core_static.lib" "${OUTPUT_DIR_WIN32}/webview.lib"
    COPIED_WIN32=true
elif [ -d "${BUILD_DIR_WIN32}/core" ] && [ -f "${BUILD_DIR_WIN32}/core/libwebview.a" ]; then
    echo "Encontrado ${BUILD_DIR_WIN32}/core/libwebview.a"
    cp "${BUILD_DIR_WIN32}/core/libwebview.a" "${OUTPUT_DIR_WIN32}/webview.lib"
    COPIED_WIN32=true
fi

if [ "$COPIED_WIN32" = false ]; then
    echo "AVISO: Artefato estático para Windows x86 não encontrado automaticamente."
    echo "Verifique o diretório de build ${BUILD_DIR_WIN32} (e subdiretório 'core') para o nome correto do arquivo (.a ou .lib) e copie manualmente para ${OUTPUT_DIR_WIN32}/webview.lib se necessário."
fi
echo "Compilação Windows x86 (MinGW) concluída. Artefato esperado em ${OUTPUT_DIR_WIN32}/webview.lib"


# --- Compilação para Windows x64 (MinGW) ---
echo "Compilando para Windows x64 (MinGW)..."
BUILD_DIR_WIN64="${WEBVIEW_SRC_DIR}/build_windows_x64"
OUTPUT_DIR_WIN64="${PRECOMPILED_DIR}/windows-x64"
TOOLCHAIN_FILE_WIN64="${WEBVIEW_SRC_DIR}/cmake/toolchains/x86_64-w64-mingw32.cmake"
mkdir -p "${BUILD_DIR_WIN64}"
mkdir -p "${OUTPUT_DIR_WIN64}"

if [ ! -f "${TOOLCHAIN_FILE_WIN64}" ]; then
    echo "AVISO: Arquivo de toolchain MinGW x64 não encontrado em ${TOOLCHAIN_FILE_WIN64}"
    echo "A compilação para Windows x64 pode falhar se o toolchain não for especificado corretamente ou não estiver instalado."
fi

cmake -S "${WEBVIEW_SRC_DIR}" -B "${BUILD_DIR_WIN64}" \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE_WIN64}" \
    -D WEBVIEW_BUILD_STATIC_LIBRARY=ON \
    -D WEBVIEW_BUILD_SHARED_LIBRARY=OFF \
    -D WEBVIEW_BUILD_EXAMPLES=OFF \
    -D WEBVIEW_BUILD_TESTS=OFF
cmake --build "${BUILD_DIR_WIN64}" --target webview_core_static --config Release

echo "Conteúdo do diretório de build Windows x64 (${BUILD_DIR_WIN64}):"
ls -la "${BUILD_DIR_WIN64}"
if [ -d "${BUILD_DIR_WIN64}/core" ]; then
    echo "Conteúdo de ${BUILD_DIR_WIN64}/core:"
    ls -la "${BUILD_DIR_WIN64}/core"
fi

COPIED_WIN64=false
if [ -f "${BUILD_DIR_WIN64}/libwebview.a" ]; then
    echo "Encontrado ${BUILD_DIR_WIN64}/libwebview.a"
    cp "${BUILD_DIR_WIN64}/libwebview.a" "${OUTPUT_DIR_WIN64}/webview.lib"
    COPIED_WIN64=true
elif [ -f "${BUILD_DIR_WIN64}/libwebview_core_static.a" ]; then
    echo "Encontrado ${BUILD_DIR_WIN64}/libwebview_core_static.a"
    cp "${BUILD_DIR_WIN64}/libwebview_core_static.a" "${OUTPUT_DIR_WIN64}/webview.lib"
    COPIED_WIN64=true
elif [ -f "${BUILD_DIR_WIN64}/webview_core_static.lib" ]; then
    echo "Encontrado ${BUILD_DIR_WIN64}/webview_core_static.lib"
    cp "${BUILD_DIR_WIN64}/webview_core_static.lib" "${OUTPUT_DIR_WIN64}/webview.lib"
    COPIED_WIN64=true
elif [ -d "${BUILD_DIR_WIN64}/core" ] && [ -f "${BUILD_DIR_WIN64}/core/libwebview.a" ]; then
    echo "Encontrado ${BUILD_DIR_WIN64}/core/libwebview.a"
    cp "${BUILD_DIR_WIN64}/core/libwebview.a" "${OUTPUT_DIR_WIN64}/webview.lib"
    COPIED_WIN64=true
fi

if [ "$COPIED_WIN64" = false ]; then
    echo "AVISO: Artefato estático para Windows x64 não encontrado automaticamente."
    echo "Verifique o diretório de build ${BUILD_DIR_WIN64} (e subdiretório 'core') para o nome correto do arquivo (.a ou .lib) e copie manualmente para ${OUTPUT_DIR_WIN64}/webview.lib se necessário."
fi
echo "Compilação Windows x64 (MinGW) concluída. Artefato esperado em ${OUTPUT_DIR_WIN64}/webview.lib"

echo "Script de compilação concluído."
echo "Lembre-se de que para compilação cruzada com MinGW, você precisa ter o toolchain MinGW (gcc, g++, etc.) instalado e no PATH."
echo "Os arquivos de toolchain CMake (.cmake) devem estar presentes nos caminhos especificados."
echo "Se a cópia automática falhar, copie os arquivos .a/.lib manualmente para os diretórios precompiled/ apropriados."