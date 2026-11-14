#!/usr/bin/env python3
# Monta roms/boot.rom (Lynx 48K/96K) y roms/boot1.rom (Lynx 128K) a partir de
# las ROMs sueltas de roms/src (los nombres son los de MAME). dosrom.rom (DOS
# de la disquetera, la que se activa con XROM) va en la pagina XDOS de las dos;
# si no estuviera, esa pagina queda a 0xFF. Las ROMs de menos de 8K (la 3a del
# 96K tiene 4K) se rellenan con 0xFF, como hace MAME.
#
#   python3 tools/make_roms.py
#
# boot.rom, 8 paginas de 8K (como romP en psd.v de lynx.poseidon):
#   0 48K.0  1 48K.1  2 96K.0  3 96K.1  4 96K.2  5 96K.2 Scorpion  6 XDOS  7 (libre)
# boot1.rom, 4 paginas de 8K (como romP en psd.v de lynx128.poseidon):
#   0 rom.0  1 rom.1  2 rom.2  3 XDOS
import hashlib, os, sys

here = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(here, '..', 'roms', 'src')
dst = os.path.join(here, '..', 'roms')

def page(name, optional=False):
    p = os.path.join(src, name)
    if not os.path.exists(p):
        if optional:
            return b'\xff' * 8192
        sys.exit('falta roms/src/' + name)
    d = open(p, 'rb').read()
    if len(d) > 8192:
        sys.exit(name + ': mas de 8K')
    return d + b'\xff' * (8192 - len(d))

dos = page('dosrom.rom', optional=True)
if dos == b'\xff' * 8192:
    print('aviso: no hay roms/src/dosrom.rom, la pagina XDOS queda vacia')

boot = b''.join([page('lynx48-1.ic46'), page('lynx48-2.ic45'),
                 page('lynx9646.ic46'), page('lynx9645.ic45'),
                 page('lynx9644.ic44'), page('skorprom.ic44'),
                 dos, b'\xff' * 8192])
boot1 = b''.join([page('lynx128-1.ic1'), page('lynx128-2.ic2'), page('lynx128-3.ic3'), dos])

for name, data in (('boot.rom', boot), ('boot1.rom', boot1)):
    open(os.path.join(dst, name), 'wb').write(data)
    print('%-9s %6d bytes  sha1 %s' % (name, len(data), hashlib.sha1(data).hexdigest()))
