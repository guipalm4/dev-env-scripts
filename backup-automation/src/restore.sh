#!/bin/bash

# Define o diretório base do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"

# Cria o diretório de logs se não existir
mkdir -p "$LOG_DIR"

# Carrega as configurações do arquivo de configuração
source "$SCRIPT_DIR/config/backup.conf"

DESTINATION="$BACKUP_DESTINATION"

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Emojis para melhor visualização
SUCCESS_EMOJI="✅"
ERROR_EMOJI="❌"
WARNING_EMOJI="⚠️"
INFO_EMOJI="ℹ️"
RESTORE_EMOJI="🔄"
FOLDER_EMOJI="📁"
FILE_EMOJI="📄"
SEARCH_EMOJI="🔍"
PACKAGE_EMOJI="📦"

# Função para registrar logs coloridos
log_message() {
    local log_file="$LOG_DIR/restore_$(date +"%Y-%m-%d").log"
    local message="$1"
    local color="${2:-$WHITE}"
    local emoji="${3:-$INFO_EMOJI}"
    
    # Log com cor no terminal
    echo -e "${color}${BOLD}$(date +"%Y-%m-%d %H:%M:%S")${NC} ${emoji} ${color}${message}${NC}"
    
    # Log sem cor no arquivo
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> "$log_file"
}

# Função para listar backups incrementais
list_incremental_backups() {
    local backup_root="$DESTINATION"
    
    echo -e "${BLUE}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║${NC} ${SEARCH_EMOJI} ${WHITE}${BOLD}BACKUPS INCREMENTAIS DISPONÍVEIS${NC} ${BLUE}${BOLD}║${NC}"
    echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    if [ ! -d "$backup_root" ]; then
        echo -e "\n${WARNING_EMOJI} ${YELLOW}Nenhum backup incremental encontrado.${NC}"
        echo -e "${GRAY}Diretório esperado: $backup_root${NC}\n"
        return 1
    fi
    
    local count=0
    local backup_list=()
    
    for backup in "$backup_root"/backup_*; do
        if [ -d "$backup" ] && [[ $(basename "$backup") =~ ^backup_[0-9]{8}_[0-9]{6}$ ]]; then
            count=$((count + 1))
            backup_list+=("$backup")
            local date_created=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$backup")
            local backup_size=$(du -sh "$backup" 2>/dev/null | awk '{print $1}')
            local basename_dir=$(basename "$backup")
            
            echo -e "\n${PURPLE}${BOLD}[$count]${NC} ${CYAN}${BOLD}$basename_dir${NC}"
            echo -e "${GRAY}├─${NC} Tamanho: ${WHITE}${backup_size}${NC}"
            echo -e "${GRAY}└─${NC} Criado em: ${GREEN}${date_created}${NC}"
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo -e "\n${WARNING_EMOJI} ${YELLOW}Nenhum backup incremental encontrado em $backup_root${NC}\n"
        return 1
    fi
    
    # Mostra qual é o mais recente
    if [ -L "$backup_root/latest" ]; then
        local latest_target=$(readlink "$backup_root/latest")
        echo -e "\n${SUCCESS_EMOJI} ${GREEN}${BOLD}Backup mais recente:${NC} ${CYAN}$(basename "$latest_target")${NC}\n"
    fi
    
    # Exporta a lista para uso global
    BACKUP_LIST=("${backup_list[@]}")
    return $count
}

# Função para listar backups completos
list_full_backups() {
    echo -e "${PURPLE}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}${BOLD}║${NC} ${PACKAGE_EMOJI} ${WHITE}${BOLD}BACKUPS COMPLETOS DISPONÍVEIS${NC} ${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    local count=0
    local backup_list=()
    
    for backup in "$DESTINATION"/backup_completo_*.tar.gz; do
        if [ -f "$backup" ]; then
            count=$((count + 1))
            backup_list+=("$backup")
            local file_size=$(ls -lh "$backup" | awk '{print $5}')
            local date_created=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$backup")
            local basename_file=$(basename "$backup")
            
            echo -e "\n${PURPLE}${BOLD}[$count]${NC} ${CYAN}${BOLD}$basename_file${NC}"
            echo -e "${GRAY}├─${NC} Tamanho: ${WHITE}${file_size}${NC}"
            echo -e "${GRAY}├─${NC} Criado em: ${GREEN}${date_created}${NC}"
            
            # Verifica se existe manifesto
            local manifest="${backup%%.tar.gz}_manifest.txt"
            if [ -f "${manifest/backup_completo_/backup_manifest_}" ]; then
                echo -e "${GRAY}└─${NC} ${SUCCESS_EMOJI} ${GREEN}Manifesto disponível${NC}"
            else
                echo -e "${GRAY}└─${NC} ${WARNING_EMOJI} ${YELLOW}Manifesto não encontrado${NC}"
            fi
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo -e "\n${WARNING_EMOJI} ${YELLOW}Nenhum backup completo encontrado.${NC}\n"
        return 1
    else
        echo ""
    fi
    
    # Exporta a lista para uso global
    FULL_BACKUP_LIST=("${backup_list[@]}")
    return $count
}

