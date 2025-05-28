#!/bin/bash

# Script Orquestrador - Setup Completo de Desenvolvimento
# Autor: Guilherme Palma
# Data: 28 de maio de 2025
# Versão: 1.1 - Corrigido

set -euo pipefail
IFS=$'\n\t'  # Previne word splitting

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Variáveis globais
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly USER_NAME="$USER"
readonly LOG_FILE="$HOME/setup-dev-env.log"

# Função de logging
setup_logging() {
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    echo "=== Setup iniciado em $(date) ===" >> "$LOG_FILE"
}

# Funções auxiliares
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"
}

log_section() {
    echo -e "\n${PURPLE}🚀 $1${NC}" | tee -a "$LOG_FILE"
    echo "==================================================" | tee -a "$LOG_FILE"
}

# Cleanup em caso de interrupção
cleanup() {
    local exit_code=$?
    log_warning "Script interrompido"
    echo "=== Setup interrompido em $(date) com código $exit_code ===" >> "$LOG_FILE"
    exit $exit_code
}

trap cleanup INT TERM

# Detecta o sistema operacional com mais precisão
detect_os() {
    local os_type=""
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        os_type="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux" ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            os_type="ubuntu"
        elif command -v yum >/dev/null 2>&1; then
            os_type="rhel"
        elif command -v pacman >/dev/null 2>&1; then
            os_type="arch"
        else
            os_type="linux"
        fi
    else
        os_type="unknown"
    fi
    
    echo "$os_type"
}

# Verifica se os scripts existem com validação melhorada
check_scripts() {
    local os_type="$1"
    local scripts=()
    local missing_scripts=()
    
    if [[ "$os_type" == "macos" ]]; then
        scripts=(
            "$SCRIPT_DIR/setup-terminal-macos.sh"
            "$SCRIPT_DIR/setup-dev-tools-macos.sh"
        )
    elif [[ "$os_type" == "ubuntu" ]]; then
        scripts=(
            "$SCRIPT_DIR/setup-terminal-ubuntu.sh"
            "$SCRIPT_DIR/setup-dev-tools-ubuntu.sh"
        )
    else
        log_error "Sistema operacional '$os_type' não suportado"
        return 1
    fi
    
    for script in "${scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            missing_scripts+=("$script")
        elif [[ ! -r "$script" ]]; then
            log_error "Script não é legível: $script"
            return 1
        fi
    done
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_error "Scripts não encontrados:"
        printf '%s\n' "${missing_scripts[@]}"
        return 1
    fi
    
    # Torna executáveis se necessário
    for script in "${scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            log_info "Tornando executável: $(basename "$script")"
            chmod +x "$script" || {
                log_error "Falha ao tornar executável: $script"
                return 1
            }
        fi
    done
    
    return 0
}

# Executa um script com tratamento de erro melhorado
execute_script() {
    local script_path="$1"
    local script_name="$(basename "$script_path")"
    local start_time=$(date +%s)
    
    log_section "Executando $script_name"
    
    # Verifica se o script existe antes de executar
    if [[ ! -f "$script_path" ]]; then
        log_error "Script não encontrado: $script_path"
        return 1
    fi
    
    # Executa com timeout para evitar travamentos
    if timeout 3600 bash "$script_path"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "$script_name executado com sucesso (${duration}s)"
        return 0
    else
        local exit_code=$?
        log_error "Falha ao executar $script_name (código: $exit_code)"
        
        echo
        read -p "Continuar mesmo assim? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Setup cancelado pelo usuário"
            exit 1
        fi
        return 1
    fi
}

# Verifica requisitos do sistema
check_system_requirements() {
    local os_type="$1"
    
    log_info "Verificando requisitos do sistema..."
    
    # Verifica conexão com internet
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        log_error "Sem conexão com a internet"
        return 1
    fi
    
    # Verifica espaço em disco (mínimo 5GB)
    local available_space
    if [[ "$os_type" == "macos" ]]; then
        available_space=$(df -g / | awk 'NR==2 {print $4}')
    else
        available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    fi
    
    if [[ $available_space -lt 5 ]]; then
        log_warning "Pouco espaço em disco disponível: ${available_space}GB"
        read -p "Continuar mesmo assim? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # Verifica se já há algum setup em andamento
    if pgrep -f "setup-.*\.sh" >/dev/null 2>&1; then
        log_warning "Outro script de setup parece estar rodando"
        read -p "Continuar mesmo assim? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    log_success "Requisitos do sistema verificados"
    return 0
}

