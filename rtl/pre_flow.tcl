# Se ejecuta antes de cada compilacion (PRE_FLOW_SCRIPT_FILE en Lynx.qsf).
#
# Los dos cores de Kyp (submodulos rtl/lynx y rtl/lynx128) tienen modulos con
# el mismo nombre (lynx y video) pero distinto contenido, y Quartus no admite
# dos modulos con el mismo nombre. Para no tocar los submodulos, este script
# genera en rtl/gen una copia de lynx.v + video.v de cada uno con:
#   - los modulos renombrados: lynx48/video48 y lynx128/video128;
#   - una salida "de" (display enable del 6845) para el blanking de MiSTer.
# Si algun cambio de Kyp hace que un patron no aparezca, la compilacion se para
# con un error en vez de generar algo distinto.
#
# Despues sigue con el script normal del marco (sys/build_id.tcl).

proc patch {text from to what} {
	set n [regsub -all -- $from $text $to text]
	if {$n != 1} { error "pre_flow.tcl: '$what' aparece $n veces (se esperaba 1)" }
	return $text
}

proc gen {src name} {
	set f [open "rtl/$src/lynx.v" r];  set lynx  [read $f]; close $f
	set f [open "rtl/$src/video.v" r]; set video [read $f]; close $f

	set lynx  [patch $lynx  {module lynx\M}                "module $name"            "module lynx"]
	set lynx  [patch $lynx  {(output\s+wire\s+rfsh\s*,)}   "\\1\n\toutput wire       de,"  "rfsh"]
	set lynx  [patch $lynx  {(wire\s+crtcDe\s*;)}          "\\1\n\tassign de = crtcDe;"   "crtcDe"]
	set lynx  [patch $lynx  {\mvideo(\s+)video\M}          "video_$name\\1video"     "video video"]
	set video [patch $video {module video\M}               "module video_$name"      "module video"]

	file mkdir rtl/gen
	set out "// GENERADO por rtl/pre_flow.tcl a partir de rtl/$src (no editar)\n$lynx\n$video"
	set old ""
	if {[file exists rtl/gen/$name.v]} { set f [open rtl/gen/$name.v r]; set old [read $f]; close $f }
	if {$old ne $out} {
		set f [open rtl/gen/$name.v w]; puts -nonewline $f $out; close $f
		post_message "Generado rtl/gen/$name.v"
	}
}

gen lynx    lynx48
gen lynx128 lynx128

source sys/build_id.tcl
