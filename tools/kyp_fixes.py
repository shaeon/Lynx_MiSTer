#!/usr/bin/env python3
# Correcciones a los cores de Kyp (Kyp069/lynx y Kyp069/lynx128), en un solo sitio.
#
# Las mismas correcciones van:
#   - como commits en los forks shaeon/lynx y shaeon/lynx128, para los PR a Kyp:
#         python3 tools/kyp_fixes.py apply <carpeta del repo> lynx|lynx128 [grupo]
#   - como parches que rtl/pre_flow.tcl aplica a los submodulos al generar rtl/gen:
#         python3 tools/kyp_fixes.py tcl      (escribe rtl/kyp_fixes.tcl)
#
# Cada correccion es un par (texto original, texto corregido). Al aplicarla: si el texto
# corregido ya esta (Kyp ha aceptado el PR), no se hace nada; si el original aparece una sola
# vez, se sustituye; en cualquier otro caso es un error. Cuando Kyp acepte un grupo, se puede
# borrar de aqui.
#
# Origen: las correcciones de Lynx48_MiSTer (MiSTer-devel, alanswx, nov-2026), hechas sobre
# este mismo core.
import os, sys

FIXES = [
    # (repo, fichero, grupo, mensaje del commit, [(original, corregido), ...])

    ('lynx', 'lynx.v', 'puerto58',
     'Puerto 58h: escribir solo en ciclos de escritura\n\n'
     'wr58 no miraba WR, asi que cualquier acceso de E/S a 58h (tambien las lecturas)\n'
     'escribia reg58.',
     [("wire wr58 = !iorq && m1 && a[6:0] == 7'h58;",
       "wire wr58 = !iorq && !wr && m1 && a[6:0] == 7'h58;")]),

    ('lynx', 'lynx.v', 'crtc',
     '6845 legible en 86h/87h\n\n'
     'El chip select solo se activaba al escribir; MAME devuelve el estado en 86h y el\n'
     'registro seleccionado en 87h.',
     [("wire crtcCs = !(!iorq && !wr && a[7] && !a[6] && a[2] && a[1]);",
       "wire crtcCs = !(!iorq && (!wr || !rd) && a[7] && !a[6] && a[2] && a[1]);   // tambien lecturas (MAME: 86h estado, 87h registro)\n"
       "\twire[ 7:0] crtcQ;"),
      ("\t\t.DO     (       ),",
       "\t\t.DO     (crtcQ  ),"),
      ("\t\t: !iorq && a[6:2] == 5'h14 && !reg58[3] ? fdcQ\n",
       "\t\t: !iorq && a[6:2] == 5'h14 && !reg58[3] ? fdcQ\n"
       "\t\t: !iorq && a[7] && !a[6] && a[2] && a[1] ? crtcQ\n")]),

    ('lynx', 'lynx.v', 'casen',
     'Escritura en la memoria de video solo con /CASEN del banco activo\n\n'
     'En el esquema (48K v3, IC41) /CASEN corta el /CAS del banco tambien al escribir;\n'
     'antes solo se tenia en cuenta al leer.',
     [("assign mem2W2 = !mreq && !wr && reg7F[1] && reg80[5];",
       "assign mem2W2 = !mreq && !wr && reg7F[1] && reg80[5] && !reg80[2];   // /CASEN corta el /CAS del banco (IC41)"),
      ("assign mem3W2 = !mreq && !wr && reg7F[2] && reg80[5];",
       "assign mem3W2 = !mreq && !wr && reg7F[2] && reg80[5] && !reg80[3];   // como el banco 2")]),

    ('lynx', 'lynx.v', 'cinta',
     'Bit de cinta del puerto 80h con MA13 del 6845\n\n'
     'La entrada de cinta sustituye al bit 0 del teclado mientras MA13 del 6845 esta alto\n'
     '(R12 bit 5), como en Jynx y en el esquema del 48K (CASS_SER_IN con MA13), no\n'
     'mientras esta el bit del motor: los Level 9 dejan el motor encendido y su teclado\n'
     'leia la cinta como teclas.',
     [(": !iorq && a[7:0] == 8'h80 ? { col[7:1], reg80[1] ? tape : col[0] }",
       ": !iorq && a[7:0] == 8'h80 ? { col[7:1], crtcMa[13] ? tape : col[0] }   // cinta en d0 con MA13 del 6845 (Jynx, esquema 48K)")]),

    ('lynx', 'lynx.v', 'rom48',
     '48K: ROM en 0000-5FFF\n\n'
     'Como en el 96K: el zocalo de 4000-5FFF esta vacio en el 48K y lee FF (pagina 7 de\n'
     'la ROM en lynx.poseidon), en vez de dar paso a la RAM.',
     [("assign mem0R = !mreq && !rd && !reg7F[4] && ((a[15:13] < (ramM ? 3 : 2)) || (a[15:13] == 7 && !reg58[4]));",
       "assign mem0R = !mreq && !rd && !reg7F[4] && ((a[15:13] < 3) || (a[15:13] == 7 && !reg58[4]));   // 48K: 4000-5FFF = zocalo vacio, lee FF")]),

    ('lynx', 'lynx.v', 'esc',
     'ESC genera /INT (BREAK)\n\n'
     'Como brk_key en MAME. Nueva entrada brk (ESC pulsada), que da matrix.v por su\n'
     'nueva salida esc. Sin conectar queda a 0 y no cambia nada.',
     [("\tinput  wire       casM,  // 0: off, 1: on\n",
       "\tinput  wire       casM,  // 0: off, 1: on\n"
       "\tinput  wire       brk,   // ESC pulsada: /INT (BREAK, como en MAME)\n"),
      ("wire irq = ~cursor;",
       "wire irq = ~(cursor | brk);")]),

    ('lynx', 'lynx.v', 'salidas',
     'Salidas de (display enable del 6845) y motor (rele de la cinta)\n\n'
     'de hace falta para el blanking en MiSTer y motor para arrancar y parar la cinta.',
     [("\toutput wire       rfsh,\n",
       "\toutput wire       rfsh,\n"
       "\toutput wire       de,    // display enable del 6845\n"
       "\toutput wire       motor, // rele del motor de la cinta (puerto 80h d1)\n"),
      ("\twire crtcDe;\n",
       "\twire crtcDe;\n"
       "\tassign de = crtcDe;\n"),
      ("\twire altg = reg80[4];\n",
       "\twire altg = reg80[4];\n"
       "\tassign motor = reg80[1];\n")]),

    ('lynx', 'matrix.v', 'teclado',
     'matrix: salida esc y teclas End, Ctrl derecho y Enter del teclado numerico\n\n'
     'esc (ESC pulsada) va a la nueva entrada brk de lynx.v. End es la tecla de la\n'
     'fila 9 bit 4, como en MAME.',
     [("\toutput reg       stop\n",
       "\toutput reg       stop,\n"
       "\toutput wire      esc    // ESC pulsada (activo a nivel alto): BREAK\n"),
      ("\t\t\t8'h74: key[9][5] <= make; // right\n",
       "\t\t\t8'h74: key[9][5] <= make; // right\n"
       "\t\t\t8'h69: key[9][4] <= make; // end (MAME \"End\")\n"
       "\t\t\t8'h14: key[2][6] <= make; // right control\n"
       "\t\t\t8'h5A: key[9][3] <= make; // keypad enter = return\n"),
      ("assign col = key[row];\n",
       "assign col = key[row];\n"
       "assign esc = !key[0][6];\n")]),

    ('lynx128', 'lynx.v', 'crtc',
     '6845 legible en 86h/87h\n\n'
     'crtcQ ya se leia en 86h/87h, pero el chip select solo se activaba al escribir y la\n'
     'lectura devolvia FF.',
     [("wire crtcCs = !(!iorq && !wr && !a[6] && a[2:1] == 2'b11);",
       "wire crtcCs = !(!iorq && (!wr || !rd) && !a[6] && a[2:1] == 2'b11);   // tambien lecturas: crtcQ se lee en 86h/87h")]),

    ('lynx128', 'lynx.v', 'esc',
     'ESC genera /INT (BREAK)\n\n'
     'Como brk_key en MAME. Nueva entrada brk (ESC pulsada), que da matrix.v por su\n'
     'nueva salida esc. Sin conectar queda a 0 y no cambia nada.',
     [("\tinput  wire      reset,\n",
       "\tinput  wire      reset,\n"
       "\tinput  wire      brk,     // ESC pulsada: /INT (BREAK, como en MAME)\n"),
      ("\t\t.irq    (~irq[IW-1]),",
       "\t\t.irq    (~(irq[IW-1] | brk)),")]),

    ('lynx128', 'lynx.v', 'salidas',
     'Salidas de (display enable del 6845) y motor (rele de la cinta)\n\n'
     'de hace falta para el blanking en MiSTer y motor para arrancar y parar la cinta.',
     [("\toutput wire      rfsh,\n",
       "\toutput wire      rfsh,\n"
       "\toutput wire      de,      // display enable del 6845\n"
       "\toutput wire      motor,   // rele del motor de la cinta (puerto 80h d3)\n"),
      ("\twire crtcDe;\n",
       "\twire crtcDe;\n"
       "\tassign de = crtcDe;\n"),
      ("\twire      altg = reg80[4];\n",
       "\twire      altg = reg80[4];\n"
       "\tassign motor = reg80[3];\n")]),
]

