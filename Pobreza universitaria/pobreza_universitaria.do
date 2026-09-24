* ==========================================================================
* Pobreza en estudiantes universitarios (publico vs privado), todos los semestres
*
* Requisitos:
*   1) eph.db generada con eph_sql.py (python eph_sql.py cargar)
*   2) python extraer_universitarios.py   -> crea universitarios.dta (chico)
* ==========================================================================
set more off

* Carpeta de este proyecto (ahi estan universitarios.dta y se guardan resultados)
local proy "C:\Users\HP\Downloads\Pobreza en Argentina\Pobreza en grupos reducidos"
cd "`proy'"

use "universitarios.dta", clear

* pobre e indigente ya vienen calculados en la base (0 o 100), con la linea
* de pobreza de cada region y trimestre. Por eso ya no hace falta fgt ... z().
* La media ponderada de "pobre" equivale a fgt ..., a(0) (incidencia).

gen gestion = ch11
label define lg 1 "Publica" 2 "Privada"
label values gestion lg
keep if inlist(gestion, 1, 2)

* --- 1) Pobreza e indigencia por semestre: total, publica y privada --------
preserve
    bysort period: gen n_total = _N
    collapse (mean) pobre indigente n_total [pw=pondih], by(period)
    rename (pobre indigente) (pobre_univ indig_univ)
    tempfile total
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
restore

* --- 2) Universitarios que trabajan (% ocupados) ----------------------------
gen UyT = 100 * (estado == 1)
preserve
    collapse (mean) UyT [pw=pondera], by(period)
    format UyT %5.1f
    list, sep(0) noobs
restore

* --- 3) Distribucion del ingreso (un semestre a elegir) ---------------------
local sem "2025-2"
twoway (kdensity ing_eq [w=pondih] if period=="`sem'" & gestion==1) ///
       (kdensity ing_eq [w=pondih] if period=="`sem'" & gestion==2), ///
       legend(order(1 "Publica" 2 "Privada")) title("Ingreso equivalente, `sem'")

* podando ingresos extremos
twoway (kdensity ing_eq [w=pondih] if period=="`sem'" & gestion==1 & ing_eq<1000000) ///
       (kdensity ing_eq [w=pondih] if period=="`sem'" & gestion==2 & ing_eq<1000000), ///
       legend(order(1 "Publica" 2 "Privada")) title("Ingreso equivalente (< 1.000.000), `sem'")
