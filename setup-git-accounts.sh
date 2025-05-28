#!/bin/bash

# Script para configuração de múltiplas contas Git com SSH
# Autor: Guilherme Palma
# Data: 28 de maio de 2025
# Versão: 1.0

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
readonly SSH_DIR="$HOME/.ssh"
readonly GIT_CONFIG_DIR="$HOME/.config/git"
readonly LOG_FILE="$HOME/setup-git-accounts.log"
readonly BACKUP_DIR="$HOME/.git_backup_$(date +%Y%m%d_%H%M%S)"

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

# Verifica se Git está instalado
check_git() {
    if ! command -v git >/dev/null 2>&1; then
        log_error "Git não está instalado"
        log_info "Instale primeiro: brew install git (macOS) ou sudo apt install git (Ubuntu)"
        exit 1
    fi
    
    local git_version
    git_version=$(git --version)
    log_info "$git_version detectado"
}

# Backup de configurações existentes
backup_git_configs() {
    log_info "Criando backup das configurações Git..."
    mkdir -p "$BACKUP_DIR"
    
    local files_to_backup=(
        "$HOME/.gitconfig"
        "$HOME/.gitconfig-personal"
        "$HOME/.gitconfig-work"
        "$SSH_DIR/config"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$BACKUP_DIR/" 2>/dev/null || true
            log_info "Backup: $(basename "$file")"
        fi
    done
    
    log_success "Backup criado em: $BACKUP_DIR"
}

# Coleta informações das contas
collect_account_info() {
    log_section "Configuração de Contas Git"
    
    echo "Vamos configurar suas contas Git com SSH."
    echo "Você precisará fornecer informações para cada conta."
    echo ""
    
    # Conta pessoal
    echo -e "${CYAN}=== Conta Pessoal ===${NC}"
    read -p "Nome completo (conta pessoal): " PERSONAL_NAME
    read -p "Email (conta pessoal): " PERSONAL_EMAIL
    read -p "Nome de usuário GitHub/GitLab (conta pessoal): " PERSONAL_USERNAME
    
    echo
    
    # Conta de trabalho
    echo -e "${CYAN}=== Conta de Trabalho ===${NC}"
    read -p "Nome completo (conta trabalho): " WORK_NAME
    read -p "Email (conta trabalho): " WORK_EMAIL
    read -p "Nome de usuário GitHub/GitLab (conta trabalho): " WORK_USERNAME
    
    echo
    log_info "Informações coletadas:"
    log_info "Pessoal: $PERSONAL_NAME <$PERSONAL_EMAIL> (@$PERSONAL_USERNAME)"
    log_info "Trabalho: $WORK_NAME <$WORK_EMAIL> (@$WORK_USERNAME)"
}

# Configura diretório SSH
setup_ssh_directory() {
    log_section "Configuração SSH"
    
    if [[ ! -d "$SSH_DIR" ]]; then
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
        log_info "Diretório SSH criado"
    fi
    
    # Backup do config SSH existente
    if [[ -f "$SSH_DIR/config" ]]; then
        cp "$SSH_DIR/config" "$SSH_DIR/config.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backup do SSH config criado"
    fi
}

# Gera chaves SSH
generate_ssh_keys() {
    log_section "Gerando Chaves SSH"
    
    # Chave pessoal
    local personal_key="$SSH_DIR/id_ed25519_personal"
    if [[ ! -f "$personal_key" ]]; then
        log_info "Gerando chave SSH pessoal..."
        ssh-keygen -t ed25519 -C "$PERSONAL_EMAIL" -f "$personal_key" -N ""
        chmod 600 "$personal_key"
        chmod 644 "${personal_key}.pub"
        log_success "Chave pessoal gerada: $personal_key"
    else
        log_warning "Chave pessoal já existe: $personal_key"
    fi
    
    # Chave de trabalho
    local work_key="$SSH_DIR/id_ed25519_work"
    if [[ ! -f "$work_key" ]]; then
        log_info "Gerando chave SSH de trabalho..."
        ssh-keygen -t ed25519 -C "$WORK_EMAIL" -f "$work_key" -N ""
        chmod 600 "$work_key"
        chmod 644 "${work_key}.pub"
        log_success "Chave de trabalho gerada: $work_key"
    else
        log_warning "Chave de trabalho já existe: $work_key"
    fi
}

# Configura SSH config
configure_ssh_config() {
    log_section "Configuração SSH Config"
    
    local ssh_config="$SSH_DIR/config"
    
    # Cria novo config SSH
    cat > "$ssh_config" << EOF
# Configuração SSH para múltiplas contas Git
# Gerado automaticamente em $(date)

# Conta pessoal (GitHub)
Host github.com-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes

# Conta de trabalho (GitHub)
Host github.com-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_work
    IdentitiesOnly yes
    
# Configurações gerais
Host *
    AddKeysToAgent yes
    UseKeychain yes
    ServerAliveInterval 60
    ServerAliveCountMax 30
EOF
    
    chmod 600 "$ssh_config"
    log_success "SSH config configurado"
}

# Adiciona chaves ao ssh-agent
add_keys_to_agent() {
    log_section "Adicionando Chaves ao SSH Agent"
    
    # Inicia ssh-agent se necessário
    if ! pgrep -f ssh-agent >/dev/null; then
        eval "$(ssh-agent -s)"
        log_info "SSH agent iniciado"
    fi
    
    # Adiciona chaves
    ssh-add "$SSH_DIR/id_ed25519_personal" 2>/dev/null || log_warning "Falha ao adicionar chave pessoal"
    ssh-add "$SSH_DIR/id_ed25519_work" 2>/dev/null || log_warning "Falha ao adicionar chave de trabalho"
    
    log_success "Chaves adicionadas ao SSH agent"
}

# Configura Git global
configure_git_global() {
    log_section "Configuração Git Global"
    
    # Configuração global básica
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global push.default simple
    git config --global core.autocrlf input
    git config --global core.editor "vim"
    
    # Remove configurações de usuário globais para forçar uso de includeIf
    git config --global --unset user.name 2>/dev/null || true
    git config --global --unset user.email 2>/dev/null || true
    
    log_success "Git global configurado"
}

# Cria configurações específicas
create_git_configs() {
    log_section "Criando Configurações Específicas"
    
    mkdir -p "$GIT_CONFIG_DIR"
    
    # Configuração pessoal
    cat > "$HOME/.gitconfig-personal" << EOF
[user]
    name = $PERSONAL_NAME
    email = $PERSONAL_EMAIL
    username = $PERSONAL_USERNAME

[github]
    user = $PERSONAL_USERNAME

[core]
    sshCommand = ssh -i ~/.ssh/id_ed25519_personal
EOF
    
    # Configuração de trabalho
    cat > "$HOME/.gitconfig-work" << EOF
[user]
    name = $WORK_NAME
    email = $WORK_EMAIL
    username = $WORK_USERNAME

[github]
    user = $WORK_USERNAME

[core]
    sshCommand = ssh -i ~/.ssh/id_ed25519_work
EOF
    
    log_success "Configurações específicas criadas"
}

# Cria estrutura de diretórios
create_project_structure() {
    log_section "Estrutura de Projetos"
    
    local dev_dirs=(
        "$HOME/Dev"
        "$HOME/Dev/Projects"
        "$HOME/Dev/Projects/Personal"
        "$HOME/Dev/Projects/Work"
        "$HOME/Dev/Scripts"
        "$HOME/Dev/Learning"
    )
    
    for dir in "${dev_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_info "Criado: $dir"
        fi
    done
    
    log_success "Estrutura de diretórios criada"
}

# Configura includeIf no .gitconfig
configure_git_includeif() {
    log_section "Configuração Condicional Git"
    
    # Adiciona includeIf ao .gitconfig global
    cat >> "$HOME/.gitconfig" << EOF

# Configuração condicional por diretório
[includeIf "gitdir:~/Dev/Projects/Personal/"]
    path = ~/.gitconfig-personal

[includeIf "gitdir:~/Dev/Projects/Work/"]
    path = ~/.gitconfig-work
EOF
    
    log_success "Configuração condicional aplicada"
}

# Cria aliases úteis
create_git_aliases() {
    log_section "Aliases Git e Shell"
    
    # Aliases Git
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.unstage "reset HEAD --"
    git config --global alias.last "log -1 HEAD"
    git config --global alias.visual "!gitk"
    git config --global alias.tree "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
    
    # Aliases para o shell
    local zshrc="$HOME/.zshrc"
    local shell_aliases=(
        '# Git aliases para múltiplas contas'
        'alias git-personal="cd ~/Dev/Projects/Personal"'
        'alias git-work="cd ~/Dev/Projects/Work"'
        'alias clone-personal="git clone git@github.com-personal:"'
        'alias clone-work="git clone git@github.com-work:"'
        'alias git-check-config="git config --list | grep -E \"user\\.(name|email)\""'
    )
    
    for alias_line in "${shell_aliases[@]}"; do
        if ! grep -Fq "$alias_line" "$zshrc" 2>/dev/null; then
            echo "$alias_line" >> "$zshrc"
        fi
    done
    
    log_success "Aliases configurados"
}

# Cria script de teste
create_test_script() {
    log_section "Script de Teste"
    
    cat > "$HOME/test-git-setup.sh" << 'EOF'
#!/bin/bash

# Script para testar configuração Git

echo "🧪 Testando configuração Git com múltiplas contas"
echo "================================================"

# Testa configuração em diferentes diretórios
echo
echo "📁 Testando diretório pessoal:"
cd ~/Dev/Projects/Personal
echo "PWD: $(pwd)"
echo "User: $(git config user.name 2>/dev/null || echo 'NÃO CONFIGURADO')"
echo "Email: $(git config user.email 2>/dev/null || echo 'NÃO CONFIGURADO')"

echo
echo "📁 Testando diretório de trabalho:"
cd ~/Dev/Projects/Work
echo "PWD: $(pwd)"
echo "User: $(git config user.name 2>/dev/null || echo 'NÃO CONFIGURADO')"
echo "Email: $(git config user.email 2>/dev/null || echo 'NÃO CONFIGURADO')"

echo
echo "🔑 Testando chaves SSH:"
ssh-add -l | grep -E "(personal|work)" || echo "Chaves não carregadas no agent"

echo
echo "🌐 Testando conectividade SSH:"
echo "GitHub (pessoal):"
ssh -T git@github.com-personal 2>&1 | head -n1 || echo "Falha na conexão"

echo "GitHub (trabalho):"
ssh -T git@github.com-work 2>&1 | head -n1 || echo "Falha na conexão"

echo
echo "✅ Teste concluído!"
EOF
    
    chmod +x "$HOME/test-git-setup.sh"
    log_success "Script de teste criado: ~/test-git-setup.sh"
}

# Mostra chaves públicas
show_public_keys() {
    log_section "Chaves Públicas SSH"
    
    echo -e "${CYAN}📋 Adicione estas chaves às suas contas:${NC}"
    echo
    
    echo -e "${YELLOW}🔑 Chave Pessoal (adicione ao GitHub/GitLab pessoal):${NC}"
    if [[ -f "$SSH_DIR/id_ed25519_personal.pub" ]]; then
        cat "$SSH_DIR/id_ed25519_personal.pub"
    else
        log_error "Chave pessoal não encontrada"
    fi
    
    echo
    echo -e "${YELLOW}🔑 Chave de Trabalho (adicione ao GitHub/GitLab do trabalho):${NC}"
    if [[ -f "$SSH_DIR/id_ed25519_work.pub" ]]; then
        cat "$SSH_DIR/id_ed25519_work.pub"
    else
        log_error "Chave de trabalho não encontrada"
    fi
    
    echo
    echo -e "${BLUE}📖 Como adicionar no GitHub:${NC}"
    echo "1. Vá para Settings > SSH and GPG keys"
    echo "2. Clique em 'New SSH key'"
    echo "3. Cole a chave pública correspondente"
    echo "4. Dê um nome descritivo (ex: 'Laptop Pessoal')"
}

# Instruções finais
show_final_instructions() {
    log_section "Instruções Finais"
    
    echo -e "${CYAN}🎉 Configuração Git concluída!${NC}"
    echo
    echo -e "${YELLOW}📝 Como usar:${NC}"
    echo
    echo "1. Para projetos pessoais:"
    echo "   cd ~/Dev/Projects/Personal"
    echo "   git clone git@github.com-personal:usuario/repo.git"
    echo
    echo "2. Para projetos de trabalho:"
    echo "   cd ~/Dev/Projects/Work" 
    echo "   git clone git@github.com-work:empresa/repo.git"
    echo
    echo -e "${YELLOW}🔧 Aliases disponíveis:${NC}"
    echo "   git-personal  - vai para diretório pessoal"
    echo "   git-work      - vai para diretório de trabalho"
    echo "   clone-personal - clone usando conta pessoal"
    echo "   clone-work     - clone usando conta de trabalho"
    echo
    echo -e "${YELLOW}🧪 Teste a configuração:${NC}"
    echo "   ~/test-git-setup.sh"
    echo
    echo -e "${YELLOW}📋 Arquivos importantes:${NC}"
    echo "   • Backup: $BACKUP_DIR"
    echo "   • Log: $LOG_FILE"
    echo "   • SSH Config: ~/.ssh/config"
    echo "   • Git Configs: ~/.gitconfig-personal, ~/.gitconfig-work"
    echo
    log_success "Setup Git com múltiplas contas finalizado! 🚀"
}

# Função principal
main() {
    echo -e "${BLUE}"
    echo "🔐 Configurador de Múltiplas Contas Git"
    echo "======================================="
    echo -e "${NC}"
    echo "Este script irá configurar Git com SSH para múltiplas contas."
    echo "Usuário: $USER_NAME"
    echo "Log: $LOG_FILE"
    echo ""
    
    read -p "Continuar com a configuração? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Configuração cancelada"
        exit 0
    fi
    
    echo "=== Setup Git iniciado em $(date) ===" | tee -a "$LOG_FILE"
    
    check_git
    backup_git_configs
    collect_account_info
    setup_ssh_directory
    generate_ssh_keys
    configure_ssh_config
    add_keys_to_agent
    configure_git_global
    create_git_configs
    create_project_structure
    configure_git_includeif
    create_git_aliases
    create_test_script
    show_public_keys
    show_final_instructions
    
    echo "=== Setup Git concluído em $(date) ===" | tee -a "$LOG_FILE"
}

# Executa apenas se for chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi