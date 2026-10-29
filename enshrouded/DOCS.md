# Enshrouded Dedicated Server

Diese App betreibt einen dedizierten Enshrouded-Server direkt auf deinem
Home Assistant. Freunde können über das Internet beitreten, auch wenn dein PC aus ist.

- Server-Dateien kommen über SteamCMD von Steam; der Windows-Server läuft unter GE-Proton.
- Bei jedem Start wird der Server aktualisiert. Während er läuft, sucht die App
  regelmäßig nach neuen Versionen und spielt sie ein, sobald niemand online ist.
- Ein RAM-Wächter startet den Server sauber neu, wenn er länger über dem
  eingestellten Limit liegt (Standard: 10 GB).
- Spielstände landen im App-Konfigurationsordner und damit in deinen
  Home-Assistant-Backups.

## Voraussetzungen

| | |
|---|---|
| CPU | Intel/AMD (x86-64). **Raspberry Pi und andere ARM-Geräte funktionieren nicht.** |
| RAM | 16 GB oder mehr im Home-Assistant-Rechner (10 GB für den Server, Rest für HA) |
| Festplatte | 20 GB frei, SSD empfohlen |
| Internet | Eine öffentliche IPv4-Adresse, kein DS-Lite (siehe unten) |

## Installation

1. In Home Assistant: **Einstellungen → Apps → App-Store**, oben rechts
   **⋮ → Repositories**.
2. `https://github.com/beumelee/Enshrouded-HA` eintragen → **Hinzufügen** → Schließen.
3. Seite neu laden. Unten im App-Store erscheint „Enshrouded Server für Home
   Assistant“ mit der App **Enshrouded Dedicated Server**.
4. **Installieren** klicken. Das Image wird auf deinem Gerät gebaut und lädt dabei
   SteamCMD und GE-Proton herunter. Das dauert 5 bis 15 Minuten.

Ohne GitHub geht es auch lokal: den Ordner `enshrouded` per Samba in die Freigabe
`local_apps` (ältere Versionen: `addons`) kopieren, dann im App-Store unter
**⋮ → Nach Updates suchen** und bei **Lokale Apps** installieren.

## Einrichtung

1. Im Reiter **Konfiguration** mindestens setzen:
   - **Servername**: so findest du den Server in der Liste.
   - **Admin-Passwort**: mindestens 8 Zeichen; nur für dich.
   - **Freunde-Passwort**: das gibst du deinen Mitspielern.
2. Optional: **Gast-Passwort**, Spielerplätze, Schwierigkeit, Chat.
3. **Starten**. Beim ersten Start werden die Server-Dateien (einige GB)
   heruntergeladen. Im Reiter **Protokoll** steht irgendwann:
   `Server ist online und lauscht auf UDP-Port 15637`.
4. **Watchdog** einschalten (auf der Info-Seite der App), dann wird die App nach
   einem Fehler automatisch neu gestartet.

### Wer darf was?

| Gruppe | Passwort | Rechte |
|---|---|---|
| Admin | Admin-Passwort | alles, auch kicken und bannen; 1 reservierter Platz |
| Friend | Freunde-Passwort | bauen, Basen bearbeiten und erweitern, Truhen nutzen |
| Guest | Gast-Passwort | spielen und abbauen, keine Änderungen an Basen, keine Truhen |

Die Passwörter müssen sich unterscheiden, weil der Server die Gruppe am Passwort
erkennt.

## Online erreichbar machen (Portfreigabe)

Damit andere über das Internet beitreten können, muss dein Router **UDP-Port 15637**
an den Home-Assistant-Rechner weiterleiten. Andere Ports braucht Enshrouded nicht mehr.

### FRITZ!Box

1. `http://fritz.box` öffnen → **Heimnetz → Netzwerk**: beim Home-Assistant-Gerät
   **„Diesem Netzwerkgerät immer die gleiche IPv4-Adresse zuweisen“** aktivieren.
2. **Internet → Freigaben → Portfreigaben → Gerät für Freigaben hinzufügen** →
   Home-Assistant-Gerät wählen.
3. **Neue Freigabe → Portfreigabe → Andere Anwendung**:
   - Bezeichnung: `Enshrouded`
   - Protokoll: **UDP**
   - Port an Gerät: `15637` bis `15637`
   - Port extern gewünscht: `15637`
   - **Freigabe aktiv** anhaken → OK → Übernehmen.

