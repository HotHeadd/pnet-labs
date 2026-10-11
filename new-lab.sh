#!/bin/sh
# Новая лаба: ./new-lab.sh lab3   (или ./new-lab.sh bks/lab3)
set -e
[ -n "$1" ] || { echo "usage: $0 <папка-лабы>"; exit 1; }
cd "$(dirname "$0")"
typst init @local/mephi-lab:0.1.0 "$1"
echo "Готово: $1/main.typ  (typst watch $1/main.typ)"
