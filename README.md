# Enshrouded Server für Home Assistant

Ein dedizierter Enshrouded-Server als Home-Assistant-App (früher „Add-on“).
Er läuft als Docker-Container auf deinem Home Assistant und ist für Freunde über
das Internet erreichbar.

## Inhalt

```
enshrouded/
├── config.yaml          App-Definition (Ports, Optionen, Backup-Regeln)
├── Dockerfile           Debian 13 + SteamCMD + GE-Proton
├── DOCS.md              Ausführliche Anleitung (erscheint in HA unter „Dokumentation“)
├── translations/        Beschriftungen der Optionen (de/en)
└── rootfs/opt/enshrouded/
    ├── run.sh           Update, Konfiguration, Start, Überwachung, RAM-Wächter
    ├── a2s_players.py   Fragt die Spielerzahl ab (für Updates ohne Rauswurf)
    └── enshrouded_server.default.json
```

## Schnellstart

1. In Home Assistant: Einstellungen → Apps → App-Store → ⋮ → **Repositories** →
   `https://github.com/beumelee/Enshrouded-HA` hinzufügen.
2. Seite neu laden, **Enshrouded Dedicated Server** öffnen und installieren.
3. Admin- und Freunde-Passwort setzen, starten.
4. Am Router **UDP 15637** auf den Home-Assistant-Rechner weiterleiten
   (für TP-Link siehe [unten](#andere-mitspielen-lassen-tp-link-router)).

Neue Versionen erscheinen in Home Assistant als Update, sobald `version` in
`enshrouded/config.yaml` erhöht wird.

Alle Details, auch zur FRITZ!Box und zu DS-Lite, stehen in
[`enshrouded/DOCS.md`](enshrouded/DOCS.md).

## Andere mitspielen lassen (TP-Link-Router)

Freunde erreichen deinen Server nur, wenn der Router Anfragen auf **UDP-Port 15637**
an deinen Home-Assistant-Rechner weiterleitet. Dafür braucht es zwei Einstellungen:
eine feste IP-Adresse für den Home-Assistant-Rechner und eine Portweiterleitung.

Die Menünamen unterscheiden sich je nach Modell und Firmware etwas. Ist die
Oberfläche auf Englisch, stehen die Begriffe in Klammern dahinter.

### 1. IP-Adresse des Home-Assistant-Rechners herausfinden

In Home Assistant: **Einstellungen → System → Netzwerk**. Dort steht die
IPv4-Adresse, z. B. `192.168.0.50`.

### 2a. TP-Link Archer und andere Router mit Weboberfläche

1. Im Browser <http://tplinkwifi.net> öffnen (oder `192.168.0.1` bzw. `192.168.1.1`)
   und mit dem Router-Passwort anmelden.
2. **Feste IP vergeben:** **Erweitert → Netzwerk → DHCP-Server → Adressreservierung**
   (Advanced → Network → DHCP Server → Address Reservation) → **Hinzufügen**.
   Den Home-Assistant-Rechner aus der Geräteliste wählen, seine IP eintragen,
   **Speichern**.
3. **Port weiterleiten:** **Erweitert → NAT-Weiterleitung → Portweiterleitung**
   (Advanced → NAT Forwarding → Port Forwarding; bei älterer Firmware
   „Virtuelle Server“ / Virtual Servers) → **Hinzufügen** und so ausfüllen:

   | Feld | Wert |
   |---|---|
   | Dienstname (Service Name) | `Enshrouded` |
   | Geräte-IP-Adresse (Device IP Address) | IP des Home-Assistant-Rechners |
   | Externer Port (External Port) | `15637` |
   | Interner Port (Internal Port) | `15637` |
   | Protokoll (Protocol) | **UDP** |
   | Diesen Eintrag aktivieren (Enable) | ✔ |

4. **Speichern**.

Ältere TP-Link-Router (z. B. TL-WR-Serie mit grüner Oberfläche) haben das Menü
**Weiterleitung → Virtuelle Server → Neu hinzufügen** (Forwarding → Virtual Servers).
Service-Port und interner Port sind beide `15637`, Protokoll **UDP**, Status
**Aktiviert**. Die feste IP findest du dort unter **DHCP → Adressreservierung**.

### 2b. TP-Link Deco (Mesh, Einstellung über die App)

Die Deco muss im **Router-Modus** laufen, nicht als Access Point.

1. Deco-App öffnen → **Mehr → Erweitert → Adressreservierung** (More → Advanced →
   Address Reservation) → **+** → Home-Assistant-Rechner wählen → **Speichern**.
2. **Mehr → Erweitert → NAT-Weiterleitung → Portweiterleitung** (NAT Forwarding →
   Port Forwarding) → **+**:
   - Name: `Enshrouded`
   - Interne IP: Home-Assistant-Rechner auswählen
   - Protokoll: **UDP**
   - Externer Port und interner Port: `15637`
3. **Speichern**.

### 3. Hängt der TP-Link hinter einem anderen Router?

Oft steckt der TP-Link hinter dem Gerät vom Anbieter (Vodafone Station, Speedport,
FRITZ!Box, Glasfaser-Modem). Dann musst du die Freigabe auch dort einrichten,
sonst kommen die Anfragen gar nicht erst beim TP-Link an.

Prüfen: In der TP-Link-Oberfläche unter **Status** bzw. **Netzwerkübersicht** die
**Internet-IP (WAN-IP)** ansehen.

| WAN-IP beginnt mit | Bedeutung | Was tun |
|---|---|---|
| etwas anderem (öffentliche IP) | alles in Ordnung | nichts weiter nötig |
| `192.168.`, `10.` oder `172.16.`–`172.31.` | doppeltes NAT: zwei Router hintereinander | Entweder auch am Anbieter-Router **UDP 15637** an die WAN-IP des TP-Link weiterleiten, oder den TP-Link in den **Access-Point-Modus** schalten und die Weiterleitung nur am Anbieter-Router einrichten |
| `100.64.` bis `100.127.` | CGNAT / DS-Lite: keine eigene öffentliche IPv4 | Portfreigaben funktionieren nicht. Beim Anbieter eine öffentliche IPv4 anfragen oder einen Tunnel wie [playit.gg](https://playit.gg) nutzen (siehe [`DOCS.md`](enshrouded/DOCS.md#hast-du-ds-lite)) |

UPnP, DMZ oder Änderungen an der TP-Link-Firewall sind nicht nötig.

### 4. Testen und Freunde einladen

1. In Home Assistant im Protokoll der App auf
   `Server ist online und lauscht auf UDP-Port 15637` warten.
2. Einem Freund **außerhalb deines WLANs** den Servernamen und das
   **Freunde-Passwort** schicken.
3. Er startet Enshrouded → **Spielen → Spiel beitreten**, sucht nach dem
   Servernamen und gibt das Passwort ein. Bei einem neuen Server kann es ein paar
   Minuten dauern, bis er in der Liste auftaucht.

Ein Test aus dem eigenen WLAN zeigt nicht, ob die Weiterleitung klappt. Online-
Portchecker sind bei UDP unzuverlässig. Der Test mit einem Freund ist am sichersten.

## Hinweise

- Nur für Intel/AMD-Rechner (x86-64), nicht für Raspberry Pi.
- Der Proton-Aufbau orientiert sich an
  [jsknnr/enshrouded-server](https://github.com/jsknnr/enshrouded-server) (MIT-Lizenz).
- Kein offizielles Produkt von Keen Games oder Home Assistant.
