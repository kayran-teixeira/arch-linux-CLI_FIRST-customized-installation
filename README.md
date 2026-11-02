# Arch Linux Bootstrap (CLI-First Setup)

Guia de instalação mínima, determinística e modular do Arch Linux focado em terminal acelerado via GPU, compositor Wayland monocle sem decorações (Hyprland), suporte a GPU híbrida NVIDIA (módulos Open e Proprietário via DKMS), controle térmico para Dell G15, virtualização KVM/QEMU, particionamento Btrfs com snapshots automáticos (Snapper), repositórios de alta performance CachyOS, firewall ativo e ferramentas modernas de desenvolvimento e inteligência artificial (Docker, Node.js, Claude Code e Google Antigravity CLI).

---

## 1. Pré-Requisitos na Firmware (BIOS/UEFI)

Antes de iniciar a Live ISO do Arch Linux, acesse as configurações da placa-mãe/firmware e garanta os seguintes ajustes:

* **Boot Mode:** Estritamente `UEFI Native` (desative o modo legado/CSM).
* **Secure Boot:** `Disabled` (o kernel padrão e os módulos DKMS da NVIDIA não são assinados pela chave de fábrica da Microsoft).
* **Virtualização:** `Intel Virtualization Technology (VT-x)` e `Intel VT-d` (ou `AMD-V` e `AMD IOMMU`) definidos como `Enabled`.
* **SATA/NVMe Operation:** Definido como `AHCI` ou `NVMe Mode` (evite modos proprietários como `RAID / Intel RST`, que ocultam os discos NVMe no kernel Linux).

---

## 2. Inicialização e Conexão na Live ISO

Dê boot pelo pendrive da mídia oficial do Arch Linux. Ao atingir o prompt root do Zsh:

### 2.1. Ajuste de Layout do Teclado (se aplicável)
```bash
loadkeys br-abnt2
```

### 2.2. Conexão com a Internet
* **Via Cabo (Ethernet):** Geralmente autoconfigurado via DHCP. Teste com `ping -c 3 archlinux.org`.
* **Via Wi-Fi (`iwctl`):**
```bash
iwctl
# Dentro do prompt do iwd:
device list
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "NomeDaSuaRede"
exit
```

### 2.3. Sincronização do Relógio do Sistema
```bash
timedatectl set-ntp true
```

---

## 3. Particionamento e Montagem dos Discos

> **ATENÇÃO:** O particionamento é intencionalmente manual. Não deixe scripts adivinharem unidades de disco para evitar a perda acidental de dados em partições adjacentes ou em discos secundários.

Identifique o disco de destino:
```bash
lsblk -d -o NAME,SIZE,MODEL,TRAN
```
*(Assumiremos `/dev/nvme0n1` neste guia. Ajuste para a sua unidade).*

### 3.1. Criando as Partições com `cfdisk`
```bash
cfdisk /dev/nvme0n1
```
Selecione o tipo de tabela `gpt` e configure o layout:

1. **Partição EFI:**
   * Tamanho: `1024M` (1 GB).
   * Tipo: `EFI System`.
2. **Partição Raiz (Root):**
   * Tamanho: Restante do disco (ou o espaço desejado).
   * Tipo: `Linux filesystem`.

Grave as alterações com `Write` (digite `yes`) e selecione `Quit`.

---

### 3.2. Formatação dos Sistemas de Arquivos

#### Opção A: Formatação Recomendada com Btrfs e Subvolumes (Snapper Ready)
Esta é a configuração padrão recomendada para garantir proteção contra atualizações quebradas via snapshots instantâneos:

```bash
# 1. Formata a partição EFI em FAT32
mkfs.fat -F32 /dev/nvme0n1p1

# 2. Formata a partição Raiz em Btrfs com rótulo
mkfs.btrfs -L "ARCH_ROOT" /dev/nvme0n1p2

# 3. Monta temporariamente para criar os subvolumes planos
mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@snapshots
umount /mnt

# 4. Monta os subvolumes definitivos com compressão Zstandard e otimizações SSD
mount -o compress=zstd:3,ssd,discard=async,subvol=@ /dev/nvme0n1p2 /mnt
mount --mkdir -o compress=zstd:3,ssd,discard=async,subvol=@home /dev/nvme0n1p2 /mnt/home
mount --mkdir -o compress=zstd:3,ssd,discard=async,subvol=@pkg /dev/nvme0n1p2 /mnt/var/cache/pacman/pkg
mount --mkdir -o compress=zstd:3,ssd,discard=async,subvol=@log /dev/nvme0n1p2 /mnt/var/log
mount --mkdir -o compress=zstd:3,ssd,discard=async,subvol=@snapshots /dev/nvme0n1p2 /mnt/.snapshots
mount --mkdir /dev/nvme0n1p1 /mnt/boot
```

