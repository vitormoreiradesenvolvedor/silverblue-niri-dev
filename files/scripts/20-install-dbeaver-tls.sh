#!/usr/bin/bash
# Instala o DBeaver Community pelo RPM oficial e injeta de forma PERMANENTE
# (na camada da imagem) a flag que aponta o java.security customizado,
# reabilitando TLSv1 / TLSv1.1. Como /usr e imutavel e reconstruido a cada
# atualizacao da imagem, o patch nunca se perde num `rpm-ostree upgrade`.
set -euo pipefail

RPM_URL="${DBEAVER_RPM_URL:-https://dbeaver.io/files/dbeaver-ce-latest-stable.x86_64.rpm}"
INI="/usr/share/dbeaver-ce/dbeaver.ini"
SEC="/etc/dbeaver-custom-java.security"
FLAG="-Djava.security.properties=${SEC}"

echo "::group:: Instalando DBeaver CE"
curl -fsSL --retry 5 --retry-delay 3 -o /tmp/dbeaver-ce.rpm "${RPM_URL}"
dnf -y install /tmp/dbeaver-ce.rpm
rm -f /tmp/dbeaver-ce.rpm
echo "::endgroup::"

if [[ ! -f "${INI}" ]]; then
  echo "ERRO: ${INI} nao existe apos a instalacao do DBeaver" >&2
  exit 1
fi

if grep -qF -- "${FLAG}" "${INI}"; then
  echo "dbeaver.ini ja contem a flag; nada a fazer"
  exit 0
fi

if grep -q '^-vmargs$' "${INI}"; then
  # Insere imediatamente apos a linha -vmargs (argumentos da JVM).
  sed -i "/^-vmargs$/a ${FLAG}" "${INI}"
else
  printf '%s\n%s\n' '-vmargs' "${FLAG}" >> "${INI}"
fi

echo "dbeaver.ini final:"
cat "${INI}"
