#!/bin/bash

# Script para configuração automática do terminal com Oh My Zsh e PowerLevel10K - Ubuntu
# Autor: Guilherme Palma
# Data: 28 de maio de 2025
# Versão: 2.1 - Corrigido

set -euo pipefail
IFS=$'\n\t'

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Variáveis globais
readonly USER_NAME="$USER"
readonly OHMYZSH_INSTALL_URL="https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
readonly P10K_REPO_URL="https://github.com/romkatv/powerlevel10k.git"
readonly BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
readonly LOG_FILE="$HOME/setup-terminal-ubuntu.log"

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
    
    # Verifica se tem privilégios sudo
    if ! sudo -n true 2>/dev/null; then
        log_info "Este script requer privilégios sudo"
        sudo -v || {
            log_error "Falha ao obter privilégios sudo"
            exit 1
        }
    fi
}

# Verifica conectividade e espaço
check_system_requirements() {
    # Verifica conexão
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "Sem conexão com a internet"
        exit 1
    fi
    
    # Verifica espaço em disco
    local available_gb
    available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [[ $available_gb -lt 3 ]]; then
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
    log_info "Criando backup das configurações existentes..."
    mkdir -p "$BACKUP_DIR"
    
    local files_to_backup=(
        "$HOME/.zshrc"
        "$HOME/.bashrc"
        "$HOME/.profile"
        "$HOME/.bash_profile"
        "$HOME/.gitconfig"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$BACKUP_DIR/" 2>/dev/null || true
            log_info "Backup: $(basename "$file")"
        fi
    done
    
    log_success "Backup criado em: $BACKUP_DIR"
}

# Atualiza o sistema
update_system() {
    log_info "Atualizando sistema..."
    
    # Atualiza lista de pacotes
    if ! sudo apt-get update -y; then
        log_error "Falha ao atualizar lista de pacotes"
        exit 1
    fi
    
    # Upgrade do sistema (opcional)
    read -p "Executar upgrade completo do sistema? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo apt-get upgrade -y || log_warning "Falha no upgrade do sistema"
    fi
    
    log_success "Sistema atualizado"
}

# Instala pacotes essenciais
install_packages() {
    log_info "Instalando pacotes essenciais..."
    
    local packages=(
        "zsh"
        "git"
        "curl"
        "wget"
        "htop"
        "tree"
        "unzip"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "build-essential"
        "fonts-powerline"
        "fontconfig"
    )
    
    local failed_packages=()
    
    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  $package "; then
            log_warning "$package já está instalado"
        else
            log_info "Instalando $package..."
            if sudo apt-get install -y "$package"; then
                log_success "$package instalado"
            else
                failed_packages+=("$package")
                log_error "Falha ao instalar $package"
            fi
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Pacotes que falharam: ${failed_packages[*]}"
        read -p "Continuar mesmo assim? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "Pacotes essenciais instalados"
}

# Instala zsh-autosuggestions e zsh-syntax-highlighting
install_zsh_plugins() {
    log_info "Instalando plugins do zsh..."
    
    local plugin_dir="/usr/share"
    local plugins_installed=0
    
    # zsh-autosuggestions
    if [[ ! -d "$plugin_dir/zsh-autosuggestions" ]]; then
        if sudo apt-get install -y zsh-autosuggestions 2>/dev/null; then
            log_success "zsh-autosuggestions instalado via apt"
            ((plugins_installed++))
        else
            log_info "Instalando zsh-autosuggestions via git..."
            if sudo git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir/zsh-autosuggestions"; then
                log_success "zsh-autosuggestions instalado via git"
                ((plugins_installed++))
            else
                log_warning "Falha ao instalar zsh-autosuggestions"
            fi
        fi
    else
        log_warning "zsh-autosuggestions já está instalado"
        ((plugins_installed++))
    fi
    
    # zsh-syntax-highlighting
    if [[ ! -d "$plugin_dir/zsh-syntax-highlighting" ]]; then
        if sudo apt-get install -y zsh-syntax-highlighting 2>/dev/null; then
            log_success "zsh-syntax-highlighting instalado via apt"
            ((plugins_installed++))
        else
            log_info "Instalando zsh-syntax-highlighting via git..."
            if sudo git clone https://github.com/zsh-users/zsh-syntax-highlighting "$plugin_dir/zsh-syntax-highlighting"; then
                log_success "zsh-syntax-highlighting instalado via git"
                ((plugins_installed++))
            else
                log_warning "Falha ao instalar zsh-syntax-highlighting"
            fi
        fi
    else
        log_warning "zsh-syntax-highlighting já está instalado"
        ((plugins_installed++))
    fi
    
    if [[ $plugins_installed -eq 2 ]]; then
        log_success "Plugins do zsh instalados com sucesso"
    else
        log_warning "Alguns plugins falharam ($plugins_installed/2), mas continuando..."
    fi
}

# Define zsh como shell padrão
set_zsh_default() {
    local zsh_path
    zsh_path="$(which zsh)"
    
    if [[ "$SHELL" == "$zsh_path" ]]; then
        log_warning "Zsh já é o shell padrão"
        return 0
    fi
    
    log_info "Definindo zsh como shell padrão..."
    
    # Adiciona zsh ao /etc/shells se necessário
    if ! grep -Fxq "$zsh_path" /etc/shells; then
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi
    
    # Muda o shell
    if chsh -s "$zsh_path"; then
        log_success "Zsh definido como shell padrão"
    else
        log_error "Falha ao definir zsh como shell padrão"
        log_info "Execute manualmente: chsh -s $zsh_path"
        return 1
    fi
}

# Instala Oh My Zsh
install_ohmyzsh() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        log_warning "Oh My Zsh já está instalado"
        
        # Opção de atualizar
        read -p "Atualizar Oh My Zsh? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [[ -f "$HOME/.oh-my-zsh/tools/upgrade.sh" ]]; then
                "$HOME/.oh-my-zsh/tools/upgrade.sh" || log_warning "Falha ao atualizar"
            fi
        fi
        return 0
    fi
    
    log_info "Instalando Oh My Zsh..."
    
    # Download do script
    local install_script="/tmp/install_ohmyzsh.sh"
    if ! curl -fsSL "$OHMYZSH_INSTALL_URL" -o "$install_script"; then
        log_error "Falha ao baixar script do Oh My Zsh"
        exit 1
    fi
    
    # Executa instalação
    if sh "$install_script" --unattended; then
        log_success "Oh My Zsh instalado com sucesso"
    else
        log_error "Falha ao instalar Oh My Zsh"
        exit 1
    fi
    
    rm -f "$install_script"
}