#### Opção B: Formatação Simples (Ext4)
```bash
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 -L "ARCH_ROOT" /dev/nvme0n1p2

mount /dev/nvme0n1p2 /mnt
mount --mkdir /dev/nvme0n1p1 /mnt/boot
```

---

## 4. Disparo do Instalador Automatizado

Com as partições montadas em `/mnt`, clone este repositório ou baixe os scripts:

```bash
cd /root
git clone https://github.com/kayran/arch-linux-CLI_FIRST-customized-installation.git arch-bootstrap
cd arch-bootstrap
chmod +x install.sh scripts/*.sh
```

Execute o orquestrador definindo as credenciais de usuário via variáveis de ambiente para evitar senhas expostas em logs:

```bash
TARGET_USER="kayran" USER_PASS="SuaSenhaSegura" ROOT_PASS="SenhaRootSegura" ./install.sh
```

O orquestrador `install.sh` executará automaticamente:
1. `pacstrap` do sistema base (`base`, `base-devel`, `linux`, `linux-firmware`, `networkmanager`);
2. Geração do `/etc/fstab` com identificadores UUID;
3. Entrada automática no `arch-chroot`;
4. Execução sequencial de todos os scripts modulares (`01` a `10`).

---

## 5. Pós-Instalação e Reinicialização

Após a conclusão bem-sucedida de todos os módulos:
```bash
umount -R /mnt
reboot
```

Retire o pendrive de instalação. O sistema iniciará no prompt do TTY1 pedindo suas credenciais. Ao logar no TTY1, o ambiente iniciará diretamente no terminal monocle acelerado por hardware sem gerenciador de login pesado.

---

## 6. Módulos do Sistema e Pacotes Instalados

| Módulo | Finalidade | Principais Pacotes Instalados |
| :--- | :--- | :--- |
| **`01-base-chroot.sh`** | Localização, sysctl I/O, usuário, ZRAM, firewall e bootloader | `fish`, `systemd-boot`, `zram-generator`, `firewalld`, `btrfs-progs`, timezone, sudoers, NetworkManager |
| **`02-hardware.sh`** | CPU microcode, GPU NVIDIA (Open/DKMS), PRIME, áudio e Dell G15 | `intel-ucode`/`amd-ucode`, `nvidia-open-dkms` (ou `nvidia-dkms`), `nvidia-prime`, `libva-nvidia-driver`, `nvtop`, `pipewire`, `wireplumber`, `awccd-git` |
| **`03-virtualization.sh`** | Virtualização KVM/QEMU, virt-manager e rede virtual | `qemu-desktop`, `libvirt`, `virt-install`, `virt-manager`, `edk2-ovmf`, `dnsmasq`, `iptables-nft` |
| **`04-cli-tools.sh`** | AUR Helper de alto desempenho | `yay`, `base-devel`, `git` |
| **`05-packages.sh`** | Desktop, particionamento, mídia, Java e EnvyControl | `dolphin`, `gparted`, `ouch`, `steam`, `obs-studio`, `jdk17-openjdk`, `code`, `atlauncher`, `envycontrol` |
| **`06-android-dev.sh`** | SDK Android, adb e emulador KVM | `android-tools`, `android-udev`, `scrcpy`, `android-studio`, sysctl inotify |
| **`07-terminal-fish.sh`** | Terminal Kitty, Shell Fish, Starship, Zoxide, Eza, FZF, Htop e Cheatsheets | `kitty`, `fish`, `starship`, `zoxide`, `eza`, `fzf`, `htop`, `fastfetch`, `tealdeer`, `ttf-jetbrains-mono-nerd` |
| **`08-dotfiles.sh`** | Hyprland Monocle Wayland puro e Mako | `hyprland`, `xdg-desktop-portal-hyprland`, `polkit-gnome`, `mako`, `brightnessctl` |
| **`09-dev-services.sh`** | Containers, Web Runtime e Agentes de IA | `nodejs`, `npm`, `docker`, `docker-compose`, `docker-buildx`, `claude-code`, `agy` (Antigravity CLI) |
| **`10-btrfs-snapper.sh`** | Snapshots automáticos Btrfs e retenção | `snapper`, `snap-pac`, timers de higienização e integração grub-btrfs |

