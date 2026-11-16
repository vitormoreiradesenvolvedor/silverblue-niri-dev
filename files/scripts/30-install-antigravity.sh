#!/usr/bin/bash
# Empacota o Antigravity IDE dentro da imagem.
#
# ATENCAO (ostree): /opt e um symlink para /var/opt no Fedora Atomic, logo
# nada gravado em /opt durante o build sobrevive. O payload real vai para
# /usr/lib/antigravity-ide e um symlink /opt/antigravity-ide e recriado a cada
# boot por tmpfiles.d, mantendo o caminho pedido no handoff funcional.
#
# A URL de download nao e estavel/versionada publicamente. Coloque a URL do
# artefato Linux x64 em files/system/etc/custom-antigravity-url (uma linha).
# Sem URL valida o script apenas avisa e segue, para nao derrubar o build
# semanal. Variaveis do runner do Actions NAO chegam aqui dentro: o modulo
# `script` roda dentro do container de build.
set -uo pipefail

DEST="/usr/lib/antigravity-ide"
URL="${ANTIGRAVITY_URL:-}"
if [[ -z "${URL}" && -r /etc/custom-antigravity-url ]]; then
  URL="$(grep -vE '^\s*(#|$)' /etc/custom-antigravity-url | head -n1)"
fi

if [[ -z "${URL}" ]]; then
  echo "AVISO: URL do Antigravity nao definida - IDE NAO sera instalado."
  echo "       Ver README (secao Antigravity) para obter a URL do tarball/deb/rpm."
  exit 0
fi

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

echo "::group:: Baixando Antigravity de ${URL}"
if ! curl -fsSL --retry 5 --retry-delay 3 -o "${workdir}/payload" "${URL}"; then
  echo "AVISO: download do Antigravity falhou - seguindo sem o IDE."
  exit 0
fi
echo "::endgroup::"

mkdir -p "${DEST}"
case "$(file -b --mime-type "${workdir}/payload")" in
  application/gzip|application/x-gzip)
    tar -xzf "${workdir}/payload" -C "${DEST}" --strip-components=1
    ;;
  application/zip)
    unzip -q "${workdir}/payload" -d "${workdir}/unzipped"
    inner="$(find "${workdir}/unzipped" -mindepth 1 -maxdepth 1 -type d | head -n1)"
    cp -a "${inner:-${workdir}/unzipped}/." "${DEST}/"
    ;;
  application/vnd.debian.binary-package)
    ( cd "${workdir}" && ar x payload )
    tar -xf "${workdir}"/data.tar.* -C "${workdir}"
    # .deb do upstream instala em /usr/share/<app> ou /opt/<app>
    inner="$(find "${workdir}/usr/share" "${workdir}/opt" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -n1)"
    if [[ -z "${inner}" ]]; then
      echo "AVISO: layout do .deb nao reconhecido - seguindo sem o IDE."
      exit 0
    fi
    cp -a "${inner}/." "${DEST}/"
    ;;
  application/x-rpm)
    dnf -y install "${workdir}/payload"
    echo "RPM oficial instalado; nenhum empacotamento manual necessario."
    exit 0
    ;;
  *)
    # AppImage ou binario solto
    install -Dm0755 "${workdir}/payload" "${DEST}/antigravity"
    ;;
esac

# Descobre o executavel real
bin="$(find "${DEST}" -maxdepth 2 -type f -name 'antigravity*' -perm -u+x | head -n1)"
if [[ -z "${bin}" ]]; then
  bin="$(find "${DEST}" -maxdepth 2 -type f -perm -u+x | head -n1)"
fi
if [[ -z "${bin}" ]]; then
  echo "AVISO: nenhum executavel encontrado em ${DEST} - seguindo sem o IDE."
  exit 0
fi

chmod -R a+rX "${DEST}"
ln -sf "${bin}" /usr/bin/antigravity-ide

cat > /usr/share/applications/antigravity-ide.desktop <<DESKTOP
[Desktop Entry]
Type=Application
Name=Antigravity IDE
Comment=Google Antigravity agentic IDE
Exec=/usr/bin/antigravity-ide %F
Icon=antigravity-ide
Terminal=false
Categories=Development;IDE;
StartupWMClass=Antigravity
MimeType=text/plain;inode/directory;
DESKTOP

# /opt -> /var/opt no ostree: o symlink e recriado a cada boot por tmpfiles.d,
# assim o caminho /opt/antigravity-ide do handoff continua valido.
cat > /usr/lib/tmpfiles.d/antigravity.conf <<'TMPFILES'
d /var/opt 0755 root root -
L+ /var/opt/antigravity-ide - - - - /usr/lib/antigravity-ide
TMPFILES

echo "Antigravity instalado: ${bin}"
