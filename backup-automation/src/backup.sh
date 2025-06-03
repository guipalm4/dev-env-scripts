#!/bin/bash
# filepath: src/backup.sh

# Define o diretório base do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"

# Cria o diretório de logs se não existir
mkdir -p "$LOG_DIR"

# Carrega as configurações do arquivo de configuração
source "$SCRIPT_DIR/config/backup.conf"

DESTINATION="$BACKUP_DESTINATION"

# Cores para terminal (apenas quando apropriado)
if [ -t 1 ] || [ "$DEBUG_MODE" = "true" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    GRAY='\033[0;90m'
    BOLD='\033[1m'
    NC='\033[0m'
    
    # Emojis
    SUCCESS_EMOJI="✅"
    ERROR_EMOJI="❌"
    WARNING_EMOJI="⚠️"
    INFO_EMOJI="ℹ️"
    ROCKET_EMOJI="🚀"
    FOLDER_EMOJI="📁"
    FILE_EMOJI="📄"
    CHART_EMOJI="📊"
    CLOCK_EMOJI="⏰"
    PACKAGE_EMOJI="📦"
else
    # Sem cores quando executado pelo LaunchAgent
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    PURPLE=''
    CYAN=''
    WHITE=''
    GRAY=''
    BOLD=''
    NC=''
    
    # Emojis limpos
    SUCCESS_EMOJI="[OK]"
    ERROR_EMOJI="[ERROR]"
    WARNING_EMOJI="[WARN]"
    INFO_EMOJI="[INFO]"
    ROCKET_EMOJI="[START]"
    FOLDER_EMOJI="[DIR]"
    FILE_EMOJI="[FILE]"
    CHART_EMOJI="[STATS]"
    CLOCK_EMOJI="[TIME]"
    PACKAGE_EMOJI="[PKG]"
fi

# Função para registrar logs separando terminal e arquivo
log_message() {
    local log_file="$LOG_DIR/backup_$(date +"%Y-%m-%d").log"
    local message="$1"
    local color="${2:-$WHITE}"
    local emoji="${3:-$INFO_EMOJI}"
    
    # Log COM cor no terminal (apenas se suportado)
    if [ -t 1 ] || [ "$DEBUG_MODE" = "true" ]; then
        echo -e "${color}${BOLD}$(date +"%Y-%m-%d %H:%M:%S")${NC} ${emoji} ${color}${message}${NC}"
    else
        # Log sem cores para LaunchAgent
        echo "$(date +"%Y-%m-%d %H:%M:%S") ${emoji} ${message}"
    fi
    
    # Log SEMPRE limpo no arquivo
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> "$log_file"
}

# Função para mostrar progresso (apenas no terminal)
show_progress() {
    local current="$1"
    local total="$2"
    local item_name="$3"
    
    # Só mostra progresso se for terminal interativo
    if [ -t 1 ] || [ "$DEBUG_MODE" = "true" ]; then
        local percentage=$((current * 100 / total))
        local filled=$((percentage / 5))
        local empty=$((20 - filled))
        
        printf "\r${CYAN}${BOLD}Progresso:${NC} ["
        printf "%*s" $filled | tr ' ' '='
        printf "%*s" $empty | tr ' ' '-'
        printf "] ${WHITE}${BOLD}%d%%${NC} ${PURPLE}(%d/%d)${NC} ${YELLOW}%s${NC}" $percentage $current $total "$item_name"
    fi
}

# Função para output apenas no arquivo de log
log_clean() {
    local log_file="$LOG_DIR/backup_$(date +"%Y-%m-%d").log"
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> "$log_file"
}

# Função para verificar permissões de destino
check_destination_permissions() {
    local dest="$1"
    
    # Verificar se o diretório existe
    if [ ! -d "$dest" ]; then
        log_message "ERRO: Diretório de destino não existe: $dest" "$RED" "$ERROR_EMOJI"
        
        # Se é um volume, tentar listar volumes disponíveis
        if [[ "$dest" =~ ^/Volumes/ ]]; then
            local volume_name=$(basename "$dest")
            log_message "Volume $volume_name não está montado" "$YELLOW" "$WARNING_EMOJI"
            
            local available=$(ls /Volumes/ 2>/dev/null | tr '\n' ' ')
            log_clean "VOLUMES_AVAILABLE: $available"
        fi
        return 1
    fi
    
    # Testar permissões de escrita
    local test_file="$dest/.backup_permission_test"
    if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        log_message "Permissões verificadas: $dest" "$GREEN" "$SUCCESS_EMOJI"
        log_clean "PERMISSIONS_OK: $dest"
        return 0
    else
        log_message "ERRO: Sem permissão de escrita em: $dest" "$RED" "$ERROR_EMOJI"
        
        # Informações de debug
        local owner=$(ls -ld "$dest" 2>/dev/null | awk '{print $3}')
        local perms=$(ls -ld "$dest" 2>/dev/null | awk '{print $1}')
        log_clean "PERMISSION_INFO: owner=$owner perms=$perms user=$(whoami)"
        
        return 1
    fi
}

# Função para fazer backup de arquivo único
backup_single_file() {
    local source_file="$1"
    local dest_dir="$2"
    local latest_link="$3"
    
    local file_name=$(basename "$source_file")
    local dest_file="$dest_dir/$file_name"
    
    log_message "Copiando arquivo: $source_file" "$CYAN" "$FILE_EMOJI"
    log_clean "FILE_BACKUP_START: $source_file"
    
    # Copia o arquivo
    if cp "$source_file" "$dest_file" 2>/dev/null; then
        local file_size=$(ls -lh "$dest_file" 2>/dev/null | awk '{print $5}')
        log_message "Arquivo $file_name copiado com sucesso" "$GREEN" "$SUCCESS_EMOJI"
        log_clean "FILE_BACKUP_SUCCESS: $source_file size=$file_size"
        
        # Mostra info no terminal
        if [ -t 1 ] || [ "$DEBUG_MODE" = "true" ]; then
            echo -e "  ${GRAY}└─ Tamanho: ${WHITE}${file_size}${NC}\n"
        fi
        
        return 0
    else
        log_message "ERRO: Falha ao copiar $source_file" "$RED" "$ERROR_EMOJI"
        log_clean "FILE_BACKUP_ERROR: $source_file"
        return 1
    fi
}

# Função para fazer backup de diretório
backup_directory() {
    local source_dir="$1"
    local dest_dir="$2"
    local latest_link="$3"
    
    local dir_name=$(basename "$source_dir")
    local dest_subdir="$dest_dir/$dir_name"
    local link_dest=""
    
    # Criar diretório de destino
    if ! mkdir -p "$dest_subdir" 2>/dev/null; then
        log_message "ERRO: Não foi possível criar $dest_subdir" "$RED" "$ERROR_EMOJI"
        log_clean "MKDIR_ERROR: $dest_subdir"
        return 1
    fi
    
    # Se existe backup anterior, usa hard links
    if [ -n "$latest_link" ] && [ -d "$latest_link/$dir_name" ]; then
        link_dest="--link-dest=$latest_link/$dir_name"
        log_clean "USING_LINK_DEST: $latest_link/$dir_name"
    fi
    
    log_message "Sincronizando: $source_dir -> $dest_subdir" "$CYAN" "$FOLDER_EMOJI"
    log_clean "RSYNC_START: $source_dir -> $dest_subdir"
    
    # Executa rsync
    local rsync_output
    rsync_output=$(rsync -av \
        --stats \
        --human-readable \
        $link_dest \
        "$source_dir/" \
        "$dest_subdir/" 2>&1)
    
    local rsync_status=$?
    
    if [ $rsync_status -eq 0 ]; then
        # Extrai estatísticas de forma segura
        local dir_files=$(echo "$rsync_output" | grep "Number of files:" | grep -o '[0-9,]*' | head -1 | tr -d ',' || echo "0")
        local created_files=$(echo "$rsync_output" | grep "Number of created files:" | grep -o '[0-9,]*' | head -1 | tr -d ',' || echo "0")
        local dir_size=$(du -sh "$dest_subdir" 2>/dev/null | awk '{print $1}' || echo "0B")
        
        # Valores padrão se extração falhar
        dir_files=${dir_files:-0}
        created_files=${created_files:-0}
        dir_size=${dir_size:-"0B"}
        
        log_message "Diretório sincronizado: $dir_name" "$GREEN" "$SUCCESS_EMOJI"
        log_clean "RSYNC_SUCCESS: $source_dir files=$dir_files created=$created_files size=$dir_size"
        
        # Mostra estatísticas no terminal
        if [ -t 1 ] || [ "$DEBUG_MODE" = "true" ]; then
            echo -e "  ${GRAY}├─ Arquivos: ${WHITE}${dir_files}${NC}"
            echo -e "  ${GRAY}├─ Novos: ${GREEN}${created_files}${NC}"
            echo -e "  ${GRAY}└─ Tamanho: ${CYAN}${dir_size}${NC}\n"
        fi
        
        echo "${dir_files},${created_files}"
        return 0
    else
        log_message "ERRO: Falha na sincronização de $source_dir (código: $rsync_status)" "$RED" "$ERROR_EMOJI"
        log_clean "RSYNC_ERROR: $source_dir code=$rsync_status"
        return 1
    fi
}

# Função para desmontar volume no macOS
unmount_volume() {
    local volume_path="$1"
    
    if [[ "$volume_path" =~ ^/Volumes/ ]]; then
        local volume_name=$(basename "$volume_path")
        
        log_message "Desmontando volume: $volume_name" "$YELLOW" "$INFO_EMOJI"
        log_clean "UNMOUNT_ATTEMPT: $volume_name"
        
        # Usar diskutil no macOS
        if diskutil unmount "$volume_path" >/dev/null 2>&1; then
            log_message "Volume $volume_name desmontado" "$GREEN" "$SUCCESS_EMOJI"
            log_clean "UNMOUNT_SUCCESS: $volume_name"
            return 0
        else
            log_message "AVISO: Não foi possível desmontar $volume_name" "$YELLOW" "$WARNING_EMOJI"
            log_clean "UNMOUNT_WARNING: $volume_name"
            return 1
        fi
    else
        log_message "Caminho não é um volume: $volume_path" "$YELLOW" "$WARNING_EMOJI"
        log_clean "UNMOUNT_SKIP: not_a_volume"
        return 1
    fi
}

# Função para realizar backup incremental
perform_incremental_backup() {
    # Header apenas no terminal
    if [ -t 1 ] || [ "$DEBUG_MODE" = "true" ]; then
        echo -e "${BLUE}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}${BOLD}║${NC} ${ROCKET_EMOJI} ${WHITE}${BOLD}INICIANDO BACKUP INCREMENTAL${NC} ${BLUE}${BOLD}║${NC}"
        echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    fi
    
    log_clean "=== BACKUP_SESSION_START ==="
    log_message "Iniciando backup incremental" "$BLUE" "$ROCKET_EMOJI"
    log_message "Destino: $DESTINATION" "$CYAN" "$FOLDER_EMOJI"
    
    # Verificar destino ANTES de tudo
    if ! check_destination_permissions "$DESTINATION"; then
        log_message "ERRO CRÍTICO: Problema com destino" "$RED" "$ERROR_EMOJI"
        log_clean "BACKUP_FAILED: destination_error"
        return 1
    fi
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_root="$DESTINATION/backups"
    local current_backup="$backup_root/backup_$timestamp"
    local latest_link="$backup_root/latest"
    local stats_file="$LOG_DIR/backup_stats_$(date +"%Y-%m-%d").txt"
    
    # Criar estrutura de backup
    if ! mkdir -p "$backup_root" 2>/dev/null; then
        log_message "ERRO: Falha ao criar estrutura de backup" "$RED" "$ERROR_EMOJI"
        log_clean "BACKUP_FAILED: mkdir_root_error"
        return 1
    fi
    
    if ! mkdir -p "$current_backup" 2>/dev/null; then
        log_message "ERRO: Falha ao criar diretório do backup" "$RED" "$ERROR_EMOJI"
        log_clean "BACKUP_FAILED: mkdir_backup_error"
        return 1
    fi
    
    log_message "Backup: $(basename "$current_backup")" "$PURPLE" "$FOLDER_EMOJI"
    log_clean "BACKUP_DIR_CREATED: $current_backup"
    
    # Array de diretórios/arquivos a fazer backup
    local DIRECTORIES=("${SOURCE_DIRECTORIES[@]}")
    local total_items=${#DIRECTORIES[@]}
    local current_item=0
    local success_count=0
    local total_files=0
    local total_transferred=0
    
    log_message "Processando $total_items itens..." "$GRAY" "$INFO_EMOJI"
    log_clean "PROCESSING_START: items=$total_items"
    
    # Processa cada item
    for item in "${DIRECTORIES[@]}"; do
        current_item=$((current_item + 1))
        
        # Mostra progresso apenas no terminal
        if [ -f "$item" ]; then
            show_progress $current_item $total_items "$(basename "$item") (arquivo)"
            echo ""
            
            log_clean "PROCESSING_FILE: $item ($current_item/$total_items)"
            
            if backup_single_file "$item" "$current_backup" "$latest_link"; then
                success_count=$((success_count + 1))
                total_files=$((total_files + 1))
                total_transferred=$((total_transferred + 1))
            fi
            
        elif [ -d "$item" ]; then
            show_progress $current_item $total_items "$(basename "$item") (diretório)"
            echo ""
            
            log_clean "PROCESSING_DIR: $item ($current_item/$total_items)"
            
            if [ -d "$item" ]; then
                # Verifica se há primeiro backup para este diretório
                local latest_dir=""
                if [ -L "$latest_link" ] && [ -d "$latest_link/$(basename "$item")" ]; then
                    latest_dir="$latest_link"
                    log_message "Backup incremental para: $item" "$BLUE" "$FOLDER_EMOJI"
                else
                    log_message "Primeiro backup para: $item" "$BLUE" "$ROCKET_EMOJI"
                fi
                
                local stats_result
                if stats_result=$(backup_directory "$item" "$current_backup" "$latest_dir"); then
                    success_count=$((success_count + 1))
                    
                    # Parse das estatísticas
                    local files_count=$(echo "$stats_result" | cut -d',' -f1)
                    local transferred_count=$(echo "$stats_result" | cut -d',' -f2)
                    
                    total_files=$((total_files + files_count))
                    total_transferred=$((total_transferred + transferred_count))
                fi
            else
                log_message "Diretório não encontrado: $item" "$YELLOW" "$WARNING_EMOJI"
                log_clean "DIR_NOT_FOUND: $item"
            fi
        else
            log_message "AVISO: Item não encontrado: $item" "$YELLOW" "$WARNING_EMOJI"
            log_clean "ITEM_NOT_FOUND: $item"
        fi
    done
    
    # Limpa linha de progresso
    if [ -t 1 ] || [ "$DEBUG_MODE" = "true" ]; then
        echo ""
    fi
    
    # Atualiza link para o backup mais recente
    if [ $success_count -gt 0 ]; then
        # Remove link anterior e cria novo
        rm -f "$latest_link"
        if ln -sf "$current_backup" "$latest_link" 2>/dev/null; then
            log_message "Link 'latest' atualizado" "$GREEN" "$SUCCESS_EMOJI"
            log_clean "LATEST_LINK_UPDATED: $current_backup"
        else
            log_message "AVISO: Falha ao atualizar link 'latest'" "$YELLOW" "$WARNING_EMOJI"
            log_clean "LATEST_LINK_ERROR"
        fi
    fi
    
    # Calcular tamanho do backup
    local backup_size=$(du -sh "$current_backup" 2>/dev/null | awk '{print $1}' || echo "0B")
    
    # Salvar estatísticas
    cat > "$stats_file" << EOF
# Estatísticas de Backup - $(date)
Sessão: backup_$timestamp
Início: $(date)
Destino: $DESTINATION
Itens processados: $current_item
Sucessos: $success_count
Falhas: $((current_item - success_count))
Total de arquivos: $total_files
Arquivos transferidos: $total_transferred
Tamanho total: $backup_size
EOF
    
    # Log final
    log_message "Backup incremental concluído" "$GREEN" "$SUCCESS_EMOJI"
    log_message "Processados: $current_item/$total_items" "$CYAN" "$CHART_EMOJI"
    log_message "Sucessos: $success_count" "$GREEN" "$CHART_EMOJI"
    log_message "Arquivos: $total_files (transferidos: $total_transferred)" "$PURPLE" "$CHART_EMOJI"
    log_message "Tamanho: $backup_size" "$CYAN" "$CHART_EMOJI"
    
    log_clean "=== BACKUP_SESSION_END: success=$success_count/$current_item files=$total_files transferred=$total_transferred size=$backup_size ==="
    
    # Desmontar volume se configurado
    if [ "${AUTO_UNMOUNT:-false}" = "true" ]; then
        unmount_volume "$DESTINATION"
    fi
    
    return 0
}

# Função para limpeza de backups antigos
cleanup_old_backups() {
    local backup_root="$DESTINATION/backups"
    local retention_days="$BACKUP_RETENTION_DAYS"
    
    log_message "Iniciando limpeza de backups antigos (>${retention_days} dias)" "$YELLOW" "$CLOCK_EMOJI"
    log_clean "CLEANUP_START: retention_days=$retention_days"
    
    if [ ! -d "$backup_root" ]; then
        log_message "Diretório de backups não encontrado para limpeza" "$YELLOW" "$WARNING_EMOJI"
        return 0
    fi
    
    local deleted_count=0
    local total_freed="0B"
    
    # Find backups older than retention period
    find "$backup_root" -maxdepth 1 -type d -name "backup_*" -mtime +$retention_days -print0 | while IFS= read -r -d '' old_backup; do
        local backup_size=$(du -sh "$old_backup" 2>/dev/null | awk '{print $1}')
        
        log_message "Removendo backup antigo: $(basename "$old_backup")" "$YELLOW" "$WARNING_EMOJI"
        log_clean "CLEANUP_REMOVE: $(basename "$old_backup") size=$backup_size"
        
        if rm -rf "$old_backup" 2>/dev/null; then
            deleted_count=$((deleted_count + 1))
            log_clean "CLEANUP_SUCCESS: $(basename "$old_backup")"
        else
            log_message "ERRO: Falha ao remover $(basename "$old_backup")" "$RED" "$ERROR_EMOJI"
            log_clean "CLEANUP_ERROR: $(basename "$old_backup")"
        fi
    done
    
    if [ $deleted_count -gt 0 ]; then
        log_message "Limpeza concluída: $deleted_count backups removidos" "$GREEN" "$SUCCESS_EMOJI"
    else
        log_message "Nenhum backup antigo para remover" "$GREEN" "$SUCCESS_EMOJI"
    fi
    
    log_clean "CLEANUP_END: removed=$deleted_count"
}

# Função principal
main() {
    local mode="${1:-incremental}"
    
    # Cabeçalho do sistema
    if [ -t 1 ] || [ "$DEBUG_MODE" = "true" ]; then
        echo -e "${WHITE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}${BOLD}           ${ROCKET_EMOJI} SISTEMA DE BACKUP AUTOMATIZADO ${ROCKET_EMOJI}${NC}"
        echo -e "${WHITE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GRAY}Início: $(date)${NC}\n"
    fi
    
    log_clean "SYSTEM_START: mode=$mode user=$(whoami) pid=$$"
    
    case "$mode" in
        "incremental")
            perform_incremental_backup
            local backup_result=$?
            
            if [ $backup_result -eq 0 ]; then
                cleanup_old_backups
            fi
            
            # Footer
            if [ -t 1 ] || [ "$DEBUG_MODE" = "true" ]; then
                echo -e "${WHITE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
                echo -e "${GRAY}Fim: $(date)${NC}"
                if [ $backup_result -eq 0 ]; then
                    echo -e "${GREEN}${BOLD}${SUCCESS_EMOJI} Backup finalizado com sucesso! ${SUCCESS_EMOJI}${NC}"
                else
                    echo -e "${RED}${BOLD}${ERROR_EMOJI} Backup falhou! ${ERROR_EMOJI}${NC}"
                fi
                echo -e "${WHITE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
            fi
            
            log_clean "SYSTEM_END: result=$backup_result"
            exit $backup_result
            ;;
        "full")
            log_message "Modo backup completo não implementado ainda" "$YELLOW" "$WARNING_EMOJI"
            exit 1
            ;;
        *)
            echo "Uso: $0 {incremental|full}"
            exit 1
            ;;
    esac
}

# Executa função principal com todos os argumentos
main "$@"