# Restricciones propias del core (las generales estan en sys/sys_top.sdc).
#
# Todo va con clk_sys (48 MHz) y la memoria esta en la FPGA, asi que no hace falta nada mas.
# Sin multiciclos en el T80: con la carga rapida de cinta (turbo) sus habilitaciones van cada
# 2-3 ciclos (48K/96K) o en todos (128K).