# Instala PowerLevel10K
install_powerlevel10k() {
    local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    
    if [[ -d "$p10k_dir" ]]; then
        log_warning "PowerLevel10K já está instalado"
        
        # Opção de atualizar
        read -p "Atualizar PowerLevel10K? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Atualizando PowerLevel10K..."
            git -C "$p10k_dir" pull || log_warning "Falha ao atualizar"
        fi
        return 0
    fi
    
    log_info "Instalando PowerLevel10K..."
    
    # Verifica se o diretório existe
    local themes_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes"
    if [[ ! -d "$themes_dir" ]]; then
        mkdir -p "$themes_dir"
    fi
    
    if git clone --depth=1 "$P10K_REPO_URL" "$p10k_dir"; then
        log_success "PowerLevel10K instalado com sucesso"
    else
        log_error "Falha ao instalar PowerLevel10K"
        exit 1
    fi
}

# Configura o tema no .zshrc
configure_theme() {
    local zshrc_path="$HOME/.zshrc"
    
    if [[ ! -f "$zshrc_path" ]]; then
        log_warning "Arquivo .zshrc não encontrado, criando..."
        touch "$zshrc_path"
    fi
    
    log_info "Configurando tema PowerLevel10K no .zshrc..."
    
    # Remove linha ZSH_THEME existente e adiciona a nova
    if grep -q "^ZSH_THEME=" "$zshrc_path"; then
        sed -i.bak 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$zshrc_path"
        log_info "Tema ZSH atualizado"
    else
        echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$zshrc_path"
        log_info "Tema ZSH adicionado"
    fi
    
    # Configura plugins
    if ! grep -q "plugins=.*zsh-autosuggestions" "$zshrc_path"; then
        if grep -q "^plugins=" "$zshrc_path"; then
            sed -i.bak 's/plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting)/' "$zshrc_path"
        else
            echo "plugins=(git zsh-autosuggestions zsh-syntax-highlighting)" >> "$zshrc_path"
        fi
        log_info "Plugins configurados"
    fi
    
    # Adiciona source dos plugins se instalados via git
    local plugin_sources=(
        "source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
        "source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    )
    
    for source_line in "${plugin_sources[@]}"; do
        local plugin_file="${source_line#source }"
        if [[ -f "$plugin_file" ]] && ! grep -Fq "$source_line" "$zshrc_path"; then
            echo "$source_line" >> "$zshrc_path"
        fi
    done
    
    log_success "Tema configurado com sucesso"
}

# Instala fontes para PowerLevel10K
install_fonts() {
    log_info "Instalando fontes para PowerLevel10K..."
    
    # Cria diretório de fontes
    local fonts_dir="$HOME/.local/share/fonts"
    mkdir -p "$fonts_dir"
    
    # Download das fontes MesloLGS NF
    local fonts=(
        "MesloLGS NF Regular.ttf"
        "MesloLGS NF Bold.ttf"
        "MesloLGS NF Italic.ttf"
        "MesloLGS NF Bold Italic.ttf"
    )
    
    local fonts_installed=0
    
    for font in "${fonts[@]}"; do
        local font_file="$fonts_dir/$font"
        if [[ ! -f "$font_file" ]]; then
            local url="https://github.com/romkatv/powerlevel10k-media/raw/master/${font// /%20}"
            log_info "Baixando $font..."
            if curl -fsSL "$url" -o "$font_file"; then
                ((fonts_installed++))
            else
                log_warning "Falha ao baixar $font"
            fi
        else
            log_warning "$font já existe"
            ((fonts_installed++))
        fi
    done
    
    # Atualiza cache de fontes
    if [[ $fonts_installed -gt 0 ]]; then
        fc-cache -f -v >/dev/null 2>&1 || log_warning "Falha ao atualizar cache de fontes"
        log_success "Fontes instaladas ($fonts_installed/${#fonts[@]})"
    else
        log_warning "Nenhuma fonte foi instalada"
    fi
}

# Configura aliases úteis
configure_aliases() {
    local zshrc_path="$HOME/.zshrc"
    
    local aliases=(
        'alias ll="ls -la"'
        'alias la="ls -la"'
        'alias dev="cd ~/Dev"'
        'alias projects="cd ~/Dev/Projects"'
        'alias scripts="cd ~/Dev/Scripts"'
        'alias aptup="sudo apt update && sudo apt upgrade"'
        'alias aptclean="sudo apt autoremove && sudo apt autoclean"'
        'alias gitlog="git log --oneline --graph --decorate --all"'
        'alias gits="git status"'
    )
    
    # Verifica se comandos modernos estão disponíveis
    if command_exists exa; then
        aliases[0]='alias ll="exa -la --git"'
        aliases[1]='alias la="exa -la"'
    fi
    
    if command_exists bat; then
        aliases+=('alias cat="bat"')
    fi
    
    if command_exists fd; then
        aliases+=('alias find="fd"')
    fi
    
    for alias_cmd in "${aliases[@]}"; do
        if ! grep -Fq "$alias_cmd" "$zshrc_path" 2>/dev/null; then
            echo "$alias_cmd" >> "$zshrc_path"
        fi
    done
    
    log_info "Aliases configurados"
}

# Finaliza a configuração
finish_setup() {
    log_success "🎉 Terminal configurado com sucesso!"
    echo ""
    echo "📝 Informações importantes:"
    echo "   • Backup das configurações: $BACKUP_DIR"
    echo "   • Reinicie o terminal ou execute: zsh"
    echo "   • Na primeira execução, o PowerLevel10K solicitará configurações"
    echo "   • Configure seu terminal para usar a fonte 'MesloLGS NF'"
    echo ""
    echo "🔧 Comandos úteis:"
    echo "   • p10k configure - Reconfigurar tema"
    echo "   • aptup - Atualizar sistema"
    echo "   • aptclean - Limpar pacotes"
    echo ""
    echo "📋 Arquivos:"
    echo "   • Log: $LOG_FILE"
    echo "   • Backup: $BACKUP_DIR"
    echo ""
}

# Função principal
main() {
    echo -e "${BLUE}"
    echo "🚀 Configurador de Terminal Avançado - Ubuntu"
    echo "=============================================="
    echo -e "${NC}"
    echo "Usuário: $USER_NAME"
    echo "Log: $LOG_FILE"
    echo ""
    
    echo "=== Setup iniciado em $(date) ===" | tee -a "$LOG_FILE"
    
    check_ubuntu
    check_system_requirements
    backup_configs
    update_system
    install_packages
    install_zsh_plugins
    set_zsh_default
    install_ohmyzsh
    install_powerlevel10k
    configure_theme
    install_fonts
    configure_aliases
    finish_setup
    
    echo "=== Setup concluído em $(date) ===" | tee -a "$LOG_FILE"
}

# Executa apenas se for chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi