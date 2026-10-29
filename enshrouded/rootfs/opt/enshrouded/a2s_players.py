#!/usr/bin/env python3
"""Fragt einen Steam-Gameserver per A2S_INFO ab und gibt "spieler max_spieler" aus.

Exit-Code 1, wenn der Server nicht (korrekt) antwortet.
"""
import socket
import sys

REQUEST = b"\xff\xff\xff\xffTSource Engine Query\x00"


def query(host: str, port: int, timeout: float = 3.0) -> tuple[int, int]:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(timeout)
        sock.sendto(REQUEST, (host, port))
        data, _ = sock.recvfrom(4096)
        # Neuere Server verlangen eine Challenge, die an die Anfrage angehängt wird
        if data[4:5] == b"A":
            sock.sendto(REQUEST + data[5:9], (host, port))
            data, _ = sock.recvfrom(4096)

    if data[:5] != b"\xff\xff\xff\xffI":
        raise ValueError("unerwartete Antwort")

    # Header (4) + Typ (1) + Protokoll (1), danach Name, Map, Ordner, Spiel (je nullterminiert)
    pos = 6
    for _ in range(4):
        pos = data.index(b"\x00", pos) + 1
    pos += 2  # Steam App ID
    return data[pos], data[pos + 1]


def main() -> int:
    host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 15637
    try:
        players, max_players = query(host, port)
    except (OSError, ValueError, IndexError):
        return 1
    print(players, max_players)
    return 0


if __name__ == "__main__":
    sys.exit(main())