# Função para mostrar conteúdo do backup incremental
show_incremental_content() {
    local backup_dir="$1"
    
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║${NC} ${FOLDER_EMOJI} ${WHITE}${BOLD}CONTEÚDO DO BACKUP INCREMENTAL${NC} ${CYAN}${BOLD}║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    log_message "Analisando conteúdo do backup incremental: $(basename "$backup_dir")" "$CYAN" "$SEARCH_EMOJI"
    
    echo -e "\n${WHITE}${BOLD}Backup:${NC} ${CYAN}$(basename "$backup_dir")${NC}\n"
    
    local item_count=0
    for subdir in "$backup_dir"/*; do
        if [ -d "$subdir" ]; then
            item_count=$((item_count + 1))
            local dir_name=$(basename "$subdir")
            local dir_size=$(du -sh "$subdir" 2>/dev/null | awk '{print $1}')
            local file_count=$(find "$subdir" -type f | wc -l)
            
            echo -e "${PURPLE}${BOLD}📁 $dir_name/${NC}"
            echo -e "${GRAY}├─${NC} Tamanho: ${WHITE}$dir_size${NC}"
            echo -e "${GRAY}└─${NC} Arquivos: ${GREEN}$file_count${NC}\n"
        fi
    done
    
    if [ $item_count -eq 0 ]; then
        echo -e "${WARNING_EMOJI} ${YELLOW}Backup vazio ou corrompido${NC}\n"
    fi
}

# Função para mostrar conteúdo do backup completo
show_full_backup_content() {
    local backup_file="$1"
    
    echo -e "${PURPLE}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}${BOLD}║${NC} ${FILE_EMOJI} ${WHITE}${BOLD}CONTEÚDO DO BACKUP COMPLETO${NC} ${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    log_message "Analisando conteúdo do backup completo: $(basename "$backup_file")" "$PURPLE" "$SEARCH_EMOJI"
    
    echo -e "\n${WHITE}${BOLD}Primeiros 20 itens:${NC}\n"
    tar -tzf "$backup_file" | head -20 | while read line; do
        if [[ $line == */ ]]; then
            echo -e "${GRAY}├─${NC} ${FOLDER_EMOJI} ${CYAN}$line${NC}"
        else
            echo -e "${GRAY}├─${NC} ${FILE_EMOJI} ${WHITE}$line${NC}"
        fi
    done
    
    local total_files=$(tar -tzf "$backup_file" | wc -l)
    echo -e "\n${INFO_EMOJI} ${WHITE}${BOLD}Total de arquivos/diretórios:${NC} ${GREEN}$total_files${NC}"
    
    # Mostra manifesto se existir
    local manifest="${backup_file%%.tar.gz}"
    manifest="${manifest/backup_completo_/backup_manifest_}.txt"
    
    if [ -f "$manifest" ]; then
        echo -e "\n${SUCCESS_EMOJI} ${GREEN}${BOLD}Informações do manifesto:${NC}\n"
        cat "$manifest" | while read line; do
            if [[ $line == \#* ]]; then
                echo -e "${GRAY}$line${NC}"
            else
                echo -e "${CYAN}├─ $line${NC}"
            fi
        done
    fi
    echo ""
}

# Função para restaurar backup incremental
restore_incremental_backup() {
    local backup_dir="$1"
    local restore_path="${2:-$HOME}"
    
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║${NC} ${RESTORE_EMOJI} ${WHITE}${BOLD}RESTAURAÇÃO INCREMENTAL${NC} ${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    log_message "INICIANDO RESTAURAÇÃO INCREMENTAL" "$GREEN" "$RESTORE_EMOJI"
    log_message "Backup: $(basename "$backup_dir")" "$CYAN" "$FOLDER_EMOJI"
    log_message "Destino: $restore_path" "$PURPLE" "$FOLDER_EMOJI"
    
    # Verifica se o backup existe
    if [ ! -d "$backup_dir" ]; then
        echo -e "\n${ERROR_EMOJI} ${RED}${BOLD}ERRO: Backup não encontrado!${NC}"
        echo -e "${GRAY}Caminho: $backup_dir${NC}\n"
        return 1
    fi
    
    # Mostra preview do que será restaurado
    echo -e "\n${INFO_EMOJI} ${WHITE}${BOLD}Conteúdo que será restaurado:${NC}\n"
    for subdir in "$backup_dir"/*; do
        if [ -d "$subdir" ]; then
            local dir_name=$(basename "$subdir")
            local file_count=$(find "$subdir" -type f | wc -l)
            echo -e "${GRAY}├─${NC} ${FOLDER_EMOJI} ${CYAN}$dir_name${NC} ${GRAY}($file_count arquivos)${NC}"
        fi
    done
    
    # Confirmação de segurança
    echo -e "\n${WARNING_EMOJI} ${YELLOW}${BOLD}ATENÇÃO:${NC} Esta operação irá restaurar arquivos para:"
    echo -e "${GRAY}├─${NC} Destino: ${WHITE}${BOLD}$restore_path${NC}"
    echo -e "${GRAY}└─${NC} ${RED}Arquivos existentes podem ser sobrescritos!${NC}\n"
    
    read -p "$(echo -e "${CYAN}Deseja continuar? ${GRAY}(s/N):${NC} ")" -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        log_message "Restauração cancelada pelo usuário" "$YELLOW" "$WARNING_EMOJI"
        return 1
    fi
    
    echo -e "\n${CYAN}Iniciando restauração...${NC}\n"
    
    # Restaura cada diretório
    local total_dirs=$(find "$backup_dir" -maxdepth 1 -type d ! -path "$backup_dir" | wc -l)
    local current_dir=0
    local success_count=0
    
    for subdir in "$backup_dir"/*; do
        if [ -d "$subdir" ]; then
            current_dir=$((current_dir + 1))
            local dir_name=$(basename "$subdir")
            local target_dir="$restore_path/$dir_name"
            
            echo -e "${CYAN}[$current_dir/$total_dirs]${NC} Restaurando: ${PURPLE}$dir_name${NC} → ${WHITE}$target_dir${NC}"
            
            # Cria diretório de destino se não existir
            mkdir -p "$(dirname "$target_dir")"
            
            # Usa rsync para restaurar mantendo permissões
            if rsync -av --progress "$subdir/" "$target_dir/" 2>/dev/null; then
                log_message "$dir_name restaurado com sucesso" "$GREEN" "$SUCCESS_EMOJI"
                echo -e "        ${SUCCESS_EMOJI} ${GREEN}Concluído${NC}"
                success_count=$((success_count + 1))
            else
                log_message "ERRO: Falha ao restaurar $dir_name" "$RED" "$ERROR_EMOJI"
                echo -e "        ${ERROR_EMOJI} ${RED}Falhou${NC}"
            fi
        fi
    done
    
    echo -e "\n${SUCCESS_EMOJI} ${GREEN}${BOLD}RESTAURAÇÃO INCREMENTAL FINALIZADA!${NC}"
    echo -e "${GRAY}├─${NC} Itens processados: ${WHITE}$current_dir${NC}"
    echo -e "${GRAY}├─${NC} Sucessos: ${GREEN}$success_count${NC}"
    echo -e "${GRAY}└─${NC} Falhas: ${RED}$((current_dir - success_count))${NC}\n"
    
    log_message "RESTAURAÇÃO INCREMENTAL FINALIZADA - $success_count/$current_dir sucessos" "$GREEN" "$SUCCESS_EMOJI"
}

# Função para restaurar backup completo
restore_full_backup() {
    local backup_file="$1"
    local restore_path="${2:-/}"
    
    echo -e "${PURPLE}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}${BOLD}║${NC} ${RESTORE_EMOJI} ${WHITE}${BOLD}RESTAURAÇÃO COMPLETA${NC} ${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    log_message "INICIANDO RESTAURAÇÃO COMPLETA" "$PURPLE" "$RESTORE_EMOJI"
    log_message "Arquivo: $(basename "$backup_file")" "$CYAN" "$FILE_EMOJI"
    log_message "Destino: $restore_path" "$PURPLE" "$FOLDER_EMOJI"
    
    # Verifica se o arquivo existe
    if [ ! -f "$backup_file" ]; then
        echo -e "\n${ERROR_EMOJI} ${RED}${BOLD}ERRO: Arquivo de backup não encontrado!${NC}"
        echo -e "${GRAY}Caminho: $backup_file${NC}\n"
        return 1
    fi
    
    # Mostra preview do conteúdo
    echo -e "\n${INFO_EMOJI} ${WHITE}${BOLD}Preview do conteúdo (primeiros 10 itens):${NC}\n"
    tar -tzf "$backup_file" | head -10 | while read line; do
        echo -e "${GRAY}├─${NC} ${CYAN}$line${NC}"
    done
    
    local total_files=$(tar -tzf "$backup_file" | wc -l)
    echo -e "${GRAY}└─${NC} ${WHITE}... e mais $((total_files - 10)) itens${NC}\n"
    
    # Confirmação de segurança
    echo -e "${WARNING_EMOJI} ${YELLOW}${BOLD}ATENÇÃO:${NC} Esta operação irá restaurar arquivos para:"
    echo -e "${GRAY}├─${NC} Destino: ${WHITE}${BOLD}$restore_path${NC}"
    echo -e "${GRAY}├─${NC} Total de itens: ${WHITE}$total_files${NC}"
    echo -e "${GRAY}└─${NC} ${RED}Arquivos existentes podem ser sobrescritos!${NC}\n"
    
    read -p "$(echo -e "${CYAN}Deseja continuar? ${GRAY}(s/N):${NC} ")" -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        log_message "Restauração cancelada pelo usuário" "$YELLOW" "$WARNING_EMOJI"
        return 1
    fi
    
    # Executa a restauração
    echo -e "\n${CYAN}Extraindo arquivos...${NC}\n"
    log_message "Iniciando extração dos arquivos..." "$CYAN" "$PACKAGE_EMOJI"
    
    if tar -xzf "$backup_file" -C "$restore_path" --progress 2>/dev/null; then
        log_message "Restauração completa concluída com sucesso" "$GREEN" "$SUCCESS_EMOJI"
        log_message "Arquivos restaurados em: $restore_path" "$CYAN" "$FOLDER_EMOJI"
        echo -e "${SUCCESS_EMOJI} ${GREEN}${BOLD}RESTAURAÇÃO COMPLETA FINALIZADA!${NC}\n"
    else
        log_message "ERRO: Falha na restauração" "$RED" "$ERROR_EMOJI"
        echo -e "${ERROR_EMOJI} ${RED}${BOLD}ERRO: Falha na restauração${NC}\n"
        return 1
    fi
}

# Menu principal
show_menu() {
    echo -e "${BOLD}${WHITE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}           🔄 SISTEMA DE RESTAURAÇÃO DE BACKUP 🔄${NC}"
    echo -e "${BOLD}${WHITE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GRAY}$(date)${NC}\n"
    
    echo -e "${WHITE}${BOLD}Opções disponíveis:${NC}"
    echo -e "${CYAN}1)${NC} ${BLUE}Listar backups incrementais${NC}"
    echo -e "${CYAN}2)${NC} ${PURPLE}Listar backups completos${NC}"
    echo -e "${CYAN}3)${NC} ${GREEN}Restaurar backup incremental${NC}"
    echo -e "${CYAN}4)${NC} ${GREEN}Restaurar backup completo${NC}"
    echo -e "${CYAN}5)${NC} ${YELLOW}Ver conteúdo de backup incremental${NC}"
    echo -e "${CYAN}6)${NC} ${YELLOW}Ver conteúdo de backup completo${NC}"
    echo -e "${CYAN}7)${NC} ${RED}Sair${NC}\n"
    
    read -p "$(echo -e "${WHITE}${BOLD}Escolha uma opção:${NC} ")" choice
    
    case $choice in
        1)
            list_incremental_backups
            ;;
        2)
            list_full_backups
            ;;
        3)
            list_incremental_backups
            local backup_count=$?
            if [ $backup_count -gt 0 ]; then
                echo -e "\n${CYAN}Digite o número do backup:${NC} "
                read backup_num
                
                # Valida o número
                if [[ "$backup_num" =~ ^[0-9]+$ ]] && [ "$backup_num" -ge 1 ] && [ "$backup_num" -le $backup_count ]; then
                    local selected_backup="${BACKUP_LIST[$((backup_num-1))]}"
                    if [ -d "$selected_backup" ]; then
                        echo -e "${CYAN}Diretório de destino [${HOME}]:${NC} "
                        read custom_path
                        restore_incremental_backup "$selected_backup" "${custom_path:-$HOME}"
                    else
                        echo -e "${ERROR_EMOJI} ${RED}Backup não encontrado!${NC}"
                    fi
                else
                    echo -e "${ERROR_EMOJI} ${RED}Número inválido! Digite um número entre 1 e $backup_count${NC}"
                fi
            fi
            ;;
        4)
            list_full_backups
            local backup_count=$?
            if [ $backup_count -gt 0 ]; then
                echo -e "\n${CYAN}Digite o número do backup:${NC} "
                read backup_num
                
                # Valida o número
                if [[ "$backup_num" =~ ^[0-9]+$ ]] && [ "$backup_num" -ge 1 ] && [ "$backup_num" -le $backup_count ]; then
                    local selected_backup="${FULL_BACKUP_LIST[$((backup_num-1))]}"
                    if [ -f "$selected_backup" ]; then
                        echo -e "${CYAN}Diretório de destino [/]:${NC} "
                        read custom_path
                        restore_full_backup "$selected_backup" "${custom_path:-/}"
                    else
                        echo -e "${ERROR_EMOJI} ${RED}Backup não encontrado!${NC}"
                    fi
                else
                    echo -e "${ERROR_EMOJI} ${RED}Número inválido! Digite um número entre 1 e $backup_count${NC}"
                fi
            fi
            ;;
        5)
            list_incremental_backups
            local backup_count=$?
            if [ $backup_count -gt 0 ]; then
                echo -e "\n${CYAN}Digite o número do backup:${NC} "
                read backup_num
                
                if [[ "$backup_num" =~ ^[0-9]+$ ]] && [ "$backup_num" -ge 1 ] && [ "$backup_num" -le $backup_count ]; then
                    local selected_backup="${BACKUP_LIST[$((backup_num-1))]}"
                    if [ -d "$selected_backup" ]; then
                        show_incremental_content "$selected_backup"
                    else
                        echo -e "${ERROR_EMOJI} ${RED}Backup não encontrado!${NC}"
                    fi
                else
                    echo -e "${ERROR_EMOJI} ${RED}Número inválido!${NC}"
                fi
            fi
            ;;
        6)
            list_full_backups
            local backup_count=$?
            if [ $backup_count -gt 0 ]; then
                echo -e "\n${CYAN}Digite o número do backup:${NC} "
                read backup_num
                
                if [[ "$backup_num" =~ ^[0-9]+$ ]] && [ "$backup_num" -ge 1 ] && [ "$backup_num" -le $backup_count ]; then
                    local selected_backup="${FULL_BACKUP_LIST[$((backup_num-1))]}"
                    if [ -f "$selected_backup" ]; then
                        show_full_backup_content "$selected_backup"
                    else
                        echo -e "${ERROR_EMOJI} ${RED}Backup não encontrado!${NC}"
                    fi
                else
                    echo -e "${ERROR_EMOJI} ${RED}Número inválido!${NC}"
                fi
            fi
            ;;
        7)
            echo -e "\n${SUCCESS_EMOJI} ${GREEN}Saindo...${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${ERROR_EMOJI} ${RED}Opção inválida!${NC}\n"
            ;;
    esac
}

# Verifica se o diretório de backups existe
if [ ! -d "$DESTINATION" ]; then
    echo -e "${ERROR_EMOJI} ${RED}${BOLD}ERRO: Diretório de backups não encontrado: $DESTINATION${NC}\n"
    exit 1
fi

# Se argumentos foram passados, executa diretamente
if [ $# -gt 0 ]; then
    case "$1" in
        "list-inc"|"list-incremental")
            list_incremental_backups
            ;;
        "list-full"|"list-complete")
            list_full_backups
            ;;
        "restore-inc"|"restore-incremental")
            if [ -n "$2" ]; then
                restore_incremental_backup "$2" "${3:-$HOME}"
            else
                echo -e "${ERROR_EMOJI} ${RED}Uso: $0 restore-inc <diretório_backup> [diretório_destino]${NC}"
            fi
            ;;
        "restore-full"|"restore-complete")
            if [ -n "$2" ]; then
                restore_full_backup "$2" "${3:-/}"
            else
                echo -e "${ERROR_EMOJI} ${RED}Uso: $0 restore-full <arquivo_backup> [diretório_destino]${NC}"
            fi
            ;;
        *)
            echo -e "${WHITE}${BOLD}Comandos disponíveis:${NC}"
            echo -e "${GRAY}  list-inc - Lista backups incrementais${NC}"
            echo -e "${GRAY}  list-full - Lista backups completos${NC}"
            echo -e "${GRAY}  restore-inc <dir> [dest] - Restaura backup incremental${NC}"
            echo -e "${GRAY}  restore-full <arquivo> [dest] - Restaura backup completo${NC}"
            ;;
    esac
else
    # Menu interativo
    while true; do
        show_menu
        echo ""
        echo -e "${GRAY}Pressione Enter para continuar...${NC}"
        read
    done
fi