---

## 7. Colinha Operacional / Cheatsheet de Administração CLI

Todas as páginas abaixo estão integradas ao utilitário `tealdeer` no terminal (`t <pagina>` ou `tldr <pagina>`).

---

### 7.1. Gerenciamento e Limpeza de Snapshots Btrfs (`snapper`)

O `snapper` gerencia cópias de segurança instantâneas (snapshots do tipo *copy-on-write*) no Btrfs. Com o pacote `snap-pac` instalado, todo `pacman -S` ou `pacman -Syu` gera um snapshot **pre** e **post** automaticamente.

* **Listar todos os snapshots da partição raiz:**
  ```bash
  snapper -c root list
  ```
* **Listar snapshots do subvolume pessoal (`/home`):**
  ```bash
  snapper -c home list
  ```
* **Criar um snapshot manual antes de testar scripts ou drivers:**
  ```bash
  sudo snapper -c root create --description "Antes-de-atualizar-nvidia"
  ```
* **Deletar um snapshot específico para liberar espaço em disco:**
  ```bash
  sudo snapper -c root delete 15
  ```
* **Deletar um intervalo de snapshots antigos:**
  ```bash
  sudo snapper -c root delete 5-20
  ```
* **Ver as diferenças de arquivos entre dois snapshots ou contra o sistema atual (0):**
  ```bash
  snapper -c root status 12..0
  snapper -c root diff 12..0 /etc/pacman.conf
  ```
* **Limpeza e Manutenção de Espaço no Btrfs:**
  * **Balancear blocos não alocados (recupera espaço fragmentado):**
    ```bash
    sudo btrfs balance start -dusage=50 -musage=50 /
    ```
  * **Verificar integridade e reparar blocos corrompidos silenciosamente (Scrub):**
    ```bash
    sudo btrfs scrub start /
    sudo btrfs scrub status /
    ```
  * **Calcular o espaço real ocupado excluindo cópias idênticas:**
    ```bash
    sudo btrfs filesystem du -s /
    ```

---

### 7.2. Repositório CachyOS e Otimizações de Kernel

O CachyOS fornece repositórios com binários compilados especificamente com flags de microarquitetura otimizada (`x86-64-v3` com AVX2 / `x86-64-v4` com AVX-512) e kernels com scheduler **BORE (Burst-Oriented Response Enhancer)** para máxima fluidez em desktop e jogos.

#### 1. Verificar Compatibilidade da sua CPU:
Execute o comando abaixo para confirmar se seu processador suporta `x86-64-v3`:
```bash
/lib64/ld-linux-x86-64.so.2 --help | grep -i supported
# Deve retornar: "x86-64-v3 (supported, searched)"
```

#### 2. Como Adicionar os Repositórios do CachyOS:
Execute o instalador oficial de chaves e mirrors do CachyOS:
```bash
curl -O https://mirror.cachyos.org/cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz && cd cachyos-repo
sudo ./cachyos-repo.sh
```

Ou adicione manualmente no `/etc/pacman.conf` **acima** dos repositórios oficiais do Arch:
```ini
[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
```

#### 3. Instalar o Kernel CachyOS e Atualizar Espelhos:
* **Instalar kernel de alta responsividade e headers DKMS:**
  ```bash
  sudo pacman -S linux-cachyos linux-cachyos-headers
  sudo mkinitcpio -P
  ```
* **Otimizar servidores de download para a menor latência:**
  ```bash
  sudo cachyos-rate-mirrors
  ```

---

### 7.3. Módulos NVIDIA (DKMS Open vs Proprietário) e NVIDIA Prime

