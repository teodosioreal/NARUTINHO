"""Fala com o PCSX2 de uma sala pelo protocolo PINE (roda dentro do container).

Uso: python3 - salvar|carregar <slot>   (o arquivo vem pela entrada padrao)
"""
import glob
import os
import socket
import struct
import sys

OPCODES = {"salvar": 0x09, "carregar": 0x0A}


def achar_socket():
    candidatos = [os.path.join(os.environ.get("XDG_RUNTIME_DIR", ""), "pcsx2.sock")]
    candidatos += glob.glob("/run/user/*/pcsx2.sock") + glob.glob("/tmp/pcsx2.sock")
    candidatos += glob.glob("/config/**/pcsx2.sock", recursive=True)
    for c in candidatos:
        if c and os.path.exists(c):
            return c
    sys.exit("PCSX2 da sala nao esta respondendo (o jogo esta aberto?)")


def main():
    acao, slot = sys.argv[1], int(sys.argv[2])
    corpo = struct.pack("<BB", OPCODES[acao], slot)
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(10)
    s.connect(achar_socket())
    s.sendall(struct.pack("<I", len(corpo) + 4) + corpo)
    resposta = s.recv(5)
    if len(resposta) < 5 or resposta[4] != 0:
        sys.exit(f"PCSX2 recusou: {acao} {slot}")
    print("ok")


if __name__ == "__main__":
    main()
