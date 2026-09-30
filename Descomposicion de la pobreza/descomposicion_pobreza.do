* ==========================================================================
* Descomposicion del cambio en la pobreza (2do semestre) en:
*   - efecto ingreso       : la distribucion se desplaza (cambia la media real)
*   - efecto distribucion  : cambia la forma de la distribucion (concentracion / desconcentracion)
* Metodo: Shapley (Datt-Ravallion). Indices FGT(0), FGT(1), FGT(2).
*
*   P(L1,mu1) = pobreza del periodo 1
*   P(L1,mu2) = distribucion del periodo 1 con la media del periodo 2
*   P(L2,mu1) = distribucion del periodo 2 con la media del periodo 1
*   P(L2,mu2) = pobreza del periodo 2
*   Efecto ingreso      = 0.5 * [ P(L1,mu2) - P(L1,mu1) + P(L2,mu2) - P(L2,mu1) ]
*   Efecto distribucion = 0.5 * [ P(L2,mu1) - P(L1,mu1) + P(L2,mu2) - P(L1,mu2) ]
*   Total               = Efecto ingreso + Efecto distribucion = P(L2,mu2) - P(L1,mu1)
*
* Requisitos:
*   1) eph.db generada con eph_sql.py (python eph_sql.py cargar)
*   2) python extraer_dta_descomp.py  -> crea descomposicion.dta
*
* Salidas (en la carpeta del proyecto):
*   resultados_descomposicion.xlsx   -> hojas "Anual" y "Gobiernos"
*   carpeta graficos (archivos png)  -> un grafico por cada una
*
* Series:
*   Anual     : cada 2do semestre vs el del anio siguiente (2017-2018, 2018-2019, ...)
*   Gobiernos : ultimo 2do semestre de un gobierno vs el del siguiente (cambio acumulado)
* ==========================================================================
clear all
set more off

* Carpeta de este proyecto
local proy "" 	/// <--- Poner la ruta a la carpeta

cd "`proy'"
capture mkdir "graficos"

* Indice FGT que se grafica: 0=Incidencia, 1=Brecha, 2=Severidad
local fgt 0

* --------------------------------------------------------------------------
* Programa 1: FGT(0), FGT(1), FGT(2) en %, ponderados por pondih, para un anio.
*   y = variable de ingreso por adulto equivalente, z = linea de pobreza (variable)
* --------------------------------------------------------------------------
capture program drop calc_fgt
program define calc_fgt, rclass
    args y z anio
    tempvar pobre brecha
    quietly gen `pobre'  = 100 * (`y' < `z')          if ano4 == `anio' & !missing(`y', `z')
    quietly gen `brecha' = max(0, (`z' - `y') / `z')  if ano4 == `anio' & !missing(`y', `z')
    quietly summarize `pobre' [aw = pondih]
    local f0 = r(mean)
    quietly summarize `brecha' [aw = pondih]
    local f1 = 100 * r(mean)
    quietly replace `brecha' = `brecha'^2
    quietly summarize `brecha' [aw = pondih]
    local f2 = 100 * r(mean)
    return scalar f0 = `f0'
    return scalar f1 = `f1'
    return scalar f2 = `f2'
end

