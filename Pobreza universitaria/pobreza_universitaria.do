* ==========================================================================
* Pobreza en estudiantes universitarios (publico vs privado), todos los semestres
* + estudiantes que trabajan (publico vs privado), todos los semestres
* + distribucion de los estudiantes por decil / quintil de ingreso
*
* Requisitos:
*   1) eph.db generada con eph_sql.py (python eph_sql.py cargar)
*   2) python extraer_dta_uni.py  -> crea universitarios.dta y poblacion_deciles.dta
*
* Salidas (en la carpeta del proyecto):
*   resultados_universitarios.xlsx   -> una hoja por tabla
*   resultados_universitarios.dta    -> tabla principal de pobreza
*   graficos*.png                   -> todos los graficos
* ==========================================================================
clear all
set more off

* Carpeta de este proyecto
local proy "" 	/// <--- Poner la ruta de la carpeta

cd "`proy'"
capture mkdir "graficos"

* Semestre para los graficos de un solo periodo (formato "AAAA-S")
local sem "2025-2"

* Archivos temporales
tempfile total trab_total dec_long qui_long gini_pob

use "universitarios.dta", clear
gen gestion = ch11
label define lg 1 "Publica" 2 "Privada"
label values gestion lg
keep if inlist(gestion, 1, 2)

* --- 1) Pobreza e indigencia por semestre: total, publica y privada --------
preserve
    bysort period: gen n_total = _N
    collapse (mean) pobre indigente n_total [pw=pondih], by(period)
    rename (pobre indigente) (pobre_univ indig_univ)
    save `total'
restore

preserve
    bysort period gestion: gen n = _N
    collapse (mean) pobre indigente n [pw=pondih], by(period gestion)
    reshape wide pobre indigente n, i(period) j(gestion)
    rename (pobre1 pobre2 indigente1 indigente2 n1 n2) ///
           (pobre_pub pobre_priv indig_pub indig_priv n_pub n_priv)
    merge 1:1 period using `total', nogen
    order period pobre_univ pobre_pub pobre_priv indig_univ indig_pub indig_priv n_total n_pub n_priv
    format pobre_* indig_* %5.1f
    list, sep(0) noobs
    save "resultados_universitarios.dta", replace
    export excel using "resultados_universitarios.xlsx", sheet("Pobreza") firstrow(variables) replace

    * grafico: evolucion de la pobreza, publica vs privada
    encode period, gen(pn)
    local N = _N
    twoway (connected pobre_pub pn) (connected pobre_priv pn) ///
           (connected pobre_univ pn, lpattern(dash)), ///
        xlabel(1(1)`N', valuelabel angle(45) labsize(small)) xtitle("") ///
        ytitle("% de estudiantes pobres") ///
        legend(order(1 "Publica" 2 "Privada" 3 "Total")) ///
        title("Pobreza en estudiantes universitarios, por semestre")
    graph export "graficos/pobreza_pub_priv.png", width(1600) replace
restore

* --- 2) Universitarios que trabajan (% ocupados): total, publica y privada ---
gen UyT = 100 * (estado == 1)

preserve
    collapse (mean) UyT [pw=pondera], by(period)
    rename UyT UyT_univ
    save `trab_total'
restore

preserve
    collapse (mean) UyT [pw=pondera], by(period gestion)
    reshape wide UyT, i(period) j(gestion)
    rename (UyT1 UyT2) (UyT_pub UyT_priv)
    merge 1:1 period using `trab_total', nogen
    order period UyT_univ UyT_pub UyT_priv
    format UyT_* %5.1f
    list, sep(0) noobs
    export excel using "resultados_universitarios.xlsx", sheet("Trabajan") sheetreplace firstrow(variables)

    * grafico: evolucion del % que trabaja, publica vs privada
    encode period, gen(pn)
    local N = _N
    twoway (connected UyT_pub pn) (connected UyT_priv pn) ///
           (connected UyT_univ pn, lpattern(dash)), ///
        xlabel(1(1)`N', valuelabel angle(45) labsize(small)) xtitle("") ///
        ytitle("% de estudiantes que trabajan") ///
        legend(order(1 "Publica" 2 "Privada" 3 "Total")) ///
        title("Estudiantes universitarios que trabajan, por semestre")
    graph export "graficos/trabajan_pub_priv.png", width(1600) replace
restore

* --- 3) Distribucion de los estudiantes por decil y quintil de ingreso ------
* "decil" viene de extraer_dta_uni.py: decil del ingreso per capita familiar (IPCF)
* de TODA la poblacion EPH, calculado trimestre por trimestre (0 = hogar sin ingresos).
quietly count
local ntot = r(N)
quietly count if !inrange(decil, 1, 10)
display as text "Estudiantes sin decil valido (hogar sin ingresos o IPCF faltante): " ///
    r(N) " de `ntot'"

