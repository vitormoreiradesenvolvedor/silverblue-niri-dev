# silverblue-niri-dev

Imagem OCI customizada de **Fedora Silverblue** construida com
[BlueBuild](https://blue-build.org), publicada e assinada automaticamente no
GitHub Container Registry (`ghcr.io`).

Compositor **niri** + desktop shell **iNiR**, toolchains de desenvolvimento
nativos na camada RPM, Docker CE, snapd funcional em OSTree, Mullvad VPN e
DBeaver Community com **TLS 1.0/1.1 reabilitado de forma permanente**.

Base: `ghcr.io/ublue-os/silverblue-nvidia` — driver NVIDIA incluso, para
notebook **hibrido Intel+NVIDIA**. Em maquina sem NVIDIA, troque para
`ghcr.io/ublue-os/silverblue-main` em `recipes/recipe.yml`.

> O Universal Blue **nao publica** variante `-nvidia-open` das imagens desktop
> (`silverblue-nvidia-open` e `kinoite-nvidia-open` retornam 403; so existem
> para Aurora/Bazzite). Entao a base usa o driver **proprietario**
> (`akmod-nvidia`), nao os kernel modules abertos. Funciona igual em hibrido;
> a diferenca aparece so em GPU muito nova, onde o aberto e o recomendado.

---

> **Instalando no hardware pela primeira vez?** O passo a passo simples,
> do pendrive ao desktop funcionando, esta em **[INSTALAR.md](INSTALAR.md)**.

## 1. O que vem na imagem

| Area | Conteudo |
|---|---|
| Compositor | `niri`, `xwayland-satellite`, `mate-polkit`, PipeWire/WirePlumber, `nm-applet`, `brightnessctl`, `playerctl`, `grim`, `slurp`, `wl-clipboard`, `fuzzel`, `ptyxis`, Qt6 completo |
| Shell | **iNiR** provisionado no `$HOME` no primeiro login (`qs-rs`, `inir-accel`, `inir-cli`) + timer semanal de update |
| C/C++ | `gcc`, `gcc-c++`, `clang`, `make`, `cmake`, `ninja-build`, `gdb`, `pkgconf`, `glibc-devel` |
| Node | `nodejs24`, `nodejs24-npm` (`node`/`npm`/`npx`) + `claude` (Claude Code CLI) em `/usr/bin` |
| Utilitarios | `git`, `curl`, `wget`, `zsh`, `jq`, `just`, `tar`, `unzip`, `fastfetch` |
| Rede/VPN | `wireguard-tools`, **Mullvad VPN** (`mullvad-daemon.service` ativo) |
| Containers | `docker-ce`, `docker-ce-cli`, `containerd.io`, `buildx`, `compose` (servicos ativos) |
| Navegadores | Google Chrome, Brave |
| Comunicacao | Slack e Teams (`teams-for-linux`) via Flatpak de sistema |
| IDEs | **Antigravity IDE** (ver secao 6), **DBeaver CE** com TLS 1.0 liberado |
| Pacotes | Flatpak + Flathub pre-configurado, **snapd nativo com `/snap` funcional** |
| GPU | Driver NVIDIA proprietario (base `silverblue-nvidia`) + `nvidia-offload` para PRIME render offload |
| Espaco do usuario | Homebrew, SDKMAN!, rustup/cargo provisionados no primeiro login |

Grupos `docker` e `dialout` sao garantidos por `sysusers.d` e aplicados a todo
usuario com UID >= 1000 a cada boot (`setup-user-groups.service`).

---

## 2. Criar o repositorio e publicar

```bash
# 1. Crie o repo vazio no GitHub (publico, para o ghcr ficar acessivel)
gh repo create silverblue-niri-dev --public --clone
cd silverblue-niri-dev

# 2. Copie os arquivos deste diretorio para dentro do repo
cp -r /caminho/para/silverblue-niri-dev/. .

# 3. Ajuste o que e seu (ver secao 3)
$EDITOR recipes/recipe.yml files/system/etc/custom-inir-repo

# 4. Gere o par de chaves Cosign
#    Instale o CLI uma vez: `npm i -g @blue-build/cli` ou
#    `brew install blue-build/tap/bluebuild`
bluebuild generate-signing-key
#    -> gera cosign.pub (commitar) e cosign.key (NAO commitar; ja no .gitignore)

# 5. Guarde a chave privada como secret do repositorio
gh secret set SIGNING_SECRET < cosign.key

# 6. Commit e push
git add -A
git commit -m "feat: imagem Silverblue customizada com niri, iNiR e toolchains"
git push -u origin main
```

O workflow roda no push, toda segunda-feira as 06:00 UTC e sob demanda
(`gh workflow run bluebuild`). O resultado vai para
`ghcr.io/vitormoreiradesenvolvedor/silverblue-niri-dev:latest`.

> Na primeira execucao, torne o pacote publico:
> GitHub > seu perfil > **Packages** > `silverblue-niri-dev` > *Package settings* >
> *Change visibility* > **Public**. Sem isso o `rpm-ostree rebase` pede login.

---

## 3. Ajustes obrigatorios antes do primeiro build

1. **URL do iNiR** — `files/system/etc/custom-inir-repo`.
   O handoff chegou com a URL truncada (`https://github.com`); o arquivo tem um
   placeholder. Coloque a URL real do repositorio git do iNiR.
2. **URL do Antigravity** — `files/system/etc/custom-antigravity-url`
   (ver secao 6). Sem ela a imagem e construida sem o IDE, com aviso no log.
3. **`image-version`** em `recipes/recipe.yml` — fixado em `44`.
   Troque ao migrar de release do Fedora.
   **`base-image`** esta em `silverblue-nvidia` (notebook hibrido).
   Sem NVIDIA: `silverblue-main`.
4. **Layout de teclado** — `files/system/etc/skel/.config/niri/config.kdl`
   esta em `br`.

---

## 4. Instalar no hardware

Dois caminhos. O primeiro e para maquina **vazia** (nada instalado ainda).

### 4a. Maquina vazia: ISO instalavel gerado da propria imagem

Nao instale Silverblue para depois rebasear. `bootc-image-builder` transforma a
imagem OCI num ISO do Anaconda que grava a imagem customizada direto no disco.

```bash
mkdir -p ~/iso-niri/output && cd ~/iso-niri

cat > config.toml <<'TOML'
[[customizations.user]]
name = "vmoreira"
password = "troque-no-primeiro-boot"
groups = ["wheel", "docker", "dialout"]
TOML

sudo podman run --rm -it --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v "$PWD/config.toml":/config.toml:ro \
  -v "$PWD/output":/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type anaconda-iso \
  ghcr.io/vitormoreiradesenvolvedor/silverblue-niri-dev:latest

# ISO em ./output/bootiso/install.iso
sudo dd if=output/bootiso/install.iso of=/dev/sdX bs=4M status=progress oflag=direct
```

Para gerar o ISO de uma imagem **local** (sem push para o ghcr), acrescente
`--local` e use `localhost/silverblue-niri-dev:local` como referencia.

Depois de instalar, a maquina ja acompanha a tag do registry: `rpm-ostree
upgrade` busca a imagem nova toda semana.

### 4b. Maquina que ja roda Fedora Atomic: rebase

```bash
# 0. Rede de seguranca
rpm-ostree status                   # anote o deployment atual
sudo ostree admin pin 0             # impede que ele seja apagado
sudo rpm-ostree reset               # DROPA pacotes em camada (ver nota abaixo)

# 1. Primeiro rebase: ainda sem verificacao de assinatura
sudo rpm-ostree rebase \
  ostree-unverified-registry:ghcr.io/vitormoreiradesenvolvedor/silverblue-niri-dev:latest

sudo systemctl reboot

# 2. Depois do boot, com a politica cosign ja dentro da imagem,
#    passe para a referencia assinada e verificada
sudo rpm-ostree rebase \
  ostree-image-signed:docker://ghcr.io/vitormoreiradesenvolvedor/silverblue-niri-dev:latest

sudo systemctl reboot
```

> **O `rpm-ostree reset` nao e opcional.** Pacotes em camada atravessam o
> rebase. Se a maquina tem `snapd` ou `mullvad-vpn` em camada e a imagem nova
> traz os dois em `/usr`, a camada colide e **todo `upgrade` seguinte falha**.

A partir dai, `rpm-ostree upgrade` busca a imagem nova toda semana e **nenhuma
das customizacoes se perde** — todas vivem em `/usr`, `/etc` ou em servicos
idempotentes de boot.

Voltar atras:

```bash
sudo rpm-ostree rollback            # volta para o deployment anterior
# ou escolha o deployment pinado no menu do GRUB
# ou, de volta ao Silverblue puro:
sudo rpm-ostree rebase fedora:fedora/44/x86_64/silverblue
```

### Primeiro login

Versao detalhada em [INSTALAR.md](INSTALAR.md).

1. Na tela do GDM, escolha a sessao **niri**.
2. `custom-first-run.service` (usuario) instala Homebrew, SDKMAN!, rustup e
   iNiR em background. Acompanhe com:
   ```bash
   journalctl --user -u custom-first-run -f
   ```
3. Abra um terminal novo (Mod+T) depois que terminar, para o
   `/etc/profile.d/custom-dev-env.sh` pegar `brew`, `sdk` e `cargo`.
4. `docker` sem sudo exige **relogin** (grupo aplicado no boot).

---

## 5. Decisoes de implementacao que divergem do handoff

Cada item abaixo e consequencia de uma restricao real do OSTree. O resultado
funcional e o pedido; o caminho e outro.

### `/opt` e `/usr/local` nao persistem em imagem OSTree
Ambos sao symlinks para `/var` (`/var/opt` e `/var/usrlocal`), e `/var` e
descartado/resetado — nada gravado ali durante o build sobrevive.

- **Antigravity IDE**: payload em `/usr/lib/antigravity-ide`; o symlink
  `/opt/antigravity-ide` e recriado a cada boot via `tmpfiles.d`. O binario
  fica em `/usr/bin/antigravity-ide` e o `.desktop` em
  `/usr/share/applications/`, como pedido.
- **Claude CLI**: `npm install -g --prefix=/usr`, gerando `/usr/bin/claude`.
  O caminho `/usr/local/bin/claude` e um symlink recriado por `tmpfiles.d`.

### `/snap` exige raiz gravavel
`snapd` precisa do diretorio de topo `/snap` para snaps *classic*. O OSTree
materializa apenas um conjunto fixo de diretorios de topo e, com composefs,
a raiz e somente-leitura — `mkdir /snap` falha tanto no build quanto em runtime.

Solucao (`files/scripts/40-enable-transient-root.sh`): habilita
`root.transient = true` em `/usr/lib/ostree/prepare-root.conf`. A raiz passa a
ser um overlay gravavel em tmpfs, descartado a cada boot; `tmpfiles.d` recria
`/snap` em todo boot e `snap.mount` faz o bind de `/var/lib/snapd/snap`
(que fica em `/var`, persistente).

> Nota: o handoff pedia tambem `var-lib-snapd.mount`. Ela nao existe aqui —
> seria um bind de `/var/lib/snapd` sobre si mesmo. `snap.mount` sozinho ja
> entrega o resultado pedido.

### `/home/linuxbrew` nao pode ser criado no build
`/home` -> `/var/home`. `homebrew-prepare.service` (root, oneshot no boot) cria
o diretorio e passa a posse ao primeiro usuario humano; o servico de usuario
instala o Homebrew **sem sudo**. A condicao
`ConditionPathExists=!/home/linuxbrew/.linuxbrew/bin/brew` faz o servico sair
na hora assim que o brew existir.

### Pacotes removidos da imagem base
`podman-docker`, `moby-engine`, `runc` e `containerd` colidem com
`docker-ce`/`containerd.io` (`/usr/bin/docker`, binarios do runtime). Sao
removidos condicionalmente em `15-prepare-docker.sh`.

### Repositorio Docker CE e `$releasever`
O repo do Docker costuma ficar alguns meses atras do Fedora mais novo. O script
testa `$releasever` do sistema para baixo (ate 39) e fixa no `.repo` o maior
que realmente responde — senao o build quebraria com 404 a cada novo Fedora.

### Slack e Teams via Flatpak
Os RPMs oficiais de ambos sao servidos em URLs com versao fixa no caminho
(`slack-<ver>-0.1.fc21.x86_64.rpm`, releases do GitHub do `teams-for-linux`),
o que quebra o build semanal a cada release upstream. Flatpak de sistema
(`com.slack.Slack`, `com.github.IsmaelMartinez.teams_for_linux`) atualiza
sozinho e e o canal suportado pelos dois projetos.
Para trocar por RPM, use `files/scripts/` com a URL pinada.

### `NetworkManager-wireguard` nao existe no Fedora
O suporte a WireGuard e **nativo** no NetworkManager (`nmcli connection import
type wireguard file wg0.conf`). Instalado apenas `wireguard-tools`.

### Nomes de pacote corrigidos contra o Fedora 44 real

Verificado com `dnf repoquery` num container `fedora:44` (47/47 presentes).
Tres nomes do handoff nao existem mais:

| Handoff | Real no Fedora 44 | Motivo |
|---|---|---|
| `nodejs`, `npm` | `nodejs24`, `nodejs24-npm` | o metapacote sem versao foi removido; so versionados (`nodejs20/22/24`). `nodejs24-npm` traz `/usr/bin/npm` e `/usr/bin/npx` |
| `wget` | `wget2-wget` | `wget` 1.x saiu do repositorio; `wget2-wget` fornece `/usr/bin/wget` |
| `polkit-gnome` | `mate-polkit` | `polkit-gnome` foi removido do Fedora. `mate-polkit` e o agente GTK equivalente, em `/usr/libexec/polkit-mate-authentication-agent-1`. `custom-niri-autostart` tenta mate, gnome, kde e lxqt na ordem |

Tambem validado de fato, instalando num container:

```
node v24.18.0 | npm 11.16.0 | /usr/bin/node -> node-24
npm install -g --prefix=/usr @anthropic-ai/claude-code  ->  claude 2.1.325
```

Isso confirma o prefixo `/usr` da secao anterior: o symlink resultante e
`/usr/bin/claude -> ../lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe`,
inteiro dentro de `/usr`, logo persiste na imagem.

Ainda **nao** verificados contra repositorio real: os pacotes de terceiros
(`docker-ce`, `google-chrome-stable`, `brave-browser`, `mullvad-vpn`) e o
DBeaver. Dependem de um build completo.

### `niri` do repositorio oficial do Fedora
Instalado do Fedora, nao do COPR `yalter/niri` — uma dependencia a menos e
versao suportada pelo release. Para o COPR, adicione ao `recipe.yml`:

```yaml
  - type: dnf
    repos:
      copr:
        - yalter/niri
```

---

## 5b. GPU hibrida Intel+NVIDIA

O compositor fica na **iGPU Intel** de proposito: e ela que esta ligada no
painel interno, e manter o Wayland na dGPU gasta bateria e da tela preta em
muitos notebooks. Por isso `config.kdl` **nao** define `GBM_BACKEND` nem
`__GLX_VENDOR_LIBRARY_NAME` globalmente.

Para rodar um aplicativo na NVIDIA:

```bash
nvidia-offload blender
nvidia-offload steam
nvidia-offload glxinfo | grep "OpenGL renderer"   # deve dizer NVIDIA
```

Diagnostico:

```bash
lsmod | grep nvidia                  # nvidia_drm carregado
cat /sys/module/nvidia_drm/parameters/modeset   # deve ser Y
ls -l /dev/dri/by-path/              # qual render node e de quem
nvidia-smi
```

Tela preta no boot ou consumo alto em idle: o niri pode ter escolhido a dGPU.
Descomente `render-drm-device` no bloco `debug` de
`~/.config/niri/config.kdl`, apontando para o render node da Intel.

---

## 6. Antigravity IDE

Google nao publica URL estavel/versionada do artefato Linux. Pegue o link em
<https://antigravity.google/download/> e coloque em
`files/system/etc/custom-antigravity-url` (uma linha, sem `#`).

`30-install-antigravity.sh` detecta o formato pelo mime-type e trata
`.tar.gz`, `.zip`, `.deb`, `.rpm` e binario/AppImage. Download ou formato
invalido gera **aviso, nao falha** — build semanal nao quebra por causa de uma
URL que mudou. Confira no log do Actions:

```
AVISO: URL do Antigravity nao definida - IDE NAO sera instalado.
```

---

## 7. DBeaver com TLS 1.0

Dois arquivos, permanentes porque vivem na camada da imagem:

1. `/etc/dbeaver-custom-java.security` — `jdk.tls.disabledAlgorithms` **sem**
   `TLSv1` e `TLSv1.1`.
2. `/usr/share/dbeaver-ce/dbeaver.ini` — recebe no build, logo apos a linha
   `-vmargs`:
   ```
   -Djava.security.properties=/etc/dbeaver-custom-java.security
   ```

Um `=` simples (nao `==`) faz a JVM **sobrepor** apenas essa propriedade, em vez
de substituir todo o `java.security`. Como o patch e aplicado em cada build,
atualizacoes do DBeaver nunca o revertem.

Verificar depois de instalar:

```bash
grep -A2 '^-vmargs' /usr/share/dbeaver-ce/dbeaver.ini
```

> TLS 1.0/1.1 sao protocolos obsoletos e vulneraveis (BEAST, POODLE, suites
> RC4/3DES). Reabilitados aqui de proposito para acesso a bancos legados —
> mantenha esse trafego em rede confiavel ou dentro da VPN.

---

## 8. Estrutura do repositorio

```
recipes/recipe.yml                 modulos files/script/dnf/systemd/default-flatpaks/signing
.github/workflows/build.yml        build semanal + on-demand, assinatura cosign
files/scripts/
  10-import-repo-keys.sh           chaves GPG Docker/Chrome/Brave/Mullvad
  15-prepare-docker.sh             resolve releasever + remove pacotes conflitantes
  20-install-dbeaver-tls.sh        DBeaver CE + patch do dbeaver.ini
  30-install-antigravity.sh        empacota o IDE em /usr/lib + .desktop
  40-enable-transient-root.sh      root.transient para o /snap de topo
  50-install-claude-cli.sh         claude em /usr/bin (prefixo /usr, nao /usr/local)
files/system/
  etc/yum.repos.d/*.repo           docker-ce, google-chrome, brave, mullvad
  etc/dbeaver-custom-java.security TLS 1.0/1.1 liberados
  etc/profile.d/custom-dev-env.sh  brew, cargo, sdkman, /snap/bin no PATH
  etc/custom-inir-repo             URL do repo do iNiR  <-- EDITAR
  etc/custom-antigravity-url       URL do artefato do IDE <-- EDITAR
  etc/systemd/system/
    snap.mount                     bind /var/lib/snapd/snap -> /snap
    setup-user-groups.service      usermod -aG dialout,docker (UID >= 1000)
    homebrew-prepare.service       cria /home/linuxbrew com dono correto
  etc/skel/
    .config/niri/config.kdl        config base do niri + autostart do iNiR
    .bashrc.d/00-custom-dev-env.sh carrega o env em shell interativo
    .zshrc                         idem para zsh
  usr/bin/nvidia-offload           PRIME render offload (dGPU por aplicativo)
  usr/lib/sysusers.d/custom-groups.conf    grupos docker e dialout
  usr/lib/tmpfiles.d/custom-toplevel.conf  /snap e symlink do claude
  usr/lib/systemd/user/
    custom-first-run.service       provisiona HOME no primeiro login
    custom-inir-update.{service,timer}  update semanal do iNiR
  usr/libexec/
    custom-setup-user-groups       logica dos grupos
    custom-homebrew-prepare        logica do /home/linuxbrew
    custom-first-run-setup         brew + sdkman + rustup + iNiR (com stamps)
    custom-inir-update             git pull + inir update
    custom-niri-autostart          polkit, xwayland-satellite, nm-applet, iNiR
```

---

## 9. Build local (opcional, antes de dar push)

```bash
# CLI do BlueBuild
brew install blue-build/tap/bluebuild   # ou: npm i -g @blue-build/cli

bluebuild build recipes/recipe.yml      # precisa de podman/docker + ~30 GB livres
```

## 10. Verificacao da imagem publicada

Conferido na imagem `latest` (digest `sha256:426dad87`), nao no codigo-fonte:

| Item | Resultado |
|---|---|
| Patch TLS do DBeaver | `-Djava.security.properties=/etc/dbeaver-custom-java.security` presente logo apos `-vmargs`; a propriedade `jdk.tls.disabledAlgorithms` nao lista `TLSv1` nem `TLSv1.1` |
| Raiz transiente | `[root] transient = true` em `/usr/lib/ostree/prepare-root.conf` |
| Binarios | `claude`, `node`, `npm`, `npx`, `niri`, `docker`, `wget`, `snap`, `nvidia-offload` todos em `/usr/bin` |
| Units de sistema | `docker`, `containerd`, `snapd.socket`, `snap.mount`, `setup-user-groups`, `homebrew-prepare` — todas `enabled` |
| Units de usuario | `custom-first-run.service`, `custom-inir-update.timer` — `enabled` globalmente |
| Skel e helpers | `config.kdl`, `.zshrc`, `custom-dev-env.sh`, `custom-inir-repo`, `custom-first-run-setup`, `custom-groups.conf` presentes |
| URL do iNiR | `https://github.com/snowarch/iNiR.git` |
| Assinatura | `cosign verify --key cosign.pub` valida contra o digest publicado |

Versoes na imagem:

```
niri 26.04       docker-ce 29.10.0     mullvad-vpn 2026.5
dbeaver-ce 26.2.5  chrome 157.0.8103.78  brave 1.99.57
snapd 2.77.1     nodejs24 24.18.0      mate-polkit 1.28.1
nvidia-driver 620.70.06 + kmod-nvidia 620.70.06
```

O driver NVIDIA vem como `kmod-nvidia` pre-compilado pelo Universal Blue, nao
como `akmod-nvidia` (que compilaria no boot). Os modulos ficam em
`/usr/lib/modules/<kernel>/extra/nvidia/`.

---

## 11. Diagnostico

```bash
rpm-ostree status                              # qual imagem esta em uso
systemctl status snap.mount snapd.service      # snap funcionando
findmnt /snap                                  # bind mount ativo
systemctl status setup-user-groups.service      # grupos aplicados
journalctl --user -u custom-first-run           # provisionamento do HOME
cat /usr/lib/ostree/prepare-root.conf           # root.transient = true
grep -A2 '^-vmargs' /usr/share/dbeaver-ce/dbeaver.ini
docker run --rm hello-world                    # depois de relogar
```
