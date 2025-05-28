#!/bin/bash

# Script para instalação de pacotes essenciais para desenvolvimento - macOS
# Autor: Guilherme Palma
# Data: 28 de maio de 2025
# Versão: 1.1 - Corrigido

set -euo pipefail
IFS=$'\n\t'

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Variáveis globais
readonly USER_NAME="$USER"
readonly NODE_VERSION="20"
readonly PYTHON_VERSION="3.11"
readonly LOG_FILE="$HOME/setup-dev-tools-macos.log"
readonly BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"

# Setup de logging
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Funções auxiliares
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_section() {
    echo -e "\n${PURPLE}🔧 $1${NC}"
    echo "=================================="
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_warning "Script interrompido (código: $exit_code)"
        log_info "Log disponível em: $LOG_FILE"
    fi
    exit $exit_code
}

trap cleanup INT TERM

# Verifica se está no macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "Este script é específico para macOS"
        exit 1
    fi
    
    local macos_version
    macos_version=$(sw_vers -productVersion)
    log_info "macOS $macos_version detectado"
}

# Verifica se Homebrew está instalado
check_homebrew() {
    if ! command_exists brew; then
        log_error "Homebrew não encontrado. Execute primeiro o script de setup do terminal."
        log_info "Instale com: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    log_success "Homebrew encontrado ($(brew --version | head -n1))"
    
    # Atualiza Homebrew
    log_info "Atualizando Homebrew..."
    brew update || log_warning "Falha ao atualizar Homebrew"
}

