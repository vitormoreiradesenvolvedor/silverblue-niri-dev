#!/usr/bin/env bash
#
# Fontes criticas do iNiR.
#
# O doctor do iNiR classifica duas como "critical - shell UI is broken without
# it (icons unreadable)":
#
#   Material Symbols Rounded  - desenha todos os icones do shell
#   JetBrainsMono Nerd Font   - glifos da barra e do terminal
#
# Nenhuma das duas e pacote no Fedora: o mapa de dependencias do iNiR diz
# "fedora:COMPILE:google-material-symbols", e o jetbrains-mono-fonts-all do
# Fedora NAO e a variante Nerd (sem os glifos extras). O setup as baixaria na
# fase de dependencias, que nao roda em sistema atomico - entao elas vem aqui,
# das mesmas URLs que o proprio iNiR usa, para /usr/share/fonts (sistema).
#
set -euo pipefail

DESTINO=/usr/share/fonts

echo "Fontes do iNiR: baixando para ${DESTINO}"

# ---------------------------------------------------------------------------
# Material Symbols - os tres conjuntos, como o install-material-symbols faz.
# Só o Rounded e critico; os outros dois sao escolhiveis nas configuracoes.
# ---------------------------------------------------------------------------
mkdir -p "${DESTINO}/material-symbols"
falhou_critica=0
for conjunto in Rounded Outlined Sharp; do
    url="https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbols${conjunto}%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
    if curl -fsSL --retry 3 --connect-timeout 15 \
        -o "${DESTINO}/material-symbols/MaterialSymbols${conjunto}.ttf" "${url}"; then
        echo "  Material Symbols ${conjunto}: ok"
    elif [[ "${conjunto}" == Rounded ]]; then
        echo "  Material Symbols Rounded: FALHOU (icones do shell ficariam quebrados)" >&2
        falhou_critica=1
    else
        echo "  Material Symbols ${conjunto}: falhou (nao critico)" >&2
    fi
done

# ---------------------------------------------------------------------------
# JetBrains Mono Nerd Font
# ---------------------------------------------------------------------------
mkdir -p "${DESTINO}/jetbrains-mono-nerd"
temporario="$(mktemp -d)"
trap 'rm -rf "${temporario}"' EXIT
if curl -fsSL --retry 3 --connect-timeout 15 \
    -o "${temporario}/JetBrainsMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
    # So as variaveis/estaticas ttf; o zip traz tambem licencas e READMEs.
    unzip -o -q "${temporario}/JetBrainsMono.zip" '*.ttf' \
        -d "${DESTINO}/jetbrains-mono-nerd"
    echo "  JetBrainsMono Nerd: ok ($(find "${DESTINO}/jetbrains-mono-nerd" -name '*.ttf' | wc -l) arquivos)"
else
    echo "  JetBrainsMono Nerd: FALHOU" >&2
    falhou_critica=1
fi

# Falhar o build e melhor que publicar uma imagem cujo shell sobe ilegivel.
if [[ "${falhou_critica}" -eq 1 ]]; then
    echo "Fonte critica do iNiR nao baixou; abortando o build." >&2
    exit 1
fi

fc-cache -f "${DESTINO}" >/dev/null 2>&1 || true
echo "Fontes do iNiR instaladas."
