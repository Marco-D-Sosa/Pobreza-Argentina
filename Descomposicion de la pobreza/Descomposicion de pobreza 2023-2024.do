cd ""


*************************************************************************************************************
************************************************* 2023-2024 *************************************************
*************************************************************************************************************

*Unimos las bases de 2019 y 2023 (2°Semestre)
use "EPH 2023 4°T ind.dta", clear
append using "EPH 2024 4°T ind.dta", force

* Renombro variables
rename ch04 sexo
rename ch06 edad
recode año (.=2024)

* verificamos que esten bien unidas
sum itf sexo edad pondih if año==2023
sum itf sexo edad pondih if año==2024

* creo un identificador de hogar
sort codusu nro_hogar año trimestre
egen id = group(codusu nro_hogar año trimestre)

*Construyo las lineas de pobreza:

* Linea de pobreza oficial moderada 2023
gen lp_moderada23 = .
replace lp_moderada23 = 132853.30	if  region==1  & trimestre==4
replace lp_moderada23 = 107236.55	if  region==40 & trimestre==4
replace lp_moderada23 = 112238.09	if  region==41 & trimestre==4
replace lp_moderada23 = 126876.39	if  region==42 & trimestre==4
replace lp_moderada23 = 131138.86	if  region==43 & trimestre==4
replace lp_moderada23 = 155201.96	if  region==44 & trimestre==4
* Linea de pobreza oficial moderada 2024
gen lp_moderada24 = .
replace lp_moderada24 = 324971.71  	if  region==1  & trimestre==4
replace lp_moderada24 = 261321.26   if  region==40 & trimestre==4
replace lp_moderada24 = 270200.17   if  region==41 & trimestre==4
replace lp_moderada24 = 307837.12   if  region==42 & trimestre==4
replace lp_moderada24 = 320848.08   if  region==43 & trimestre==4
replace lp_moderada24 = 379207.06   if  region==44 & trimestre==4

* Escala de Adulto Equivalente
recode sexo (2=0)
replace edad = 0 if edad<0
gen ae=.
replace ae = 0.35	if edad==0
replace ae = 0.37	if edad==1
replace ae = 0.46	if edad==2
replace ae = 0.51	if edad==3
replace ae = 0.55	if edad==4
replace ae = 0.60	if edad==5
replace ae = 0.64	if edad==6
replace ae = 0.66	if edad==7
replace ae = 0.68	if edad==8
replace ae = 0.69	if edad==9
replace ae = 0.79	if sexo==1 & edad==10 
replace ae = 0.82	if sexo==1 & edad==11 
replace ae = 0.85	if sexo==1 & edad==12 
replace ae = 0.90	if sexo==1 & edad==13 
replace ae = 0.96	if sexo==1 & edad==14 
replace ae = 1		if sexo==1 & edad==15 
replace ae = 1.03	if sexo==1 & edad==16 
replace ae = 1.04	if sexo==1 & edad==17 
replace ae = 0.70	if sexo==0 & edad==10 
replace ae = 0.72	if sexo==0 & edad==11 
replace ae = 0.74	if sexo==0 & edad==12 
replace ae = 0.76	if sexo==0 & edad==13 
replace ae = 0.76	if sexo==0 & edad==14 
replace ae = 0.77	if sexo==0 & edad==15 
replace ae = 0.77	if sexo==0 & edad==16 
replace ae = 0.77	if sexo==0 & edad==17 
replace ae = 1.02	if sexo==1 & edad>=18 & edad<=29
replace ae = 1		if sexo==1 & edad>=30 & edad<=45
replace ae = 1		if sexo==1 & edad>=46 & edad<=60
replace ae = 0.83	if sexo==1 & edad>=61 & edad<=75
replace ae = 0.74	if sexo==1 & edad>=76 & edad<110
replace ae = 0.76	if sexo==0 & edad>=18 & edad<=29
replace ae = 0.77	if sexo==0 & edad>=30 & edad<=45
replace ae = 0.76	if sexo==0 & edad>=46 & edad<=60
replace ae = 0.67	if sexo==0 & edad>=61 & edad<=75
replace ae = 0.63	if sexo==0 & edad>=76 & edad<110

*Deflactamos los valores de 2024 para ser comparables
*Utilizamos el indice de precios implicito Z2/Z1
gen IPI = lp_moderada24/lp_moderada23
replace itf = itf/IPI if año==2024
replace lp_moderada24 = lp_moderada24/IPI
sum lp_moderada24 lp_moderada23
*Al deflactar, las lineas de pobreza para ambos años son la misma

*calculamos ingreso por adulto equivalente por hogar
egen aef=total(ae), by(id)
gen ing_eq= itf/aef
label var ing_eq "ingreso oficial por adulto equivalente"
label var lp_moderada23 "Linea de pobreza moderada en 2023"
label var lp_moderada24 "Linea de pobreza moderada en 2024"

*Comenzamos a calcular los indices de pobreza utilizando FGT 0, 1 y 2
run "fgt.do"
mat Mon = J(4,3,.)

* P(L1,µ1,z)
forvalues i = 0/2 {
fgt ing_eq [w=pondih] if año==2023, a(`i') z(lp_moderada23)
mat Mon[1,`i'+1] = r(fgt)
}

* P(L2,µ2,z)
forvalues i = 0/2 {
fgt ing_eq [w=pondih] if año==2024, a(`i') z(lp_moderada24)
mat Mon[4,`i'+1] = r(fgt)
}

* P(L1,µ2,z)
*Tomo la distribucion de 2019 y cambio la media de ingresos 
sum itf if año==2023
local µ1 = r(mean)
sum itf if año==2024
local µ2 = r(mean)
local aux = `µ2'/`µ1'
replace itf = itf*`aux' if año==2023
gen ing_eq2= itf/aef 
*Calculo la pobreza
forvalues i = 0/2 {
fgt ing_eq2 [w=pondih] if año==2023, a(`i') z(lp_moderada23)
mat Mon[2,`i'+1] = r(fgt)
}

* P(L2,µ1,z)
*Tomo la distribucion de 2023 y cambio la media de ingresos
replace itf = itf/`aux' if año==2024
gen ing_eq3= itf/aef
*Calculo la pobreza
forvalues i = 0/2 {
fgt ing_eq3 [w=pondih] if año==2024, a(`i') z(lp_moderada23)
mat Mon[3,`i'+1] = r(fgt)
}

*Pasamos los datos a Excel
preserve
   drop _all
   svmat Mon
   export excel using "Descomposicion.xlsx", sheetmodify sheet("sheet1") cell(B2)
restore
