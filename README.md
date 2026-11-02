# Arch Linux Bootstrap (CLI-First Setup)

Guia de instalação mínima e determinística do Arch Linux focado em terminal puro, compositor Wayland mínimo sem decorações (Hyprland monocle), suporte a GPU dedicada NVIDIA, virtualização KVM/QEMU e ferramentas de desenvolvimento de baixo nível.

---

## 1. Pré-Requisitos na Firmware (BIOS/UEFI)

Antes de iniciar a Live ISO do Arch Linux, acesse as configurações da placa-mãe/firmware e garanta os seguintes ajustes:

* **Boot Mode:** Estritamente `UEFI Native` (desative o modo legado/CSM).
* **Secure Boot:** `Disabled` (o kernel padrão do Arch e os módulos DKMS da NVIDIA não são assinados pela chave da Microsoft).
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

## 3. Particionamento e Montagem Manual dos Discos

> **ATENÇÃO:** O particionamento é intencionalmente manual. Não deixe scripts adivinharem unidades de disco para evitar a perda acidental de dados em partições adjacentes ou em discos secundários.

Identifique o disco de destino:
```bash
lsblk -d -o NAME,SIZE,MODEL,TRAN
```
*(Assumiremos `/dev/nvme0n1` neste guia. Ajuste para a sua unidade).*

### 3.1. Criando as Partições com `cfdisk`
Execute:
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

### 3.2. Formatação dos Sistemas de Arquivos
```bash
# Formata a partição EFI em FAT32
mkfs.fat -F32 /dev/nvme0n1p1

# Formata a partição Raiz em Ext4
mkfs.ext4 -L "ARCH_ROOT" /dev/nvme0n1p2
```

### 3.3. Montagem Cirúrgica dos Pontos do Sistema
A ordem das montagens é mandatória. Monte a raiz primeiro e, em seguida, crie e monte o `/boot`:
```bash
mount /dev/nvme0n1p2 /mnt
mount --mkdir /dev/nvme0n1p1 /mnt/boot
```

Verifique se a hierarquia está correta:
```bash
lsblk /dev/nvme0n1
# Deve exibir:
# nvme0n1p1  --> /mnt/boot
# nvme0n1p2  --> /mnt
```

---

## 4. Disparo do Instalador Automatizado

Com as partições montadas em `/mnt`, clone este repositório ou baixe os scripts:

```bash
cd /root
git clone [https://github.com/seu-usuario/arch-bootstrap.git](https://github.com/seu-usuario/arch-bootstrap.git)
cd arch-bootstrap
chmod +x install.sh scripts/*.sh
```

Execute o orquestrador definindo as credenciais de usuário via variáveis de ambiente para evitar senhas expostas em logs:

```bash
TARGET_USER="kayran" USER_PASS="SuaSenhaSegura" ROOT_PASS="SenhaRootSegura" ./install.sh
```

---

## 5. Pós-Instalação e Reinicialização

Após a conclusão bem-sucedida de todos os módulos:
```bash
umount -R /mnt
reboot
```

Retire o pendrive de instalação. O sistema iniciará no prompt do TTY1 pedindo suas credenciais. Ao logar no TTY1, o ambiente iniciará diretamente no terminal monocle sem display manager.