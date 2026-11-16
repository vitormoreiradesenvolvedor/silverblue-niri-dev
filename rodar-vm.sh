#!/usr/bin/env bash
#
# Sobe a imagem em uma VM local (KVM) para testar sem depender do outro
# notebook. Usa o qcow2 gerado por ./gerar-iso.sh com TIPO=qcow2.
#
# A VM e UEFI (a imagem nao tem boot legado), com virtio-gpu e janela GTK.
# Nao ha NVIDIA aqui: nvidia-smi e nvidia-offload so se testam no hardware.
#
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISCO="${DISCO:-$RAIZ/output/qcow2/disk.qcow2}"
MEM="${MEM:-6144}"
CPUS="${CPUS:-4}"

if [[ ! -f "$DISCO" ]]; then
    echo "Disco nao encontrado: $DISCO" >&2
    echo "Gere com: TIPO=qcow2 ./gerar-iso.sh" >&2
    exit 1
fi

if [[ ! -r /dev/kvm ]]; then
    echo "/dev/kvm inacessivel: sem aceleracao a VM fica inutilizavel." >&2
    exit 1
fi

# O firmware UEFI e lido em modo somente-leitura; as variaveis (ordem de boot)
# precisam de uma copia gravavel por VM.
VARS="$RAIZ/output/qcow2/OVMF_VARS.fd"
if [[ ! -f "$VARS" ]]; then
    for origem in /usr/share/edk2/ovmf/OVMF_VARS.fd /usr/share/OVMF/OVMF_VARS.fd; do
        [[ -f "$origem" ]] && { cp "$origem" "$VARS"; break; }
    done
fi
[[ -f "$VARS" ]] || { echo "OVMF_VARS.fd nao encontrado" >&2; exit 1; }

echo "Disco : $DISCO"
echo "RAM   : ${MEM} MiB   vCPUs: $CPUS"
echo "Feche a janela da VM para encerrar."

exec qemu-system-x86_64 \
    -enable-kvm \
    -machine q35,smm=on \
    -cpu host \
    -smp "$CPUS" \
    -m "$MEM" \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.fd \
    -drive if=pflash,format=raw,file="$VARS" \
    -drive file="$DISCO",if=virtio,format=qcow2,cache=writeback \
    -device virtio-vga-gl \
    -display gtk,gl=on,show-cursor=on \
    -device virtio-tablet \
    -device virtio-keyboard \
    -netdev user,id=rede \
    -device virtio-net-pci,netdev=rede \
    -object rng-random,filename=/dev/urandom,id=rng0 \
    -device virtio-rng-pci,rng=rng0
