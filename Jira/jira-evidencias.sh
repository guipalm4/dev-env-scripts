#!/usr/bin/env zsh
# Sobe imagens como anexos de uma issue do Jira Cloud e publica um comentário
# em wiki markup (API v2) que pode referenciar essas imagens com !arquivo.png!.
#
# Uso: jira-evidencias.sh [--dry-run] <ISSUE> <pasta-imagens> <comentario.txt>
set -euo pipefail
script=${0:t}

uso() {
  echo "Uso: $script [--dry-run] <ISSUE> <pasta-imagens> <comentario.txt>" >&2
  exit 2
}

dry_run=false
if [[ ${1:-} == --dry-run ]]; then dry_run=true; shift; fi
(( $# == 3 )) || uso

issue=$1; img_dir=$2; comment_file=$3
[[ -d $img_dir ]] || { echo "Pasta de imagens não encontrada: $img_dir" >&2; exit 1; }
[[ -f $comment_file ]] || { echo "Arquivo de comentário não encontrado: $comment_file" >&2; exit 1; }

# Credenciais: usa as do ambiente; senão carrega o arquivo de secrets.
if [[ -z ${JIRA_API_TOKEN:-} || -z ${JIRA_EMAIL:-} || -z ${JIRA_SITE:-} ]]; then
  secrets=${JIRA_SECRETS_FILE:-$HOME/.config/zsh/secrets.zsh}
  [[ -f $secrets ]] && source "$secrets"
fi
for v in JIRA_API_TOKEN JIRA_EMAIL JIRA_SITE; do
  [[ -n ${(P)v:-} ]] || { echo "Variável $v não definida" >&2; exit 1; }
done

host=${JIRA_SITE#*://}; host=${host%%/*}
base="https://$host"
auth=(-u "$JIRA_EMAIL:$JIRA_API_TOKEN")

# Valida credenciais e issue antes de enviar qualquer coisa.
resp=$(curl -s -w '\n%{http_code}' "${auth[@]}" "$base/rest/api/2/issue/$issue?fields=summary,attachment,comment")
code=${resp##*$'\n'}; json=${resp%$'\n'*}
if [[ $code != 200 ]]; then
  echo "Falha ao ler $issue: HTTP $code" >&2
  exit 1
fi
print -r -- "$json" | python3 -I -c '
import json, sys
f = json.load(sys.stdin)["fields"]
print("Issue:", sys.argv[1], "–", f["summary"])
print("Anexos atuais:", len(f["attachment"]), "| Comentários atuais:", f["comment"]["total"])
' "$issue"
existentes=$(print -r -- "$json" | python3 -I -c 'import json,sys; print("\n".join(a["filename"] for a in json.load(sys.stdin)["fields"]["attachment"]))')

imagens=("$img_dir"/*.(png|jpg|jpeg|gif)(N))
(( ${#imagens} )) || echo "Aviso: nenhuma imagem em $img_dir"

for f in $imagens; do
  nome=${f:t}
  if print -r -- "$existentes" | grep -qxF "$nome"; then
    echo "anexo já existe, pulando: $nome"
    continue
  fi
  if $dry_run; then
    echo "[dry-run] subiria: $nome"
    continue
  fi
  code=$(curl -s -o /dev/null -w '%{http_code}' "${auth[@]}" -X POST \
    -H 'X-Atlassian-Token: no-check' -F "file=@$f" "$base/rest/api/2/issue/$issue/attachments")
  echo "anexo $nome: HTTP $code"
  [[ $code == 200 ]] || exit 1
done

if $dry_run; then
  echo "[dry-run] publicaria o comentário de $comment_file:"
  echo "----"; cat "$comment_file"; echo "----"
  exit 0
fi

python3 -I -c 'import json,sys; print(json.dumps({"body": open(sys.argv[1], encoding="utf-8").read()}))' "$comment_file" \
  | curl -sf "${auth[@]}" -X POST -H 'Content-Type: application/json' --data-binary @- \
      "$base/rest/api/2/issue/$issue/comment" \
  | python3 -I -c 'import json,sys; d=json.load(sys.stdin); print("comentário criado: id", d["id"])'

echo "$base/browse/$issue"
