#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" $@
}

cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
  log "Removing workspace archive."
  rm -f /tmp/$DEPLOY_DIR_NAME.tar.bz2
}
trap cleanup EXIT

log "Packing workspace into archive to transfer onto remote machine."
tar cjvf /tmp/$DEPLOY_DIR_NAME.tar.bz2 --exclude .git .

log "Launching ssh agent."
eval `ssh-agent -s`

remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; log 'Removing workspace...' ; rm -rf \"\$HOME/$DEPLOY_DIR_NAME\" ; log 'Creating workspace directory...' ; mkdir -p \"\$HOME/$DEPLOY_DIR_NAME\" ; log 'Unpacking workspace...' ; tar -C \"\$HOME/$DEPLOY_DIR_NAME\" -xjv ; log 'Launching docker-compose...' ; cd \"\$HOME/$DEPLOY_DIR_NAME\" ; docker-compose -f \"$DOCKER_COMPOSE_FILENAME\" -p \"$DOCKER_COMPOSE_PREFIX\" up -d --remove-orphans --build"

ssh-add <(echo "$SSH_PRIVATE_KEY")

echo ">> [local] Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
  < /tmp/$DEPLOY_DIR_NAME.tar.bz2
