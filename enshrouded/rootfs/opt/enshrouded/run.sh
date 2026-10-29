#!/usr/bin/env bash
# Startet und überwacht den Enshrouded Dedicated Server in der Home-Assistant-App.
set -uo pipefail

DATA_DIR="${DATA_DIR:-/data}"
CONFIG_DIR="${CONFIG_DIR:-/config}"
APP_DIR="$(cd "$(dirname "$0")" && pwd)"

OPTIONS_FILE="${DATA_DIR}/options.json"
SERVER_DIR="${DATA_DIR}/steam_server"
SERVER_CONFIG="${SERVER_DIR}/enshrouded_server.json"
SERVER_LOG="${SERVER_DIR}/logs/enshrouded_server.log"
CONFIG_FILE="${CONFIG_DIR}/enshrouded_server.json"
SAVE_DIR="${CONFIG_DIR}/savegame"
STEAMCMD="${STEAMCMD_PATH}/steamcmd.sh"
PROTON="${PROTON_PATH}/proton"
STEAM_APP_ID=2278520
QUERY_PORT=15637
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"   # Sekunden zwischen zwei Überwachungsrunden
STATUS_INTERVAL=600                      # Sekunden zwischen zwei Statusmeldungen
STARTUP_TIMEOUT=900                      # Sekunden, bis der Port offen sein sollte
MEMORY_STRIKES=3                         # so oft hintereinander über dem Limit -> Neustart

STOP_REQUESTED=0
SERVER_PID=""
TAIL_PID=""

log()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1: ${*:2}"; }
info()  { log INFO "$@"; }
warn()  { log WARN "$@"; }
fatal() { log ERROR "$@"; exit 1; }

as_steam() { gosu steam "$@"; }

on_signal() {
    info "Stopp angefordert"
    STOP_REQUESTED=1
}
trap on_signal TERM INT

# Unterbrechbares Warten, damit ein Stopp-Signal sofort verarbeitet wird
pause() {
    sleep "$1" &
    wait $! || true
}

option() {
    jq -r --arg key "$1" '.[$key] | if . == null then "" else tostring end' "$OPTIONS_FILE"
}

