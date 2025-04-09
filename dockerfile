FROM ubuntu:22.04

ARG APT_GET_PACKAGES
ARG POSTGRES_VERSION
ARG REPOSITORY_OWNER_UID
ARG REPOSITORY_OWNER_UNAME
ARG TIMEZONE
ARG VSCODE_DIRECT_DOWNLOAD_URL
ARG VSCODE_PORT
ARG WKHTMLTOPDF_DIRECT_DOWNLOAD_URL

ENV TIMEZONE=${TIMEZONE}

RUN ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime && echo $TIMEZONE > /etc/timezone

RUN apt update && \
    apt install -y $APT_GET_PACKAGES sudo tzdata apt-transport-https gpg cabextract ssl-cert git wget software-properties-common build-essential tmux fontconfig vim; \
    apt install -y -f

RUN if [ -n "$WKHTMLTOPDF_DIRECT_DOWNLOAD_URL"]; then \
    filename="wkhtmltox.deb"; \
    wget -O $filename $WKHTMLTOPDF_DIRECT_DOWNLOAD_URL; \
    if [ $? -ne 0 ]; then \
        echo "Error downloading wkhtmltopdf. Exiting." >&2; \
        exit 1; \
    fi; \
    dpkg -i $filename; \
    apt install -y -f; \
    rm $filename; \
fi

RUN apt install -y cabextract; \
    apt --fix-broken install; \
    wget http://ftp.jp.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.8.1_all.deb; \
    dpkg -i ./ttf-mscorefonts-installer_3.8.1_all.deb; \
    rm ./ttf-mscorefonts-installer_3.8.1_all.deb

RUN if [ -n "$POSTGRES_VERSION" ]; then \
        apt install -y postgresql-common postgresql-client-common; \
        apt install -y -f; \
        bash /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y; \
        apt search postgresql-client-$POSTGRES_VERSION; \
        apt install -y postgresql-client-$POSTGRES_VERSION; \
    else \
        apt install -y postgresql-client; \
    fi

# RUN if [ -n "$VSCODE_DIRECT_DOWNLOAD_URL" ] && { [ "$VSCODE_DIRECT_DOWNLOAD_URL" != "${VSCODE_DIRECT_DOWNLOAD_URL#[http://]}" ] || [ "$VSCODE_DIRECT_DOWNLOAD_URL" != "${VSCODE_DIRECT_DOWNLOAD_URL#[https://]}" ]; }; then \
#     filename="vscode_installer.deb"; \
#     wget -O "$filename" $VSCODE_DIRECT_DOWNLOAD_URL; \
#     if [ $? -ne 0 ]; then \
#         echo "Error downloading VS Code. Exiting." >&2; \
#         exit 1; \
#     fi; \
#     DEBIAN_FRONTEND=noninteractive dpkg -i "./$filename"; \
#     apt --fix-broken install -y; \
#     rm "$filename"; \
# fi

RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg; \
    install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg; \
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list > /dev/null; \
    rm -f packages.microsoft.gpg; \
    apt update; \
    apt install -y code

RUN useradd -m -s /bin/bash -u 8069  odoo; \
    useradd -m -s /bin/bash -u ${REPOSITORY_OWNER_UID} ${REPOSITORY_OWNER_UNAME}; \
    usermod -aG sudo ${REPOSITORY_OWNER_UNAME}; \
    echo "%sudo ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers.d/00_${REPOSITORY_OWNER_UNAME}

RUN mkdir -p /var/log/odoo /var/lib/odoo; \
    chown odoo: /var/log/odoo /var/lib/odoo

USER ${REPOSITORY_OWNER_UNAME}

WORKDIR /home/$REPOSITORY_OWNER_UNAME

CMD ["/bin/bash", "-c", "code serve-web --without-connection-token --port \"$VSCODE_PORT\" > /home/$REPOSITORY_OWNER_UNAME/vscode.log"]
