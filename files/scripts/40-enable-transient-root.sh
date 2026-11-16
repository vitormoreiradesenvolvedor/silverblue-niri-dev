#!/usr/bin/bash
# O snapd exige o diretorio de topo /snap para snaps "classic". O ostree so
# materializa um conjunto fixo de diretorios de topo (/usr, /etc, /var, /opt...),
# e com composefs a raiz e somente-leitura: criar /snap no build nao persiste e
# em runtime da "Read-only file system".
#
# Solucao suportada pelo ostree: root.transient = true em prepare-root.conf.
# A raiz passa a ser um overlay gravavel em tmpfs (descartado a cada boot),
# e /usr/lib/tmpfiles.d/snap-toplevel.conf recria /snap em todo boot antes do
# snap.mount fazer o bind de /var/lib/snapd/snap.
set -euo pipefail

CONF="/usr/lib/ostree/prepare-root.conf"
mkdir -p "$(dirname "${CONF}")"
touch "${CONF}"

if grep -qE '^\s*transient\s*=\s*true' "${CONF}"; then
  echo "root.transient ja habilitado"
elif grep -qE '^\s*\[root\]' "${CONF}"; then
  sed -i '/^\s*\[root\]/a transient = true' "${CONF}"
else
  printf '\n[root]\ntransient = true\n' >> "${CONF}"
fi

echo "prepare-root.conf final:"
cat "${CONF}"

# Diretorio de dados do snapd fica em /var (persistente e gravavel).
mkdir -p /var/lib/snapd/snap