#### 1. Diferença entre `nvidia-open-dkms` e `nvidia-dkms`:
* **`nvidia-open-dkms` (Módulos Open Source Oficiais):**
  * **Recomendado para:** Arquiteturas modernas Turing e superiores — Séries **GTX 16xx, RTX 20xx, RTX 30xx, RTX 40xx e RTX 50xx**.
  * Código do módulo de kernel disponibilizado publicamente pela NVIDIA, com melhor integração a kernels customizados (como o `linux-cachyos` e `linux-zen`), melhor gerenciamento de energia e suporte a recursos modernos de Wayland.
* **`nvidia-dkms` (Proprietário Fechado Clássico):**
  * **Recomendado para:** Arquiteturas legadas (séries **Maxwell GTX 9xx** e **Pascal GTX 10xx**) que não suportam a interface aberta de firmware da NVIDIA.

#### 2. Como Alternar entre os Módulos com Segurança:
O `pacman` detecta o conflito e substitui o pacote automaticamente:
```bash
# Migrar para o módulo moderno Open Source:
sudo pacman -S nvidia-open-dkms

# Ou retornar para o módulo proprietário fechado:
sudo pacman -S nvidia-dkms

# Regenerar imagens de boot com os módulos corretos:
sudo mkinitcpio -P
```

#### 3. NVIDIA Prime e PRIME Render Offload:
Em notebooks híbridos com iGPU (Intel/AMD) e dGPU dedicada NVIDIA:
* **Executar qualquer jogo ou aplicação pesada na placa NVIDIA sob demanda:**
  ```bash
  prime-run steam
  prime-run obs
  prime-run blender
  ```

#### 4. Alternador de Modos de GPU para Notebooks (`envycontrol`):
O `envycontrol` permite desligar totalmente a GPU NVIDIA para poupar bateria ou travar na placa dedicada:
* **Verificar o modo gráfico em uso:**
  ```bash
  envycontrol --query
  ```
* **Modo Híbrido (Padrão):** iGPU renderiza a área de trabalho; NVIDIA acorda apenas com `prime-run`:
  ```bash
  sudo envycontrol -s hybrid
  ```
* **Modo Integrado (Máxima Bateria):** Desliga a energia da controladora PCIe da NVIDIA:
  ```bash
  sudo envycontrol -s integrated
  ```
* **Modo Dedicado (Máximo Desempenho):** dGPU controla diretamente a saída de vídeo:
  ```bash
  sudo envycontrol -s nvidia
  ```

---

### 7.4. Administração de Firewall com `firewalld`

O daemon `firewalld` gerencia regras de filtragem dinâmicas através de **zonas de confiança** (ex: `public`, `home`, `trusted`, `drop`), sem derrubar conexões ativas.

* **Verificar estado do firewall e zona em uso:**
  ```bash
  sudo firewall-cmd --state
  sudo firewall-cmd --get-active-zones
  ```
* **Listar todas as portas, regras e serviços abertos na zona ativa:**
  ```bash
  sudo firewall-cmd --list-all
  ```
* **Liberar um serviço de rede conhecido de forma permanente:**
  ```bash
  sudo firewall-cmd --add-service=ssh --permanent
  sudo firewall-cmd --add-service=syncthing --permanent
  sudo firewall-cmd --reload
  ```
* **Abrir uma porta TCP específica (ex: servidores web locais, containers):**
  ```bash
  sudo firewall-cmd --add-port=8080/tcp --permanent
  sudo firewall-cmd --reload
  ```
* **Abrir uma porta UDP específica (ex: servidores de jogos):**
  ```bash
  sudo firewall-cmd --add-port=19132/udp --permanent
  sudo firewall-cmd --reload
  ```
* **Fechar/Remover uma porta que não precisa mais ficar acessível:**
  ```bash
  sudo firewall-cmd --remove-port=8080/tcp --permanent
  sudo firewall-cmd --reload
  ```
* **Bloquear um endereço IP invasor imediatamente com Rich Rule:**
  ```bash
  sudo firewall-cmd --add-rich-rule='rule family="ipv4" source address="192.168.1.150" reject' --permanent
  sudo firewall-cmd --reload
  ```
* **Desativar o firewall temporariamente para testes:**
  ```bash
  sudo systemctl stop firewalld.service
  ```

---

### 7.5. Gerenciamento de Versões Java (`archlinux-java`)

