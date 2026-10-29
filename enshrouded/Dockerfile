# Enshrouded Dedicated Server als Home-Assistant-App.
# Den Server gibt es nur für Windows, daher läuft er hier unter GE-Proton.
# Aufbau angelehnt an https://github.com/jsknnr/enshrouded-server (MIT).
FROM debian:13-slim

ARG GE_PROTON_VERSION=11-9

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    HOME=/home/steam \
    STEAMCMD_PATH=/home/steam/steamcmd \
    PROTON_PATH=/home/steam/steamcmd/compatibilitytools.d/GE-Proton${GE_PROTON_VERSION} \
    STEAM_COMPAT_CLIENT_INSTALL_PATH=/home/steam/steamcmd \
    STEAM_COMPAT_DATA_PATH=/data/proton_prefix \
    UMU_ID=0 \
    WINEDEBUG=-all

RUN groupadd -g 10000 steam \
    && useradd -g 10000 -u 10000 -m steam \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dbus \
        gosu \
        jq \
        lib32gcc-s1 \
        libfreetype6 \
        libvulkan1 \
        locales \
        procps \
        python3 \
        winbind \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && rm -f /etc/machine-id \
    && dbus-uuidgen --ensure=/etc/machine-id \
    && rm -rf /var/lib/apt/lists/*

USER steam

RUN mkdir -p "${STEAMCMD_PATH}/compatibilitytools.d" /home/steam/.steam /tmp/ge-proton \
    && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
        | tar -xz -C "${STEAMCMD_PATH}" \
    && ("${STEAMCMD_PATH}/steamcmd.sh" +login anonymous +quit || true) \
    && ln -s "${STEAMCMD_PATH}/linux64" /home/steam/.steam/sdk64 \
    && ln -s /home/steam/.steam/sdk64/steamclient.so /home/steam/.steam/sdk64/steamservice.so \
    && ln -s "${STEAMCMD_PATH}/linux32" /home/steam/.steam/sdk32 \
    && ln -s /home/steam/.steam/sdk32/steamclient.so /home/steam/.steam/sdk32/steamservice.so \
    && curl -fsSL "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton${GE_PROTON_VERSION}/GE-Proton${GE_PROTON_VERSION}-x86_64.tar.gz" \
        | tar -xz -C /tmp/ge-proton \
    && mv /tmp/ge-proton/* "${PROTON_PATH}" \
    && rmdir /tmp/ge-proton \
    # GE-Proton 11 deaktiviert lsteamclient, das der Server für Steamworks braucht
    && sed -i 's/append_to_env_str(self.env, "WINEDLLOVERRIDES", "lsteamclient=d", ";")/pass/' "${PROTON_PATH}/proton" \
    && ! grep -q "lsteamclient=d" "${PROTON_PATH}/proton"

USER root

COPY rootfs/opt/enshrouded/ /opt/enshrouded/
RUN chmod 755 /opt/enshrouded/run.sh /opt/enshrouded/a2s_players.py

CMD [ "/opt/enshrouded/run.sh" ]