Andere Router haben das gleiche Prinzip: „Port Forwarding / NAT“, UDP 15637 → IP des
Home-Assistant-Rechners, Port 15637. Eine Schritt-für-Schritt-Anleitung für
**TP-Link** (Archer, ältere Modelle und Deco) steht im
[README des Repositorys](https://github.com/beumelee/Enshrouded-HA#andere-mitspielen-lassen-tp-link-router).

Den Port im Reiter **Netzwerk** der App bitte nicht ändern: der Server meldet sich
mit Port 15637 bei Steam an.

### Hast du DS-Lite?

Viele Kabel- und Glasfaseranschlüsse (z. B. Vodafone Kabel) haben **keine eigene
öffentliche IPv4-Adresse** (DS-Lite / CGNAT). Dann funktioniert keine Portfreigabe.
So prüfst du das:

- FRITZ!Box **Übersicht**: steht dort „DS-Lite“ oder beginnt die IPv4-Adresse mit
  `100.64.` bis `100.127.`, hast du keine öffentliche IPv4.
- Oder: die IPv4 in der FRITZ!Box mit der auf <https://ifconfig.me> vergleichen.
  Sind sie unterschiedlich, liegt CGNAT vor.

Lösungen: beim Anbieter einen „echten Dual-Stack“- bzw. IPv4-Anschluss anfragen
(oft kostenlos oder günstig) oder einen UDP-fähigen Tunnel nutzen, z. B.
[playit.gg](https://playit.gg) oder einen kleinen VPS mit WireGuard.

## Beitreten

Enshrouded starten → **Spielen → Spiel beitreten** → in der Serverliste nach dem
Servernamen suchen → Passwort eingeben. Im eigenen WLAN funktioniert das genauso.

Wenn der Server neu ist, kann es ein paar Minuten dauern, bis er in der Liste
auftaucht.

## Spielstände und Einstellungen

Alle deine Daten liegen im App-Konfigurationsordner, erreichbar über Samba:

- `app_configs/<kennung>_enshrouded/` (ältere Versionen: `addon_configs/…`).
  Bei Installation über GitHub ist `<kennung>` eine Zeichenfolge wie `a1b2c3d4`,
  bei lokaler Installation `local`.
  - `savegame/`: die Welt; Enshrouded legt darin eigene Sicherungen an (`…-1`, `…-2`, …)
  - `enshrouded_server.json`: die Server-Konfiguration

**Vorhandene Welt übernehmen** (z. B. aus einem Koop-Spiel vom PC):

1. App einmal starten, bis sie online ist, damit der Server eine leere Welt anlegt.
   Dann die App **stoppen**.
2. Deine Welt-Dateien vom PC (meist im Steam-Ordner unter
   `userdata\<deine ID>\1203620\remote`) in den Ordner `savegame` kopieren und
   **genauso benennen** wie die Dateien, die der Server angelegt hat. Die
   Server-Dateien vorher zur Sicherheit wegkopieren.
3. App starten.

**Eigene Spieleinstellungen**: Schwierigkeit auf **Custom** stellen und die Werte unter
`gameSettings` in `enshrouded_server.json` anpassen, während die App gestoppt ist.
Name, Passwörter, Plätze, Chat und Port übernimmt die App bei jedem Start aus der
Konfiguration in Home Assistant. Die Gruppen in `userGroups` werden dabei
überschrieben; alles andere, auch Bans, bleibt erhalten.

**Backups**: Home-Assistant-Backups enthalten die Spielstände und die Konfiguration.
Die Spieldateien selbst sind ausgenommen, weil sie beim Start ohnehin neu geladen
werden.

## RAM-Limit

Home Assistant kann einer App kein festes Speicherlimit geben. Die App überwacht
deshalb selbst, wie viel RAM der Server belegt:

- Liegt er dreimal hintereinander (etwa 90 Sekunden) über **RAM-Limit (GB)**, wird er
  sauber heruntergefahren (der Spielstand wird gespeichert) und neu gestartet.
- Überschreitet er das Limit kurz nach einem Neustart erneut, stoppt die App mit
  einer Fehlermeldung, statt endlos neu zu starten. Dann das Limit erhöhen.
- Alle 10 Minuten steht der aktuelle Verbrauch im Protokoll, z. B.
  `Status: RAM 4.2 GB / 10 GB, Spieler 3/16`.

Ein Enshrouded-Server braucht je nach Weltgröße und Spielerzahl meist 3 bis 6 GB.
10 GB reichen also auch für 16 Spieler mit Reserve.

## Fehlerbehebung

| Problem | Lösung |
|---|---|
| Server nicht in der Liste | Portfreigabe UDP 15637 prüfen, DS-Lite prüfen, ein paar Minuten warten. |
| „Version stimmt nicht überein“ | Nach einem Spiel-Update die App neu starten; sie lädt die neue Version sofort. |
| App startet nicht | Protokoll lesen; meist Passwort zu kurz oder doppelt, oder `enshrouded_server.json` kaputt. Eine kaputte Datei kannst du löschen, sie wird neu angelegt. |
| Freunde fliegen alle paar Minuten raus | Im Protokoll nach `RAM-Verbrauch … über dem Limit` suchen und das Limit erhöhen. |
