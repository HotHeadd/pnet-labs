#!/bin/bash
# На PNET-хосте: только загрузка общедоступных образов, без запуска контейнеров.
set -euo pipefail
images=(quay.io/keycloak/keycloak:26.8.2 vaultwarden/server:1.37.5 docker.gitea.com/gitea:28.4.0 postgres:17-alpine)
docker --version
for image in "${images[@]}"; do
    docker pull "$image"
done
docker save -o /tmp/sa6-native-web-images.tar "${images[@]}"
sha256sum /tmp/sa6-native-web-images.tar