# Verifica espaço em disco
check_disk_space() {
    local available_gb
    available_gb=$(df -g / | awk 'NR==2 {print $4}')
    
    if [[ $available_gb -lt 10 ]]; then
        log_warning "Pouco espaço em disco: ${available_gb}GB disponível"
        read -p "Continuar mesmo assim? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Backup de configurações
backup_configs() {
    log_info "Criando backup de configurações..."
    mkdir -p "$BACKUP_DIR"
    
    local config_files=(
        "$HOME/.zshrc"
        "$HOME/.bashrc"
        "$HOME/.gitconfig"
        "$HOME/.vimrc"
        "$HOME/.tmux.conf"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done
    
    log_success "Backup criado em: $BACKUP_DIR"
}

# Instala ferramentas de linha de comando essenciais
install_cli_tools() {
    log_section "Ferramentas de Linha de Comando"
    
    local cli_tools=(
        "git"
        "curl"
        "wget"
        "jq"
        "tree"
        "htop"
        "bat"
        "exa"
        "fd"
        "ripgrep"
        "fzf"
        "tldr"
        "neofetch"
        "mas"
        "watch"
        "tmux"
        "vim"
        "neovim"
    )
    
    local failed_tools=()
    
    for tool in "${cli_tools[@]}"; do
        if brew list "$tool" &>/dev/null; then
            log_warning "$tool já está instalado"
        else
            log_info "Instalando $tool..."
            if brew install "$tool"; then
                log_success "$tool instalado"
            else
                failed_tools+=("$tool")
                log_error "Falha ao instalar $tool"
            fi
        fi
    done
    
    if [[ ${#failed_tools[@]} -gt 0 ]]; then
        log_warning "Ferramentas que falharam: ${failed_tools[*]}"
        log_info "Você pode tentar instalar manualmente depois"
    fi
    
    log_success "Ferramentas CLI processadas"
}

# Instala linguagens de programação
install_programming_languages() {
    log_section "Linguagens de Programação"
    
    # Node.js
    install_nodejs
    
    # Python
    install_python
    
    # Java
    install_java
    
    # Go
    install_go
    
    # Rust
    install_rust
    
    log_success "Linguagens de programação instaladas"
}

install_nodejs() {
    if command_exists node; then
        local current_version
        current_version=$(node --version | sed 's/v//')
        log_warning "Node.js já está instalado (v$current_version)"
        
        # Verifica se é uma versão antiga
        local major_version
        major_version=$(echo "$current_version" | cut -d. -f1)
        if [[ $major_version -lt $NODE_VERSION ]]; then
            log_warning "Versão antiga detectada. Recomendado: v$NODE_VERSION"
            read -p "Atualizar para Node.js $NODE_VERSION? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                brew install "node@$NODE_VERSION" || log_error "Falha ao atualizar Node.js"
            fi
        fi
    else
        log_info "Instalando Node.js $NODE_VERSION..."
        if brew install "node@$NODE_VERSION"; then
            # Adiciona ao PATH se necessário
            local node_path="/opt/homebrew/opt/node@$NODE_VERSION/bin"
            if [[ -d "$node_path" ]] && ! echo "$PATH" | grep -q "$node_path"; then
                echo "export PATH=\"$node_path:\$PATH\"" >> "$HOME/.zshrc"
                export PATH="$node_path:$PATH"
            fi
            log_success "Node.js instalado ($(node --version))"
        else
            log_error "Falha ao instalar Node.js"
        fi
    fi
}

install_python() {
    if command_exists python3; then
        local current_version
        current_version=$(python3 --version | awk '{print $2}')
        log_warning "Python já está instalado (v$current_version)"
    else
        log_info "Instalando Python $PYTHON_VERSION..."
        if brew install "python@$PYTHON_VERSION"; then
            log_success "Python instalado ($(python3 --version))"
        else
            log_error "Falha ao instalar Python"
        fi
    fi
    
    # Instala pipx para pacotes globais
    if ! command_exists pipx; then
        log_info "Instalando pipx..."
        brew install pipx || python3 -m pip install --user pipx
        pipx ensurepath || true
    fi
}

install_java() {
    if command_exists java; then
        local java_version
        java_version=$(java -version 2>&1 | head -n1 | awk -F '"' '{print $2}')
        log_warning "Java já está instalado (v$java_version)"
    else
        log_info "Instalando OpenJDK 17..."
        if brew install openjdk@17; then
            local java_home="/opt/homebrew/opt/openjdk@17"
            if [[ -d "$java_home" ]]; then
                echo "export JAVA_HOME=\"$java_home\"" >> "$HOME/.zshrc"
                echo "export PATH=\"\$JAVA_HOME/bin:\$PATH\"" >> "$HOME/.zshrc"
                export JAVA_HOME="$java_home"
                export PATH="$JAVA_HOME/bin:$PATH"
            fi
            log_success "Java instalado"
        else
            log_error "Falha ao instalar Java"
        fi
    fi
}

install_go() {
    if command_exists go; then
        local go_version
        go_version=$(go version | awk '{print $3}' | sed 's/go//')
        log_warning "Go já está instalado (v$go_version)"
    else
        log_info "Instalando Go..."
        if brew install go; then
            # Configura GOPATH
            local gopath="$HOME/go"
            if [[ ! -d "$gopath" ]]; then
                mkdir -p "$gopath"
            fi
            echo "export GOPATH=\"$gopath\"" >> "$HOME/.zshrc"
            echo "export PATH=\"\$GOPATH/bin:\$PATH\"" >> "$HOME/.zshrc"
            log_success "Go instalado ($(go version | awk '{print $3}'))"
        else
            log_error "Falha ao instalar Go"
        fi
    fi
}

install_rust() {
    if command_exists rustc; then
        local rust_version
        rust_version=$(rustc --version | awk '{print $2}')
        log_warning "Rust já está instalado (v$rust_version)"
    else
        log_info "Instalando Rust..."
        if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
            source "$HOME/.cargo/env"
            log_success "Rust instalado ($(rustc --version | awk '{print $2}'))"
        else
            log_error "Falha ao instalar Rust"
        fi
    fi
}

# Instala ferramentas de desenvolvimento
install_dev_tools() {
    log_section "Ferramentas de Desenvolvimento"
    
    local dev_tools=(
        "docker"
        "docker-compose"
        "terraform"
        "ansible"
        "kubernetes-cli"
        "helm"
        "mysql"
        "postgresql"
        "redis"
        "nginx"
        "imagemagick"
        "ffmpeg"
        "wireshark"
        "nmap"
        "tcpdump"
    )
    
    log_info "Instalando ferramentas de desenvolvimento..."
    
    local failed_tools=()
    
    for tool in "${dev_tools[@]}"; do
        if brew list "$tool" &>/dev/null; then
            log_warning "$tool já está instalado"
        else
            log_info "Instalando $tool..."
            if brew install "$tool"; then
                log_success "$tool instalado"
            else
                failed_tools+=("$tool")
                log_warning "Falha ao instalar $tool"
            fi
        fi
    done
    
    if [[ ${#failed_tools[@]} -gt 0 ]]; then
        log_warning "Ferramentas que falharam: ${failed_tools[*]}"
    fi
    
    log_success "Ferramentas de desenvolvimento processadas"
}

# Instala aplicações via Homebrew Cask
install_applications() {
    log_section "Aplicações"
    
    local apps=(
        "visual-studio-code"
        "sublime-text"
        "iterm2"
        "postman"
        "insomnia"
        "tableplus"
        "sequel-pro"
        "github-desktop"
        "sourcetree"
        "figma"
        "slack"
        "discord"
        "notion"
        "obsidian"
        "google-chrome"
        "firefox"
        "docker"
        "virtualbox"
    )
    
    echo "Aplicações disponíveis para instalação:"
    for i in "${!apps[@]}"; do
        echo "$((i+1)). ${apps[i]}"
    done
    echo
    
    read -p "Instalar todas as aplicações? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local failed_apps=()
        
        for app in "${apps[@]}"; do
            if brew list --cask "$app" &>/dev/null; then
                log_warning "$app já está instalado"
            else
                log_info "Instalando $app..."
                if brew install --cask "$app"; then
                    log_success "$app instalado"
                else
                    failed_apps+=("$app")
                    log_warning "Falha ao instalar $app"
                fi
            fi
        done
        
        if [[ ${#failed_apps[@]} -gt 0 ]]; then
            log_warning "Apps que falharam: ${failed_apps[*]}"
            log_info "Você pode instalar manualmente: brew install --cask <app>"
        fi
    else
        log_info "Instalação de aplicações pulada"
        log_info "Para instalar depois: brew install --cask <app-name>"
    fi
    
    log_success "Aplicações processadas"
}

# Instala gerenciadores de pacotes específicos
install_package_managers() {
    log_section "Gerenciadores de Pacotes"
    
    # npm packages globais
    install_npm_packages
    
    # pip packages
    install_pip_packages
    
    log_success "Gerenciadores de pacotes configurados"
}

install_npm_packages() {
    if ! command_exists npm; then
        log_warning "npm não encontrado, pulando pacotes npm"
        return 0
    fi
    
    log_info "Instalando pacotes npm globais..."
    
    local npm_packages=(
        "yarn"
        "pnpm"
        "nodemon"
        "pm2"
        "typescript"
        "ts-node"
        "@angular/cli"
        "@vue/cli"
        "create-react-app"
        "next"
        "eslint"
        "prettier"
        "serverless"
        "vercel"
        "netlify-cli"
    )
    
    local failed_packages=()
    
    for package in "${npm_packages[@]}"; do
        log_info "Instalando $package..."
        if npm install -g "$package"; then
            log_success "$package instalado"
        else
            failed_packages+=("$package")
            log_warning "Falha ao instalar $package"
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Pacotes npm que falharam: ${failed_packages[*]}"
    fi
}

install_pip_packages() {
    if ! command_exists pip3; then
        log_warning "pip3 não encontrado, pulando pacotes Python"
        return 0
    fi
    
    log_info "Instalando pacotes Python globais..."
    
    local pip_packages=(
        "pipenv"
        "poetry"
        "virtualenv"
        "jupyter"
        "black"
        "flake8"
        "pytest"
        "requests"
        "django"
        "flask"
        "fastapi"
        "cookiecutter"
        "pre-commit"
    )
    
    local failed_packages=()
    
    for package in "${pip_packages[@]}"; do
        log_info "Instalando $package..."
        if pip3 install "$package"; then
            log_success "$package instalado"
        else
            failed_packages+=("$package")
            log_warning "Falha ao instalar $package"
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Pacotes Python que falharam: ${failed_packages[*]}"
    fi
}

# Configurações adicionais
configure_development_environment() {
    log_section "Configurações do Ambiente"
    
    # Configura Git se necessário
    configure_git
    
    # Cria estrutura de diretórios
    create_dev_directories
    
    # Configura aliases
    configure_aliases
    
    log_success "Ambiente de desenvolvimento configurado"
}

configure_git() {
    if ! git config --global user.name &>/dev/null; then
        echo
        read -p "Digite seu nome para o Git: " git_name
        read -p "Digite seu email para o Git: " git_email
        
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        git config --global init.defaultBranch main
        git config --global pull.rebase false
        
        log_success "Git configurado"
    else
        log_info "Git já está configurado"
        log_info "Nome: $(git config --global user.name)"
        log_info "Email: $(git config --global user.email)"
    fi
}

create_dev_directories() {
    local dev_dirs=(
        "$HOME/Dev"
        "$HOME/Dev/Projects"
        "$HOME/Dev/Scripts"
        "$HOME/Dev/Learning"
        "$HOME/Dev/Playground"
        "$HOME/Dev/Tools"
    )
    
    for dir in "${dev_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_info "Criado diretório: $dir"
        fi
    done
}

configure_aliases() {
    local zshrc="$HOME/.zshrc"
    
    local aliases=(
        'alias ll="exa -la --git"'
        'alias la="exa -la"'
        'alias cat="bat"'
        'alias find="fd"'
        'alias grep="rg"'
        'alias dev="cd ~/Dev"'
        'alias projects="cd ~/Dev/Projects"'
        'alias scripts="cd ~/Dev/Scripts"'
        'alias playground="cd ~/Dev/Playground"'
        'alias tools="cd ~/Dev/Tools"'
        'alias brewup="brew update && brew upgrade && brew cleanup"'
        'alias npmup="npm update -g"'
        'alias gitlog="git log --oneline --graph --decorate --all"'
        'alias gits="git status"'
        'alias dockerclean="docker system prune -af"'
    )
    
    for alias_cmd in "${aliases[@]}"; do
        if ! grep -Fq "$alias_cmd" "$zshrc" 2>/dev/null; then
            echo "$alias_cmd" >> "$zshrc"
        fi
    done
    
    log_info "Aliases configurados"
}

# Função de cleanup e otimização
cleanup_and_optimize() {
    log_section "Limpeza e Otimização"
    
    log_info "Executando brew cleanup..."
    brew cleanup || log_warning "Falha no cleanup do Homebrew"
    
    log_info "Atualizando banco de dados do locate..."
    sudo /usr/libexec/locate.updatedb &>/dev/null || true
    
    # Verifica saúde do Homebrew
    log_info "Verificando saúde do Homebrew..."
    brew doctor || log_warning "Homebrew doctor encontrou problemas"
    
    log_success "Sistema otimizado"
}

# Resumo final
show_summary() {
    log_section "Resumo da Instalação"
    
    echo -e "${CYAN}🎉 Instalação concluída com sucesso!${NC}\n"
    
    echo "✅ Instalado:"
    echo "   • Linguagens: $(command_exists node && echo "Node.js" || echo "")$(command_exists python3 && echo ", Python" || echo "")$(command_exists java && echo ", Java" || echo "")$(command_exists go && echo ", Go" || echo "")$(command_exists rustc && echo ", Rust" || echo "")"
    echo "   • Databases: $(brew list mysql &>/dev/null && echo "MySQL" || echo "")$(brew list postgresql &>/dev/null && echo ", PostgreSQL" || echo "")$(brew list redis &>/dev/null && echo ", Redis" || echo "")"
    echo "   • Tools: Docker, Git, e muito mais"
    echo ""
    
    echo "📝 Próximos passos:"
    echo "   1. Reinicie o terminal: source ~/.zshrc"
    echo "   2. Configure suas chaves SSH: ssh-keygen -t ed25519"
    echo "   3. Configure IDEs e extensões favoritas"
    echo "   4. Explore os aliases: ll, cat, dev, projects"
    echo ""
    
    echo "📚 Comandos úteis:"
    echo "   • brewup - atualizar todos os pacotes"
    echo "   • dockerclean - limpar Docker"
    echo "   • gitlog - visualizar git log"
    echo ""
    
    echo "📋 Arquivos importantes:"
    echo "   • Log: $LOG_FILE"
    echo "   • Backup: $BACKUP_DIR"
    echo ""
    
    log_success "Ambiente de desenvolvimento pronto! 🚀"
}

# Função principal
main() {
    echo -e "${BLUE}"
    echo "🚀 Instalador de Pacotes para Desenvolvimento - macOS"
    echo "===================================================="
    echo -e "${NC}"
    echo "Usuário: $USER_NAME"
    echo "Sistema: $(sw_vers -productName) $(sw_vers -productVersion)"
    echo "Log: $LOG_FILE"
    echo ""
    
    read -p "Continuar com a instalação? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Instalação cancelada"
        exit 0
    fi
    
    echo "=== Instalação iniciada em $(date) ===" | tee -a "$LOG_FILE"
    
    check_macos
    check_homebrew
    check_disk_space
    backup_configs
    install_cli_tools
    install_programming_languages
    install_dev_tools
    install_applications
    install_package_managers
    configure_development_environment
    cleanup_and_optimize
    show_summary
    
    echo "=== Instalação concluída em $(date) ===" | tee -a "$LOG_FILE"
}

# Executa apenas se for chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi