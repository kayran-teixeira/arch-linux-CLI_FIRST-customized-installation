# Controle Vivo de Progresso e Roadmap (`PROGRESS.md`)

Este documento rastreia o estado atual de maturidade do projeto `arch-bootstrap`, histórico de implementações concluídas, backlog de melhorias e dívidas técnicas mapeadas.

> **Regra para Agentes de IA:** Sempre que você concluir uma tarefa, implementar um novo módulo ou identificar uma dívida técnica, você **DEVE** atualizar este arquivo refletindo a nova realidade do projeto.

---

## 1. Status Geral do Projeto

* **Estado Atual:** `Pronto para Uso / Baseline Estável` (V2.0)
* **Kernel Padrão:** `linux` (Arch Oficial) com suporte documentado ao `linux-cachyos` (BORE Scheduler)
* **Arquitetura de Boot:** UEFI Nativo (GPT) via `systemd-boot` (ou GRUB)
* **Armazenamento:** Btrfs com subvolumes planos (`@`, `@home`, `@pkg`, `@log`, `@snapshots`), compressão `zstd:3` e Snapper
* **Interface:** TTY1 puro com autostart condicional do Hyprland Monocle sem display manager

---

## 2. Marcos Concluídos (Milestones)

### Fase 1: Fundação do Sistema Base e Hardware
- [x] **Orquestrador Live ISO (`install.sh`):** Implementado com validações de pré-voo (`EUID`, montagem em `/mnt`, internet), `pacstrap`, `genfstab` e execução sequencial dos scripts dentro do `arch-chroot`.
- [x] **Configuração Base (`01-base-chroot.sh`):** Fuso horário `America/Sao_Paulo`, locales `en_US`/`pt_BR`, teclado `br-abnt2`, hostname e tuning de buffer no kernel (`vm.dirty_bytes` absoluto para eliminar travamento de USB).
- [x] **Gerenciamento de Memória (ZRAM):** Instalação do `zram-generator` configurando `/etc/systemd/zram-generator.conf` com algoritmo `zstd` em substituição ao swap em disco.
- [x] **Segurança de Rede Inicial:** Habilitação do `firewalld.service` logo na base chroot.
- [x] **GPU NVIDIA e Early KMS (`02-hardware.sh`):** Suporte nativo ao `nvidia-open-dkms` (padrão) e `nvidia-dkms`, injeção dos módulos no `mkinitcpio.conf`, hook automático de recompilação do initramfs, flags DRM do Wayland e suporte a PRIME Render Offload (`nvidia-prime`).
- [x] **Controle Térmico Dell G15 (`awccd`):** Módulo `dell-wmi`, compilação do daemon via AUR com elevação de sudo efêmera e keybinds no Hyprland (`Super+G` para G-Mode/Performance).
- [x] **Pipeline de Áudio PipeWire:** Remoção de conflitos do PulseAudio e provisionamento do stack PipeWire + WirePlumber com suporte a multilib 32-bit.

### Fase 2: Virtualização, Ferramentas CLI e Desktop
- [x] **Virtualização KVM/QEMU (`03-virtualization.sh`):** Hipervisor KVM completo, módulo `vhost_net`, autostart da bridge virtual `virbr0`, socket libvirt restrito e interface gráfica `virt-manager`.
- [x] **AUR Helper Yay (`04-cli-tools.sh` / `04-aur-yay.sh`):** Provisionamento seguro com concessão temporária de sudo NOPASSWD sob `trap cleanup EXIT` e flags de limpeza automática ativadas.
- [x] **Desktop e Particionamento (`05-packages.sh`):** Resolução do arquivo truncado, instalação do Dolphin com tema Breeze e codecs Wayland, GParted, suite completa de compressão (`ouch`, `7z`, `zstd`, `tar`) e Steam com fontes Liberation.
- [x] **Matriz Java e Runtimes Python:** Instalação de JDK 8, 11, 17 e 21 (Java 17 padrão via `archlinux-java`), e ferramentas de isolamento Python (`uv`, `pipx`) em conformidade com a PEP 668.
- [x] **Gerenciamento Híbrido de GPU:** Instalação do `envycontrol` via AUR para alternância entre modos `hybrid`, `integrated` e `nvidia`.

