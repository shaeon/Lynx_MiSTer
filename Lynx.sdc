# Restricciones propias del core (las generales estan en sys/sys_top.sdc).

# ----------------------------------------------------------------------------
# SDRAM (rtl/sdram_mister.v)
# ----------------------------------------------------------------------------
# La salida 0 de la PLL es clk_sys (48 MHz). SDRAM_CLK sale por un registro DDR
# con datain_h = 0 y datain_l = 1, es decir, clk_sys invertido.
set clk_sys {*|pll|pll_inst|altera_pll_i|*[0].*|divclk}

create_generated_clock -name SDRAM_CLK -source [get_pins -compatibility_mode $clk_sys] -invert [get_ports {SDRAM_CLK}]

# Tiempos del chip a CL2 (modulos SDRAM de MiSTer):
#   entrada: tAC 6 ns + pista (max), tOH 2,5 ns + pista (min)
#   salida:  tIS 1,5 ns (setup), tIH 0,8 ns (hold)
set_input_delay  -clock SDRAM_CLK -max 6.4  [get_ports {SDRAM_DQ[*]}]
set_input_delay  -clock SDRAM_CLK -min 3.2  [get_ports {SDRAM_DQ[*]}]
set_output_delay -clock SDRAM_CLK -max 1.5  [get_ports {SDRAM_DQ[*] SDRAM_A[*] SDRAM_BA[*] SDRAM_DQML SDRAM_DQMH SDRAM_n* SDRAM_CKE}]
set_output_delay -clock SDRAM_CLK -min -0.8 [get_ports {SDRAM_DQ[*] SDRAM_A[*] SDRAM_BA[*] SDRAM_DQML SDRAM_DQMH SDRAM_n* SDRAM_CKE}]

# ----------------------------------------------------------------------------
# T80: sus registros internos solo cambian con CEN_p / CEN_n, que en el 48/96K
# van cada 12 ciclos (separados 6) y en el 128K cada 8 (separados 4): las rutas
# de T80 a T80 tienen al menos 2 ciclos.
# ----------------------------------------------------------------------------
set t80 [get_keepers {emu|lynx48|cpu|Cpu|* emu|lynx128|cpu|Cpu|*}]
set_multicycle_path -from $t80 -to $t80 -setup 2
set_multicycle_path -from $t80 -to $t80 -hold 1
