#!/bin/bash

# Script para configuração automática do terminal com Oh My Zsh e PowerLevel10K - macOS
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
readonly HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
readonly OHMYZSH_INSTALL_URL="https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
readonly P10K_REPO_URL="https://github.com/romkatv/powerlevel10k.git"
readonly BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"

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

# Backup de arquivos de configuração
backup_configs() {
    log_info "Criando backup das configurações existentes..."
    mkdir -p "$BACKUP_DIR"
    
    local files_to_backup=(
        "$HOME/.zshrc"
        "$HOME/.zprofile"
        "$HOME/.bashrc"
        "$HOME/.bash_profile"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$BACKUP_DIR/" 2>/dev/null || true
            log_info "Backup criado: $file -> $BACKUP_DIR/"
        fi
    done
    
    log_success "Backup criado em: $BACKUP_DIR"
}

# Verifica se já está rodando no macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "Este script é específico para macOS"
        exit 1
    fi
    
    # Verifica versão mínima do macOS
    local macos_version
    macos_version=$(sw_vers -productVersion | cut -d. -f1,2)
    local required_version="10.15"
    
    if [[ $(echo "$macos_version >= $required_version" | bc 2>/dev/null || echo "0") -eq 0 ]]; then
        log_warning "macOS $macos_version detectado. Recomendado: $required_version ou superior"
    fi
}

# Instala Homebrew se não existir com verificações melhoradas
install_homebrew() {
    if command_exists brew; then
        log_warning "Homebrew já está instalado ($(brew --version | head -n1))"
        
        # Verifica se está no PATH
        if ! echo "$PATH" | grep -q "/opt/homebrew/bin\|/usr/local/bin"; then
            log_warning "Homebrew não está no PATH, configurando..."
            setup_homebrew_path
        fi
        return 0
    fi
    
    log_info "Instalando Homebrew..."
    
    # Verifica se Xcode Command Line Tools estão instalados
    if ! xcode-select -p >/dev/null 2>&1; then
        log_info "Instalando Xcode Command Line Tools..."
        xcode-select --install
        log_warning "Por favor, complete a instalação do Xcode CLI Tools e execute o script novamente"
        exit 1
    fi
    
    # Instala Homebrew com verificação de erro
    if ! /bin/bash -c "$(curl -fsSL $HOMEBREW_INSTALL_URL)"; then
        log_error "Falha ao instalar Homebrew"
        exit 1
    fi
    
    setup_homebrew_path
    log_success "Homebrew instalado com sucesso"
}

# Configura PATH do Homebrew
setup_homebrew_path() {
    local shell_profile="$HOME/.zprofile"
    local homebrew_path=""
    
    # Detecta arquitetura
    if [[ -f /opt/homebrew/bin/brew ]]; then
        homebrew_path="/opt/homebrew/bin/brew"
    elif [[ -f /usr/local/bin/brew ]]; then
        homebrew_path="/usr/local/bin/brew"
    else
        log_error "Homebrew não encontrado em locais padrão"
        return 1
    fi
    
    # Adiciona ao PATH se necessário
    local homebrew_env="eval \"\$($homebrew_path shellenv)\""
    if [[ -f "$shell_profile" ]] && grep -Fq "$homebrew_env" "$shell_profile"; then
        log_info "PATH do Homebrew já configurado"
    else
        echo "$homebrew_env" >> "$shell_profile"
        log_info "PATH do Homebrew adicionado ao $shell_profile"
    fi
    
    # Aplica imediatamente
    eval "$($homebrew_path shellenv)"
}

# Instala pacotes essenciais com verificação de falhas
install_packages() {
    log_info "Instalando pacotes essenciais..."
    
    local packages=(
        "zsh"
        "zsh-autosuggestions"
        "zsh-syntax-highlighting"
        "htop"
        "git"
        "tree"
        "wget"
    )
    
    local failed_packages=()
    
    for package in "${packages[@]}"; do
        if brew list "$package" &>/dev/null; then
            log_warning "$package já está instalado"
        else
            log_info "Instalando $package..."
            if ! brew install "$package"; then
                failed_packages+=("$package")
                log_error "Falha ao instalar $package"
            else
                log_success "$package instalado"
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
    
    log_success "Instalação de pacotes concluída"
}

