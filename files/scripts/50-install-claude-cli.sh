#!/usr/bin/bash
# Claude Code CLI global na camada da imagem.
#
# ATENCAO (ostree): /usr/local e symlink para /var/usrlocal, ou seja, instalar
# com o prefixo padrao do npm (/usr/local) NAO persiste na imagem. Por isso o
# prefixo e /usr, gerando /usr/bin/claude. O symlink /usr/local/bin/claude e
# recriado em runtime por tmpfiles.d para quem espera esse caminho.
set -euo pipefail

export npm_config_prefix=/usr
npm install -g --prefix=/usr @anthropic-ai/claude-code

test -x /usr/bin/claude
/usr/bin/claude --version || true
