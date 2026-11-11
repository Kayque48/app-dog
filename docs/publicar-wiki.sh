#!/usr/bin/env bash
# Publica o vault do Obsidian (docs/wiki) na wiki do GitHub.
#
# Antes da primeira vez: abra https://github.com/Kayque48/app-dog/wiki e clique em
# "Create the first page" (salve qualquer coisa). Só depois disso o GitHub cria o
# repositório da wiki. Este script substitui as páginas pelo conteúdo de docs/wiki.
#
# Uso (na raiz do repositório):  bash docs/publicar-wiki.sh
set -euo pipefail

REPO_URL="${WIKI_URL:-https://github.com/Kayque48/app-dog.wiki.git}"
ORIGEM="$(cd "$(dirname "$0")/wiki" && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT

git clone --quiet "$REPO_URL" "$TEMP/wiki"
# remove as páginas antigas (mantém o histórico do git da wiki)
find "$TEMP/wiki" -maxdepth 1 -name '*.md' -delete
cp "$ORIGEM"/*.md "$TEMP/wiki/"

cd "$TEMP/wiki"
git add -A
if git diff --cached --quiet; then
  echo "A wiki já está atualizada."
  exit 0
fi
git commit --quiet -m "Atualiza a documentação a partir de docs/wiki"
git push --quiet
echo "Wiki publicada: ${REPO_URL%.wiki.git}/wiki"