No Arch Linux, múltiplos JDKs podem coexistir em `/usr/lib/jvm/`. A ferramenta nativa `archlinux-java` controla qual versão fornece os binários `java`, `javac` e `jar` no PATH.

* **Listar todas as versões de JDK instaladas no sistema:**
  ```bash
  archlinux-java status
  ```
* **Alterar a versão padrão global do Java:**
  ```bash
  sudo archlinux-java set java-17-openjdk
  # ou para JDK 21:
  sudo archlinux-java set java-21-openjdk
  ```
* **Desativar a versão Java em uso:**
  ```bash
  sudo archlinux-java unset
  ```
* **Verificar a versão ativa e caminho no terminal:**
  ```bash
  java -version
  which java
  ```
* **Configurar `JAVA_HOME` manualmente no Fish shell (`~/.config/fish/config.fish`):**
  ```fish
  set -gx JAVA_HOME /usr/lib/jvm/default
  ```

---

### 7.6. Gerenciamento de Serviços com `systemctl`

O Systemd controla daemons de sistema (nível root) e serviços do usuário comum (sem sudo).

#### Comandos de Nível de Sistema (requer sudo):
* **Iniciar / Parar um serviço imediatamente:**
  ```bash
  sudo systemctl start docker.service
  sudo systemctl stop docker.service
  ```
* **Reiniciar ou recarregar configurações sem encerrar o processo:**
  ```bash
  sudo systemctl restart NetworkManager.service
  sudo systemctl reload nginx.service
  ```
* **Habilitar para inicializar no boot e iniciar imediatamente (`--now`):**
  ```bash
  sudo systemctl enable --now libvirtd.service
  sudo systemctl enable --now firewalld.service
  ```
* **Desabilitar inicialização no boot:**
  ```bash
  sudo systemctl disable awccd.service
  ```
* **Verificar se um serviço está ativo (retorno 0 se rodando):**
  ```bash
  systemctl is-active docker
  systemctl is-enabled docker
  ```
* **Bloquear completamente um serviço contra qualquer tentativa de execução (Mask):**
  ```bash
  sudo systemctl mask pulseaudio.service
  sudo systemctl unmask pulseaudio.service
  ```
* **Listar serviços que falharam durante a inicialização:**
  ```bash
  systemctl --failed
  ```
* **Recarregar o systemd após editar arquivos `.service` manuais:**
  ```bash
  sudo systemctl daemon-reload
  ```

#### Serviços em Nível de Usuário (executados sem sudo):
* **Gerenciar daemons da sessão atual (PipeWire, WirePlumber, agentes Polkit):**
  ```bash
  systemctl --user status pipewire.service
  systemctl --user restart wireplumber.service
  ```

---

### 7.7. Diagnóstico e Análise de Logs com `journalctl`

O `journalctl` consulta os logs binários indexados pelo daemon `systemd-journald`.

* **Seguir logs em tempo real (estilo `tail -f`):**
  ```bash
  journalctl -u docker.service -f
  ```
* **Ver logs filtrados por um serviço específico desde o último boot:**
  ```bash
  journalctl -u libvirtd.service -b
  ```
* **Exibir apenas erros, falhas críticas e alertas do boot atual:**
  ```bash
  journalctl -b -p err
  ```
* **Filtrar logs por janela de tempo específica:**
  ```bash
  journalctl --since "15 minutes ago"
  journalctl --since "2026-11-01 22:00:00" --until "2026-11-01 23:00:00"
  ```
* **Inspecionar logs do Kernel (equivalente ao `dmesg` moderno):**
  ```bash
  journalctl -k -b
  ```
* **Verificar o espaço em disco consumido pelos arquivos de log:**
  ```bash
  journalctl --disk-usage
  ```

---

### 7.8. Compressão e Extração de Arquivos no Linux

#### 1. Sintaxe Universal Moderna (`ouch`):
* **Descompactar qualquer arquivo (`.tar.gz`, `.tar.zst`, `.zip`, `.rar`, `.7z`):**
  ```bash
  ouch decompress arquivo.tar.gz
  # No shell Fish deste setup, há o alias configurado:
  cat arquivo.tar.zst
  ```
* **Compactar pastas ou múltiplos arquivos de forma transparente:**
  ```bash
  ouch compress pasta/ backup.tar.zst
  ouch compress doc1.txt doc2.pdf pacote.zip
  ```

#### 2. Utilitários Clássicos Padrão:
* **Arquivos TAR (`.tar` e variações compactadas):**
  * `tar -czvf arquivo.tar.gz /caminho/pasta/` → Criar arquivo compactado com gzip.
  * `tar -xzvf arquivo.tar.gz` → Extrair arquivo tar.gz no diretório atual.
  * `tar -xjvf arquivo.tar.bz2` → Extrair arquivo tar.bz2.
  * `tar -xvf arquivo.tar.xz` → Extrair arquivo tar.xz moderno.
  * `tar -tvf arquivo.tar.gz` → Listar conteúdo do arquivo sem extrair.
* **Arquivos ZIP:**
  * `zip -r pacote.zip pasta/` → Compactar recursivamente.
  * `unzip pacote.zip` → Extrair pacote zip.
  * `unzip -l pacote.zip` → Listar arquivos dentro do zip.
* **Arquivos 7-Zip e RAR:**
  * `7z a backup.7z pasta/` → Criar arquivo 7z de alta compressão.
  * `7z x backup.7z` → Extrair mantendo árvore completa de diretórios.
  * `unrar x arquivo.rar` → Extrair arquivo RAR com integridade de pastas.
* **Compressão Zstandard ultrarrápida (`zstd`):**
  * `zstd arquivo.img` → Comprime gerando `arquivo.img.zst`.
  * `zstd -d arquivo.img.zst` → Descomprime para `arquivo.img`.

---

### 7.9. Sessões `sudo`, Permissões e Gestão de Usuários

* **Renovar o tempo de expiração do sudo sem rodar comandos:**
  ```bash
  sudo -v
  ```
* **Encerrar e revogar a autenticação do sudo imediatamente:**
  ```bash
  sudo -k
  ```
* **Editar o arquivo `/etc/sudoers` com validação de sintaxe mandatória:**
  ```bash
  sudo visudo
  sudo visudo -f /etc/sudoers.d/10-installer
  ```
* **Criar novo usuário comum com home e shell fish:**
  ```bash
  sudo useradd -m -g users -G wheel,video,audio,storage,input -s /usr/bin/fish novo_usuario
  ```
* **Adicionar usuário a grupos secundários (ex: docker, libvirt, adbusers):**
  ```bash
  sudo usermod -aG docker,libvirt,adbusers kayran
  ```
* **Consultar grupos:**
  ```bash
  groups
  id
  ```

---

### 7.10. Gerenciamento e Monitoramento de Processos

* **Monitores TUI interativos em tempo real:**
  ```bash
  btop     # Telemetria moderna e completa (CPU, GPU, memória, discos e rede)
  htop     # Visualização clássica, rápida e leve de árvore de processos
  ```
* **Listar processos ordenados pelo maior consumo de memória RAM:**
  ```bash
  ps aux --sort=-%mem | head -n 15
  ```
* **Listar processos ordenados por maior uso de CPU:**
  ```bash
  ps aux --sort=-%cpu | head -n 15
  ```
* **Localizar o PID de um processo pelo nome:**
  ```bash
  pgrep -l hyprland
  pidof kitty
  ```
* **Sinais de Encerramento:**
  * `pkill <nome_do_processo>` ou `kill <PID>` → **SIGTERM (15)** (encerramento limpo).
  * `pkill -9 <nome_do_processo>` ou `kill -9 <PID>` → **SIGKILL (9)** (mata imediatamente).
* **Alterar prioridade de CPU de um processo (Nice level: -20 máxima a +19 mínima):**
  ```bash
  sudo renice -n -5 -p <PID>
  ```

---

### 7.11. Limpeza e Higienização Geral do Sistema

* **Limpar cache do Pacman (manter as 2 versões mais recentes para rollback seguro):**
  ```bash
  sudo paccache -r
  ```
* **Limpar todo o cache de pacotes desinstalados:**
  ```bash
  sudo paccache -ruk0
  ```
* **Remover pacotes órfãos (bibliotecas sem uso):**
  ```bash
  # No shell Fish:
  sudo pacman -Rns (pacman -Qtdq)
  
  # No shell Bash:
  sudo pacman -Rns $(pacman -Qtdq)
  ```
