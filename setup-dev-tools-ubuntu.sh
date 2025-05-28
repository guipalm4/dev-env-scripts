#!/bin/bash

# Script para instalação de pacotes essenciais para desenvolvimento - Ubuntu
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
readonly LOG_FILE="$HOME/setup-dev-tools-ubuntu.log"
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

# Verifica se está no Ubuntu
check_ubuntu() {
    if ! command -v apt-get >/dev/null 2>&1; then
        log_error "Este script é específico para Ubuntu/Debian"
        exit 1
    fi
    
    local ubuntu_version
    ubuntu_version=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Ubuntu/Debian")
    log_info "Sistema detectado: $ubuntu_version"
    
    # Verifica privilégios sudo
    if ! sudo -n true 2>/dev/null; then
        log_info "Este script requer privilégios sudo"
        sudo -v || {
            log_error "Falha ao obter privilégios sudo"
            exit 1
        }
    fi
}

# Verifica requisitos do sistema
check_system_requirements() {
    # Conectividade
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "Sem conexão com a internet"
        exit 1
    fi
    
    # Espaço em disco
    local available_gb
    available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [[ $available_gb -lt 10 ]]; then
        log_warning "Pouco espaço em disco: ${available_gb}GB disponível"
        read -p "Continuar mesmo assim? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "Requisitos do sistema verificados"
}

