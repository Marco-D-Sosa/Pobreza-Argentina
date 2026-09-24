cd ""


*************************************************************************************************************
************************************************* 2019-2020 *************************************************
*************************************************************************************************************


*Unimos las bases de 2019 y 2020 (2°Semestre)
use "arg19s2_base.dta", clear
append using "arg20s2_base.dta", force

* Renombro variables
rename ano4 año
rename ch04 sexo
rename ch06 edad

* verificamos que esten bien unidas
sum itf sexo edad pondih if año==2019
sum itf sexo edad pondih if año==2020

* creo un identificador de hogar
sort codusu nro_hogar año trimestre
egen id = group(codusu nro_hogar año trimestre)

*Construyo las lineas de pobreza:

* Linea de pobreza oficial moderada 2019
gen     lp_moderada2019 = 10758.623 	 if  region==1  & trimestre==3
replace lp_moderada2019 = 8691.627  	 if  region==40 & trimestre==3
replace lp_moderada2019 = 9003.213 		 if  region==41 & trimestre==3
replace lp_moderada2019 = 10179.853	 	 if  region==42 & trimestre==3
replace lp_moderada2019 = 10626.387    	 if  region==43 & trimestre==3
replace lp_moderada2019 = 12656.66  	 if  region==44 & trimestre==3
replace lp_moderada2019 = 12103.993  	 if  region==1  & trimestre==4
replace lp_moderada2019 = 9821.87  	 	 if  region==40 & trimestre==4
replace lp_moderada2019 = 10177.857  	 if  region==41 & trimestre==4
replace lp_moderada2019 = 11499.717  	 if  region==42 & trimestre==4
replace lp_moderada2019 = 11990.517    	 if  region==43 & trimestre==4
replace lp_moderada2019 = 14287.89  	 if  region==44 & trimestre==4
* Linea de pobreza oficial moderada 2020
gen     lp_moderada2020 = 14802.037  	if  region==1  & trimestre==3
replace lp_moderada2020 = 11955.91  	if  region==40 & trimestre==3
replace lp_moderada2020 = 12411.69 		if  region==41 & trimestre==3
replace lp_moderada2020 = 13939.213 	if  region==42 & trimestre==3
replace lp_moderada2020 = 14588.287  	if  region==43 & trimestre==3
replace lp_moderada2020 = 17387.157  	if  region==44 & trimestre==3
replace lp_moderada2020 = 16817.123  	if  region==1  & trimestre==4
replace lp_moderada2020 = 13557.75 	    if  region==40 & trimestre==4
replace lp_moderada2020 = 14100.19 		if  region==41 & trimestre==4
replace lp_moderada2020 = 15896.083 	if  region==42 & trimestre==4
replace lp_moderada2020 = 16698.967 	if  region==43 & trimestre==4
replace lp_moderada2020 = 19855.18   	if  region==44 & trimestre==4

* Escala de Adulto Equivalente
recode sexo (2=0)
replace edad = 0 if edad<0
gen ae=.
replace ae = 0.35 	if edad==0
replace ae = 0.37 	if edad==1
replace ae = 0.46 	if edad==2
replace ae = 0.51 	if edad==3
replace ae = 0.55 	if edad==4
replace ae = 0.60 	if edad==5
replace ae = 0.64 	if edad==6
replace ae = 0.66 	if edad==7
replace ae = 0.68 	if edad==8
replace ae = 0.69 	if edad==9
replace ae = 0.79 	if sexo==1 & edad==10 
replace ae = 0.82 	if sexo==1 & edad==11 
replace ae = 0.85 	if sexo==1 & edad==12 
replace ae = 0.90 	if sexo==1 & edad==13 
replace ae = 0.96 	if sexo==1 & edad==14 
replace ae = 1 		if sexo==1 & edad==15 
replace ae = 1.03 	if sexo==1 & edad==16 
replace ae = 1.04 	if sexo==1 & edad==17 
replace ae = 0.70 	if sexo==0 & edad==10 
replace ae = 0.72 	if sexo==0 & edad==11 
replace ae = 0.74 	if sexo==0 & edad==12 
replace ae = 0.76 	if sexo==0 & edad==13 
replace ae = 0.76 	if sexo==0 & edad==14 
replace ae = 0.77 	if sexo==0 & edad==15 
replace ae = 0.77 	if sexo==0 & edad==16 
replace ae = 0.77 	if sexo==0 & edad==17 
replace ae = 1.02 	if sexo==1 & edad>=18 & edad<=29
replace ae = 1 		if sexo==1 & edad>=30 & edad<=45
replace ae = 1 		if sexo==1 & edad>=46 & edad<=60
replace ae = 0.83 	if sexo==1 & edad>=61 & edad<=75
replace ae = 0.74 	if sexo==1 & edad>=76 & edad<110
replace ae = 0.76 	if sexo==0 & edad>=18 & edad<=29
replace ae = 0.77 	if sexo==0 & edad>=30 & edad<=45
replace ae = 0.76 	if sexo==0 & edad>=46 & edad<=60
replace ae = 0.67 	if sexo==0 & edad>=61 & edad<=75
replace ae = 0.63 	if sexo==0 & edad>=76 & edad<110

*Deflactamos los valores de 2020 para ser comparables
*Utilizamos el indice de precios implicito Z2/Z1
gen IPI = lp_moderada2020/lp_moderada2019
replace itf = itf/IPI if año==2020
replace lp_moderada2020 = lp_moderada2020/IPI
sum lp_moderada2020 lp_moderada2019
*Al deflactar, las lineas de pobreza para ambos años son la misma

*calculamos ingreso por adulto equivalente por hogar
egen aef=total(ae), by(id)
gen ing_eq= itf/aef
label var ing_eq "ingreso oficial por adulto equivalente"
label var lp_moderada2019 "Linea de pobreza moderada en 2019"
label var lp_moderada2020 "Linea de pobreza moderada en 2020"

*Comenzamos a calcular los indices de pobreza utilizando FGT 0, 1 y 2
run "fgt.do"
mat Mon = J(4,3,.)

* P(L1,µ1,z)
forvalues i = 0/2 {
fgt ing_eq [w=pondih] if año==2019, a(`i') z(lp_moderada2019)
mat Mon[1,`i'+1] = r(fgt)
}

* P(L2,µ2,z)
forvalues i = 0/2 {
fgt ing_eq [w=pondih] if año==2020, a(`i') z(lp_moderada2020)
mat Mon[4,`i'+1] = r(fgt)
}

* P(L1,µ2,z)
*Tomo la distribucion de 2019 y cambio la media de ingresos 
sum itf if año==2019
local µ1 = r(mean)
sum itf if año==2020
local µ2 = r(mean)
local aux = `µ2'/`µ1'
replace itf = itf*`aux' if año==2019
gen ing_eq2= itf/aef 
*Calculo la pobreza
forvalues i = 0/2 {
fgt ing_eq2 [w=pondih] if año==2019, a(`i') z(lp_moderada2019)
mat Mon[2,`i'+1] = r(fgt)
}

* P(L2,µ1,z)
*Tomo la distribucion de 2020 y cambio la media de ingresos
replace itf = itf/`aux' if año==2020
gen ing_eq3= itf/aef
*Calculo la pobreza
forvalues i = 0/2 {
fgt ing_eq3 [w=pondih] if año==2020, a(`i') z(lp_moderada2020)
mat Mon[3,`i'+1] = r(fgt)
}

*Pasamos los datos a Excel
preserve
   drop _all
   svmat Mon
   export excel using "Resultados Monografia.xlsx", sheetmodify sheet("sheet1") cell(F2)
restore

drop _all


*************************************************************************************************************
************************************************* 2020-2021 *************************************************
*************************************************************************************************************


*Unimos las bases de 2020 y 2021 (2°Semestre)
use "arg20s2_base.dta", clear
append using "arg21s2_base.dta", force

* Renombro variables
rename ano4 año
rename ch04 sexo
rename ch06 edad

* verificamos que esten bien unidas
sum itf sexo edad pondih if año==2020
sum itf sexo edad pondih if año==2021

* creo un identificador de hogar
sort codusu nro_hogar año trimestre
egen id = group(codusu nro_hogar año trimestre)

*Construyo las lineas de pobreza:

* Linea de pobreza oficial moderada 2020
gen     lp_moderada20 = 14802.040	if  region==1  & trimestre==3
replace lp_moderada20 = 11955.910	if  region==40 & trimestre==3 
replace lp_moderada20 = 12411.690	if  region==41 & trimestre==3
replace lp_moderada20 = 13939.213	if  region==42 & trimestre==3
replace lp_moderada20 = 14588.286	if  region==43 & trimestre==3
replace lp_moderada20 = 17387.156	if  region==44 & trimestre==3
replace lp_moderada20 = 16817.123	if  region==1  & trimestre==4
replace lp_moderada20 = 13557.083	if  region==40 & trimestre==4 
replace lp_moderada20 = 14100.190	if  region==41 & trimestre==4
replace lp_moderada20 = 15896.083	if  region==42 & trimestre==4
replace lp_moderada20 = 16698.966	if  region==43 & trimestre==4
replace lp_moderada20 = 19855.180	if  region==44 & trimestre==4
* Linea de pobreza oficial moderada 2021
gen     lp_moderada21 = 22272.723	if  region==1  & trimestre==3
replace lp_moderada21 = 17919.403	if  region==40 & trimestre==3 
replace lp_moderada21 = 18712.076	if  region==41 & trimestre==3
replace lp_moderada21 = 21002.890	if  region==42 & trimestre==3
replace lp_moderada21 = 21928.553	if  region==43 & trimestre==3
replace lp_moderada21 = 25934.756	if  region==44 & trimestre==3
replace lp_moderada21 = 23994.523	if  region==1  & trimestre==4
replace lp_moderada21 = 19375.193   if  region==40 & trimestre==4
replace lp_moderada21 = 20267.580	if  region==41 & trimestre==4
replace lp_moderada21 = 22792.286	if  region==42 & trimestre==4
replace lp_moderada21 = 23801.126	if  region==43 & trimestre==4
replace lp_moderada21 = 28152.253	if  region==44 & trimestre==4

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

*Deflactamos los valores de 2021 para ser comparables
*Utilizamos el indice de precios implicito Z2/Z1
gen IPI = lp_moderada21/lp_moderada20
replace itf = itf/IPI if año==2021
replace lp_moderada21 = lp_moderada21/IPI
sum lp_moderada21 lp_moderada20
*Al deflactar, las lineas de pobreza para ambos aÃ±os son la misma

*calculamos ingreso por adulto equivalente por hogar
egen aef=total(ae), by(id)
gen ing_eq= itf/aef
label var ing_eq "ingreso oficial por adulto equivalente"
label var lp_moderada20 "Linea de pobreza moderada en 2020"
label var lp_moderada21 "Linea de pobreza moderada en 2021"

*Comenzamos a calcular los indices de pobreza utilizando FGT 0, 1 y 2
run "fgt.do"
mat Mon = J(4,3,.)

* P(L1,aµ1,z)
forvalues i = 0/2 {
fgt ing_eq [w=pondih] if año==2020, a(`i') z(lp_moderada20)
mat Mon[1,`i'+1] = r(fgt)
}

* P(L2,aµ_2,z)
forvalues i = 0/2 {
fgt ing_eq [w=pondih] if año==2021, a(`i') z(lp_moderada21)
mat Mon[4,`i'+1] = r(fgt)
}

* P(L1,aµ_2,z)
*Tomo la distribucion de 2020 y cambio la media de ingresos 
sum itf if año==2020
local au_1 = r(mean)
sum itf if año==2021
local au_2 = r(mean)
local aux  = `au_1' / `au_2'
replace itf = itf * `aux' if año==2020
gen ing_eq2= itf/aef 
*Calculo la pobreza
forvalues i = 0/2 {
fgt ing_eq2 [w=pondih] if año==2020, a(`i') z(lp_moderada20)
mat Mon[2,`i'+1] = r(fgt)
}

* P(L2,aµ_1,z)
*Tomo la distribucion de 2021 y cambio la media de ingresos
replace itf = itf/`aux' if año==2021
gen ing_eq3= itf/aef
*Calculo la pobreza
forvalues i = 0/2 {
fgt ing_eq3 [w=pondih] if año==2021, a(`i') z(lp_moderada21)
mat Mon[3,`i'+1] = r(fgt)
}

*Pasamos los datos a Excel
preserve
   drop _all
   svmat Mon
   export excel using "Resultados Monografia.xlsx", sheetmodify sheet("sheet1") cell(J2)
restore

drop _all


*************************************************************************************************************
************************************************* 2021-2022 *************************************************
*************************************************************************************************************


*Unimos las bases de 2021 y 2022 (2°Semestre)
use "arg21s2_base.dta", clear
append using "arg22s2_base.dta", force

* Renombro variables
rename ano4 año
rename ch04 sexo
rename ch06 edad

* verificamos que esten bien unidas
sum itf sexo edad pondih if año==2021
sum itf sexo edad pondih if año==2022

* creo un identificador de hogar
sort codusu nro_hogar año trimestre
egen id = group(codusu nro_hogar año trimestre)

*Construyo las lineas de pobreza:

* Linea de pobreza oficial moderada 2021
gen     lp_moderada21 = 22272.723	if  region==1  & trimestre==3
replace lp_moderada21 = 17919.403	if  region==40 & trimestre==3
replace lp_moderada21 = 18712.403	if  region==41 & trimestre==3
replace lp_moderada21 = 21002.890	if  region==42 & trimestre==3
replace lp_moderada21 = 21928.553	if  region==43 & trimestre==3
replace lp_moderada21 = 25934.757	if  region==44 & trimestre==3
replace lp_moderada21 = 23994.523	if  region==1  & trimestre==4
replace lp_moderada21 = 19375.193	if  region==40 & trimestre==4
replace lp_moderada21 = 20267.580	if  region==41 & trimestre==4
replace lp_moderada21 = 22792.287	if  region==42 & trimestre==4
replace lp_moderada21 = 23801.127	if  region==43 & trimestre==4
replace lp_moderada21 = 28152.253	if  region==44 & trimestre==4
* Linea de pobreza oficial moderada 2022
gen     lp_moderada22 = 38756.053	if  region==1  & trimestre==3
replace lp_moderada22 = 31200.057	if  region==40 & trimestre==3
replace lp_moderada22 = 32623.527	if  region==41 & trimestre==3
replace lp_moderada22 = 36813.920	if  region==42 & trimestre==3
replace lp_moderada22 = 38293.470	if  region==43 & trimestre==3
replace lp_moderada22 = 45713.383	if  region==44 & trimestre==3
replace lp_moderada22 = 47270.863	if  region==1  & trimestre==4
replace lp_moderada22 = 37964.420	if  region==40 & trimestre==4
replace lp_moderada22 = 39625.137	if  region==41 & trimestre==4
replace lp_moderada22 = 44885.637	if  region==42 & trimestre==4
replace lp_moderada22 = 46720.947	if  region==43 & trimestre==4
replace lp_moderada22 = 55843.573	if  region==44 & trimestre==4

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

*Deflactamos los valores de 2022 para ser comparables
*Utilizamos el indice de precios implicito Z2/Z1
gen IPI = lp_moderada22/lp_moderada21
replace itf = itf/IPI if año==2022
replace lp_moderada22 = lp_moderada22/IPI
sum lp_moderada22 lp_moderada21
*Al deflactar, las lineas de pobreza para ambos años son la misma

*calculamos ingreso por adulto equivalente por hogar
egen aef=total(ae), by(id)
gen ing_eq= itf/aef
label var ing_eq "ingreso oficial por adulto equivalente"
label var lp_moderada21 "Linea de pobreza moderada en 2021"
label var lp_moderada22 "Linea de pobreza moderada en 2022"

*Comenzamos a calcular los indices de pobreza utilizando FGT 0, 1 y 2
run "fgt.do"
mat Mon = J(4,3,.)

* P(L1,µ1,z)
forvalues i = 0/2 {
fgt ing_eq [w=pondih] if año==2021, a(`i') z(lp_moderada21)
mat Mon[1,`i'+1] = r(fgt)
}

* P(L2,µ2,z)
forvalues i = 0/2 {
fgt ing_eq [w=pondih] if año==2022, a(`i') z(lp_moderada22)
mat Mon[4,`i'+1] = r(fgt)
}

* P(L1,µ2,z)
*Tomo la distribucion de 2021 y cambio la media de ingresos 
sum itf if año==2021
local µ1 = r(mean)
sum itf if año==2022
local µ2 = r(mean)
local aux = `µ2'/`µ1'
replace itf = itf*`aux' if año==2021
gen ing_eq2= itf/aef 
*Calculo la pobreza
forvalues i = 0/2 {
fgt ing_eq2 [w=pondih] if año==2021, a(`i') z(lp_moderada21)
mat Mon[2,`i'+1] = r(fgt)
}

* P(L2,µ1,z)
*Tomo la distribucion de 2022 y cambio la media de ingresos
replace itf = itf/`aux' if año==2022
gen ing_eq3= itf/aef
*Calculo la pobreza
forvalues i = 0/2 {
fgt ing_eq3 [w=pondih] if año==2022, a(`i') z(lp_moderada22)
mat Mon[3,`i'+1] = r(fgt)
}

*Pasamos los datos a Excel
preserve
   drop _all
   svmat Mon
   export excel using "Resultados Monografia.xlsx", sheetmodify sheet("sheet1") cell(N2)
restore

drop _all


*************************************************************************************************************
************************************************* 2022-2023 *************************************************
*************************************************************************************************************


*Unimos las bases de 2022 y 2023 (2°Semestre)
use "arg22s2_base.dta", clear
append using "arg23s2_base.dta", force

* Renombro variables
rename ano4 año
rename ch04 sexo
rename ch06 edad

* verificamos que esten bien unidas
sum itf sexo edad pondih if año==2022
sum itf sexo edad pondih if año==2023

* creo un identificador de hogar
sort codusu nro_hogar año trimestre
egen id = group(codusu nro_hogar año trimestre)

*Construyo las lineas de pobreza:

* Linea de pobreza oficial moderada 2022
gen     lp_moderada22 = 38756.053	if  region==1  & trimestre==3
replace lp_moderada22 = 31200.057	if  region==40 & trimestre==3
replace lp_moderada22 = 32623.527	if  region==41 & trimestre==3
replace lp_moderada22 = 36813.920	if  region==42 & trimestre==3
replace lp_moderada22 = 38293.470	if  region==43 & trimestre==3
replace lp_moderada22 = 45713.383	if  region==44 & trimestre==3
replace lp_moderada22 = 47270.863	if  region==1  & trimestre==4
replace lp_moderada22 = 37964.420	if  region==40 & trimestre==4
replace lp_moderada22 = 39625.137	if  region==41 & trimestre==4
replace lp_moderada22 = 44885.637	if  region==42 & trimestre==4
replace lp_moderada22 = 46720.947	if  region==43 & trimestre==4
replace lp_moderada22 = 55843.573	if  region==44 & trimestre==4
* Linea de pobreza oficial moderada 2023
gen     lp_moderada23 = 92024.923	if  region==1  & trimestre==3
replace lp_moderada23 = 74303.670	if  region==40 & trimestre==3
replace lp_moderada23 = 77564.397	if  region==41 & trimestre==3
replace lp_moderada23 = 88100.177	if  region==42 & trimestre==3
replace lp_moderada23 = 90869.837	if  region==43 & trimestre==3
replace lp_moderada23 = 108270.797	if  region==44 & trimestre==3
replace lp_moderada23 = 132853.300	if  region==1  & trimestre==4
replace lp_moderada23 = 107236.547	if  region==40 & trimestre==4
replace lp_moderada23 = 112238.093	if  region==41 & trimestre==4
replace lp_moderada23 = 126876.387	if  region==42 & trimestre==4
replace lp_moderada23 = 131138.857	if  region==43 & trimestre==4
replace lp_moderada23 = 155201.957	if  region==44 & trimestre==4

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

*Deflactamos los valores de 2023 para ser comparables
*Utilizamos el indice de precios implicito Z2/Z1
gen IPI = lp_moderada23/lp_moderada22
replace itf = itf/IPI if año==2023
replace lp_moderada23 = lp_moderada23/IPI
sum lp_moderada23 lp_moderada22
*Al deflactar, las lineas de pobreza para ambos años son la misma

*calculamos ingreso por adulto equivalente por hogar
egen aef=total(ae), by(id)
gen ing_eq= itf/aef
label var ing_eq "ingreso oficial por adulto equivalente"
label var lp_moderada22 "Linea de pobreza moderada en 2022"
label var lp_moderada23 "Linea de pobreza moderada en 2023"

*Comenzamos a calcular los indices de pobreza utilizando FGT 0, 1 y 2
run "fgt.do"
mat Mon = J(4,3,.)

* P(L1,µ1,z)
forvalues i = 0/2 {
fgt ing_eq [w=pondih] if año==2022, a(`i') z(lp_moderada22)
mat Mon[1,`i'+1] = r(fgt)
}

* P(L2,µ2,z)
forvalues i = 0/2 {
fgt ing_eq [w=pondih] if año==2023, a(`i') z(lp_moderada23)
mat Mon[4,`i'+1] = r(fgt)
}

* P(L1,µ2,z)
*Tomo la distribucion de 2022 y cambio la media de ingresos 
sum itf if año==2022
local µ1 = r(mean)
sum itf if año==2023
local µ2 = r(mean)
local aux = `µ2'/`µ1'
replace itf = itf*`aux' if año==2022
gen ing_eq2= itf/aef 
*Calculo la pobreza
forvalues i = 0/2 {
fgt ing_eq2 [w=pondih] if año==2022, a(`i') z(lp_moderada22)
mat Mon[2,`i'+1] = r(fgt)
}

* P(L2,µ1,z)
*Tomo la distribucion de 2023 y cambio la media de ingresos
replace itf = itf/`aux' if año==2023
gen ing_eq3= itf/aef
*Calculo la pobreza
forvalues i = 0/2 {
fgt ing_eq3 [w=pondih] if año==2023, a(`i') z(lp_moderada23)
mat Mon[3,`i'+1] = r(fgt)
}

*Pasamos los datos a Excel
preserve
   drop _all
   svmat Mon
   export excel using "Resultados Monografia.xlsx", sheetmodify sheet("sheet1") cell(R2)
restore

drop _all


*************************************************************************************************************
************************************************* 2019-2023 *************************************************
*************************************************************************************************************


*Unimos las bases de 2019 y 2023 (2°Semestre)
use "arg19s2_base.dta", clear
append using "arg23s2_base.dta", force

* Renombro variables
rename ano4 año
rename ch04 sexo
rename ch06 edad

* verificamos que esten bien unidas
sum itf sexo edad pondih if año==2019
sum itf sexo edad pondih if año==2023

* creo un identificador de hogar
sort codusu nro_hogar año trimestre
egen id = group(codusu nro_hogar año trimestre)

*Construyo las lineas de pobreza:

* Linea de pobreza oficial moderada 2019
gen     lp_moderada19 = 10758.623	if  region==1  & trimestre==3
replace lp_moderada19 = 8691.627	if  region==40 & trimestre==3
replace lp_moderada19 = 9003.213	if  region==41 & trimestre==3
replace lp_moderada19 = 10179.853	if  region==42 & trimestre==3
replace lp_moderada19 = 10626.387	if  region==43 & trimestre==3
replace lp_moderada19 = 12656.660	if  region==44 & trimestre==3
replace lp_moderada19 = 12103.993	if  region==1  & trimestre==4
replace lp_moderada19 = 9821.870	if  region==40 & trimestre==4
replace lp_moderada19 = 10177.857	if  region==41 & trimestre==4
replace lp_moderada19 = 11499.717	if  region==42 & trimestre==4
replace lp_moderada19 = 11990.517	if  region==43 & trimestre==4
replace lp_moderada19 = 14287.890	if  region==44 & trimestre==4
* Linea de pobreza oficial moderada 2023
gen     lp_moderada23 = 92024.923	if  region==1  & trimestre==3
replace lp_moderada23 = 74303.670	if  region==40 & trimestre==3
replace lp_moderada23 = 77564.397	if  region==41 & trimestre==3
replace lp_moderada23 = 88100.177	if  region==42 & trimestre==3
replace lp_moderada23 = 90869.837	if  region==43 & trimestre==3
replace lp_moderada23 = 108270.797	if  region==44 & trimestre==3
replace lp_moderada23 = 132853.300	if  region==1  & trimestre==4
replace lp_moderada23 = 107236.547	if  region==40 & trimestre==4
replace lp_moderada23 = 112238.093	if  region==41 & trimestre==4
replace lp_moderada23 = 126876.387	if  region==42 & trimestre==4
replace lp_moderada23 = 131138.857	if  region==43 & trimestre==4
replace lp_moderada23 = 155201.957	if  region==44 & trimestre==4

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

*Deflactamos los valores de 2023 para ser comparables
*Utilizamos el indice de precios implicito Z2/Z1
gen IPI = lp_moderada23/lp_moderada19
replace itf = itf/IPI if año==2023
replace lp_moderada23 = lp_moderada23/IPI
sum lp_moderada23 lp_moderada19
*Al deflactar, las lineas de pobreza para ambos años son la misma

*calculamos ingreso por adulto equivalente por hogar
egen aef=total(ae), by(id)
gen ing_eq= itf/aef
label var ing_eq "ingreso oficial por adulto equivalente"
label var lp_moderada19 "Linea de pobreza moderada en 2019"
label var lp_moderada23 "Linea de pobreza moderada en 2023"

*Comenzamos a calcular los indices de pobreza utilizando FGT 0, 1 y 2
run "fgt.do"
mat Mon = J(4,3,.)

* P(L1,µ1,z)
forvalues i = 0/2 {
fgt ing_eq [w=pondih] if año==2019, a(`i') z(lp_moderada19)
mat Mon[1,`i'+1] = r(fgt)
}

* P(L2,µ2,z)
forvalues i = 0/2 {
fgt ing_eq [w=pondih] if año==2023, a(`i') z(lp_moderada23)
mat Mon[4,`i'+1] = r(fgt)
}

* P(L1,µ2,z)
*Tomo la distribucion de 2019 y cambio la media de ingresos 
sum itf if año==2019
local µ1 = r(mean)
sum itf if año==2023
local µ2 = r(mean)
local aux = `µ2'/`µ1'
replace itf = itf*`aux' if año==2019
gen ing_eq2= itf/aef 
*Calculo la pobreza
forvalues i = 0/2 {
fgt ing_eq2 [w=pondih] if año==2019, a(`i') z(lp_moderada19)
mat Mon[2,`i'+1] = r(fgt)
}

* P(L2,µ1,z)
*Tomo la distribucion de 2023 y cambio la media de ingresos
replace itf = itf/`aux' if año==2023
gen ing_eq3= itf/aef
*Calculo la pobreza
forvalues i = 0/2 {
fgt ing_eq3 [w=pondih] if año==2023, a(`i') z(lp_moderada23)
mat Mon[3,`i'+1] = r(fgt)
}

*Pasamos los datos a Excel
preserve
   drop _all
   svmat Mon
   export excel using "Resultados Monografia.xlsx", sheetmodify sheet("sheet1") cell(B2)
restore