* **Higienizar logs acumulados do `journalctl`:**
  ```bash
  sudo journalctl --vacuum-time=7d
  sudo journalctl --vacuum-size=200M
  ```
* **Limpar o ecossistema Docker (containers parados, redes vazias, imagens sem uso e volumes órfãos):**
  ```bash
  docker system prune -a --volumes
  ```
* **Verificar a integridade e saúde de discos SSD/NVMe (SMART):**
  ```bash
  sudo smartctl -a /dev/nvme0n1
  ```

---

### 7.12. Consultas Rápidas no Terminal (`tealdeer`)

O script `07-terminal-fish.sh` provisiona páginas customizadas do Tealdeer. No terminal Fish, basta usar o atalho `t`:

```bash
t arch-snapper       # Snapshots Btrfs, listagem, remoção e manutenção
t arch-cachyos       # Configuração de repositórios CachyOS e kernels BORE
t arch-nvidia        # NVIDIA Open vs Proprietário, prime-run e EnvyControl
t arch-firewall      # Firewalld, abertura de portas e zonas
t arch-java          # Comandos do archlinux-java
t arch-systemd       # Comandos do systemctl e journalctl
t arch-compression   # ouch, tar, zip, 7z e zstd
t arch-users-sudo    # sudo -v, sudo -k, timeout e grupos
t arch-processes     # btop, pgrep, pkill e prioridades
t arch-maintenance   # paccache, órfãos e limpeza de logs
t arch-disks         # udisksctl e montagem sem root
t arch-gpu           # awcc-cli do Dell G15 e nvtop
t arch-vm            # virsh, virt-manager e qemu
t arch-android       # adb e scrcpy
```

---

## 8. Ferramentas de Desenvolvimento e IA Adicionadas

O módulo `09-dev-services.sh` configura o ambiente de trabalho moderno:

### Docker & Containers
* Daemon ativado e gerenciado pelo systemd (`systemctl enable docker.service`).
* Usuário configurado no grupo `docker` para rodar containers sem necessitar de `sudo`.

### Claude Code CLI
* Instalado globalmente via npm (`@anthropic-ai/claude-code`).
* Executável: `claude`.

### Google Antigravity CLI (`agy`)
* Instalado em `~/.local/bin/agy` com acesso direto pelo shell Fish.
* Executável: `agy`.

---

## 9. Governança e Base de Conhecimento para IA (`gemini/`)

Este repositório adota um padrão de arquitetura cognitiva e documentação persistente voltada para assistentes autônomos de IA (**Google Antigravity CLI**, **Claude Code**, Cursor, etc.) localizado no diretório [gemini/](gemini/):

* **[gemini/INDEX.md](gemini/INDEX.md):** Ponto de entrada rápido e roteador de contexto para economizar tokens.
* **[gemini/PROGRESS.md](gemini/PROGRESS.md):** Controle vivo de progresso, marcos concluídos, tarefas em andamento e backlog.
* **[gemini/DECISIONS.md](gemini/DECISIONS.md):** Registro formal de decisões de arquitetura (ADRs) com justificativas e alternativas rejeitadas.
* **[gemini/RUNBOOK.md](gemini/RUNBOOK.md):** Playbooks operacionais passo a passo para resolução de incidentes (tela preta, rollback de snapshots, disco cheio, firewall).
* **[gemini/FIREWALL.md](gemini/FIREWALL.md):** Manual exaustivo de arquitetura do Firewalld, nftables e mitigação de bypass com Docker.
* **[gemini/CONTEXT.md](gemini/CONTEXT.md):** Especificação técnica master de hardware, particionamento e módulos.
* **[gemini/AGENTS_AND_SKILLS.md](gemini/AGENTS_AND_SKILLS.md):** Definição de personas de agentes, skills executáveis e guardrails de segurança.
* **[gemini/TOKEN_OPTIMIZATION_AND_AI_OPS.md](gemini/TOKEN_OPTIMIZATION_AND_AI_OPS.md):** Diretrizes para inspeções de sistema com baixo consumo de tokens.
* **[gemini/AI_WORKFLOW_RULES.md](gemini/AI_WORKFLOW_RULES.md):** Protocolo das quatro fases de trabalho de IA neste repositório.
