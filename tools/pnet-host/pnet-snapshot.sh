#!/bin/sh
# Хост PNETLab (root): свернуть диск qemu-узла из pod в самостоятельный образ.
# Запускает tools/pnet-helper.py snapshot: ssh root@host sh -s -- LAB_SESSION NODE_SESSION IMAGE BASE KEEP < этот файл
#   оверлей узла: /opt/unetlab/tmp/<id сессии лабы>/<поле session узла из get_lab>/*.qcow2 (поверх базового образа)
#   IMAGE — новый образ (BASE-vN) в /opt/unetlab/addons/qemu/; KEEP — сколько версий BASE-v* хранить
#   (старые удаляются, только если ни один .unl на них не ссылается)
set -eu
SESSION=$1 NODE=$2 IMAGE=$3 BASE=$4 KEEP=$5
SRC=/opt/unetlab/tmp/$SESSION/$NODE
QEMU=/opt/unetlab/addons/qemu
DST=$QEMU/$IMAGE
QIMG=/opt/qemu/bin/qemu-img
[ -x "$QIMG" ] || QIMG=qemu-img

ls "$SRC"/*.qcow2 > /dev/null 2>&1 || { echo "нет дисков узла в $SRC"; exit 1; }
if command -v fuser > /dev/null && fuser "$SRC"/*.qcow2 > /dev/null 2>&1; then
  echo "диски $SRC открыты (узел запущен) — остановить узел"; exit 1
fi
[ ! -e "$DST" ] || { echo "образ $IMAGE уже есть"; exit 1; }

mkdir -p "$DST"
for f in "$SRC"/*.qcow2; do
  "$QIMG" convert -p -O qcow2 "$f" "$DST/$(basename "$f")"
done
"$QIMG" check "$DST"/*.qcow2 > /dev/null
/opt/unetlab/wrappers/unl_wrapper -a fixpermissions > /dev/null 2>&1 || true
echo "образ $IMAGE: $(du -sh "$DST" | cut -f1)"

# старые версии BASE-vN: оставить KEEP последних, не трогать те, на которые ссылается какая-нибудь лаба
ls -d "$QEMU/$BASE"-v* 2> /dev/null | sort -V -r | sed "1,${KEEP}d" | while read -r old; do
  name=$(basename "$old")
  if grep -rqs "image=\"$name\"" /opt/unetlab/labs; then
    echo "оставлен $name: используется в лабе"
  else
    rm -rf "$old" && echo "удалён $name"
  fi
done
