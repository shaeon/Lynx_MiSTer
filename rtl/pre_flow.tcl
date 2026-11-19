# Se ejecuta antes de cada compilacion (PRE_FLOW_SCRIPT_FILE en Lynx.qsf).
#
# Genera en rtl/gen, a partir de los cores de Kyp (submodulos rtl/lynx y rtl/lynx128,
# que no se tocan):
#   - lynx48.v y lynx128.v: lynx.v + video.v de cada core, con las correcciones de
#     rtl/kyp_fixes.tcl y los modulos renombrados (lynx48/video_lynx48 y
#     lynx128/video_lynx128), porque los dos repos tienen modulos lynx y video
#     distintos con el mismo nombre y Quartus no lo admite;
#   - matrix.v: el teclado de rtl/lynx (igual en los dos), con sus correcciones.
#
# Las correcciones (tools/kyp_fixes.py) son las de los PR a Kyp: si ya estan en el
# submodulo no se hace nada, y si el texto original no aparece la compilacion se para
# con un error en vez de generar algo distinto.
#
# Despues sigue con el script normal del marco (sys/build_id.tcl).

source rtl/kyp_fixes.tcl

proc readf {path} { set f [open $path r]; set t [read $f]; close $f; return $t }

proc count {text sub} {
	set n 0; set i 0
	while {[set j [string first $sub $text $i]] >= 0} { incr n; set i [expr {$j + 1}] }
	return $n
}

proc fixes {text repo fname} {
	global kyp_fixes
	foreach fix $kyp_fixes {
		lassign $fix r f group pairs
		if {$r ne $repo || $f ne $fname} continue
		foreach {old new} $pairs {
			if {[string first $new $text] >= 0} continue
			set n [count $text $old]
			if {$n != 1} { error "pre_flow.tcl: $repo/$fname ($group): el texto a corregir aparece $n veces" }
			set i [string first $old $text]
			set text [string replace $text $i [expr {$i + [string length $old] - 1}] $new]
		}
	}
	return $text
}

proc renmod {text from to what} {
	set n [regsub -all -- $from $text $to text]
	if {$n != 1} { error "pre_flow.tcl: '$what' aparece $n veces (se esperaba 1)" }
	return $text
}

proc writegen {name text} {
	file mkdir rtl/gen
	set out "// GENERADO por rtl/pre_flow.tcl (no editar)\n$text"
	set old ""
	if {[file exists rtl/gen/$name]} { set old [readf rtl/gen/$name] }
	if {$old ne $out} {
		set f [open rtl/gen/$name w]; puts -nonewline $f $out; close $f
		post_message "Generado rtl/gen/$name"
	}
}

proc gen {src name} {
	set lynx  [fixes [readf rtl/$src/lynx.v]  $src lynx.v]
	set video [fixes [readf rtl/$src/video.v] $src video.v]
	set lynx  [renmod $lynx  {module lynx\M}       "module $name"         "module lynx"]
	set lynx  [renmod $lynx  {\mvideo(\s+)video\M} "video_$name\\1video"  "video video"]
	set video [renmod $video {module video\M}      "module video_$name"   "module video"]
	writegen $name.v "$lynx\n$video"
}

gen lynx    lynx48
gen lynx128 lynx128
writegen matrix.v [fixes [readf rtl/lynx/matrix.v] lynx matrix.v]

source sys/build_id.tcl
