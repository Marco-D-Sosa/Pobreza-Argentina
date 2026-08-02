* Abrimos los archivos
cd "C:\Users\HP\Documents\Base datos"
use "EPH 1°T 2024 ind", clear
run "fgt.do"
* Renombro variables
rename ano4 año
rename ch04 sexo
rename ch06 edad
* Creo un identificador de hogar
sort codusu nro_hogar año trimestre
egen id = group(codusu nro_hogar año trimestre)
* Construyo las lineas de pobreza oficiales moderada 2024
gen     lp_moderada24 = 222341.95	if  region==1
replace lp_moderada24 = 176818.51	if  region==40
replace lp_moderada24 = 185468.55	if  region==41
replace lp_moderada24 = 138488.39	if  region==42
replace lp_moderada24 = 218701.44	if  region==43
replace lp_moderada24 = 258084.29	if  region==44
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
* calculamos ingreso por adulto equivalente por hogar
egen aef=total(ae), by(id)
gen ing_eq= itf/aef
label var ing_eq "ingreso oficial por adulto equivalente"
label var lp_moderada24 "Linea de pobreza moderada en 2024"


*Pobreza estudiante universitario
fgt ing_eq [w=pondih] if ch10==1 & ch12==7, a(0) z(lp_moderada24)
*Pobreza estudiante universitario Publico
fgt ing_eq [w=pondih] if ch10==1 & ch12==7 & ch11==1, a(0) z(lp_moderada24)
*Pobreza estudiante universitario Privado
fgt ing_eq [w=pondih] if ch10==1 & ch12==7 & ch11==2, a(0) z(lp_moderada24)

*universitarios que trabajan
gen UyT = 0
replace UyT = 1 if ch10==1 & ch12==7 & estado==1
sum UyT [w=pondera] if ch10==1 & ch12==7


*Distribucion del ingreso estudiantes universitarios
twoway (kdensity ing_eq [w=pondih] if ch10==1 & ch12==7 & ch11==1) (kdensity ing_eq [w=pondih] if ch10==1 & ch12==7 & ch11==2)
*podando
twoway (kdensity ing_eq [w=pondih] if ch10==1 & ch12==7 & ch11==1 & ing_eq<1000000) (kdensity ing_eq [w=pondih] if ch10==1 & ch12==7 & ch11==2 & ing_eq<1000000)

