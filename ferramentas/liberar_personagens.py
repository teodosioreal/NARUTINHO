#!/usr/bin/env python3
"""Libera todos os personagens do Naruto Shippuden: Ultimate Ninja 5 (SLES-55605 / versao BR).

Grava direto no executavel dentro da ISO os dois codigos do CodeMasters Project:
  201E94B4 24020003  -> todos os personagens liberados no modo VS
  201E95AC 2402FFFF  -> todos os personagens "linkados" liberados

Uso:
  python3 liberar_personagens.py jogo.iso              (aplica)
  python3 liberar_personagens.py jogo.iso --verificar  (so confere, nao altera)
"""
import struct
import sys

SETOR = 2048
PATCHES = [
    # endereco,  instrucao original (lbu v0,0x900(v0)), nova (li v0,3)
    (0x1E94B4, 0x90420900, 0x24020003),
    # endereco,  instrucao original (lw v0,0x960(a0)),  nova (li v0,-1)
    (0x1E95AC, 0x8C820960, 0x2402FFFF),
]


def achar_executavel(iso):
    """Procura o SLES_xxx.xx na raiz da ISO e devolve (offset em bytes, tamanho)."""
    iso.seek(16 * SETOR)
    pvd = iso.read(SETOR)
    if pvd[1:6] != b'CD001':
        sys.exit('Isso nao parece uma ISO de PS2.')
    raiz = pvd[156:190]
    lba, tam = struct.unpack('<I', raiz[2:6])[0], struct.unpack('<I', raiz[10:14])[0]
    iso.seek(lba * SETOR)
    dados = iso.read(tam)
    i = 0
    while i < len(dados):
        n = dados[i]
        if n == 0:
            i = (i // SETOR + 1) * SETOR
            continue
        reg = dados[i:i + n]
        nome = reg[33:33 + reg[32]].decode('latin1').split(';')[0]
        if nome.startswith('SLES_') or nome.startswith('SLUS_') or nome.startswith('SLPS_'):
            return nome, struct.unpack('<I', reg[2:6])[0] * SETOR, struct.unpack('<I', reg[10:14])[0]
        i += n
    sys.exit('Executavel do jogo nao encontrado na ISO.')


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    caminho = sys.argv[1]
    so_verificar = '--verificar' in sys.argv

    with open(caminho, 'rb' if so_verificar else 'r+b') as iso:
        nome, base, tam = achar_executavel(iso)
        iso.seek(base)
        cab = iso.read(0x400)
        if cab[:4] != b'\x7fELF':
            sys.exit(f'{nome} nao e um ELF valido.')
        phoff = struct.unpack('<I', cab[0x1C:0x20])[0]
        phnum = struct.unpack('<H', cab[0x2C:0x2E])[0]
        segs = [struct.unpack('<8I', cab[phoff + k * 32:phoff + k * 32 + 32]) for k in range(phnum)]

        def offset_na_iso(va):
            for _, off, vaddr, _, filesz, _, _, _ in segs:
                if vaddr <= va < vaddr + filesz:
                    return base + off + (va - vaddr)
            sys.exit(f'Endereco {va:#x} fora do executavel: versao do jogo diferente.')

        print(f'Jogo: {nome}')
        alterar = []
        for va, original, nova in PATCHES:
            pos = offset_na_iso(va)
            iso.seek(pos)
            atual = struct.unpack('<I', iso.read(4))[0]
            if atual == nova:
                print(f'  {va:08X}: ja liberado')
            elif atual == original:
                print(f'  {va:08X}: original, pronto para liberar')
                alterar.append((pos, nova))
            else:
                sys.exit(f'  {va:08X}: valor inesperado {atual:08X}. Versao do jogo diferente, nada foi alterado.')

        if so_verificar or not alterar:
            print('Nada alterado.' if so_verificar else 'Todos os personagens ja estavam liberados.')
            return
        for pos, nova in alterar:
            iso.seek(pos)
            iso.write(struct.pack('<I', nova))
        print('Pronto: todos os personagens liberados.')


if __name__ == '__main__':
    main()