# Instala Oh My Zsh com verificações melhoradas
install_ohmyzsh() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        log_warning "Oh My Zsh já está instalado"
        
        # Verifica se precisa atualizar
        if [[ -f "$HOME/.oh-my-zsh/tools/upgrade.sh" ]]; then
            read -p "Atualizar Oh My Zsh? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                "$HOME/.oh-my-zsh/tools/upgrade.sh" || true
            fi
        fi
        return 0
    fi
    
    log_info "Instalando Oh My Zsh..."
    
    # Download e verificação
    local install_script="/tmp/install_ohmyzsh.sh"
    if ! curl -fsSL "$OHMYZSH_INSTALL_URL" -o "$install_script"; then
        log_error "Falha ao baixar script do Oh My Zsh"
        exit 1
    fi
    
    # Executa instalação não interativa
    if ! sh "$install_script" --unattended; then
        log_error "Falha ao instalar Oh My Zsh"
        exit 1
    fi
    
    rm -f "$install_script"
    log_success "Oh My Zsh instalado com sucesso"
}

# Instala PowerLevel10K com validação
install_powerlevel10k() {
    local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    
    if [[ -d "$p10k_dir" ]]; then
        log_warning "PowerLevel10K já está instalado"
        
        # Verifica se precisa atualizar
        read -p "Atualizar PowerLevel10K? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Atualizando PowerLevel10K..."
            git -C "$p10k_dir" pull || log_warning "Falha ao atualizar PowerLevel10K"
        fi
        return 0
    fi
    
    log_info "Instalando PowerLevel10K..."
    
    # Verifica se o diretório pai existe
    local themes_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes"
    if [[ ! -d "$themes_dir" ]]; then
        mkdir -p "$themes_dir"
    fi
    
    if ! git clone --depth=1 "$P10K_REPO_URL" "$p10k_dir"; then
        log_error "Falha ao instalar PowerLevel10K"
        exit 1
    fi
    
    log_success "PowerLevel10K instalado com sucesso"
}

# Configura o tema no .zshrc com validação melhorada
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
    
    # Configura plugins se Oh My Zsh estiver presente
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        if ! grep -q "plugins=.*zsh-autosuggestions" "$zshrc_path"; then
            if grep -q "^plugins=" "$zshrc_path"; then
                sed -i.bak 's/plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting)/' "$zshrc_path"
            else
                echo "plugins=(git zsh-autosuggestions zsh-syntax-highlighting)" >> "$zshrc_path"
            fi
            log_info "Plugins configurados"
        fi
    fi
    
    log_success "Tema configurado com sucesso"
}

# Define zsh como shell padrão
set_default_shell() {
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
    if ! chsh -s "$zsh_path"; then
        log_error "Falha ao definir zsh como shell padrão"
        log_info "Execute manualmente: chsh -s $zsh_path"
        return 1
    fi
    
    log_success "Zsh definido como shell padrão"
}

# Finaliza a configuração
finish_setup() {
    log_success "🎉 Terminal configurado com sucesso!"
    echo ""
    echo "📝 Informações importantes:"
    echo "   • Backup das configurações: $BACKUP_DIR"
    echo "   • Reinicie o terminal ou execute: source ~/.zshrc"
    echo "   • Na primeira execução, o PowerLevel10K solicitará configurações"
    echo "   • Use 'p10k configure' para reconfigurar o tema"
    echo ""
    echo "🔧 Comandos úteis:"
    echo "   • upgrade_oh_my_zsh - Atualizar Oh My Zsh"
    echo "   • brew update && brew upgrade - Atualizar Homebrew"
    echo ""
}

# Função principal
main() {
    echo -e "${BLUE}"
    echo "🚀 Configurador de Terminal Avançado - macOS"
    echo "=============================================="
    echo -e "${NC}"
    echo "Usuário detectado: $USER_NAME"
    echo ""
    
    check_macos
    backup_configs
    install_homebrew
    install_packages
    install_ohmyzsh
    install_powerlevel10k
    configure_theme
    set_default_shell
    finish_setup
}

# Executa apenas se for chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi