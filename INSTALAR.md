# Instalar no notebook novo — passo a passo

Guia direto, do zero ao desktop funcionando. Os comandos de preparo rodam
**neste** notebook (o Aurora); o notebook novo só recebe o pendrive.

Imagem: `ghcr.io/vitormoreiradesenvolvedor/silverblue-niri-dev:latest`

---

## O que você precisa

- Pendrive de 8 GB ou mais (**será apagado**)
- ~20 GB livres neste notebook para gerar o ISO
- `podman` (já vem no Aurora/Silverblue)

---

## Passo 1 — Confirmar que a imagem está no ar

Já está publicada e **pública**, com assinatura verificada:

```
ghcr.io/vitormoreiradesenvolvedor/silverblue-niri-dev:latest
digest sha256:426dad87a05012bea348f1207dd18ae5bdcd84da27c49003c7006430c0766bef
```

Confira que baixa sem login:

```bash
podman pull ghcr.io/vitormoreiradesenvolvedor/silverblue-niri-dev:latest
```

Conferir a assinatura (opcional, mas é o motivo de existir o `cosign.pub`):

```bash
cd ~/Downloads/silverblue-niri-dev
podman run --rm --user 0 -v "$PWD":/w:z -w /w gcr.io/projectsigstore/cosign:latest \
  verify --key cosign.pub \
  ghcr.io/vitormoreiradesenvolvedor/silverblue-niri-dev:latest
```

Builds futuros rodam sozinhos toda segunda, 06:00 UTC. Para acompanhar um:

```bash
cd ~/Downloads/silverblue-niri-dev && gh run watch
```

Falhou? `gh run view --log-failed` mostra o passo que quebrou.

---

## Passo 2 — Gerar o ISO instalável

Neste notebook (o que já funciona), dentro do repositório:

```bash
cd ~/Downloads/silverblue-niri-dev
./gerar-iso.sh
```

Ele pergunta o usuário e a senha inicial do sistema novo, pede sua senha do
sudo e gera `output/bootiso/install.iso`. Baixa ~5 GB e leva de 10 a 25 minutos.

O script monta o `config.toml` num arquivo temporário fora do repositório e o
apaga ao terminar — a senha **não** fica gravada aqui. Para não digitar nada:

```bash
USUARIO=vmoreira SENHA='sua-senha' ./gerar-iso.sh
```

Para uma máquina virtual em vez de pendrive: `TIPO=qcow2 ./gerar-iso.sh`.

<details>
<summary>Comando manual equivalente (se preferir sem o script)</summary>

```bash
mkdir -p ~/iso-niri/output && cd ~/iso-niri

# A senha vai em hash, não em texto puro:
#   openssl passwd -6 'sua-senha'
cat > config.toml <<'TOML'
[[customizations.user]]
name = "vmoreira"
password = "$6$cole-o-hash-aqui"
groups = ["wheel", "docker", "dialout"]
TOML

sudo podman run --rm -it --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v "$PWD/config.toml":/config.toml:ro \
  -v "$PWD/output":/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type anaconda-iso \
  --rootfs ext4 \
  --config /config.toml \
  ghcr.io/vitormoreiradesenvolvedor/silverblue-niri-dev:latest
```

Duas flags são obrigatórias e falham de formas diferentes:

- `--config /config.toml` — sem ela o builder monta o arquivo mas não o lê, e o
  sistema instala **sem usuário nenhum**, tela de login sem conta.
- `--rootfs ext4` — sem ela o build aborta com
  `no default root filesystem type specified in container`.

E a imagem precisa estar na storage do podman **root** antes
(`sudo podman pull ...`): versões recentes do builder não a baixam sozinhas.

</details>

O ISO sai em `output/bootiso/install.iso` (ou `~/iso-niri/output/...` no modo
manual). Os passos seguintes usam o primeiro caminho.

**São ~7,6 GB.** Um pendrive de 8 GB serve, mas por pouco; de 16 GB é folga.

---

## Passo 3 — Gravar no pendrive

Descubra o dispositivo certo **antes** de gravar:

```bash
lsblk -o NAME,SIZE,MODEL,TRAN
```

Procure o de tamanho igual ao seu pendrive, com `TRAN=usb`. Supondo `/dev/sdb`:

```bash
sudo dd if=output/bootiso/install.iso of=/dev/sdb \
  bs=4M status=progress oflag=direct conv=fsync
sync
```

> **Confira a letra do dispositivo duas vezes.** O `dd` apaga o disco inteiro,
> sem pergunta e sem recuperação. Se errar e apontar para `/dev/nvme0n1`, você
> destrói este notebook. Use `lsblk` com o pendrive desconectado e depois
> conectado, e compare a diferença.

---

## Passo 4 — Instalar no notebook novo

1. Pendrive no notebook novo, ligue e entre no menu de boot
   (normalmente **F12**, **F2**, **F10** ou **Esc** — depende do fabricante)
2. Escolha o pendrive, de preferência a entrada **UEFI**
3. No instalador (Anaconda): escolha o disco de destino, confirme o
   particionamento automático e mande instalar
4. Terminou: desligue, **tire o pendrive** e ligue de novo

Não precisa escolher idioma de pacote, usuário nem senha — já vem no ISO.

---

## Passo 5 — Primeiro login

1. Na tela de login, clique no ícone de engrenagem (ou no nome da sessão) e
   escolha **niri**
2. Entre com o usuário e senha do `config.toml`
3. A tela ficará **praticamente vazia** — isso é esperado. O iNiR ainda não
   está instalado. Abra um terminal com **Super+T**
4. Acompanhe o provisionamento (Homebrew, SDKMAN, rustup, iNiR):

   ```bash
   journalctl --user -u custom-first-run -f
   ```

   Espere `provisionamento concluido`. Leva de 5 a 15 minutos, dependendo da
   internet.

5. **Reinicie o computador.**

   ```bash
   systemctl reboot
   ```

   Isso não é opcional: a documentação do iNiR diz que relogar não basta.

6. Entre de novo na sessão **niri**. Agora o shell iNiR carrega.

---

## Passo 6 — Conferir que tudo veio

```bash
# Ferramentas de desenvolvimento
node --version && npm --version && claude --version
gcc --version | head -1
cargo --version          # se faltar: source ~/.cargo/env
sdk version              # SDKMAN
brew --version

# Docker sem sudo (precisa de um logout/login depois do 1º boot)
docker run --rm hello-world

# Snap
snap install hello-world && hello-world

# GPU NVIDIA
nvidia-smi
nvidia-offload glxinfo | grep "OpenGL renderer"   # deve dizer NVIDIA

# VPN
mullvad status
```

Atalhos básicos do niri: **Super+T** terminal, **Super+D** lançador,
**Super+Q** fecha janela, **Super+Shift+/** mostra todos os atalhos.

---

## Passo 7 — Manter atualizado

```bash
rpm-ostree upgrade && systemctl reboot    # sistema (imagem nova toda segunda)
inir update                               # shell iNiR (também roda sozinho, semanal)
flatpak update
brew upgrade
```

---

## Se algo der errado

**A tela fica preta ao entrar no niri**
GPU híbrida: o niri pode ter escolhido a NVIDIA em vez da Intel. Entre numa
sessão GNOME/console (Ctrl+Alt+F3), e em `~/.config/niri/config.kdl`
descomente `render-drm-device` no bloco `debug`, apontando para o render node
da Intel (`ls -l /dev/dri/by-path/` mostra qual é).

**Nenhum prompt de senha aparece ao usar sudo em app gráfico**
O agente polkit não subiu. Teste:
`/usr/libexec/polkit-mate-authentication-agent-1 &`

**O iNiR não carregou depois do reboot**
```bash
journalctl --user -u custom-first-run --no-pager | tail -30
inir doctor
```
Reinstalar na mão:
```bash
cd ~/.local/share/inir-repo && ./setup install -y --skip-deps
```

**`docker` pede sudo**
Faça logout e login. O grupo é aplicado no boot, mas a sessão já aberta não
recebe grupo novo.

**`snap install` reclama de `/snap`**
```bash
findmnt /snap                       # tem que aparecer o bind mount
systemctl status snap.mount
cat /usr/lib/ostree/prepare-root.conf   # precisa ter transient = true
```

**Quero voltar ao estado anterior do sistema**
```bash
sudo rpm-ostree rollback && systemctl reboot
```
Ou escolha o deployment antigo no menu do GRUB (segure **Esc** no boot).