# matrix.v es igual en los dos repos
FIXES += [('lynx128',) + f[1:] for f in FIXES if f[0] == 'lynx' and f[1] == 'matrix.v']


def fix_text(text, pairs, where):
    for old, new in pairs:
        if new in text:
            continue
        n = text.count(old)
        if n != 1:
            sys.exit('%s: el texto a corregir aparece %d veces:\n%s' % (where, n, old))
        text = text.replace(old, new)
    return text


def tcl_quote(s):
    if s.count('{') != s.count('}') or '\\' in s:
        sys.exit('no se puede poner entre llaves en Tcl: ' + s)
    return '{' + s + '}'


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    if len(sys.argv) >= 2 and sys.argv[1] == 'tcl':
        out = ['# GENERADO por tools/kyp_fixes.py (no editar): correcciones a los cores de Kyp.',
               '# Lista de { repo fichero grupo {original corregido ...} }.',
               'set kyp_fixes {']
        for repo, fname, group, _msg, pairs in FIXES:
            flat = ' '.join(tcl_quote(o) + ' ' + tcl_quote(n) for o, n in pairs)
            out.append('\t{%s %s %s {%s}}' % (repo, fname, group, flat))
        out.append('}')
        path = os.path.join(here, '..', 'rtl', 'kyp_fixes.tcl')
        open(path, 'w', newline='\n').write('\n'.join(out) + '\n')
        print('escrito', os.path.normpath(path))
    elif len(sys.argv) >= 4 and sys.argv[1] == 'apply':
        root, repo = sys.argv[2], sys.argv[3]
        only = sys.argv[4] if len(sys.argv) > 4 else None
        for r, fname, group, msg, pairs in FIXES:
            if r != repo or (only and group != only):
                continue
            p = os.path.join(root, fname)
            text = open(p, newline='').read()
            open(p, 'w', newline='').write(fix_text(text, pairs, '%s/%s (%s)' % (repo, fname, group)))
    elif len(sys.argv) >= 3 and sys.argv[1] == 'groups':
        seen = []
        for r, fname, group, msg, pairs in FIXES:
            if r == sys.argv[2] and group not in [g for g, _ in seen]:
                seen.append((group, msg))
        for g, m in seen:
            print(g + '\t' + m.split('\n')[0])
    elif len(sys.argv) >= 4 and sys.argv[1] == 'msg':
        for r, fname, group, msg, pairs in FIXES:
            if r == sys.argv[2] and group == sys.argv[3]:
                print(msg)
                break
    else:
        sys.exit(__doc__ or 'uso: kyp_fixes.py tcl | apply <dir> <repo> [grupo] | groups <repo> | msg <repo> <grupo>')


if __name__ == '__main__':
    main()
