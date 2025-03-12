#!/bin/bash

CURRENT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")
REPOSITORY_DIRPATH=$(sudo -u "$CURRENT_DIR_USER" git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)
REPOSITORY_DIRNAME=$(basename "$REPOSITORY_DIRPATH")
SERVICE_NAME=$REPOSITORY_DIRNAME
REPOSITORY_OWNER_UID=$(stat -c '%u' "$REPOSITORY_DIRPATH")
REPOSITORY_OWNER_UNAME=$(stat -c '%U' "$REPOSITORY_DIRPATH")

ENV_FILE="./.env"

# Global Variable
TODO=()

# Exit immediately if a command exits with a non-zero status
set -e

error_handler() {
  echo "An error occurred on line $1. Exiting..."
  exit 1
}

trap 'error_handler $LINENO' ERR

function checkImportantEnvVariable() {
  local param=$1
  local env_file=$2

  env_variable_value=$(grep "^$param=" "$env_file" | cut -d '=' -f 2)

  if [ "$env_variable_value" == "" ]; then
    echo "$(getDate) ❌ $param variable has empty value."
    TODO+=("Please fill in the $param variable in your $env_file file.")
  else
    echo "$(getDate) ✅ $param is set to $env_variable_value"
  fi
}

function copyBashSkelConf() {
  if ! [ -f "$REPOSITORY_DIRPATH/data/vscode_data/.bash_logout" ] && ! [ -f "$REPOSITORY_DIRPATH/data/vscode_data/.bashrc" ] && ! [ -f "$REPOSITORY_DIRPATH/data/vscode_data/.profile" ]; then
    if command -v bash > /dev/null; then
      echo "$(getDate) 🟦 Copy Bash skel configuration file to the data directory"
      output_cp_skel=$(rsync -avzc /etc/skel/.bash_logout /etc/skel/.bashrc /etc/skel/.profile "$REPOSITORY_DIRPATH/data/vscode_data/" 2>&1) || {
        echo "$(getDate) 🔴 rsync command failed: $output_cp_skel"
      }
      chown -R "$REPOSITORY_OWNER_UNAME": "$REPOSITORY_DIRPATH/data/vscode_data/.bash_logout" "$REPOSITORY_DIRPATH/data/vscode_data/.bashrc" "$REPOSITORY_DIRPATH/data/vscode_data/.profile"
    fi
  fi
}

function createDataDirectory() {
  local directory_name=$1
  local directory_to_create="./data/$directory_name"

  echo "$(getDate) 📁 Creating directory data: $directory_name"
  output_mkdir_createDataDirectory=$(mkdir "$directory_to_create" 2>&1) && {
    echo "$(getDate) ✅ Directory created: $directory_name"
  } || {
    echo "$(getDate) ⚠️: $output_mkdir_createDataDirectory"
  }

  echo "$(getDate) 👤 Change the ownership of $directory_name directory"
  chown "$REPOSITORY_OWNER_UNAME": "$directory_to_create"
}

function getDate() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")]"
}

function printTodo() {
  if [[ ${#TODO[@]} -gt 0 ]]; then
    echo

    printTodoMessage "${#TODO[@]}"

    echo
    for i in "${TODO[@]}"; do
      echo "🟦  $i"
    done

    echo
    echo

    printTodoMessage "${#TODO[@]}"

    return 1
  else
    return 0
  fi
}

function printTodoMessage() {
  todo_count=$1

  if [ "$todo_count" -eq 1 ]; then
    echo "$(getDate) ❌ There is 1 thing that needs to be done before you can create your docker image."
  else
    echo "$(getDate) ❌ There are $todo_count things that need to be done before you can create your docker image."
  fi
}

function writeContainerInfo() {
  local postgresql_uid
  local postgresql_gid
  local max_uid=65535

  postgresql_uid=$(id -u postgres 2>&1) && {
    postgresql_gid=$(id -g postgres 2>&1)
  } || {
    postgresql_uid=5432
    while [[ $postgresql_uid -le $max_uid ]]; do
      if ! getent passwd $postgresql_uid > /dev/null; then
        postgresql_gid=$postgresql_uid
        break;
      else
        postgresql_uid=$((postgresql_uid + 1))
      fi
    done
  }

  if ! grep -q "SERVICE_NAME" "$ENV_FILE"; then
    cat <<-EOF >> "$ENV_FILE"

# # # # # # # # # # # # # # # # # # # # #
# CONTAINER INFO                        #
# # # # # # # # # # # # # # # # # # # # #
SERVICE_NAME=$SERVICE_NAME
REPOSITORY_OWNER_UID=$REPOSITORY_OWNER_UID
REPOSITORY_OWNER_UNAME=$REPOSITORY_OWNER_UNAME
POSTGRES_UID=$postgresql_uid
POSTGRES_GID=$postgresql_gid
EOF
  fi
}

function main() {
  "$REPOSITORY_DIRPATH/scripts/update-env-file.sh"
  writeContainerInfo

  checkImportantEnvVariable "APT_GET_PACKAGES" $ENV_FILE
  checkImportantEnvVariable "POSTGRES_VERSION" $ENV_FILE
  checkImportantEnvVariable "POSTGRES_PORT" $ENV_FILE
  checkImportantEnvVariable "POSTGRES_USER" $ENV_FILE
  checkImportantEnvVariable "POSTGRES_PASSWORD" $ENV_FILE
  checkImportantEnvVariable "VSCODE_DIRECT_DOWNLOAD_URL" $ENV_FILE
  checkImportantEnvVariable "VSCODE_PORT" $ENV_FILE
  checkImportantEnvVariable "WKHTMLTOPDF_DIRECT_DOWNLOAD_URL" $ENV_FILE

  createDataDirectory "vscode_data"
  copyBashSkelConf

  echo "$(getDate) 👤 Change the permission of init_postgres.sh script"
  output_chmod_entrypoint_postgres=$(chmod 755 ./init_postgres.sh 2>&1 ) && {
    echo "$(getDate) ✅ Change permission done"
  } || {
    echo "$(getDate) 🔴 ERROR: $output_chmod_entrypoint_postgres"
  }

  if printTodo; then
    echo
    echo
    echo "$(getDate) ✅ Everything is ready to build your docker image."
    echo "$(getDate) 🟦 Please run the following command to build your docker image: 'docker compose build'"
    echo "$(getDate) 🟦 Then, you can run the compose using this command: 'docker compose up -d'"
    echo "$(getDate) 🟦 You can combine the command using: 'docker compose up --build -d'."
    exit 0
  else
    exit 1
  fi
}

main
