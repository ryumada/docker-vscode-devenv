# docker-vscode-devenv

This repository contains docker compose with vscode and postgresql service for help developing Apps. The container will help you to not messed up any installation packages on your local computer.

## Features

- VSCode Data on `./data/vscode_data` directory. You can use this directory to clone your repository. This directory is mounted inside container.
- PostgreSQL data saved on `./data/postgres_data` directory.

## Requirements

- At least `Debian`-based Linux distro (Debian, Ubuntu, KDE Neon, Elementary OS, etc) because I tested only on this distro.

## Usage

- Run the `install.sh` script first using sudo.

    ```bash
    sudo ./install.sh
    ```

- Setup your configuration on the `.env` file. After that run `install.sh` script again to make sure that your `.env` file configured correctly.

- Then, you can create the service using:

    ```bash
    docker compose up -d --build
    ```

- You can access your vscode by visiting `localhost:$VSCODE_PORT` in your browser where `$VSCODE_PORT` is the port you've setup in your `.env` file.

---

Copyright © 2025 ryumada. All Rights Reserved.

Licensed under the [MIT](LICENSE) license.
