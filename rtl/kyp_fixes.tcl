# GENERADO por tools/kyp_fixes.py (no editar): correcciones a los cores de Kyp.
# Lista de { repo fichero grupo {original corregido ...} }.
set kyp_fixes {
	{lynx lynx.v puerto58 {{wire wr58 = !iorq && m1 && a[6:0] == 7'h58;} {wire wr58 = !iorq && !wr && m1 && a[6:0] == 7'h58;}}}
	{lynx lynx.v crtc {{wire crtcCs = !(!iorq && !wr && a[7] && !a[6] && a[2] && a[1]);} {wire crtcCs = !(!iorq && (!wr || !rd) && a[7] && !a[6] && a[2] && a[1]);   // tambien lecturas (MAME: 86h estado, 87h registro)
	wire[ 7:0] crtcQ;} {		.DO     (       ),} {		.DO     (crtcQ  ),} {		: !iorq && a[6:2] == 5'h14 && !reg58[3] ? fdcQ
} {		: !iorq && a[6:2] == 5'h14 && !reg58[3] ? fdcQ
		: !iorq && a[7] && !a[6] && a[2] && a[1] ? crtcQ
}}}
	{lynx lynx.v casen {{assign mem2W2 = !mreq && !wr && reg7F[1] && reg80[5];} {assign mem2W2 = !mreq && !wr && reg7F[1] && reg80[5] && !reg80[2];   // /CASEN corta el /CAS del banco (IC41)} {assign mem3W2 = !mreq && !wr && reg7F[2] && reg80[5];} {assign mem3W2 = !mreq && !wr && reg7F[2] && reg80[5] && !reg80[3];   // como el banco 2}}}
	{lynx lynx.v cinta {{: !iorq && a[7:0] == 8'h80 ? { col[7:1], reg80[1] ? tape : col[0] }} {: !iorq && a[7:0] == 8'h80 ? { col[7:1], crtcMa[13] ? tape : col[0] }   // cinta en d0 con MA13 del 6845 (Jynx, esquema 48K)}}}
	{lynx lynx.v rom48 {{assign mem0R = !mreq && !rd && !reg7F[4] && ((a[15:13] < (ramM ? 3 : 2)) || (a[15:13] == 7 && !reg58[4]));} {assign mem0R = !mreq && !rd && !reg7F[4] && ((a[15:13] < 3) || (a[15:13] == 7 && !reg58[4]));   // 48K: 4000-5FFF = zocalo vacio, lee FF}}}
	{lynx lynx.v esc {{	input  wire       casM,  // 0: off, 1: on
} {	input  wire       casM,  // 0: off, 1: on
	input  wire       brk,   // ESC pulsada: /INT (BREAK, como en MAME)
} {wire irq = ~cursor;} {wire irq = ~(cursor | brk);}}}
	{lynx lynx.v salidas {{	output wire       rfsh,
} {	output wire       rfsh,
	output wire       de,    // display enable del 6845
	output wire       motor, // rele del motor de la cinta (puerto 80h d1)
} {	wire crtcDe;
} {	wire crtcDe;
	assign de = crtcDe;
} {	wire altg = reg80[4];
} {	wire altg = reg80[4];
	assign motor = reg80[1];
}}}
	{lynx matrix.v teclado {{	output reg       stop
} {	output reg       stop,
	output wire      esc    // ESC pulsada (activo a nivel alto): BREAK
} {			8'h74: key[9][5] <= make; // right
} {			8'h74: key[9][5] <= make; // right
			8'h69: key[9][4] <= make; // end (MAME "End")
			8'h14: key[2][6] <= make; // right control
			8'h5A: key[9][3] <= make; // keypad enter = return
} {assign col = key[row];
} {assign col = key[row];
assign esc = !key[0][6];
}}}
	{lynx128 lynx.v crtc {{wire crtcCs = !(!iorq && !wr && !a[6] && a[2:1] == 2'b11);} {wire crtcCs = !(!iorq && (!wr || !rd) && !a[6] && a[2:1] == 2'b11);   // tambien lecturas: crtcQ se lee en 86h/87h}}}
	{lynx128 lynx.v esc {{	input  wire      reset,
} {	input  wire      reset,
	input  wire      brk,     // ESC pulsada: /INT (BREAK, como en MAME)
} {		.irq    (~irq[IW-1]),} {		.irq    (~(irq[IW-1] | brk)),}}}
	{lynx128 lynx.v salidas {{	output wire      rfsh,
} {	output wire      rfsh,
	output wire      de,      // display enable del 6845
	output wire      motor,   // rele del motor de la cinta (puerto 80h d3)
} {	wire crtcDe;
} {	wire crtcDe;
	assign de = crtcDe;
} {	wire      altg = reg80[4];
} {	wire      altg = reg80[4];
	assign motor = reg80[3];
}}}
	{lynx128 matrix.v teclado {{	output reg       stop
} {	output reg       stop,
	output wire      esc    // ESC pulsada (activo a nivel alto): BREAK
} {			8'h74: key[9][5] <= make; // right
} {			8'h74: key[9][5] <= make; // right
			8'h69: key[9][4] <= make; // end (MAME "End")
			8'h14: key[2][6] <= make; // right control
			8'h5A: key[9][3] <= make; // keypad enter = return
} {assign col = key[row];
} {assign col = key[row];
assign esc = !key[0][6];
}}}
}