# Backup de configurações
backup_configs() {
    log_info "Criando backup de configurações..."
    mkdir -p "$BACKUP_DIR"
    
    local config_files=(
        "$HOME/.zshrc"
        "$HOME/.bashrc"
        "$HOME/.profile"
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

# Atualiza sistema
update_system() {
    log_info "Atualizando sistema..."
    
    # Atualiza lista de pacotes
    sudo apt-get update -y || {
        log_error "Falha ao atualizar lista de pacotes"
        exit 1
    }
    
    # Upgrade opcional
    read -p "Executar upgrade completo? (recomendado) (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo apt-get upgrade -y || log_warning "Falha no upgrade"
    fi
    
    log_success "Sistema atualizado"
}

# Instala Snap se não disponível
install_snap() {
    if command_exists snap; then
        log_warning "Snap já está instalado"
        return 0
    fi
    
    log_info "Instalando Snap..."
    sudo apt-get install -y snapd || {
        log_error "Falha ao instalar Snap"
        return 1
    }
    
    # Adiciona ao PATH
    if ! echo "$PATH" | grep -q "/snap/bin"; then
        echo 'export PATH="/snap/bin:$PATH"' >> "$HOME/.zshrc"
        export PATH="/snap/bin:$PATH"
    fi
    
    log_success "Snap instalado"
}

# Instala ferramentas CLI essenciais
install_cli_tools() {
    log_section "Ferramentas de Linha de Comando"
    
    local apt_tools=(
        "git"
        "curl"
        "wget"
        "jq"
        "tree"
        "htop"
        "unzip"
        "zip"
        "vim"
        "neovim"
        "tmux"
        "screen"
        "build-essential"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "gnupg"
        "lsb-release"
    )
    
    local failed_tools=()
    
    log_info "Instalando ferramentas básicas via apt..."
    for tool in "${apt_tools[@]}"; do
        if dpkg -l | grep -q "^ii  $tool "; then
            log_warning "$tool já está instalado"
        else
            log_info "Instalando $tool..."
            if sudo apt-get install -y "$tool"; then
                log_success "$tool instalado"
            else
                failed_tools+=("$tool")
                log_error "Falha ao instalar $tool"
            fi
        fi
    done
    
    # Ferramentas modernas
    install_modern_cli_tools
    
    if [[ ${#failed_tools[@]} -gt 0 ]]; then
        log_warning "Ferramentas que falharam: ${failed_tools[*]}"
    fi
    
    log_success "Ferramentas CLI processadas"
}

install_modern_cli_tools() {
    log_info "Instalando ferramentas modernas..."
    
    # bat (melhor cat)
    if ! command_exists bat && ! command_exists batcat; then
        if sudo apt-get install -y bat 2>/dev/null; then
            log_success "bat instalado via apt"
        else
            log_info "Instalando bat via snap..."
            sudo snap install bat || log_warning "Falha ao instalar bat"
        fi
    fi
    
    # exa (melhor ls)
    if ! command_exists exa; then
        if sudo apt-get install -y exa 2>/dev/null; then
            log_success "exa instalado via apt"
        else
            # Instalação manual para versões antigas do Ubuntu
            local exa_url="https://github.com/ogham/exa/releases/latest/download/exa-linux-x86_64-v0.10.1.zip"
            local temp_dir="/tmp/exa_install"
            mkdir -p "$temp_dir"
            if curl -fsSL "$exa_url" -o "$temp_dir/exa.zip" && \
               cd "$temp_dir" && \
               unzip -q exa.zip && \
               sudo mv bin/exa /usr/local/bin/; then
                log_success "exa instalado manualmente"
            else
                log_warning "Falha ao instalar exa"
            fi
            rm -rf "$temp_dir"
        fi
    fi
    
    # fd (melhor find)
    if ! command_exists fd; then
        if sudo apt-get install -y fd-find 2>/dev/null; then
            # Cria link simbólico para fd
            if [[ ! -L /usr/local/bin/fd ]] && [[ -f /usr/bin/fdfind ]]; then
                sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
            fi
            log_success "fd instalado via apt"
        else
            log_warning "fd não disponível"
        fi
    fi
    
    # ripgrep (melhor grep)
    if ! command_exists rg; then
        if sudo apt-get install -y ripgrep 2>/dev/null; then
            log_success "ripgrep instalado via apt"
        else
            log_warning "ripgrep não disponível"
        fi
    fi
    
    # fzf (fuzzy finder)
    if ! command_exists fzf; then
        sudo apt-get install -y fzf || log_warning "Falha ao instalar fzf"
    fi
}

# Instala Node.js via NodeSource
install_nodejs() {
    log_section "Node.js"
    
    if command_exists node; then
        local current_version
        current_version=$(node --version | sed 's/v//')
        local major_version
        major_version=$(echo "$current_version" | cut -d. -f1)
        
        log_warning "Node.js já está instalado (v$current_version)"
        
        if [[ $major_version -lt $NODE_VERSION ]]; then
            log_warning "Versão antiga detectada. Recomendado: v$NODE_VERSION"
            read -p "Atualizar para Node.js $NODE_VERSION? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return 0
            fi
        else
            return 0
        fi
    fi
    
    log_info "Instalando Node.js $NODE_VERSION..."
    
    # Remove versões antigas
    sudo apt-get remove -y nodejs npm 2>/dev/null || true
    
    # Adiciona repositório NodeSource
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | sudo -E bash - || {
        log_error "Falha ao adicionar repositório NodeSource"
        return 1
    }
    
    # Instala Node.js
    if sudo apt-get install -y nodejs; then
        log_success "Node.js instalado: $(node --version)"
        
        # Configura npm para não usar sudo
        mkdir -p "$HOME/.npm-global"
        npm config set prefix "$HOME/.npm-global"
        if ! grep -q "npm-global" "$HOME/.zshrc" 2>/dev/null; then
            echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.zshrc"
        fi
        export PATH="$HOME/.npm-global/bin:$PATH"
    else
        log_error "Falha ao instalar Node.js"
        return 1
    fi
}

# Instala Python e pip
install_python() {
    log_section "Python"
    
    local python_packages=(
        "python3"
        "python3-pip"
        "python3-venv"
        "python3-dev"
        "python3-setuptools"
        "python3-wheel"
    )
    
    if command_exists python3; then
        local current_version
        current_version=$(python3 --version | awk '{print $2}')
        log_warning "Python já está instalado (v$current_version)"
    else
        log_info "Instalando Python..."
        for package in "${python_packages[@]}"; do
            sudo apt-get install -y "$package" || log_warning "Falha ao instalar $package"
        done
    fi
    
    # Instala pipx para pacotes globais
    if ! command_exists pipx; then
        log_info "Instalando pipx..."
        if sudo apt-get install -y pipx 2>/dev/null; then
            pipx ensurepath || true
        else
            python3 -m pip install --user pipx
            python3 -m pipx ensurepath || true
        fi
    fi
    
    log_success "Python configurado"
}

# Instala Java
install_java() {
    log_section "Java"
    
    if command_exists java; then
        local java_version
        java_version=$(java -version 2>&1 | head -n1 | awk -F '"' '{print $2}')
        log_warning "Java já está instalado (v$java_version)"
        return 0
    fi
    
    log_info "Instalando OpenJDK 17..."
    if sudo apt-get install -y openjdk-17-jdk openjdk-17-jre; then
        # Configura JAVA_HOME
        local java_home="/usr/lib/jvm/java-17-openjdk-amd64"
        if [[ -d "$java_home" ]]; then
            if ! grep -q "JAVA_HOME" "$HOME/.zshrc" 2>/dev/null; then
                {
                    echo "export JAVA_HOME=\"$java_home\""
                    echo "export PATH=\"\$JAVA_HOME/bin:\$PATH\""
                } >> "$HOME/.zshrc"
            fi
            export JAVA_HOME="$java_home"
            export PATH="$JAVA_HOME/bin:$PATH"
        fi
        log_success "Java instalado"
    else
        log_error "Falha ao instalar Java"
    fi
}

# Instala Go
install_go() {
    log_section "Go"
    
    if command_exists go; then
        local go_version
        go_version=$(go version | awk '{print $3}' | sed 's/go//')
        log_warning "Go já está instalado (v$go_version)"
        return 0
    fi
    
    log_info "Instalando Go..."
    
    # Remove versão antiga se existir
    sudo rm -rf /usr/local/go
    
    # Download da versão mais recente
    local go_version="1.21.5"
    local go_url="https://golang.org/dl/go${go_version}.linux-amd64.tar.gz"
    
    if curl -fsSL "$go_url" -o /tmp/go.tar.gz && \
       sudo tar -C /usr/local -xzf /tmp/go.tar.gz; then
        
        # Configura PATH
        if ! grep -q "/usr/local/go/bin" "$HOME/.zshrc" 2>/dev/null; then
            {
                echo "export PATH=\"/usr/local/go/bin:\$PATH\""
                echo "export GOPATH=\"\$HOME/go\""
                echo "export PATH=\"\$GOPATH/bin:\$PATH\""
            } >> "$HOME/.zshrc"
        fi
        
        export PATH="/usr/local/go/bin:$PATH"
        export GOPATH="$HOME/go"
        export PATH="$GOPATH/bin:$PATH"
        
        # Cria diretório GOPATH
        mkdir -p "$GOPATH"
        
        log_success "Go instalado ($(go version | awk '{print $3}'))"
    else
        log_error "Falha ao instalar Go"
    fi
    
    rm -f /tmp/go.tar.gz
}

# Instala Rust
install_rust() {
    log_section "Rust"
    
    if command_exists rustc; then
        local rust_version
        rust_version=$(rustc --version | awk '{print $2}')
        log_warning "Rust já está instalado (v$rust_version)"
        return 0
    fi
    
    log_info "Instalando Rust..."
    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
        source "$HOME/.cargo/env"
        log_success "Rust instalado ($(rustc --version | awk '{print $2}'))"
    else
        log_error "Falha ao instalar Rust"
    fi
}

# Instala Docker
install_docker() {
    log_section "Docker"
    
    if command_exists docker; then
        log_warning "Docker já está instalado"
        return 0
    fi
    
    log_info "Instalando Docker..."
    
    # Remove versões antigas
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Adiciona repositório oficial do Docker
    if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
       echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
       sudo apt-get update && \
       sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin; then
        
        # Adiciona usuário ao grupo docker
        sudo usermod -aG docker "$USER"
        
        # Inicia e habilita Docker
        sudo systemctl start docker
        sudo systemctl enable docker
        
        log_success "Docker instalado (reinicie a sessão para usar sem sudo)"
    else
        log_error "Falha ao instalar Docker"
    fi
}

# Instala bancos de dados
install_databases() {
    log_section "Bancos de Dados"
    
    # MySQL
    read -p "Instalar MySQL? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if sudo apt-get install -y mysql-server mysql-client; then
            log_success "MySQL instalado"
            log_info "Configure com: sudo mysql_secure_installation"
        else
            log_error "Falha ao instalar MySQL"
        fi
    fi
    
    # PostgreSQL
    read -p "Instalar PostgreSQL? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if sudo apt-get install -y postgresql postgresql-contrib; then
            log_success "PostgreSQL instalado"
            log_info "Configure com: sudo -u postgres createuser --interactive"
        else
            log_error "Falha ao instalar PostgreSQL"
        fi
    fi
    
    # Redis
    read -p "Instalar Redis? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if sudo apt-get install -y redis-server; then
            log_success "Redis instalado"
        else
            log_error "Falha ao instalar Redis"
        fi
    fi
}

# Instala aplicações via Snap
install_applications() {
    log_section "Aplicações"
    
    if ! command_exists snap; then
        log_warning "Snap não disponível, pulando aplicações"
        return 0
    fi
    
    local apps=(
        "code --classic"
        "sublime-text --classic"
        "postman"
        "discord"
        "slack --classic"
        "firefox"
        "chromium"
        "dbeaver-ce"
    )
    
    echo "Aplicações disponíveis via Snap:"
    for i in "${!apps[@]}"; do
        local app_name="${apps[i]%% *}"
        echo "$((i+1)). $app_name"
    done
    echo
    
    read -p "Instalar todas as aplicações? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local failed_apps=()
        
        for app in "${apps[@]}"; do
            local app_name="${app%% *}"
            if snap list 2>/dev/null | grep -q "^$app_name "; then
                log_warning "$app_name já está instalado"
            else
                log_info "Instalando $app_name..."
                if sudo snap install $app; then
                    log_success "$app_name instalado"
                else
                    failed_apps+=("$app_name")
                    log_warning "Falha ao instalar $app_name"
                fi
            fi
        done
        
        if [[ ${#failed_apps[@]} -gt 0 ]]; then
            log_warning "Apps que falharam: ${failed_apps[*]}"
        fi
    else
        log_info "Instalação de aplicações pulada"
    fi
    
    log_success "Aplicações processadas"
}

# Instala pacotes npm globais
install_npm_packages() {
    if ! command_exists npm; then
        log_warning "npm não encontrado, pulando pacotes npm"
        return 0
    fi
    
    log_section "Pacotes npm Globais"
    
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
    
    log_success "Pacotes npm processados"
}

# Instala pacotes Python globais
install_pip_packages() {
    if ! command_exists pip3; then
        log_warning "pip3 não encontrado, pulando pacotes Python"
        return 0
    fi
    
    log_section "Pacotes Python Globais"
    
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
        if pip3 install --user "$package"; then
            log_success "$package instalado"
        else
            failed_packages+=("$package")
            log_warning "Falha ao instalar $package"
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Pacotes Python que falharam: ${failed_packages[*]}"
    fi
    
    log_success "Pacotes Python processados"
}

# Configura ambiente de desenvolvimento
configure_development_environment() {
    log_section "Configurações do Ambiente"
    
    # Configura Git
    configure_git
    
    # Cria diretórios
    create_dev_directories
    
    # Configura aliases
    configure_aliases
    
    log_success "Ambiente configurado"
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
    local zshrc_path="$HOME/.zshrc"
    
    local aliases=(
        'alias ll="ls -la"'
        'alias la="ls -la"'
        'alias dev="cd ~/Dev"'
        'alias projects="cd ~/Dev/Projects"'
        'alias scripts="cd ~/Dev/Scripts"'
        'alias playground="cd ~/Dev/Playground"'
        'alias tools="cd ~/Dev/Tools"'
        'alias aptup="sudo apt update && sudo apt upgrade"'
        'alias aptclean="sudo apt autoremove && sudo apt autoclean"'
        'alias gitlog="git log --oneline --graph --decorate --all"'
        'alias gits="git status"'
        'alias dockerclean="docker system prune -af"'
    )
    
    # Verifica comandos modernos
    if command_exists exa; then
        aliases[0]='alias ll="exa -la --git"'
        aliases[1]='alias la="exa -la"'
    fi
    
    if command_exists bat || command_exists batcat; then
        if command_exists batcat; then
            aliases+=('alias cat="batcat"')
        else
            aliases+=('alias cat="bat"')
        fi
    fi
    
    if command_exists fd; then
        aliases+=('alias find="fd"')
    fi
    
    if command_exists rg; then
        aliases+=('alias grep="rg"')
    fi
    
    for alias_cmd in "${aliases[@]}"; do
        if ! grep -Fq "$alias_cmd" "$zshrc_path" 2>/dev/null; then
            echo "$alias_cmd" >> "$zshrc_path"
        fi
    done
    
    log_info "Aliases configurados"
}

# Resumo final
show_summary() {
    log_section "Resumo da Instalação"
    
    echo -e "${CYAN}🎉 Instalação concluída com sucesso!${NC}\n"
    
    echo "✅ Instalado:"
    echo "   • Linguagens: $(command_exists node && echo "Node.js" || echo "")$(command_exists python3 && echo ", Python" || echo "")$(command_exists java && echo ", Java" || echo "")$(command_exists go && echo ", Go" || echo "")$(command_exists rustc && echo ", Rust" || echo "")"
    echo "   • Tools: Docker, Git, e muito mais"
    echo ""
    
    echo "📝 Próximos passos:"
    echo "   1. Faça logout/login para usar Docker sem sudo"
    echo "   2. Reinicie o terminal: source ~/.zshrc"
    echo "   3. Configure suas chaves SSH: ssh-keygen -t ed25519"
    echo "   4. Configure bancos de dados se instalados"
    echo ""
    
    echo "📚 Comandos úteis:"
    echo "   • aptup - atualizar sistema"
    echo "   • aptclean - limpar pacotes"
    echo "   • dockerclean - limpar Docker"
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
    echo "🚀 Instalador de Pacotes para Desenvolvimento - Ubuntu"
    echo "====================================================="
    echo -e "${NC}"
    echo "Usuário: $USER_NAME"
    echo "Sistema: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Ubuntu/Debian")"
    echo "Log: $LOG_FILE"
    echo ""
    
    read -p "Continuar com a instalação? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Instalação cancelada"
        exit 0
    fi
    
    echo "=== Instalação iniciada em $(date) ===" | tee -a "$LOG_FILE"
    
    check_ubuntu
    check_system_requirements
    backup_configs
    update_system
    install_snap
    install_cli_tools
    install_nodejs
    install_python
    install_java
    install_go
    install_rust
    install_docker
    install_databases
    install_applications
    install_npm_packages
    install_pip_packages
    configure_development_environment
    show_summary
    
    echo "=== Instalação concluída em $(date) ===" | tee -a "$LOG_FILE"
}

# Executa apenas se for chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi