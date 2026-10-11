#!/bin/sh
# Регистрирует эту папку как локальный typst-пакет @local/mephi-lab:0.1.0.
# Ставится симлинком: правки в шаблоне сразу подхватываются всеми отчётами.
set -e
VERSION=0.1.0
HERE=$(cd "$(dirname "$0")" && pwd)
case "$(uname)" in
  Darwin) DATA="$HOME/Library/Application Support" ;;
  *)      DATA="${XDG_DATA_HOME:-$HOME/.local/share}" ;;
esac
DEST="$DATA/typst/packages/local/mephi-lab"
mkdir -p "$DEST"
ln -sfn "$HERE" "$DEST/$VERSION"
echo "@local/mephi-lab:$VERSION -> $HERE"