* --------------------------------------------------------------------------
* Programa 2: los 4 escenarios para un par de anios (y1 -> y2) y su posteo
* --------------------------------------------------------------------------
capture program drop desc_par
program define desc_par
    args h y1 y2 idx
    preserve
        quietly keep if inlist(ano4, `y1', `y2')

        * Linea de pobreza del anio 1 para el mismo trimestre y region
        quietly gen lp1 = lp_moderada if ano4 == `y1'
        quietly egen lp_base = max(lp1), by(trimestre region)

        * Deflactacion: el itf del anio 2 se lleva a precios del anio 1 con el indice
        * implicito (razon de lineas de pobreza). Para el anio 1 el indice es 1.
        quietly gen itf_r   = itf / (lp_moderada / lp_base)
        quietly gen ing_eq  = itf_r / aef

        * Medias del ingreso por adulto equivalente (a precios del anio 1), ponderadas por pondih
        quietly summarize ing_eq [aw = pondih] if ano4 == `y1'
        local mu1 = r(mean)
        quietly summarize ing_eq [aw = pondih] if ano4 == `y2'
        local mu2 = r(mean)
        local aux = `mu2' / `mu1'

        quietly gen ing_eq_a = ing_eq * `aux'     // distribucion 1 con la media 2
        quietly gen ing_eq_b = ing_eq / `aux'     // distribucion 2 con la media 1

        calc_fgt ing_eq   lp_base `y1'            // P(L1,mu1)
        local f0_11 = r(f0)
        local f1_11 = r(f1)
        local f2_11 = r(f2)
        calc_fgt ing_eq_a lp_base `y1'            // P(L1,mu2)
        local f0_12 = r(f0)
        local f1_12 = r(f1)
        local f2_12 = r(f2)
        calc_fgt ing_eq_b lp_base `y2'            // P(L2,mu1)
        local f0_21 = r(f0)
        local f1_21 = r(f1)
        local f2_21 = r(f2)
        calc_fgt ing_eq   lp_base `y2'            // P(L2,mu2)
        local f0_22 = r(f0)
        local f1_22 = r(f1)
        local f2_22 = r(f2)

        post `h' (`idx') (`y1') (`y2') ///
            (`f0_11') (`f0_12') (`f0_21') (`f0_22') ///
            (`f1_11') (`f1_12') (`f1_21') (`f1_22') ///
            (`f2_11') (`f2_12') (`f2_21') (`f2_22')
    restore
end

* --------------------------------------------------------------------------
* Programa 3: serie de descomposiciones -> tabla, Excel y grafico
*   pares   = lista "y1 y2 y1 y2 ..." (cada par de anios es un periodo a descomponer)
*   nombres = etiquetas opcionales, una por par y de una sola palabra (ej. nombres de gobierno)
* --------------------------------------------------------------------------
capture program drop serie_desc
program define serie_desc
    args nombre opcion fgt pares nombres
    tempname h
    tempfile res

    local vars ""
    foreach a in 0 1 2 {
        foreach s in 11 12 21 22 {
            local vars `vars' double f`a'_`s'
        }
    }
    postfile `h' double idx double y1 double y2 `vars' using `res', replace

    local npares : word count `pares'
    local npares = `npares' / 2
    forvalues i = 1/`npares' {
        local y1 : word `=2 * `i' - 1' of `pares'
        local y2 : word `=2 * `i'' of `pares'
        quietly count if ano4 == `y1'
        local n1 = r(N)
        quietly count if ano4 == `y2'
        local n2 = r(N)
        if `n1' == 0 | `n2' == 0 {
            display as error "Sin datos para `y1' o `y2': se omite ese periodo."
            continue
        }
        display as text "Descomponiendo `y1' -> `y2' ..."
        desc_par `h' `y1' `y2' `i'
    }
    postclose `h'

    preserve
        use `res', clear
        gen str40 periodo = string(y1) + "-" + string(y2)
        if "`nombres'" != "" {
            forvalues j = 1/`npares' {
                local nm : word `j' of `nombres'
                quietly replace periodo = "`nm' " + string(y1) + "-" + string(y2) if idx == `j'
            }
        }
        rename idx orden      // orden de los pares (para ordenar el eje del grafico)
        foreach a in 0 1 2 {
            gen ef_ing_`a'  = 0.5 * ((f`a'_12 - f`a'_11) + (f`a'_22 - f`a'_21))
            gen ef_dist_`a' = 0.5 * ((f`a'_21 - f`a'_11) + (f`a'_22 - f`a'_12))
            gen total_`a'   = ef_ing_`a' + ef_dist_`a'
            label var ef_ing_`a'  "Efecto ingreso FGT(`a')"
            label var ef_dist_`a' "Efecto distribucion FGT(`a')"
            label var total_`a'   "Total FGT(`a')"
        }
        order periodo y1 y2 f0_* ef_ing_0 ef_dist_0 total_0 f1_* ef_ing_1 ef_dist_1 total_1 ///
              f2_* ef_ing_2 ef_dist_2 total_2
        format f?_* ef_* total_* %7.2f

        display as result _newline "Descomposicion FGT(0), cambio en p.p. - `nombre'"
        list periodo f0_11 f0_22 ef_ing_0 ef_dist_0 total_0, sep(0) noobs

        * Grafico: titulo en dos lineas, eje y horizontal, mas separacion entre periodos,
        * y periodos en el orden en que se definieron (sort(orden)), no alfabetico
        graph bar ef_ing_`fgt' ef_dist_`fgt' total_`fgt', ///
            over(periodo, sort(orden) gap(150) label(angle(45) labsize(small))) ///
            bargap(5) ///
            blabel(bar, format(%3.1f) size(vsmall)) yline(0, lcolor(black)) ///
            ylabel(, angle(horizontal) labsize(small)) ///
            ytitle("Puntos porcentuales", size(small) margin(small)) ///
            legend(order(1 "Efecto ingreso" 2 "Efecto distribucion" 3 "Total") rows(1) size(small)) ///
            title("Cambio en la tasa de pobreza y sus efectos", size(medsmall)) ///
            subtitle("2do semestre - `nombre'", size(small))
        graph export "graficos/descomposicion_`nombre'.png", width(1600) replace

        drop orden
        export excel using "resultados_descomposicion.xlsx", sheet("`nombre'") ///
            firstrow(variables) `opcion'
    restore
end

* --------------------------------------------------------------------------
* Programa 4: serie de tiempo de la tasa de pobreza y dos contrafactuales.
*   Cada anio t se compara contra un anio base (ingresos a precios del anio base):
*   - Oficial                : P(L_t, mu_t)    pobreza observada
*   - Sin efecto ingreso     : P(L_t, mu_base) distribucion del anio t, media del anio base fija
*   - Sin efecto desigualdad : P(L_base, mu_t) distribucion del anio base fija, media del anio t
*   (reusa desc_par: son los escenarios f_21 y f_12 de cada par base -> t)
* --------------------------------------------------------------------------
capture program drop serie_tiempo
program define serie_tiempo
    args base fgt opcion
    tempname h
    tempfile res

    local vars ""
    foreach a in 0 1 2 {
        foreach s in 11 12 21 22 {
            local vars `vars' double f`a'_`s'
        }
    }
    postfile `h' double idx double y1 double y2 `vars' using `res', replace

    quietly count if ano4 == `base'
    if r(N) == 0 {
        display as error "Sin datos para el anio base `base'."
        postclose `h'
        exit 111
    }
    quietly summarize ano4
    local a1 = r(max)
    local i = 0
    forvalues t = `base'/`a1' {
        quietly count if ano4 == `t'
        if r(N) > 0 {
            local ++i
            display as text "Serie de tiempo: `base' -> `t' ..."
            desc_par `h' `base' `t' `i'
        }
    }
    postclose `h'

    preserve
        use `res', clear
        gen anio    = y2
        gen oficial = f`fgt'_22
        gen sin_ing = f`fgt'_21
        gen sin_des = f`fgt'_12
        label var oficial "Oficial"
        label var sin_ing "Sin efecto ingreso (media de `base' constante)"
        label var sin_des "Sin efecto desigualdad (distribucion de `base' constante)"
        format oficial sin_ing sin_des %7.2f

        display as result _newline "Serie de tiempo FGT(`fgt'), base `base'"
        list anio oficial sin_ing sin_des, sep(0) noobs

        twoway (line oficial anio, lcolor("27 70 110") lwidth(thick) lpattern(solid)) ///
               (line sin_ing anio, lcolor("143 53 62") lwidth(medthick) lpattern(dash)) ///
               (line sin_des anio, lcolor("85 119 46") lwidth(medthick) lpattern(shortdash)), ///
            xlabel(`base'(1)`a1', labsize(small)) xtitle("") ///
            ylabel(, angle(horizontal) labsize(small)) ///
            ytitle("Tasa de pobreza FGT(`fgt'), %", size(small) margin(small)) ///
            legend(order(1 "Oficial" ///
                         2 "Sin efecto ingreso (media de `base' constante)" ///
                         3 "Sin efecto desigualdad (distribucion de `base' constante)") ///
                   rows(3) size(small)) ///
            title("Tasa de pobreza oficial y contrafactuales", size(medsmall)) ///
            subtitle("2do semestre, base `base'", size(small))
        graph export "graficos/serie_tiempo_pobreza.png", width(1600) replace

        keep anio oficial sin_ing sin_des
        export excel using "resultados_descomposicion.xlsx", sheet("SerieTiempo") ///
            firstrow(varlabels) `opcion'
    restore
end

* --------------------------------------------------------------------------
* Datos y corrida
* --------------------------------------------------------------------------
use "descomposicion.dta", clear
quietly keep if !missing(itf, aef, pondih, lp_moderada)

* Serie anual: todos los pares de 2dos semestres consecutivos
quietly summarize ano4
local a0  = r(min)
local a1  = r(max)
local fin = `a1' - 1
local pares_anual ""
forvalues y = `a0'/`fin' {
    local pares_anual `pares_anual' `y' `=`y' + 1'
}

* Serie por gobierno: ultimo 2do semestre de cada gobierno vs el del anterior.
*   Macri   : primer 2do semestre con datos (2017, las canastas arrancan en 2017) vs su ultimo (2019)
*   Alberto : 2019 (fin de Macri) vs 2023 (fin de Alberto)
*   Milei   : 2023 (fin de Alberto) vs 2025 (ultimo dato disponible)
local pares_gob   2017 2019  2019 2023  2023 2025
local nombres_gob Macri Alberto Milei

serie_desc Anual     replace      `fgt' "`pares_anual'" ""
serie_desc Gobiernos sheetreplace `fgt' "`pares_gob'"   "`nombres_gob'"

* Serie de tiempo: oficial vs sin efecto ingreso vs sin efecto desigualdad (anio base editable)
local base_ts 2017
serie_tiempo `base_ts' `fgt' sheetreplace

display as result "Listo. Resultados en resultados_descomposicion.xlsx (hojas Anual, Gobiernos, SerieTiempo) y graficos/"
