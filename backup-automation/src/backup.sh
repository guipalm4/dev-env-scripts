#!/bin/bash

# Define o diretório base do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"

# Cria o diretório de logs se não existir
mkdir -p "$LOG_DIR"

# Carrega as configurações do arquivo de configuração
source "$SCRIPT_DIR/config/backup.conf"

# Define as variáveis corretas
DIRECTORIES=("${SOURCE_DIRECTORIES[@]}")
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
ROCKET_EMOJI="🚀"
FOLDER_EMOJI="📁"
FILE_EMOJI="📄"
CLOCK_EMOJI="🕐"
CHART_EMOJI="📊"
CLEAN_EMOJI="🧹"

# Função para registrar logs coloridos
log_message() {
    local log_file="$LOG_DIR/backup_$(date +"%Y-%m-%d").log"
    local message="$1"
    local color="${2:-$WHITE}"
    local emoji="${3:-$INFO_EMOJI}"
    
    # Log com cor no terminal
    echo -e "${color}${BOLD}$(date +"%Y-%m-%d %H:%M:%S")${NC} ${emoji} ${color}${message}${NC}"
    
    # Log sem cor no arquivo
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> "$log_file"
}

# Função para mostrar progresso
show_progress() {
    local current="$1"
    local total="$2"
    local item_name="$3"
    local percentage=$((current * 100 / total))
    
    # Barra de progresso colorida
    local filled=$((percentage / 5))
    local empty=$((20 - filled))
    
    printf "\r${CYAN}${BOLD}Progresso:${NC} ["
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $empty | tr ' ' '-'
    printf "] ${WHITE}${BOLD}%d%%${NC} ${PURPLE}(%d/%d)${NC} ${YELLOW}%s${NC}" $percentage $current $total "$item_name"
}

# Função para fazer backup de arquivo individual
backup_single_file() {
    local source_file="$1"
    local dest_dir="$2"
    local latest_link="$3"
    
    local file_name=$(basename "$source_file")
    local file_dir=$(dirname "$source_file")
    local dest_file_dir="$dest_dir/$(basename "$file_dir")"
    local dest_file="$dest_file_dir/$file_name"
    local link_dest=""
    
    # Cria diretório de destino
    mkdir -p "$dest_file_dir"
    
    # Se existe backup anterior, usa hard link para arquivo não modificado
    if [ -n "$latest_link" ] && [ -f "$latest_link/$(basename "$file_dir")/$file_name" ]; then
        link_dest="--link-dest=$latest_link/$(basename "$file_dir")"
    fi
    
    # Usa rsync para o arquivo individual
    local rsync_output=$(rsync -av \
        --stats \
        $link_dest \
        "$source_file" \
        "$dest_file_dir/" 2>&1)
    
    if [ $? -eq 0 ]; then
        local file_size=$(ls -lh "$source_file" 2>/dev/null | awk '{print $5}')
        log_message "Arquivo $source_file copiado (Tamanho: $file_size)" "$GREEN" "$SUCCESS_EMOJI"
        return 0
    else
        log_message "ERRO: Falha ao copiar arquivo $source_file" "$RED" "$ERROR_EMOJI"
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
    
    # Se existe backup anterior, usa hard links para arquivos não modificados
    if [ -n "$latest_link" ] && [ -d "$latest_link/$dir_name" ]; then
        link_dest="--link-dest=$latest_link/$dir_name"
    fi
    
    log_message "Sincronizando diretório: $source_dir → $dest_subdir" "$CYAN" "$FOLDER_EMOJI"
    
    # Executa rsync com estatísticas detalhadas
    local rsync_output=$(rsync -av \
        --stats \
        --human-readable \
        --progress \
        $link_dest \
        "$source_dir/" \
        "$dest_subdir/" 2>&1)
    
    if [ $? -eq 0 ]; then
        local dir_files=$(echo "$rsync_output" | grep "Number of files:" | awk '{print $4}' | tr -d ',')
        local dir_size=$(du -sh "$dest_subdir" 2>/dev/null | awk '{print $1}')
        local transferred=$(echo "$rsync_output" | grep "Total transferred file size:" | awk '{print $5}')
        local created_files=$(echo "$rsync_output" | grep "Number of created files:" | awk '{print $5}' | tr -d ',')
        
        log_message "Diretório $source_dir sincronizado" "$GREEN" "$SUCCESS_EMOJI"
        
        # Mostra estatísticas coloridas
        echo -e "  ${GRAY}├─ Arquivos: ${WHITE}${dir_files:-0}${NC}"
        echo -e "  ${GRAY}├─ Tamanho: ${WHITE}${dir_size:-0}${NC}"
        echo -e "  ${GRAY}├─ Transferidos: ${GREEN}${created_files:-0}${NC}"
        echo -e "  ${GRAY}└─ Dados: ${CYAN}${transferred:-0}${NC}\n"
        
        # Retorna estatísticas
        echo "${dir_files:-0},${created_files:-0}"
        return 0
    else
        log_message "ERRO: Falha na sincronização de $source_dir" "$RED" "$ERROR_EMOJI"
        return 1
    fi
}

