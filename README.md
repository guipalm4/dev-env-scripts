# 🚀 Scripts de Configuração de Ambiente de Desenvolvimento

Uma coleção de scripts automatizados para configurar rapidamente um ambiente de desenvolvimento completo no macOS e Ubuntu, incluindo terminal personalizado, ferramentas essenciais e configuração de múltiplas contas Git.

## 📋 Índice

- [Visão Geral](#-visão-geral)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Scripts Disponíveis](#-scripts-disponíveis)
- [Uso Rápido](#-uso-rápido)
- [Instalação Manual](#-instalação-manual)
- [O que é Instalado](#-o-que-é-instalado)
- [Configuração do Git](#-configuração-do-git)
- [Personalização](#-personalização)
- [Solução de Problemas](#-solução-de-problemas)
- [Contribuição](#-contribuição)
- [Licença](#-licença)

## 🎯 Visão Geral

Este repositório contém scripts automatizados que configuram um ambiente de desenvolvimento completo com:

- **Terminal avançado** com Oh My Zsh e PowerLevel10K
- **Ferramentas de desenvolvimento** essenciais (Node.js, Python, Docker, etc.)
- **Configuração automática do Git** com múltiplas contas
- **Suporte para macOS e Ubuntu**
- **Interface interativa** para escolher componentes

## 📁 Estrutura do Projeto

```
.
├── Scripts/
│   ├── setup-dev-env.sh          # Script orquestrador principal
│   ├── setup-terminal-macos.sh   # Configuração do terminal (macOS)
│   ├── setup-git-accounts.sh     # Configuração múltiplas contas Git
│   └── setup-terminal-macos.sh   # Terminal setup para macOS
├── setup-dev-tools-macos.sh      # Ferramentas de desenvolvimento (macOS)
├── setup-dev-tools-ubuntu.sh     # Ferramentas de desenvolvimento (Ubuntu)
├── setup-terminal-ubuntu.sh      # Configuração do terminal (Ubuntu)
└── README.md                     # Este arquivo
```

## 🛠️ Scripts Disponíveis

### Script Principal

- **[`Scripts/setup-dev-env.sh`](Scripts/setup-dev-env.sh)** - Orquestrador principal com menu interativo

### Scripts por Sistema Operacional

#### macOS

- **[`Scripts/setup-terminal-macos.sh`](Scripts/setup-terminal-macos.sh)** - Terminal + Oh My Zsh + PowerLevel10K
- **[`setup-dev-tools-macos.sh`](setup-dev-tools-macos.sh)** - Ferramentas via Homebrew

#### Ubuntu

- **[`setup-terminal-ubuntu.sh`](setup-terminal-ubuntu.sh)** - Terminal + Oh My Zsh + PowerLevel10K
- **[`setup-dev-tools-ubuntu.sh`](setup-dev-tools-ubuntu.sh)** - Ferramentas via apt/snap

### Scripts Utilitários

- **[`Scripts/setup-git-accounts.sh`](Scripts/setup-git-accounts.sh)** - Configuração de múltiplas contas Git com SSH

## ⚡ Uso Rápido

### Instalação Completa (Recomendado)

```bash
# Clone o repositório
git clone https://github.com/seu-usuario/dev-setup-scripts.git
cd dev-setup-scripts

# Torne o script principal executável
chmod +x Scripts/setup-dev-env.sh

# Execute o setup completo
./Scripts/setup-dev-env.sh
```

### Scripts Individuais

```bash
# Apenas terminal
./Scripts/setup-terminal-macos.sh    # macOS
./setup-terminal-ubuntu.sh           # Ubuntu

# Apenas ferramentas de desenvolvimento
./setup-dev-tools-macos.sh          # macOS
./setup-dev-tools-ubuntu.sh         # Ubuntu

# Configuração do Git
./Scripts/setup-git-accounts.sh
```

## 📦 O que é Instalado

### Terminal

- **Zsh** como shell padrão
- **Oh My Zsh** para gerenciamento de configurações
- **PowerLevel10K** tema moderno e informativo
- **Plugins úteis**: autosuggestions, syntax highlighting
- **Fontes PowerLine** para ícones e símbolos

### Linguagens de Programação

- **Node.js** (LTS) + npm, yarn, pnpm
- **Python** + pip, pipenv, poetry
- **Java** (OpenJDK 17)
- **Go** (última versão)
- **Rust** + Cargo

### Ferramentas CLI Essenciais

- **Git** - Controle de versão
- **Docker** + Docker Compose - Containerização
- **curl/wget** - Download de arquivos
- **jq** - Processamento JSON
- **htop** - Monitor de processos
- **tree** - Visualização de diretórios
- **bat** - Melhor versão do cat
- **exa** - Melhor versão do ls
- **ripgrep** - Busca avançada
- **fzf** - Fuzzy finder

### Bancos de Dados

- **MySQL** - Banco relacional
- **PostgreSQL** - Banco avançado
- **Redis** - Cache/DB in-memory

### Aplicações (via Homebrew/Snap)

- **Visual Studio Code** - Editor principal
- **Postman** - Teste de APIs
- **GitHub Desktop** - Interface Git
- **Figma** - Design
- **Slack/Discord** - Comunicação

## 🔐 Configuração do Git

O script [`Scripts/setup-git-accounts.sh`](Scripts/setup-git-accounts.sh) configura automaticamente:

### Estrutura de Pastas

```
~/Dev/Projects/
├── Personal/     # Projetos pessoais
└── Work/        # Projetos profissionais
```

### Configuração Automática

- **Contas separadas** por pasta
- **Chaves SSH** específicas para cada conta
- **Aliases úteis** para clonagem rápida

### Como Usar Após Configuração

```bash
# Clonar projeto pessoal
clone-personal usuario/repositorio

# Clonar projeto de trabalho
clone-work empresa/repositorio

# Navegar rapidamente
git-personal  # vai para ~/Dev/Projects/Personal
git-work      # vai para ~/Dev/Projects/Work

# Verificar configuração atual
git-check-config
```

## 🎨 Personalização

### Modificar Cores do Terminal

Edite as variáveis no início de qualquer script:

```bash
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
# ... adicione suas cores
```

### Adicionar Ferramentas

No arquivo de ferramentas correspondente ao seu SO:

```bash
# Em install_cli_tools() ou install_dev_tools()
local tools=(
    "existing-tool"
    "your-new-tool"    # Adicione aqui
)
```

### Modificar Aliases

Edite a função `configure_development_environment()`:

```bash
local aliases=(
    'alias seu-alias="seu-comando"'
)
```

## 🔧 Solução de Problemas

### Permissões

```bash
# Se scripts não executarem
chmod +x Scripts/*.sh
chmod +x *.sh
```

### Homebrew não Encontrado (macOS)

```bash
# Reinstale o Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Oh My Zsh não Funcionando

```bash
# Recarregue as configurações
source ~/.zshrc

# Ou reinstale
rm -rf ~/.oh-my-zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Teste da Configuração Git

```bash
# Execute o script de teste
~/test-git-setup.sh
```

### Logs de Instalação

Os scripts mantêm logs detalhados com cores:

- 🔵 **Info**: Informações gerais
- 🟢 **Sucesso**: Operação bem-sucedida
- 🟡 **Aviso**: Algo já existe ou erro não crítico
- 🔴 **Erro**: Falha crítica

## 🤝 Contribuição

1. **Fork** o projeto
2. **Crie** uma branch para sua feature (`git checkout -b feature/nova-feature`)
3. **Commit** suas mudanças (`git commit -m 'Adiciona nova feature'`)
4. **Push** para a branch (`git push origin feature/nova-feature`)
5. **Abra** um Pull Request

### Diretrizes

- Use as funções de log existentes (`log_info`, `log_success`, etc.)
- Mantenha compatibilidade com macOS e Ubuntu
- Adicione verificações para evitar reinstalações desnecessárias
- Documente mudanças no README

## 📋 Roadmap

- [ ] Suporte para Windows (WSL)
- [ ] Configuração de IDEs automática
- [ ] Script de backup de configurações
- [ ] Instalação via curl direto do GitHub
- [ ] Suporte para mais distribuições Linux
- [ ] Interface gráfica opcional

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para detalhes.

## ✨ Agradecimentos

- [Oh My Zsh](https://ohmyz.sh/) - Framework para Zsh
- [PowerLevel10K](https://github.com/romkatv/powerlevel10k) - Tema do terminal
- [Homebrew](https://brew.sh/) - Gerenciador de pacotes para macOS
- Comunidade open source por todas as ferramentas incríveis

---

**⭐ Se este projeto te ajudou, considere dar uma estrela!**

Para dúvidas ou sugestões, abra uma [issue](https://github.com/seu-usuario/dev-setup-scripts/issues).
