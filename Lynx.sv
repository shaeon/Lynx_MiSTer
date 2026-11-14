//-------------------------------------------------------------------------------------------------
// Camputers Lynx para MiSTer: Lynx 48K, 96K, 96K Scorpion y 128K en un solo core.
//
// Cores: Kyp (https://github.com/Kyp069/lynx y https://github.com/Kyp069/lynx128), a partir de
//        sus versiones para Poseidon (lynx.poseidon y lynx128.poseidon).
// Port MiSTer: Shaeon (Carlos Palmero).
//
// Las dos maquinas estan dentro del core y solo funciona la elegida en el OSD (la otra se queda
// en reset). Comparten la SDRAM, la disquetera (WD1793), la cinta, el teclado, el audio y el
// video. El modelo se aplica al hacer reset ("Reset & apply model").
//
// ROMs (games/Lynx):
//   boot.rom  (indice 0x00, 64K): Lynx 48K/96K, 8 paginas de 8K (ver roms/README.md)
//   boot1.rom (indice 0x40, 32K): Lynx 128K, 4 paginas de 8K
//
// Mapa de la SDRAM (direcciones de 16 bits, se usa el byte bajo):
//   0x00000-0x0FFFF  boot.rom             0x20000-0x2FFFF  RAM (banco 1 de los dos modelos)
//   0x10000-0x17FFF  boot1.rom            0x30000-0x3FFFF  RAM (banco 4 del 128K)
//
// This program is free software; you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation; either version 3 of
// the License, or (at your option) any later version.
//-------------------------------------------------------------------------------------------------
module emu
(
	`include "sys/emu_ports.vh"
);
//--- defaults ------------------------------------------------------------------------------------

	assign USER_OUT = '1;
	assign {UART_RTS, UART_TXD, UART_DTR} = 0;
	assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

	assign VGA_F1 = 0;
	assign VGA_SCALER = 0;
	assign VGA_DISABLE = 0;
	assign HDMI_FREEZE = 0;
	assign HDMI_BLACKOUT = 0;
	assign HDMI_BOB_DEINT = 0;

	assign BUTTONS = 0;
	assign LED_POWER = 0;

//--- forward declarations ------------------------------------------------------------------------

	wire[127:0] status;

	wire       F9;                        // reset desde el teclado (activo a nivel bajo)
	wire       ready;                     // SDRAM iniciada
	wire[15:0] sdrQ;
	wire       tape;
	wire       tzxBusy;
	wire       tzxTape;
	wire       tapeWait;
	wire[ 7:0] fdcQ;
	wire       fdcBusy;

	// Lynx 48K / 96K
	wire       rfsh48;
	wire       hs48, vs48, r48, g48, b48, de48;
	wire[ 5:0] sound48;
	wire[ 3:0] row48;

	wire[15:0] mem0A48;
	wire       mem0R48;
	wire[15:0] mem1A48;
	wire[ 7:0] mem1D48;
	wire       mem1R48;
	wire       mem1W48;

	wire[13:0] mem2A1, mem2A2, mem3A1, mem3A2;
	wire[ 7:0] mem2Q1, mem2D2, mem2Q2, mem3Q1, mem3D2, mem3Q2;
	wire       mem2W2, mem3W2;

	wire[ 1:0] fdcA48;
	wire[ 7:0] fdcD48;
	wire       fdcR48, fdcW48, fdcSel48, fdcSide48;

	// Lynx 128K
	wire       rfsh128;
	wire       hs128, vs128, r128, g128, b128, de128;
	wire[ 5:0] sound128;
	wire[ 3:0] row128;

	wire[15:0] mem0A128;
	wire       mem0R128;
	wire[15:0] mem1A128;
	wire[ 7:0] mem1D128;
	wire       mem1R128;
	wire       mem1W128;
	wire[15:0] mem4A128;
	wire[ 7:0] mem4D128;
	wire       mem4R128;
	wire       mem4W128;

	wire[15:0] vramA1, vramA2;
	wire[ 7:0] vramQ1, vramD2, vramQ2;
	wire       vramW2;

	wire[ 1:0] fdcA128;
	wire[ 7:0] fdcD128;
	wire       fdcR128, fdcW128, fdcSel128, fdcSide128;

//--- config string -------------------------------------------------------------------------------
//
//  bits usados: 0-4, 6-7, 9-15, 18-19
//  0         1         2         3
//  01234567890123456789012345678901
//  XXXXX XX XXXXXXX  XX
//

	`include "build_id.v"
	localparam CONF_STR =
	{
		"Lynx;;",
		"-;",
		"S0,LDF,Mount LDF;",
		"F1,TZX,Load TZX;",
		"-;",
		"O[2:1],Model,96K,96K Scorpion,48K,128K;",
		"H0O[3],Bank 2 CAS enable,On,Off;",
		"-;",
		"P1,Video;",
		"P1-;",
		"P1O[10:9],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
		"P1O[13:11],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
		"P1O[15:14],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
		"P2,Audio & Tape;",
		"P2-;",
		"P2O[4],Tape sound,Off,On;",
		"P2O[6],Invert tape in,Off,On;",
		"P2O[7],Swap joysticks,Off,On;",
		"-;",
		"T[18],Tape play;",
		"T[19],Tape stop;",
		"-;",
		"R[0],Reset & apply model;",
		"J1,Fire;",
		"jn,A;",
		"V,v",`BUILD_DATE
	};

//--- clock ---------------------------------------------------------------------------------------

	wire clock;                           // 48 MHz, como en las versiones de Poseidon
	wire power;

	pll pll
	(
		.refclk  (CLK_50M),
		.rst     (1'b0   ),
		.outclk_0(clock  ),
		.locked  (power  )
	);

	// Habilitaciones de reloj: las mismas que psd.v de cada core de Kyp
	reg[5:0] ce6;
	always @(negedge clock, negedge power) if(!power) ce6 <= 1'd0; else ce6 <= ce6+1'd1;

	wire pe12M = ce6[1:0] == 1;           // 128K: pixel
	wire pe06M = ce6[2:0] == 3;           // 48/96K: pixel
	wire peM75 = ce6[5:0] == 31;          // 48/96K: 6845
	wire ne6M0 = ce6[2:0] == 7;           // 128K: CPU (6 MHz)
	wire pe6M0 = ce6[2:0] == 3;
	wire pe1M5 = ce6[4:0] == 15;          // 128K: 6845

	reg [3:0] ce4;                        // 48/96K: CPU a 4 MHz (48/12)
	wire      ne04M = ce4[3:0] == 11;
	wire      pe04M = ce4[3:0] == 5;
	always @(negedge clock, negedge power) if(!power) ce4 <= 1'd0; else if(ne04M) ce4 <= 1'd0; else ce4 <= ce4+1'd1;

//--- hps io --------------------------------------------------------------------------------------

	wire [  1:0] buttons;
	wire         forced_scandoubler;
	wire [ 21:0] gamma_bus;

	wire         ps2kCk;
	wire         ps2kD;

	wire [ 31:0] joystick_0;
	wire [ 31:0] joystick_1;

	wire         ioctl_download;
	wire [ 15:0] ioctl_index;
	wire         ioctl_wr;
	wire [ 26:0] ioctl_addr;
	wire [  7:0] ioctl_dout;
	wire         ioctl_wait;

	wire [  0:0] img_mounted;
	wire         img_readonly;
	wire [ 63:0] img_size;

	wire [ 31:0] sd_lba[1];
	wire [  0:0] sd_rd;
	wire [  0:0] sd_wr;
	wire [  0:0] sd_ack;
	wire [ 13:0] sd_buff_addr;
	wire [  7:0] sd_buff_dout;
	wire [  7:0] sd_buff_din[1];
	wire         sd_buff_wr;

	hps_io #(.CONF_STR(CONF_STR), .PS2DIV(2000), .VDNUM(1)) hps_io
	(
		.clk_sys           (clock             ),
		.HPS_BUS           (HPS_BUS           ),
		.EXT_BUS           (                  ),
		.gamma_bus         (gamma_bus         ),

		.forced_scandoubler(forced_scandoubler),
		.buttons           (buttons           ),
		.status            (status            ),
		.status_menumask   ({ 15'd0, status[2:1] == 2'd3 }),

		.ps2_kbd_clk_out   (ps2kCk            ),
		.ps2_kbd_data_out  (ps2kD             ),

		.joystick_0        (joystick_0        ),
		.joystick_1        (joystick_1        ),

		.ioctl_download    (ioctl_download    ),
		.ioctl_index       (ioctl_index       ),
		.ioctl_wr          (ioctl_wr          ),
		.ioctl_addr        (ioctl_addr        ),
		.ioctl_dout        (ioctl_dout        ),
		.ioctl_wait        (ioctl_wait        ),

		.img_mounted       (img_mounted       ),
		.img_readonly      (img_readonly      ),
		.img_size          (img_size          ),

		.sd_lba            (sd_lba            ),
		.sd_blk_cnt        ('{6'd0}           ),
		.sd_rd             (sd_rd             ),
		.sd_wr             (sd_wr             ),
		.sd_ack            (sd_ack            ),
		.sd_buff_addr      (sd_buff_addr      ),
		.sd_buff_dout      (sd_buff_dout      ),
		.sd_buff_din       (sd_buff_din       ),
		.sd_buff_wr        (sd_buff_wr        )
	);

	// boot.rom llega con indice 0 y boot1.rom con 0x40 (Main_MiSTer carga bootN.rom con N<<6)
	wire romIo  = ioctl_download && ioctl_index[5:0] == 0;
	wire rom128 = ioctl_index[6];
	wire tzxIo  = ioctl_download && ioctl_index[5:0] == 1;

	reg romIoP = 1'b0;
	always @(posedge clock) romIoP <= romIo;

	reg romLoaded = 1'b0;
	always @(posedge clock) if(!romIo && romIoP) romLoaded <= 1'b1;

//--- model ---------------------------------------------------------------------------------------

	// reset pedido (activo a nivel alto); mientras dura se toma el modelo elegido en el OSD
	wire resetReq = !(power && ready && F9 && romLoaded && !romIo && !status[0] && !buttons[1] && !RESET);

	reg[1:0] model = 2'd0;                // 0: 96K, 1: 96K Scorpion, 2: 48K, 3: 128K
	always @(posedge clock) if(resetReq) model <= status[2:1];

	wire m128 = model == 2'd3;
	wire ramM = model <= 2'd1;            // 96K
	wire romX = model == 2'd1;            // ROM Scorpion
	wire casM = status[3];

	wire reset48  = !resetReq && !m128;   // reset de cada maquina (activo a nivel bajo)
	wire reset128 = !resetReq &&  m128;

//--- joysticks -----------------------------------------------------------------------------------

	wire[31:0] joyA = status[7] ? joystick_1 : joystick_0;
	wire[31:0] joyB = status[7] ? joystick_0 : joystick_1;

	// como mist.v de Kyp: { -, -, fuego, -, derecha, izquierda, abajo, arriba }, activo a nivel bajo
	wire[7:0] joy0 = ~{ 2'b00, joyA[4], 1'b0, joyA[0], joyA[1], joyA[2], joyA[3] };
	wire[7:0] joy1 = ~{ 2'b00, joyB[4], 1'b0, joyB[0], joyB[1], joyB[2], joyB[3] };

//--- keyboard ------------------------------------------------------------------------------------

	wire      strb;
	wire[7:0] code;

	ps2k ps2k(clock, ps2kCk, ps2kD, strb, code);

	wire[3:0] row = m128 ? row128 : row48;
	wire[7:0] col;
	wire play, stop;

	matrix matrix(clock, strb, code, row, col, F9, play, stop);

//--- tape ----------------------------------------------------------------------------------------

	tape_ddr #(.MS(48000)) tape_ddr
	(
		.clock           (clock           ),
		.ce              (1'b1            ),
		.dl              (tzxIo           ),
		.dlA             (ioctl_addr      ),
		.dlD             (ioctl_dout      ),
		.dlW             (ioctl_wr && tzxIo),
		.dlWait          (tapeWait        ),
		.play            (!play || status[18]),
		.stop            (!stop || status[19]),
		.stop48          (1'b1            ),   // como tzx.v de Kyp: el bloque 0x2A para la cinta
		.busy            (tzxBusy         ),
		.tape            (tzxTape         ),
		.DDRAM_CLK       (DDRAM_CLK       ),
		.DDRAM_BUSY      (DDRAM_BUSY      ),
		.DDRAM_BURSTCNT  (DDRAM_BURSTCNT  ),
		.DDRAM_ADDR      (DDRAM_ADDR      ),
		.DDRAM_DOUT      (DDRAM_DOUT      ),
		.DDRAM_DOUT_READY(DDRAM_DOUT_READY),
		.DDRAM_RD        (DDRAM_RD        ),
		.DDRAM_DIN       (DDRAM_DIN       ),
		.DDRAM_BE        (DDRAM_BE        ),
		.DDRAM_WE        (DDRAM_WE        )
	);

	// entrada de audio analogica (ADC de la placa I/O)
	wire tapeAdc;
	wire tapeAdcAct;

	ltc2308_tape ltc2308_tape
	(
		.reset   (1'b0      ),
		.clk     (CLK_50M   ),
		.ADC_BUS (ADC_BUS   ),
		.dout    (tapeAdc   ),
		.active  (tapeAdcAct),
		.adc_sync(          ),
		.adc_data(          )
	);

	reg tapeAdcS1 = 1'b0, tapeAdcS = 1'b0, tapeAdcActS1 = 1'b0, tapeAdcActS = 1'b0;
	always @(posedge clock) begin
		tapeAdcS1 <= tapeAdc;       tapeAdcS <= tapeAdcS1;
		tapeAdcActS1 <= tapeAdcAct; tapeAdcActS <= tapeAdcActS1;
	end

	assign tape = tzxBusy ? tzxTape : tapeAdcActS && (tapeAdcS ^ status[6]);

//--- floppy (WD1793, compartida) -----------------------------------------------------------------

	wire[1:0] fdcA    = m128 ? fdcA128    : fdcA48;
	wire[7:0] fdcD    = m128 ? fdcD128    : fdcD48;
	wire      fdcR    = m128 ? fdcR128    : fdcR48;
	wire      fdcW    = m128 ? fdcW128    : fdcW48;
	wire      fdcSel  = m128 ? fdcSel128  : fdcSel48;
	wire      fdcSide = m128 ? fdcSide128 : fdcSide48;
	reg fdcDisk = 1'b0;
	always @(posedge clock) if(img_mounted[0]) fdcDisk <= |img_size;

	wire fdcRdy = fdcSel && fdcDisk;

	wd1793 #(.EDSK(0), .RWMODE(1)) wd1793
	(
		.clk_sys            (clock          ),
		.ce                 (m128 ? pe6M0 : pe04M),
		.reset              (m128 ? !reset128 : !reset48),
		.io_en              (1'b1           ),
		.rd                 (fdcR           ),
		.wr                 (fdcW           ),
		.addr               (fdcA           ),
		.din                (fdcD           ),
		.dout               (fdcQ           ),
		.drq                (               ),
		.intrq              (               ),
		.busy               (fdcBusy        ),
		.wp                 (img_readonly   ),
		.size_code          (3'd4           ),
		.layout             (1'b1           ),
		.side               (fdcSide        ),
		.ready              (fdcRdy         ),
		.img_mounted        (img_mounted[0] ),
		.img_mounted_overide(1'b0           ),
		.img_size           (img_size       ),
		.prepare            (               ),
		.sd_lba             (sd_lba[0]      ),
		.sd_rd              (sd_rd[0]       ),
		.sd_wr              (sd_wr[0]       ),
		.sd_ack             (sd_ack[0]      ),
		.sd_buff_addr       (sd_buff_addr[8:0]),
		.sd_buff_dout       (sd_buff_dout   ),
		.sd_buff_din        (sd_buff_din[0] ),
		.sd_buff_wr         (sd_buff_wr     ),
		.input_active       (1'b0           ),
		.input_addr         (20'd0          ),
		.input_data         (8'd0           ),
		.input_wr           (1'b0           ),
		.buff_addr          (               ),
		.buff_read          (               ),
		.buff_din           (8'd0           )
	);

//--- sdram ---------------------------------------------------------------------------------------

	// paginas de ROM (las mismas que psd.v de cada core)
	reg[2:0] romP48;
	always @*
		casex({ romX, ramM, mem0A48[15:13] })
			5'bx_0_000: romP48 = 3'd0; // 48K.0
			5'bx_0_001: romP48 = 3'd1; // 48K.1
			5'bx_1_000: romP48 = 3'd2; // 96K.0
			5'bx_1_001: romP48 = 3'd3; // 96K.1
			5'b0_1_010: romP48 = 3'd4; // 96K.2 estandar
			5'b1_1_010: romP48 = 3'd5; // 96K.2 Scorpion
			5'bx_x_111: romP48 = 3'd6; // XDOS
			default:    romP48 = 3'd7;
		endcase

	reg[1:0] romP128;
	always @*
		case(mem0A128[15:13])
			3'd0:    romP128 = 2'd0; // rom.0
			3'd1:    romP128 = 2'd1; // rom.1
			3'd2:    romP128 = 2'd2; // rom.2
			default: romP128 = 2'd3; // XDOS
		endcase

	wire[23:0] sdrA48  = mem0R48 ? { 8'h00, romP48, mem0A48[12:0] } : { 8'h02, mem1A48 };
	wire[23:0] sdrA128 = mem0R128 ? { 8'h01, 1'b0, romP128, mem0A128[12:0] }
	                   : mem1R128 || mem1W128 ? { 8'h02, mem1A128 } : { 8'h03, mem4A128 };

	wire[23:0] sdrA = romIo ? (rom128 ? { 8'h01, 1'b0, ioctl_addr[14:0] } : { 8'h00, ioctl_addr[15:0] })
	                : m128 ? sdrA128 : sdrA48;
	wire[15:0] sdrD = { 8'hFF, romIo ? ioctl_dout : m128 ? (mem1W128 ? mem1D128 : mem4D128) : mem1D48 };
	wire       sdrR = m128 ? mem0R128 || mem1R128 || mem4R128 : mem0R48 || mem1R48;
	wire       sdrW = romIo ? ioctl_wr : m128 ? mem1W128 || mem4W128 : mem1W48;
	wire       rfsh = m128 ? rfsh128 : rfsh48;

	wire[1:0] dramDQM;
	wire      sdrBusy;

	// hps_io espera mientras el controlador esta ocupado (refresco automatico durante la carga)
	assign ioctl_wait = tapeWait || (romIo && sdrBusy);

	sdram_mister sdram
	(
		.clock  (clock     ),
		.phase  (ce6[3:0]  ),
		.ready  (ready     ),
		.busy   (sdrBusy   ),
		.rfsh   (rfsh      ),
		.rd     (sdrR      ),
		.wr     (sdrW      ),
		.a      (sdrA      ),
		.d      (sdrD      ),
		.q      (sdrQ      ),
		.dramCe (SDRAM_CKE ),
		.dramCs (SDRAM_nCS ),
		.dramWe (SDRAM_nWE ),
		.dramRas(SDRAM_nRAS),
		.dramCas(SDRAM_nCAS),
		.dramDQM(dramDQM   ),
		.dramDQ (SDRAM_DQ  ),
		.dramBA (SDRAM_BA  ),
		.dramA  (SDRAM_A   )
	);

	assign { SDRAM_DQMH, SDRAM_DQML } = dramDQM;

	// SDRAM_CLK = clk_sys invertido (ver la cabecera de rtl/sdram_mister.v)
	altddio_out
	#(
		.extend_oe_disable     ("OFF"         ),
		.intended_device_family("Cyclone V"   ),
		.invert_output         ("OFF"         ),
		.lpm_hint              ("UNUSED"      ),
		.lpm_type              ("altddio_out" ),
		.oe_reg                ("UNREGISTERED"),
		.power_up_high         ("OFF"         ),
		.width                 (1             )
	)
	sdramclk_ddr
	(
		.datain_h  (1'b0       ),
		.datain_l  (1'b1       ),
		.outclock  (clock      ),
		.dataout   (SDRAM_CLK  ),
		.aclr      (1'b0       ),
		.aset      (1'b0       ),
		.oe        (1'b1       ),
		.outclocken(1'b1       ),
		.sclr      (1'b0       ),
		.sset      (1'b0       )
	);

//--- Lynx 48K / 96K (Kyp069/lynx) ----------------------------------------------------------------

	vram #(16) mem2(clock, mem2A1, mem2Q1, mem2A2, mem2D2, mem2Q2, mem2W2);
	vram #(16) mem3(clock, mem3A1, mem3Q1, mem3A2, mem3D2, mem3Q2, mem3W2);

	lynx48 lynx48
	(
		.ramM   (ramM     ),
		.casM   (casM     ),
		.clock  (clock    ),
		.pe06M  (pe06M    ),
		.peM75  (peM75    ),
		.ne04M  (ne04M    ),
		.pe04M  (pe04M    ),
		.reset  (reset48  ),
		.rfsh   (rfsh48   ),
		.de     (de48     ),
		.hSync  (hs48     ),
		.vSync  (vs48     ),
		.r      (r48      ),
		.g      (g48      ),
		.b      (b48      ),
		.tape   (tape     ),
		.sound  (sound48  ),
		.row    (row48    ),
		.col    (col      ),
		.joy0   (joy0     ),
		.joy1   (joy1     ),
		.mem0A  (mem0A48  ),
		.mem0Q  (sdrQ[7:0]),
		.mem0R  (mem0R48  ),
		.mem1A  (mem1A48  ),
		.mem1D  (mem1D48  ),
		.mem1Q  (sdrQ[7:0]),
		.mem1R  (mem1R48  ),
		.mem1W  (mem1W48  ),
		.mem2A1 (mem2A1   ),
		.mem2Q1 (mem2Q1   ),
		.mem2A2 (mem2A2   ),
		.mem2D2 (mem2D2   ),
		.mem2Q2 (mem2Q2   ),
		.mem2W2 (mem2W2   ),
		.mem3A1 (mem3A1   ),
		.mem3Q1 (mem3Q1   ),
		.mem3A2 (mem3A2   ),
		.mem3D2 (mem3D2   ),
		.mem3Q2 (mem3Q2   ),
		.mem3W2 (mem3W2   ),
		.fdcA   (fdcA48   ),
		.fdcD   (fdcD48   ),
		.fdcQ   (fdcQ     ),
		.fdcR   (fdcR48   ),
		.fdcW   (fdcW48   ),
		.fdcSel (fdcSel48 ),
		.fdcSide(fdcSide48)
	);

//--- Lynx 128K (Kyp069/lynx128) ------------------------------------------------------------------

	vram #(64) vram128(clock, vramA1, vramQ1, vramA2, vramD2, vramQ2, vramW2);

	lynx128 lynx128
	(
		.clock  (clock     ),
		.pe12M  (pe12M     ),
		.ne6M0  (ne6M0     ),
		.pe6M0  (pe6M0     ),
		.pe1M5  (pe1M5     ),
		.reset  (reset128  ),
		.rfsh   (rfsh128   ),
		.de     (de128     ),
		.hsync  (hs128     ),
		.vsync  (vs128     ),
		.r      (r128      ),
		.g      (g128      ),
		.b      (b128      ),
		.tape   (tape      ),
		.sound  (sound128  ),
		.row    (row128    ),
		.col    (col       ),
		.joy0   (joy0      ),
		.joy1   (joy1      ),
		.mem0A  (mem0A128  ),
		.mem0Q  (sdrQ[7:0] ),
		.mem0R  (mem0R128  ),
		.mem1A  (mem1A128  ),
		.mem1D  (mem1D128  ),
		.mem1Q  (sdrQ[7:0] ),
		.mem1R  (mem1R128  ),
		.mem1W  (mem1W128  ),
		.mem2A1 (vramA1    ),
		.mem2Q1 (vramQ1    ),
		.mem2A2 (vramA2    ),
		.mem2D2 (vramD2    ),
		.mem2Q2 (vramQ2    ),
		.mem2W2 (vramW2    ),
		.mem4A  (mem4A128  ),
		.mem4D  (mem4D128  ),
		.mem4Q  (sdrQ[7:0] ),
		.mem4R  (mem4R128  ),
		.mem4W  (mem4W128  ),
		.fdcA   (fdcA128   ),
		.fdcD   (fdcD128   ),
		.fdcQ   (fdcQ      ),
		.fdcR   (fdcR128   ),
		.fdcW   (fdcW128   ),
		.fdcSel (fdcSel128 ),
		.fdcSide(fdcSide128)
	);

//--- audio ---------------------------------------------------------------------------------------

	wire[5:0] sound = m128 ? sound128 : sound48;
	wire      tapeSnd = status[4] && tape;

	wire[15:0] mix = { 2'b00, sound, 8'd0 }+{ 3'b000, {11{ tapeSnd }}, 2'b00 };

	assign AUDIO_S = 1'b0;
	assign AUDIO_L = mix;
	assign AUDIO_R = mix;
	assign AUDIO_MIX = 2'd0;

//--- video ---------------------------------------------------------------------------------------

	wire cePixel = m128 ? pe12M : pe06M;
	wire hsync = m128 ? hs128 : hs48;
	wire vsync = m128 ? vs128 : vs48;
	wire de    = m128 ? de128 : de48;
	wire[2:0] rgb = m128 ? { r128, g128, b128 } : { r48, g48, b48 };

	// video.v saca cada caracter (8 pixeles) un caracter despues de que el 6845 lo direccione:
	// se retrasa DE lo mismo para el blanking horizontal.
	reg[7:0] deDly = 8'd0;
	always @(posedge clock) if(cePixel) deDly <= { deDly[6:0], de };
	wire deOut = deDly[7];

	// Blanking vertical: lineas con DE del cuadro anterior (el 6845 lo programa la ROM).
	reg      hsP = 1'b0, vsP = 1'b0, lineDe = 1'b0, gotFirst = 1'b0;
	reg[9:0] line = 10'd0, curFirst = 10'd0, curLast = 10'd0, deFirst = 10'd0, deLast = 10'd1023;

	always @(posedge clock) if(cePixel) begin
		hsP <= hsync;
		vsP <= vsync;
		if(deOut) lineDe <= 1'b1;
		if(hsync && !hsP) begin
			if(lineDe) begin
				if(!gotFirst) begin curFirst <= line; gotFirst <= 1'b1; end
				curLast <= line;
			end
			lineDe <= 1'b0;
			if(line != 10'h3FF) line <= line+1'd1;
		end
		if(vsync && !vsP) begin
			deFirst <= curFirst;
			deLast <= curLast;
			gotFirst <= 1'b0;
			line <= 10'd0;
		end
	end

	wire vblank = line < deFirst || line > deLast;

	reg ce_pix = 1'b0;
	always @(posedge clock) ce_pix <= cePixel;

	reg[7:0] R, G, B;
	reg      hs, vs, hbl, vbl;

	always @(posedge clock) if(cePixel) begin
		hs  <= hsync;
		vs  <= vsync;
		hbl <= !deOut;
		vbl <= vblank;
		R   <= {8{ rgb[2] }};
		G   <= {8{ rgb[1] }};
		B   <= {8{ rgb[0] }};
	end

	wire[2:0] scale = status[13:11];
	wire[1:0] ar = status[10:9];
	wire      vga_de;

	assign CLK_VIDEO = clock;
	assign VGA_SL = scale >= 2 ? scale[1:0]-1'd1 : 2'd0;

	video_freak video_freak
	(
		.CLK_VIDEO  (CLK_VIDEO  ),
		.CE_PIXEL   (CE_PIXEL   ),
		.VGA_VS     (VGA_VS     ),
		.HDMI_WIDTH (HDMI_WIDTH ),
		.HDMI_HEIGHT(HDMI_HEIGHT),
		.VGA_DE     (VGA_DE     ),
		.VIDEO_ARX  (VIDEO_ARX  ),
		.VIDEO_ARY  (VIDEO_ARY  ),
		.VGA_DE_IN  (vga_de     ),
		.ARX        ((!ar) ? 12'd4 : (ar - 1'd1)),
		.ARY        ((!ar) ? 12'd3 : 12'd0),
		.CROP_SIZE  (12'd0      ),
		.CROP_OFF   (5'd0       ),
		.SCALE      ({ 1'b0, status[15:14] })
	);

	video_mixer #(.LINE_LENGTH(1024), .GAMMA(1)) video_mixer
	(
		.CLK_VIDEO  (CLK_VIDEO  ),
		.CE_PIXEL   (CE_PIXEL   ),
		.ce_pix     (ce_pix     ),
		.scandoubler(scale || forced_scandoubler),
		.hq2x       (scale == 1 ),
		.gamma_bus  (gamma_bus  ),
		.R          (R          ),
		.G          (G          ),
		.B          (B          ),
		.HSync      (hs         ),
		.VSync      (vs         ),
		.HBlank     (hbl        ),
		.VBlank     (vbl        ),
		.HDMI_FREEZE(HDMI_FREEZE),
		.freeze_sync(           ),
		.VGA_R      (VGA_R      ),
		.VGA_G      (VGA_G      ),
		.VGA_B      (VGA_B      ),
		.VGA_VS     (VGA_VS     ),
		.VGA_HS     (VGA_HS     ),
		.VGA_DE     (vga_de     )
	);

//--- leds ----------------------------------------------------------------------------------------

	assign LED_USER = ioctl_download || tzxBusy;
	assign LED_DISK = { 1'b0, fdcBusy };

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
