#!/bin/bash

# Função para validar se um diretório ou arquivo existe
validate_path() {
    if [ ! -e "$1" ]; then
        echo "Erro: O caminho '$1' não existe."
        return 1
    fi
    return 0
}

# Função para validar as entradas de configuração
validate_config() {
    local paths=("$@")
    for path in "${paths[@]}"; do
        validate_path "$path" || return 1
    done
    return 0
}