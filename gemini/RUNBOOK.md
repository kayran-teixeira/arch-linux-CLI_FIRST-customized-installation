# Playbooks Operacionais e Resolução de Incidentes (`RUNBOOK.md`)

Este documento reúne procedimentos operacionais padrão (SOPs) para diagnóstico e remediação rápida de incidentes no sistema operacional provisionado.

> **Para Agentes de IA:** Quando o usuário relatar uma falha técnica (ex: "tela preta", "disco cheio", "sem internet"), consulte o Runbook correspondente antes de executar comandos avulsos.

---

## Índice de Playbooks

* [Runbook 1: Falha Gráfica / Tela Preta após Atualização da NVIDIA ou Kernel](#runbook-1-falha-gráfica--tela-preta-após-atualização-da-nvidia-ou-kernel)
* [Runbook 2: Rollback Imediato de Sistema via Snapshots Btrfs (Snapper)](#runbook-2-rollback-imediato-de-sistema-via-snapshots-btrfs-snapper)
* [Runbook 3: Recuperação do Sistema via Live USB (Procedimento Chroot)](#runbook-3-recuperação-do-sistema-via-live-usb-procedimento-chroot)
* [Runbook 4: Esgotamento de Espaço em Disco (Armazenamento 100% Cheio)](#runbook-4-esgotamento-de-espaço-em-disco-armazenamento-100-cheio)
* [Runbook 5: Falha de Resolução de Nomes (DNS) ou Conexão Wi-Fi](#runbook-5-falha-de-resolução-de-nomes-dns-ou-conexão-wi-fi)
* [Runbook 6: Diagnóstico de Bloqueio de Portas no Firewall ou Containers Docker](#runbook-6-diagnóstico-de-bloqueio-de-portas-no-firewall-ou-containers-docker)
* [Runbook 7: Falha de Controle Térmico ou Modo G no Dell G15 (`awccd`)](#runbook-7-falha-de-controle-térmico-ou-modo-g-no-dell-g15-awccd)

---

### Runbook 1: Falha Gráfica / Tela Preta após Atualização da NVIDIA ou Kernel

#### Sintoma:
O sistema liga, conclui os logs do kernel, mas não entra no TTY1 ou o Hyprland falha ao iniciar com mensagem `No backend found` ou cursor travado.

#### Procedimento de Resolução:
1. **Acessar um terminal secundário:**
   Pressione `Ctrl + Alt + F2` ou `Ctrl + Alt + F3` para abrir um TTY texto limpo e faça login.
2. **Auditar os logs de erro da sessão:**
   ```bash
   journalctl -b -p err --no-pager -n 30
   ```
3. **Verificar se os módulos da NVIDIA foram carregados pelo kernel:**
   ```bash
   lsmod | grep nvidia
   ```
   *Se não retornar nada:* Os módulos DKMS não foram compilados para a versão atual do kernel.
4. **Recompilar os módulos DKMS e initramfs forçadamente:**
   ```bash
   sudo dkms autoinstall
   sudo mkinitcpio -P
   ```
5. **Alternar entre módulos Open e Proprietário (caso haja regressão de driver):**
   ```bash
   # Se estiver com nvidia-open-dkms:
   sudo pacman -S nvidia-dkms
   # Se estiver com nvidia-dkms:
   sudo pacman -S nvidia-open-dkms
   sudo mkinitcpio -P
   ```
6. **Reiniciar o sistema:**
   ```bash
   sudo reboot
   ```

---

### Runbook 2: Rollback Imediato de Sistema via Snapshots Btrfs (Snapper)

#### Sintoma:
Uma atualização quebrou pacotes essenciais, bibliotecas glibc ou arquivos de configuração do sistema.

#### Procedimento de Resolução:
1. **Listar os snapshots disponíveis:**
   ```bash
   snapper -c root list
   ```
   Identifique o ID do snapshot anterior ao evento que gerou o problema (procure pela coluna `Description` contendo `before pacman` ou sua descrição manual).
2. **Reverter arquivos ou diretórios específicos:**
   Se o problema foi em uma configuração de `/etc`:
   ```bash
   sudo snapper -c root undochange <ID_ANTIGO>..0 /etc/
   ```
3. **Rollback Completo do Subvolume Raiz:**
   ```bash
   # Restaura a raiz inteira para o estado do snapshot selecionado:
   sudo snapper -c root rollback <ID_ANTIGO>
   sudo reboot
   ```
   *Nota:* O `snapper rollback` cria um novo snapshot com o estado restaurado e define como o subvolume padrão de boot no Btrfs.

---

### Runbook 3: Recuperação do Sistema via Live USB (Procedimento Chroot)

#### Sintoma:
O sistema não atinge nem o menu de boot nem qualquer TTY devido a bootloader corrompido ou erro fatal de inicialização.

#### Procedimento de Resolução:
1. **Dar boot com o pendrive da Live ISO oficial do Arch Linux.**
2. **Montar as partições Btrfs corretamente em `/mnt`:**
   ```bash
   mount -o compress=zstd:3,subvol=@ /dev/nvme0n1p2 /mnt
   mount -o compress=zstd:3,subvol=@home /dev/nvme0n1p2 /mnt/home
   mount -o compress=zstd:3,subvol=@pkg /dev/nvme0n1p2 /mnt/var/cache/pacman/pkg
   mount -o compress=zstd:3,subvol=@log /dev/nvme0n1p2 /mnt/var/log
   mount /dev/nvme0n1p1 /mnt/boot
   ```
3. **Entrar no chroot:**
   ```bash
   arch-chroot /mnt
   ```
4. **Executar a manutenção necessária:**
   * Reinstalar o kernel e microcode:
     ```bash
     pacman -S linux linux-firmware intel-ucode
     mkinitcpio -P
     ```
   * Reinstalar o bootloader `systemd-boot`:
     ```bash
     bootctl install --path=/boot
     ```
5. **Sair e reiniciar:**
   ```bash
   exit
   umount -R /mnt
   reboot
   ```

---

### Runbook 4: Esgotamento de Espaço em Disco (Armazenamento 100% Cheio)

#### Sintoma:
Comandos falham com erro `No space left on device`, o Fish desativa autocomplete e o Pacman recusa instalar pacotes.

#### Procedimento de Resolução:
1. **Auditar o uso real do sistema de arquivos Btrfs:**
   ```bash
   btrfs filesystem usage /
   ```
2. **Esvaziar cache antigo de pacotes do Pacman:**
   ```bash
   # Mantém apenas a versão ativa (remove todas as versões antigas):
   sudo paccache -rk1
   # Remove pacotes já desinstalados:
   sudo paccache -ruk0
   ```
3. **Deletar snapshots acumulados do Snapper:**
   ```bash
   snapper -c root list
   # Deleta intervalo de snapshots velhos (ex: do 5 ao 20):
   sudo snapper -c root delete 5-20
   ```
4. **Limpar histórico de logs do journalctl:**
   ```bash
   sudo journalctl --vacuum-size=100M
   ```
5. **Limpar imagens e volumes mortos do Docker:**
   ```bash
   docker system prune -a --volumes -f
   ```
6. **Executar balanceamento para recuperar blocos de metadados não alocados:**
   ```bash
   sudo btrfs balance start -dusage=30 -musage=30 /
   ```

---

### Runbook 5: Falha de Resolução de Nomes (DNS) ou Conexão Wi-Fi

#### Sintoma:
O ping para endereços IP numéricos (ex: `8.8.8.8`) funciona, mas `ping archlinux.org` retorna `Name or service not known`.

#### Procedimento de Resolução:
1. **Verificar status do NetworkManager:**
   ```bash
   systemctl is-active NetworkManager
   ```
2. **Verificar se a interface Wi-Fi está bloqueada via software/hardware:**
   ```bash
   rfkill list
   # Se estiver blocked:
   rfkill unblock all
   ```
3. **Verificar o link simbólico de resolução DNS (`systemd-resolved` ou `/etc/resolv.conf`):**
   ```bash
   cat /etc/resolv.conf
   ```
   *Correção emergencial caso vazio:*
   ```bash
   echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
   ```
4. **Reconectar à rede Wi-Fi via `nmcli`:**
   ```bash
   nmcli dev wifi list
   nmcli dev wifi connect "NomeDaRede" password "SuaSenha"
   ```

---

### Runbook 6: Diagnóstico de Bloqueio de Portas no Firewall ou Containers Docker

#### Sintoma:
Um servidor local (Node.js, Python FastAPI, banco de dados ou container Docker) está em execução, mas requisições externas ou locais tomam timeout ou recusa de conexão.

#### Procedimento de Resolução:
1. **Descobrir em qual interface e porta a aplicação está escutando:**
   ```bash
   ss -tulpn | grep -E "LISTEN"
   ```
   *Se estiver escutando em `127.0.0.1:8080`:* Apenas o próprio computador tem acesso. Para acesso em rede local, o app deve escutar em `0.0.0.0:8080`.
2. **Verificar se a porta está liberada na zona ativa do Firewalld:**
   ```bash
   sudo firewall-cmd --list-all | grep ports
   ```
3. **Liberar a porta imediatamente:**
   ```bash
   sudo firewall-cmd --add-port=8080/tcp --permanent
   sudo firewall-cmd --reload
   ```
4. **Verificar se o tráfego do Docker está sendo bloqueado:**
   ```bash
   sudo firewall-cmd --zone=trusted --add-interface=docker0 --permanent
   sudo firewall-cmd --reload
   ```

---

### Runbook 7: Falha de Controle Térmico ou Modo G no Dell G15 (`awccd`)

#### Sintoma:
Pressionar `Super + G` não altera o modo de ventoinha ou `awcc-cli` retorna erro de comunicação com o dispositivo.

#### Procedimento de Resolução:
1. **Verificar se o módulo de interface WMI está carregado:**
   ```bash
   lsmod | grep dell_wmi
   # Se ausente:
   sudo modprobe dell-wmi
   ```
2. **Verificar o status do daemon `awccd`:**
   ```bash
   systemctl status awccd.service --no-pager
   ```
3. **Reiniciar o serviço:**
   ```bash
   sudo systemctl restart awccd.service
   ```
4. **Testar manualmente:**
   ```bash
   awcc-cli --list-profiles
   awcc-cli --set-profile Performance
   ```