### Fase 3: Desenvolvimento Mobile, IA e Terminal Moderno
- [x] **Desenvolvimento Android (`06-android-dev.sh`):** ADB, fastboot, regras do udev (`android-udev`), grupo `adbusers`, aumento do limite de inotify do kernel (`524288`) para o Gradle e Android Studio via AUR.
- [x] **Terminal e Shell Fish (`07-terminal-fish.sh`):** Emulador Kitty de ultra-baixa latência, Fish shell configurado, Fastfetch compacto, Starship prompt, Zoxide (`cd` inteligente), Eza (substituto do `ls`), FZF, Htop e função interativa `colinha`.
- [x] **Cheatsheets Tealdeer:** 15 páginas customizadas locais em `~/.local/share/tealdeer/pages/custom/` com consulta offline via `t arch-*`.
- [x] **Hyprland Monocle (`08-dotfiles.sh`):** Modo monocle puro (0 gaps, 0 bordas, sem blur ou animações), workspaces isolados por classe de janela, Mako e autostart via TTY1 com variáveis NVIDIA Wayland.
- [x] **Serviços de IA e Docker (`09-dev-services.sh`):** Docker com limites de log em `/etc/docker/daemon.json`, FNM (Fast Node Manager), Claude Code CLI e Antigravity CLI (`agy`).
- [x] **Snapshots Btrfs (`10-btrfs-snapper.sh`):** Provisionamento de perfis Snapper para `/` e `/home`, hook `snap-pac` para snapshots automáticos antes/depois do pacman, políticas de retenção e timers de limpeza.

### Fase 4: Base de Conhecimento e Documentação de IA (`gemini/`)
- [x] Reescrita profunda do [README.md](../README.md) com manual de particionamento e colinha operacional completa.
- [x] Criação da pasta `gemini/` contendo [INDEX.md](INDEX.md), [CONTEXT.md](CONTEXT.md), [FIREWALL.md](FIREWALL.md), [AGENTS_AND_SKILLS.md](AGENTS_AND_SKILLS.md) e [TOKEN_OPTIMIZATION_AND_AI_OPS.md](TOKEN_OPTIMIZATION_AND_AI_OPS.md).

---

## 3. Tarefas em Andamento (In Progress)

* [ ] Validação de execução completa em máquina virtual KVM limpa (teste de ponta a ponta do `install.sh`).
* [ ] Validação do hook `grub-btrfsd` em cenários onde o usuário opta explicitamente por GRUB em vez de `systemd-boot`.

---

## 4. Backlog de Futuras Melhorias

### Prioridade Alta (Essencial / Estabilidade)
- [ ] **Secure Boot com `sbctl`:** Adicionar módulo opcional para assinar o kernel e módulos da NVIDIA com chaves personalizadas da placa-mãe.
- [ ] **Configuração Automática de Espelhos com `reflector`:** Adicionar chamada do reflector no `install.sh` antes do `pacstrap` para priorizar espelhos brasileiros de alta velocidade.

### Prioridade Média (Ergonomia e Ferramentas)
- [ ] **Gerenciador de Dotfiles via `gnu-stow`:** Modularizar os arquivos de configuração de `~/.config` para facilitar sincronização via Git.
- [ ] **Perfil de Economia de Energia com `auto-cpufreq`:** Otimizar consumo de bateria do Dell G15 quando desconectado da tomada.
- [ ] **Integração com Plymouth:** Adicionar tela de boot silenciosa opcional para quem não deseja logs de inicialização do kernel.

### Prioridade Baixa (Opcionais)
- [ ] **Tema Starship Customizado:** Adicionar preset estilizado escuro no repositório combinando com as cores do Kitty (`#0f1117`).

---

## 5. Dívidas Técnicas e Observações Mapeadas

1. **Dependência do Repositório do `awccd-git` no AUR:**
   * O `awccd-git` requer compilação via GCC/CMake. Caso o autor do repositório upstream altere dependências, a compilação pode falhar. Solução: manter monitoramento da compatibilidade da controladora WMI da Dell.
2. **Conflito Potencial entre Docker e Regras de Firewall:**
   * Documentado exaustivamente em [FIREWALL.md](FIREWALL.md). O Docker pode expor portas mapeadas para `0.0.0.0` ignorando o Firewalld. A mitigação de usar sempre `127.0.0.1` foi documentada e reforçada nos guardrails de IA.