read_options() {
    [[ -r "$OPTIONS_FILE" ]] || fatal "${OPTIONS_FILE} nicht gefunden"
    SERVER_NAME=$(option server_name)
    ADMIN_PASSWORD=$(option admin_password)
    FRIEND_PASSWORD=$(option friend_password)
    GUEST_PASSWORD=$(option guest_password)
    SLOT_COUNT=$(option slot_count)
    GAME_PRESET=$(option game_preset)
    TEXT_CHAT=$(option text_chat)
    VOICE_CHAT=$(option voice_chat)
    VOICE_CHAT_MODE=$(option voice_chat_mode)
    AUTO_UPDATE=$(option auto_update)
    UPDATE_CHECK_INTERVAL=$(option update_check_interval)
    MEMORY_LIMIT_GB=$(option memory_limit_gb)

    [[ -n "$SERVER_NAME" ]] || fatal "server_name darf nicht leer sein"
    (( ${#ADMIN_PASSWORD} >= 8 )) || fatal "admin_password muss mindestens 8 Zeichen lang sein"
    if [[ -z "$FRIEND_PASSWORD" ]]; then
        warn "friend_password ist leer - JEDER kann ohne Passwort mit Bau-Rechten beitreten!"
    fi
    if [[ "$ADMIN_PASSWORD" == "$FRIEND_PASSWORD" ]] \
        || [[ -n "$GUEST_PASSWORD" && ( "$GUEST_PASSWORD" == "$ADMIN_PASSWORD" || "$GUEST_PASSWORD" == "$FRIEND_PASSWORD" ) ]]; then
        fatal "Alle Passwörter müssen unterschiedlich sein (der Server erkennt die Gruppe am Passwort)"
    fi
}

# Verzeichnisse anlegen und dem steam-Benutzer geben (rekursiv nur, wenn nötig)
ensure_owned() {
    local dir
    for dir in "$@"; do
        mkdir -p "$dir" || fatal "Kann ${dir} nicht anlegen"
        [[ "$(stat -c %U "$dir")" == steam ]] || chown -R steam:steam "$dir"
    done
}

prepare_dirs() {
    ensure_owned "$SERVER_DIR" "$SERVER_DIR/logs" "$STEAM_COMPAT_DATA_PATH" "$SAVE_DIR"
    # Per Samba hineinkopierte Spielstände gehören root -> immer korrigieren
    chown -R steam:steam "$SAVE_DIR"

    # Spielstände liegen in /config, damit sie per Samba erreichbar und im Backup sind
    if [[ -e "$SERVER_DIR/savegame" && ! -L "$SERVER_DIR/savegame" ]]; then
        warn "Verschiebe altes Verzeichnis ${SERVER_DIR}/savegame nach savegame.old"
        mv "$SERVER_DIR/savegame" "$SERVER_DIR/savegame.old.$(date +%s)"
    fi
    ln -sfn "$SAVE_DIR" "$SERVER_DIR/savegame"

    # SteamCMD bricht auf manchen VMs ab, wenn die CPU-Frequenz unbekannt ist
    if ! awk -F: '/^cpu MHz/ && $2 + 0 > 0 { found = 1 } END { exit !found }' /proc/cpuinfo; then
        export CPU_MHZ=1500.000
    fi
}

installed_build() {
    awk -F'"' '$2 == "buildid" { print $4; exit }' \
        "$SERVER_DIR/steamapps/appmanifest_${STEAM_APP_ID}.acf" 2>/dev/null
}

latest_build() {
    curl -fsS --max-time 20 "https://api.steamcmd.net/v1/info/${STEAM_APP_ID}" 2>/dev/null \
        | jq -r --arg app "$STEAM_APP_ID" '.data[$app].depots.branches.public.buildid // empty' 2>/dev/null
}

update_server() {
    info "Lade/prüfe Enshrouded-Server über SteamCMD (der erste Download dauert einige Minuten) ..."
    local attempt
    for attempt in 1 2; do
        if as_steam "$STEAMCMD" +@sSteamCmdForcePlatformType windows \
                +force_install_dir "$SERVER_DIR" +login anonymous \
                +app_update "$STEAM_APP_ID" validate +quit \
            && [[ -f "$SERVER_DIR/enshrouded_server.exe" ]]; then
            info "Server-Build $(installed_build) ist installiert"
            return 0
        fi
        warn "SteamCMD-Update fehlgeschlagen (Versuch ${attempt}/2)"
        (( STOP_REQUESTED )) && return 1
        # Ein kaputter Update-Zustand lässt sich meist durch Löschen des Manifests beheben
        rm -f "$SERVER_DIR/steamapps/appmanifest_${STEAM_APP_ID}.acf"
        pause 10
    done
    return 1
}

# Optionen aus Home Assistant in die Server-Konfiguration übernehmen.
# Alles andere (z. B. gameSettings, bannedAccounts) bleibt erhalten.
write_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        info "Lege ${CONFIG_FILE} an"
        cp "$APP_DIR/enshrouded_server.default.json" "$CONFIG_FILE"
    fi

    local tmp
    tmp=$(mktemp)
    if ! jq \
        --arg name "$SERVER_NAME" \
        --arg admin "$ADMIN_PASSWORD" \
        --arg friend "$FRIEND_PASSWORD" \
        --arg guest "$GUEST_PASSWORD" \
        --argjson slots "$SLOT_COUNT" \
        --arg preset "$GAME_PRESET" \
        --argjson text "$TEXT_CHAT" \
        --argjson voice "$VOICE_CHAT" \
        --arg voice_mode "$VOICE_CHAT_MODE" \
        --argjson port "$QUERY_PORT" \
        '
        def group($n; $pw; $kick; $inv; $world; $base; $extend; $reserved):
            {name: $n, password: $pw, canKickBan: $kick, canAccessInventories: $inv,
             canEditWorld: $world, canEditBase: $base, canExtendBase: $extend,
             reservedSlots: $reserved};
        del(.password, .gamePort)
        | .name = $name
        | .ip = "0.0.0.0"
        | .queryPort = $port
        | .saveDirectory = "./savegame"
        | .logDirectory = "./logs"
        | .slotCount = $slots
        | .gameSettingsPreset = $preset
        | .enableTextChat = $text
        | .enableVoiceChat = $voice
        | .voiceChatMode = $voice_mode
        | .userGroups = [
            group("Admin"; $admin; true; true; true; true; true; (if $slots > 1 then 1 else 0 end)),
            group("Friend"; $friend; false; true; true; true; true; 0)
          ] + (if $guest == "" then [] else
            [group("Guest"; $guest; false; false; true; false; false; 0)] end)
        ' "$CONFIG_FILE" > "$tmp"; then
        rm -f "$tmp"
        fatal "${CONFIG_FILE} ist kein gültiges JSON - bitte korrigieren oder löschen (wird dann neu angelegt)"
    fi

    install -m 600 "$tmp" "$CONFIG_FILE"
    install -m 600 -o steam -g steam "$tmp" "$SERVER_CONFIG"
    rm -f "$tmp"
}

# Der Server schreibt z. B. Bans in seine Konfiguration -> nach dem Beenden zurückholen
save_config() {
    if [[ -f "$SERVER_CONFIG" ]] && jq empty "$SERVER_CONFIG" 2>/dev/null; then
        install -m 600 "$SERVER_CONFIG" "$CONFIG_FILE"
    fi
}

server_running() {
    pgrep -u steam -f '[e]nshrouded_server.exe' >/dev/null
}

port_open() {
    local hex
    hex=$(printf '%04X' "$QUERY_PORT")
    # Spalte 2 ist die lokale Adresse, z. B. "00000000:3D15"
    grep -qiE "^ *[0-9]+: [0-9A-F]+:${hex} " /proc/net/udp /proc/net/udp6 2>/dev/null
}

memory_used_kb() {
    ps -u steam -o rss= 2>/dev/null | awk '{ sum += $1 } END { print sum + 0 }'
}

format_gb() {
    awk -v kb="$1" 'BEGIN { printf "%.1f GB", kb / 1048576 }'
}

# Ausgabe: "Spieler Max" oder nichts, wenn der Server nicht antwortet
player_count() {
    python3 "$APP_DIR/a2s_players.py" 127.0.0.1 "$QUERY_PORT" 2>/dev/null
}

start_server() {
    info "Starte Enshrouded-Server \"${SERVER_NAME}\" (${SLOT_COUNT} Plätze, Preset ${GAME_PRESET})"
    : > "$SERVER_LOG"
    chown steam:steam "$SERVER_LOG"
    tail -n 0 -F "$SERVER_LOG" 2>/dev/null &
    TAIL_PID=$!

    # Proton erwartet einen relativen Pfad zur .exe im Installationsordner
    (cd "$SERVER_DIR" && exec gosu steam "$PROTON" run enshrouded_server.exe) &
    SERVER_PID=$!
    SERVER_STARTED_AT=$(date +%s)
}

stop_server() {
    if server_running; then
        info "Fahre Server herunter (Spielstand wird gespeichert) ..."
        pkill -INT -u steam -f '[e]nshrouded_server.exe'
        local waited=0
        while server_running && (( waited < 60 )); do
            sleep 2
            waited=$(( waited + 2 ))
        done
        if server_running; then
            warn "Server reagiert nicht - beende ihn hart"
            pkill -TERM -u steam -f '[e]nshrouded_server.exe'
            sleep 10
        fi
    fi
    # wineserver kurz Zeit zum Aufräumen geben, dann Reste beenden
    local grace=0
    while pgrep -u steam >/dev/null && (( grace < 5 )); do
        sleep 1
        grace=$(( grace + 1 ))
    done
    pkill -KILL -u steam 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
    if [[ -n "$TAIL_PID" ]]; then
        kill "$TAIL_PID" 2>/dev/null
        wait "$TAIL_PID" 2>/dev/null
        TAIL_PID=""
    fi
    save_config
}

# Überwacht den laufenden Server. Rückgabe über $MONITOR_RESULT:
#   stop    - Home Assistant will die App stoppen
#   crash   - der Server hat sich selbst beendet
#   memory  - RAM-Limit dauerhaft überschritten
#   update  - neuer Server-Build verfügbar und niemand online
monitor_server() {
    local limit_kb=$(( MEMORY_LIMIT_GB * 1024 * 1024 ))
    local ready=0 strikes=0 last_status=0 last_update_check now used players
    local announced_build=""
    last_update_check=$(date +%s)

    while true; do
        pause "$CHECK_INTERVAL"
        now=$(date +%s)

        if (( STOP_REQUESTED )); then
            MONITOR_RESULT=stop
            return
        fi
        if ! server_running; then
            MONITOR_RESULT=crash
            return
        fi

        if (( ! ready )); then
            if port_open; then
                ready=1
                info "Server ist online und lauscht auf UDP-Port ${QUERY_PORT}"
            elif (( now - SERVER_STARTED_AT > STARTUP_TIMEOUT )); then
                warn "UDP-Port ${QUERY_PORT} ist nach $(( STARTUP_TIMEOUT / 60 )) Minuten noch nicht offen - Log prüfen"
                SERVER_STARTED_AT=$now
            fi
        fi

        used=$(memory_used_kb)
        if (( used > limit_kb )); then
            strikes=$(( strikes + 1 ))
            warn "RAM-Verbrauch $(format_gb "$used") über dem Limit von ${MEMORY_LIMIT_GB} GB (${strikes}/${MEMORY_STRIKES})"
            if (( strikes >= MEMORY_STRIKES )); then
                MONITOR_RESULT=memory
                return
            fi
        else
            strikes=0
        fi

        if (( ready && now - last_status >= STATUS_INTERVAL )); then
            last_status=$now
            players=$(player_count)
            players=${players/ //}
            info "Status: RAM $(format_gb "$used") / ${MEMORY_LIMIT_GB} GB, Spieler ${players:-?}"
        fi

        if (( ready )) && [[ "$AUTO_UPDATE" == true ]] && (( UPDATE_CHECK_INTERVAL > 0 )) \
            && (( now - last_update_check >= UPDATE_CHECK_INTERVAL * 60 )); then
            last_update_check=$now
            local installed latest
            installed=$(installed_build)
            latest=$(latest_build)
            if [[ "$latest" =~ ^[0-9]+$ && "$installed" =~ ^[0-9]+$ && "$latest" != "$installed" ]]; then
                players=$(player_count)
                if [[ "${players%% *}" == 0 ]]; then
                    info "Neuer Server-Build ${latest} verfügbar (installiert: ${installed}) - starte Update"
                    MONITOR_RESULT=update
                    return
                elif [[ "$announced_build" != "$latest" ]]; then
                    announced_build=$latest
                    info "Neuer Server-Build ${latest} verfügbar - Update folgt, sobald niemand mehr online ist"
                fi
            fi
        fi
    done
}

main() {
    read_options
    prepare_dirs
    info "RAM-Limit: ${MEMORY_LIMIT_GB} GB, automatische Updates: ${AUTO_UPDATE}"

    if [[ "$AUTO_UPDATE" == true || ! -f "$SERVER_DIR/enshrouded_server.exe" ]]; then
        if ! update_server; then
            (( STOP_REQUESTED )) && exit 0
            [[ -f "$SERVER_DIR/enshrouded_server.exe" ]] || fatal "Server konnte nicht heruntergeladen werden"
            warn "Update fehlgeschlagen - starte vorhandene Version"
        fi
    fi

    local crashes=0 memory_restarts=0
    while (( ! STOP_REQUESTED )); do
        write_config
        start_server
        monitor_server
        stop_server

        case "$MONITOR_RESULT" in
            stop)
                info "Server gestoppt"
                exit 0
                ;;
            crash)
                # Mehrere Abstürze kurz nach dem Start -> aufgeben, damit der Fehler sichtbar wird
                if (( $(date +%s) - SERVER_STARTED_AT < 300 )); then
                    crashes=$(( crashes + 1 ))
                else
                    crashes=1
                fi
                (( crashes >= 3 )) && fatal "Server stürzt wiederholt kurz nach dem Start ab - Log prüfen"
                warn "Server hat sich unerwartet beendet - Neustart in 10 Sekunden"
                pause 10
                ;;
            memory)
                # Wiederholt kurz nach dem Start über dem Limit -> Limit ist zu klein für die Welt
                if (( $(date +%s) - SERVER_STARTED_AT < 900 )); then
                    memory_restarts=$(( memory_restarts + 1 ))
                else
                    memory_restarts=1
                fi
                (( memory_restarts >= 2 )) \
                    && fatal "RAM-Limit von ${MEMORY_LIMIT_GB} GB reicht nicht - memory_limit_gb erhöhen"
                warn "RAM-Limit von ${MEMORY_LIMIT_GB} GB dauerhaft überschritten - Server wird neu gestartet"
                ;;
            update)
                update_server || warn "Update fehlgeschlagen - starte vorhandene Version"
                ;;
        esac
    done
    info "Server gestoppt"
}

main "$@"
