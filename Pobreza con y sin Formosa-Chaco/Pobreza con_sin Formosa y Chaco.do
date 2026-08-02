cd "C:\Users\HP\Documents\Stata\Bases_Datos"
use "EPH 2024 2°S ind", clear


* creo un identificador de hogar
sort codusu nro_hogar año trimestre
egen id = group(codusu nro_hogar año trimestre)

*Construyo las lineas de pobreza:
gen lp_moderada = .
replace lp_moderada = 302605.62  	 if  region==1  & trimestre==3
replace lp_moderada = 244736  		 if  region==40 & trimestre==3
replace lp_moderada = 252282.70 	 if  region==41 & trimestre==3
replace lp_moderada = 286923.38	 	 if  region==42 & trimestre==3
replace lp_moderada = 299050.19    	 if  region==43 & trimestre==3
replace lp_moderada = 353498.33  	 if  region==44 & trimestre==3
replace lp_moderada = 324971.71  	 if  region==1  & trimestre==4
replace lp_moderada = 261321.26  	 if  region==40 & trimestre==4
replace lp_moderada = 270200.17  	 if  region==41 & trimestre==4
replace lp_moderada = 307837.12  	 if  region==42 & trimestre==4
replace lp_moderada = 320848.08    	 if  region==43 & trimestre==4
replace lp_moderada = 379207.06  	 if  region==44 & trimestre==4

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

*calculamos ingreso por adulto equivalente por hogar
egen aef=total(ae), by(id)
gen ing_eq= itf/aef
label var ing_eq "ingreso oficial por adulto equivalente"
label var lp_moderada "Linea de pobreza moderada"

*Comenzamos a calcular los indices de pobreza utilizando FGT 0 y 1
run "fgt.do"
mat Insfran = J(2,2,.)

* Pobreza normal
forvalues i = 0/1 {
fgt ing_eq [w=pondih], a(`i') z(lp_moderada)
mat Insfran[1,`i'+1] = r(fgt)
}

*Pobreza sin Formosa/Chaco
forvalues i = 0/1 {
fgt ing_eq [w=pondih] if aglomerado!=15 & aglomerado!=8, a(`i') z(lp_moderada)
mat Insfran[2,`i'+1] = r(fgt)
}

mat list Insfran