# Função para realizar backup incremental com rsync
perform_incremental_backup() {
    echo -e "${BLUE}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║${NC} ${ROCKET_EMOJI} ${WHITE}${BOLD}INICIANDO BACKUP INCREMENTAL${NC} ${BLUE}${BOLD}║${NC}"
    echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    log_message "Destino: $DESTINATION" "$CYAN" "$FOLDER_EMOJI"
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_root="$DESTINATION"
    local current_backup="$backup_root/backup_$timestamp"
    local latest_link="$backup_root/latest"
    local stats_file="$LOG_DIR/backup_stats_$(date +"%Y-%m-%d").txt"
    
    # Cria estrutura de diretórios
    mkdir -p "$backup_root"
    mkdir -p "$current_backup"
    
    log_message "Backup atual: $(basename "$current_backup")" "$PURPLE" "$FOLDER_EMOJI"
    
    # Inicializa estatísticas
    echo "=== ESTATÍSTICAS DO BACKUP - $(date) ===" > "$stats_file"
    local total_files=0
    local total_transferred=0
    local total_items=${#DIRECTORIES[@]}
    local current_item=0
    
    echo -e "\n${GRAY}${BOLD}Processando ${total_items} itens...${NC}\n"
    
    # Para cada item (diretório ou arquivo), faz backup incremental
    for item in "${DIRECTORIES[@]}"; do
        current_item=$((current_item + 1))
        
        if [ -f "$item" ]; then
            # É um arquivo
            local item_name=$(basename "$item")
            show_progress $current_item $total_items "$item_name (arquivo)"
            echo ""
            
            log_message "Fazendo backup do arquivo: $item" "$BLUE" "$FILE_EMOJI"
            
            if backup_single_file "$item" "$current_backup" "$latest_link"; then
                echo "Arquivo: $item" >> "$stats_file"
                echo "  Status: Sucesso" >> "$stats_file"
                echo "  Tipo: Arquivo individual" >> "$stats_file"
                echo "" >> "$stats_file"
                
                total_files=$((total_files + 1))
                total_transferred=$((total_transferred + 1))
            else
                echo "Arquivo: $item - ERRO" >> "$stats_file"
            fi
            
        elif [ -d "$item" ]; then
            # É um diretório
            local item_name=$(basename "$item")
            show_progress $current_item $total_items "$item_name (diretório)"
            echo ""
            
            # Se existe backup anterior, usa hard links para arquivos não modificados
            if [ -L "$latest_link" ] && [ -d "$latest_link/$item_name" ]; then
                log_message "Usando backup anterior como referência para: $item" "$YELLOW" "$INFO_EMOJI"
            else
                log_message "Primeiro backup para: $item" "$BLUE" "$ROCKET_EMOJI"
            fi
            
            local stats=$(backup_directory "$item" "$current_backup" "$latest_link")
            if [ $? -eq 0 ]; then
                local dir_files=$(echo "$stats" | cut -d',' -f1)
                local created_files=$(echo "$stats" | cut -d',' -f2)
                
                echo "Diretório: $item" >> "$stats_file"
                echo "  Arquivos totais: $dir_files" >> "$stats_file"
                echo "  Arquivos criados/modificados: $created_files" >> "$stats_file"
                echo "" >> "$stats_file"
                
                total_files=$((total_files + dir_files))
                total_transferred=$((total_transferred + created_files))
            else
                echo "Diretório: $item - ERRO" >> "$stats_file"
            fi
            
        else
            log_message "AVISO: Item não encontrado: $item" "$YELLOW" "$WARNING_EMOJI"
            echo "Item não encontrado: $item" >> "$stats_file"
        fi
    done
    
    # Atualiza link para o backup mais recente
    if [ -L "$latest_link" ]; then
        rm "$latest_link"
    fi
    ln -sf "$current_backup" "$latest_link"
    
    # Calcula tamanho total do backup atual
    local backup_size=$(du -sh "$current_backup" 2>/dev/null | awk '{print $1}')
    
    # Finaliza estatísticas
    echo "RESUMO GERAL:" >> "$stats_file"
    echo "  Total de arquivos: $total_files" >> "$stats_file"
    echo "  Arquivos transferidos: $total_transferred" >> "$stats_file"
    echo "  Tamanho do backup: $backup_size" >> "$stats_file"
    echo "  Data/Hora: $(date)" >> "$stats_file"
    
    # Mostra resumo final colorido
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║${NC} ${SUCCESS_EMOJI} ${WHITE}${BOLD}BACKUP INCREMENTAL CONCLUÍDO${NC} ${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${CHART_EMOJI} ${WHITE}${BOLD}ESTATÍSTICAS FINAIS:${NC}"
    echo -e "${GRAY}├─${NC} Total de arquivos: ${WHITE}${BOLD}$total_files${NC}"
    echo -e "${GRAY}├─${NC} Arquivos transferidos: ${GREEN}${BOLD}$total_transferred${NC}"
    echo -e "${GRAY}├─${NC} Tamanho do backup: ${CYAN}${BOLD}$backup_size${NC}"
    
    if [ $total_files -gt 0 ]; then
        echo -e "${GRAY}└─${NC} Eficiência: ${PURPLE}${BOLD}$((100 - (total_transferred * 100 / total_files)))% economia${NC}\n"
    else
        echo -e "${GRAY}└─${NC} Eficiência: ${PURPLE}${BOLD}N/A${NC}\n"
    fi
    
    log_message "Backup incremental concluído" "$GREEN" "$SUCCESS_EMOJI"
    log_message "Arquivos transferidos: $total_transferred de $total_files" "$CYAN" "$CHART_EMOJI"
    log_message "Tamanho total: $backup_size" "$PURPLE" "$CHART_EMOJI"
    log_message "Estatísticas salvas em: $stats_file" "$GRAY" "$INFO_EMOJI"
}

# Função para realizar backup completo (quando solicitado)
perform_full_backup() {
    echo -e "${PURPLE}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}${BOLD}║${NC} ${ROCKET_EMOJI} ${WHITE}${BOLD}INICIANDO BACKUP COMPLETO${NC} ${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$DESTINATION/backup_completo_$timestamp.tar.gz"
    local manifest_file="$DESTINATION/backup_manifest_$timestamp.txt"
    local temp_dir="/tmp/backup_temp_$timestamp"
    
    # Cria diretório temporário
    mkdir -p "$temp_dir"
    
    # Cria o manifesto
    echo "# Backup Completo - $(date)" > "$manifest_file"
    echo "# Arquivo: $backup_file" >> "$manifest_file"
    echo "# Itens incluídos:" >> "$manifest_file"
    
    valid_items=()
    for item in "${DIRECTORIES[@]}"; do
        if [ -f "$item" ] || [ -d "$item" ]; then
            # Para arquivos individuais, copia para estrutura temporária
            if [ -f "$item" ]; then
                local item_dir=$(dirname "$item")
                local item_name=$(basename "$item")
                local temp_item_dir="$temp_dir$(dirname "$item")"
                mkdir -p "$temp_item_dir"
                cp "$item" "$temp_item_dir/"
                log_message "Arquivo preparado: $item" "$CYAN" "$FILE_EMOJI"
            fi
            
            valid_items+=("$item")
            echo "$item" >> "$manifest_file"
        fi
    done
    
    if [ ${#valid_items[@]} -eq 0 ]; then
        log_message "ERRO: Nenhum item válido encontrado" "$RED" "$ERROR_EMOJI"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_message "Criando arquivo TAR compactado..." "$YELLOW" "$FOLDER_EMOJI"
    
    # Mostra progresso durante a compactação
    echo -e "${CYAN}Compactando ${#valid_items[@]} itens...${NC}"
    
    # Cria lista de itens para tar, tratando arquivos individuais
    local tar_items=()
    for item in "${valid_items[@]}"; do
        if [ -d "$item" ]; then
            # Diretório: adiciona diretamente
            tar_items+=("${item#/}")
        elif [ -f "$item" ]; then
            # Arquivo: adiciona do diretório temporário
            tar_items+=("tmp/backup_temp_$timestamp$(dirname "$item")/$(basename "$item")")
        fi
    done
    
    if tar -czf "$backup_file" -C / "${tar_items[@]}" 2>/dev/null; then
        local file_size=$(ls -lh "$backup_file" | awk '{print $5}')
        log_message "Backup completo criado: $(basename "$backup_file") (Tamanho: $file_size)" "$GREEN" "$SUCCESS_EMOJI"
        
        echo -e "\n${SUCCESS_EMOJI} ${GREEN}${BOLD}Backup completo finalizado!${NC}"
        echo -e "${GRAY}├─${NC} Arquivo: ${WHITE}$(basename "$backup_file")${NC}"
        echo -e "${GRAY}└─${NC} Tamanho: ${CYAN}${BOLD}$file_size${NC}\n"
    else
        log_message "ERRO: Falha ao criar backup completo" "$RED" "$ERROR_EMOJI"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Remove diretório temporário
    rm -rf "$temp_dir"
}

# Função para limpeza de backups antigos
cleanup_old_backups() {
    local backup_root="$DESTINATION"
    local keep_days=${BACKUP_RETENTION_DAYS:-14}
    
    echo -e "${YELLOW}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║${NC} ${CLEAN_EMOJI} ${WHITE}${BOLD}LIMPANDO BACKUPS ANTIGOS${NC} ${YELLOW}${BOLD}║${NC}"
    echo -e "${YELLOW}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    log_message "Iniciando limpeza de backups antigos (mantendo últimos $keep_days dias)" "$YELLOW" "$CLEAN_EMOJI"
    
    if [ -d "$backup_root" ]; then
        # Conta backups que serão removidos
        local old_backups=$(find "$backup_root" -maxdepth 1 -type d -name "backup_*" -mtime +$keep_days | wc -l)
        
        if [ $old_backups -gt 0 ]; then
            log_message "Removendo $old_backups backups incrementais antigos..." "$YELLOW" "$CLEAN_EMOJI"
            find "$backup_root" -maxdepth 1 -type d -name "backup_*" -mtime +$keep_days -exec rm -rf {} \;
            log_message "Limpeza de backups incrementais concluída" "$GREEN" "$SUCCESS_EMOJI"
        else
            log_message "Nenhum backup incremental antigo encontrado" "$GRAY" "$INFO_EMOJI"
        fi
    fi
    
    # Limpa backups completos antigos também
    local old_complete=$(find "$DESTINATION" -name "backup_completo_*.tar.gz" -mtime +$keep_days | wc -l)
    
    if [ $old_complete -gt 0 ]; then
        log_message "Removendo $old_complete backups completos antigos..." "$YELLOW" "$CLEAN_EMOJI"
        find "$DESTINATION" -name "backup_completo_*.tar.gz" -mtime +$keep_days -delete 2>/dev/null
        find "$DESTINATION" -name "backup_manifest_*.txt" -mtime +$keep_days -delete 2>/dev/null
        log_message "Limpeza de backups completos concluída" "$GREEN" "$SUCCESS_EMOJI"
    else
        log_message "Nenhum backup completo antigo encontrado" "$GRAY" "$INFO_EMOJI"
    fi
    
    echo -e "\n${SUCCESS_EMOJI} ${GREEN}${BOLD}Limpeza concluída!${NC}\n"
}

# Verifica se o diretório de destino existe
if [ ! -d "$DESTINATION" ]; then
    log_message "ERRO: Diretório de destino não existe: $DESTINATION" "$RED" "$ERROR_EMOJI"
    log_message "Criando diretório de destino: $DESTINATION" "$YELLOW" "$FOLDER_EMOJI"
    mkdir -p "$DESTINATION"
    if [ $? -eq 0 ]; then
        log_message "Diretório de destino criado com sucesso" "$GREEN" "$SUCCESS_EMOJI"
    else
        log_message "ERRO: Não foi possível criar o diretório de destino" "$RED" "$ERROR_EMOJI"
        exit 1
    fi
fi

# Mostra header inicial
echo -e "${BOLD}${WHITE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}           🚀 SISTEMA DE BACKUP AUTOMATIZADO 🚀${NC}"
echo -e "${BOLD}${WHITE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GRAY}Início: $(date)${NC}\n"

# Verifica argumentos da linha de comando
case "${1:-incremental}" in
    "full"|"completo")
        perform_full_backup
        ;;
    "incremental"|"inc"|"")
        perform_incremental_backup
        cleanup_old_backups
        ;;
    "cleanup"|"limpar")
        cleanup_old_backups
        ;;
    *)
        echo -e "${RED}${BOLD}Uso inválido!${NC}"
        echo -e "${WHITE}Uso: $0 [incremental|full|cleanup]${NC}"
        echo -e "${GRAY}  incremental (padrão) - Backup incremental eficiente${NC}"
        echo -e "${GRAY}  full - Backup completo em arquivo TAR${NC}"
        echo -e "${GRAY}  cleanup - Limpa backups antigos${NC}"
        exit 1
        ;;
esac

umount "$BACKUP_DESTINATION"


echo -e "${BOLD}${WHITE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GRAY}Fim: $(date)${NC}"
echo -e "${BOLD}${GREEN}✨ Backup finalizado com sucesso! ✨${NC}"
echo -e "${BOLD}${WHITE}════════════════════════════════════════════════════════════════${NC}\n"