# Menu interativo melhorado
show_menu() {
    local os_type="$1"
    
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║        🚀 Setup Completo de Desenvolvimento     ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "Sistema detectado: $os_type"
    echo "Usuário: $USER_NAME"
    echo "Log: $LOG_FILE"
    echo ""
    echo "Opções disponíveis:"
    echo "1. 🖥️  Setup completo (terminal + ferramentas)"
    echo "2. 🐚 Apenas setup do terminal"
    echo "3. 🛠️  Apenas ferramentas de desenvolvimento"
    echo "4. 📋 Verificar sistema antes de instalar"
    echo "5. ❌ Cancelar"
    echo ""
}

# Validação de entrada do usuário
get_user_choice() {
    local choice
    while true; do
        read -p "Escolha uma opção (1-5): " -n 1 -r choice
        echo
        
        case $choice in
            [1-5])
                echo "$choice"
                return 0
                ;;
            *)
                log_warning "Opção inválida. Digite um número de 1 a 5."
                ;;
        esac
    done
}

# Função principal melhorada
main() {
    local os_type
    local choice
    
    # Setup inicial
    setup_logging
    
    # Detecta OS
    os_type="$(detect_os)"
    log_info "Sistema detectado: $os_type"
    
    if [[ "$os_type" == "unknown" ]] || [[ "$os_type" == "linux" ]]; then
        log_error "Sistema operacional '$os_type' não suportado"
        log_info "Sistemas suportados: macOS, Ubuntu"
        exit 1
    fi
    
    # Mostra menu e pega escolha
    show_menu "$os_type"
    choice="$(get_user_choice)"
    echo
    
    case $choice in
        1)
            log_info "Iniciando setup completo..."
            if ! check_system_requirements "$os_type"; then
                log_error "Falha na verificação de requisitos"
                exit 1
            fi
            
            if ! check_scripts "$os_type"; then
                exit 1
            fi
            
            if [[ "$os_type" == "macos" ]]; then
                execute_script "$SCRIPT_DIR/setup-terminal-macos.sh"
                execute_script "$SCRIPT_DIR/setup-dev-tools-macos.sh"
            elif [[ "$os_type" == "ubuntu" ]]; then
                execute_script "$SCRIPT_DIR/setup-terminal-ubuntu.sh"
                execute_script "$SCRIPT_DIR/setup-dev-tools-ubuntu.sh"
            fi
            ;;
        2)
            log_info "Iniciando setup do terminal..."
            if [[ "$os_type" == "macos" ]]; then
                execute_script "$SCRIPT_DIR/setup-terminal-macos.sh"
            elif [[ "$os_type" == "ubuntu" ]]; then
                execute_script "$SCRIPT_DIR/setup-terminal-ubuntu.sh"
            fi
            ;;
        3)
            log_info "Iniciando setup das ferramentas..."
            if [[ "$os_type" == "macos" ]]; then
                execute_script "$SCRIPT_DIR/setup-dev-tools-macos.sh"
            elif [[ "$os_type" == "ubuntu" ]]; then
                execute_script "$SCRIPT_DIR/setup-dev-tools-ubuntu.sh"
            fi
            ;;
        4)
            if check_system_requirements "$os_type"; then
                log_success "Sistema pronto para instalação!"
            else
                log_error "Sistema não atende aos requisitos"
            fi
            exit 0
            ;;
        5)
            log_warning "Setup cancelado pelo usuário"
            exit 0
            ;;
    esac
    
    log_section "Setup Finalizado"
    echo -e "${GREEN}🎉 Todos os scripts foram executados!${NC}"
    echo ""
    echo "📝 Próximos passos:"
    echo "   1. Reinicie o terminal ou execute: source ~/.zshrc"
    echo "   2. Verifique se tudo está funcionando"
    echo "   3. Configure suas preferências pessoais"
    echo "   4. Veja o log completo em: $LOG_FILE"
    echo ""
    log_success "Ambiente de desenvolvimento pronto! 🚀"
    
    echo "=== Setup finalizado em $(date) ===" >> "$LOG_FILE"
}

# Executa apenas se for chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi