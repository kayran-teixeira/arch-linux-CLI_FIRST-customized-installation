# Regras de Engajamento e Ciclo de Trabalho de IA (`AI_WORKFLOW_RULES.md`)

Este documento padroniza o fluxo de trabalho obrigatório para assistentes CLI de inteligência artificial (**Antigravity CLI - `agy`**, **Claude Code - `claude`**, Cursor, Cline e ferramentas de terceiros) que forem ler, editar ou expandir este repositório.

---

## 1. O Protocolo das Quatro Fases de Execução

Toda interação da IA neste repositório deve seguir rigorosamente as quatro fases abaixo:

```text
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ 1. Orientação   │ ──> │ 2. Planejamento │ ──> │ 3. Execução     │ ──> │ 4. Finalização  │
│   e Memória     │     │   Cirúrgico     │     │   Determinística│     │   e Sincronia   │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

### Fase 1: Orientação e Memória (Início da Sessão)
1. **Leitura do Roteador Rápido:**
   * Sempre inicie lendo [gemini/INDEX.md](INDEX.md) para identificar o contexto da solicitação sem gastar tokens com leituras cegas.
2. **Checagem de Estado Vivo:**
   * Leia [gemini/PROGRESS.md](PROGRESS.md) para saber quais milestones já foram concluídos e quais tarefas estão pendentes.
3. **Respeito aos ADRs:**
   * Consulte [gemini/DECISIONS.md](DECISIONS.md) para não sugerir ferramentas ou abordagens que já foram formalmente descartadas (ex: propor Flatpaks, UFW ou swap em disco).

---

### Fase 2: Planejamento Cirúrgico
1. **Avaliação de Impacto Sistêmico:**
   * A alteração envolve pacotes do sistema? Deve ir para [scripts/05-packages.sh](../scripts/05-packages.sh) ou [scripts/09-dev-services.sh](../scripts/09-dev-services.sh).
   * A alteração envolve portas ou rede? Deve prever regras no [gemini/FIREWALL.md](FIREWALL.md) e [scripts/01-base-chroot.sh](../scripts/01-base-chroot.sh).
   * A alteração envolve o shell? Deve ser configurada no [scripts/07-terminal-fish.sh](../scripts/07-terminal-fish.sh) e registrada em nova página do Tealdeer.
2. **Definição de Modificações por Diferença (Diffs):**
   * Planeje edições pontuais com a ferramenta `edit_file` em vez de reescrever arquivos inteiros com `write_file`.

---

### Fase 3: Execução Determinística e Validação
1. **Sintaxe Obrigatória:**
   * Todo script shell deve iniciar com `set -euo pipefail`.
   * Todo script shell deve conter funções padronizadas de log: `log_info`, `log_success`, `log_warn`, `log_err`.
2. **Validação Sintática Imediata:**
   * Imediatamente após modificar qualquer arquivo `.sh`, o agente **DEVE** executar no terminal:
     ```bash
     bash -n scripts/<script-modificado>.sh
     ```
   * Nunca entregue um script com erro de sintaxe.
3. **Segurança de Privilégios (Sudo Efêmero):**
   * Qualquer compilação via `makepkg` ou `yay` deve ser empacotada em arquivo temporário `/etc/sudoers.d/99-temp-*` protegido por `trap cleanup EXIT`.

---

### Fase 4: Finalização e Sincronia de Documentação
1. **Atualização da Memória de IA:**
   * Concluiu uma tarefa? Marque com `[x]` no [gemini/PROGRESS.md](PROGRESS.md).
   * Tomou uma nova decisão de arquitetura? Adicione um novo registro no [gemini/DECISIONS.md](DECISIONS.md).
2. **Atualização da Documentação Humana:**
   * Se adicionou um novo comando ou utilitário, adicione a respectiva seção no [README.md](../README.md) e uma cheatsheet correspondente para o Tealdeer.
3. **Proposta de Commits Semânticos:**
   * Proponha sempre commits atômicos baseados no padrão **Conventional Commits** (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`), separando alterações de infraestrutura de documentação.

---

## 2. Padrões de Qualidade de Código (Linting Mental)

| Componente | Padrão Mandatório |
| :--- | :--- |
| **Scripts Shell** | `set -euo pipefail`, validação com `bash -n`, comentários explicativos nos blocos de comandos. |
| **Arquivos de Configuração** | Gravados via `cat <<'EOF' > /caminho/arquivo` com aspas no delimitador para impedir expansão indevida de variáveis. |
| **Manipulação do Pacman** | Sempre usar flags `--noconfirm --needed` para garantir idempotência. |
| **Manipulação do Yay** | Sempre executar sob `su - $TARGET_USER -c "..."` com sudo efêmero. |
| **Serviços Systemd** | Sempre usar `systemctl enable` no chroot ou `systemctl enable --now` no sistema pós-boot. |
| **Documentação Tealdeer** | Formato Markdown simples com título `# nome`, bloco descritivo `> resumo` e lista de comandos entre crases. |

---

## 3. Checklist de Conclusão de Tarefa para a IA

Antes de considerar qualquer tarefa finalizada, responda internamente:

* [ ] Os scripts modificados passam no `bash -n` sem warnings ou erros?
* [ ] As permissões de execução (`chmod +x`) foram preservadas?
* [ ] As regras do Firewalld foram atualizadas se novas portas foram expostas?
* [ ] O [gemini/PROGRESS.md](PROGRESS.md) reflete o estado atual?
* [ ] Os comandos foram estruturados para poupar tokens conforme o [gemini/TOKEN_OPTIMIZATION_AND_AI_OPS.md](TOKEN_OPTIMIZATION_AND_AI_OPS.md)?