* 3a) % de estudiantes en cada decil (ponderado por pondih)
preserve
    keep if inrange(decil, 1, 10)
    gen w = pondih
    collapse (sum) w, by(period decil)
    bysort period: egen tot = total(w)
    gen pct = 100 * w / tot
    keep period decil pct
    save `dec_long'
restore

* 3b) idem por quintil (quintil = decil 1-2, 3-4, ...)
preserve
    keep if inrange(decil, 1, 10)
    gen quintil = ceil(decil / 2)
    gen w = pondih
    collapse (sum) w, by(period quintil)
    bysort period: egen tot = total(w)
    gen pct = 100 * w / tot
    keep period quintil pct
    save `qui_long'
restore

* tablas anchas (una fila por semestre) -> hojas del Excel
preserve
    use `dec_long', clear
    reshape wide pct, i(period) j(decil)
    format pct* %5.1f
    list, sep(0) noobs
    export excel using "resultados_universitarios.xlsx", sheet("Decil") sheetreplace firstrow(variables)
restore

preserve
    use `qui_long', clear
    reshape wide pct, i(period) j(quintil)
    format pct* %5.1f
    list, sep(0) noobs
    export excel using "resultados_universitarios.xlsx", sheet("Quintil") sheetreplace firstrow(variables)
restore


* --- 4) Graficos de un solo semestre --------------------
* 4a) quintil: barras y torta
preserve
    use `qui_long', clear
    keep if period == "`sem'"
    graph bar pct, over(quintil) blabel(bar, format(%4.1f)) ///
        ytitle("% de estudiantes") b1title("Quintil de IPCF") ///
        title("Estudiantes universitarios por quintil, `sem'")
    graph export "graficos/quintil_barras_`sem'.png", width(1600) replace

    graph pie pct, over(quintil) plabel(_all percent, format(%3.1f)) ///
        title("Estudiantes universitarios por quintil, `sem'")
    graph export "graficos/quintil_torta_`sem'.png", width(1600) replace
restore

* 4b) distribucion del ingreso equivalente, publica vs privada
twoway (kdensity ing_eq [aw=pondih] if period=="`sem'" & gestion==1) ///
       (kdensity ing_eq [aw=pondih] if period=="`sem'" & gestion==2), ///
       legend(order(1 "Publica" 2 "Privada")) title("Ingreso equivalente, `sem'")
graph export "graficos/kdensity_`sem'.png", width(1600) replace

* podando ingresos extremos
twoway (kdensity ing_eq [aw=pondih] if period=="`sem'" & gestion==1 & ing_eq<2000000) ///
       (kdensity ing_eq [aw=pondih] if period=="`sem'" & gestion==2 & ing_eq<2000000), ///
       legend(order(1 "Publica" 2 "Privada")) title("Ingreso equivalente (< 2.000.000), `sem'")
graph export "graficos/kdensity_podado_`sem'.png", width(1600) replace

display as result "Listo. Resultados en resultados_universitarios.xlsx y graficos/"
