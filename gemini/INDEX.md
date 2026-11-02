# Índice Mestre da Base de Conhecimento e Operações de IA (`gemini/`)

> **Para Agentes de IA (Antigravity CLI, Claude Code e similares):**
> Este arquivo é o ponto de entrada rápido (< 60 tokens). Ao iniciar uma sessão, **leia este arquivo primeiro**. Ele indica exatamente qual documento carregar para sua tarefa específica, evitando o carregamento desnecessário de centenas de linhas.

---

## Mapa de Documentação por Objetivo

| Se a sua tarefa for... | Leia o arquivo: | Linhas / Foco |
| :--- | :--- | :--- |
| **Entender o status atual, pendências ou histórico de tarefas** | [PROGRESS.md](PROGRESS.md) | Milestones concluídos, tarefas em andamento, backlog e dívidas técnicas. |
| **Saber POR QUE uma tecnologia ou padrão foi escolhido** | [DECISIONS.md](DECISIONS.md) | Architecture Decision Records (ADRs): Btrfs, Snapper, ZRAM, NVIDIA, FNM, etc. |
| **Resolver um problema, pane ou manutenção emergencial** | [RUNBOOK.md](RUNBOOK.md) | Playbooks passo a passo: tela preta, disco cheio, rollback de snapshot, firewall, USB freeze. |
| **Configurar, abrir portas ou auditar o firewall / Docker** | [FIREWALL.md](FIREWALL.md) | Manual definitivo do Firewalld, zonas, rich rules e prevenção de bypass do Docker. |
| **Entender a arquitetura completa e especificações do OS** | [CONTEXT.md](CONTEXT.md) | Especificação técnica mestre do sistema, hardware Dell G15 e módulos 01 ao 10. |
| **Consultar papéis de agentes, skills e automações** | [AGENTS_AND_SKILLS.md](AGENTS_AND_SKILLS.md) | Personas, skills executáveis e guardrails de segurança para IA. |
| **Operar com economia de tokens e comandos compactos** | [TOKEN_OPTIMIZATION_AND_AI_OPS.md](TOKEN_OPTIMIZATION_AND_AI_OPS.md) | Filtros de CLI otimizados, uso de subagente `research` e skill de diagnóstico de 8 linhas. |
| **Aprender o ciclo de trabalho de IA neste repositório** | [AI_WORKFLOW_RULES.md](AI_WORKFLOW_RULES.md) | Protocolo de início de sessão, edição cirúrgica, validação e atualização de progresso. |

---

## Estrutura de Arquivos do Repositório

```text
arch-bootstrap/
├── README.md                      # Manual do usuário humano (particionamento, cheatsheets, comandos)
├── install.sh                     # Orquestrador da Live ISO (pacstrap, genfstab, chroot)
├── gemini/                        # Base de conhecimento e memória para agentes de IA
│   ├── INDEX.md                   # Este arquivo (Sitemap e roteador rápido de contexto)
│   ├── PROGRESS.md                # Controle vivo de progresso, marcos e backlog
│   ├── DECISIONS.md               # Architecture Decision Records (ADRs)
│   ├── RUNBOOK.md                 # Procedimentos operacionais padrão (SOPs e troubleshooting)
│   ├── FIREWALL.md                # Manual exaustivo do Firewalld e integração com Docker
│   ├── CONTEXT.md                 # Especificação técnica master de engenharia
│   ├── AGENTS_AND_SKILLS.md       # Papéis de agentes, ferramentas e skills executáveis
│   ├── TOKEN_OPTIMIZATION_AND_AI_OPS.md # Padrões de economia de tokens e baixo overhead
│   └── AI_WORKFLOW_RULES.md       # Regras de engajamento e protocolo de trabalho da IA
└── scripts/                       # Módulos determinísticos numerados (01 a 10)
```
