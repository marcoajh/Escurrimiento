#!/bin/sh
#
#Script para calcular el escurrimiento medio anual según lo propuesto 
#en la  NOM-011 -CNA-2000. (SEMARNAT, 2002).
#
#Vm = Ce Pm A
#Dónde:
#Vm - Volumen medio de escurrimiento (Hm³)
#Pm - Precipitación media (mm)
#A  - Área de dreanje (km²)
#Ce  - Coeficiente de escurrimiento (adimensional)
#
#
#
#Área de drenaje
#La superficie de cada cuenca es constante y sólo se calcula una vez (ya está calculado)
#r.stats -an CHA |
#gawk '{printf "%i %s %i\n", $1, "=", $2}' > /home/marco/CVM_SIG/Shells/area_CHA.rec
#r.reclass i=CHA o=CHA_A rules=/home/marco/CVM_SIG/Shells/area_CHA.rec --o
#El área estaba en m², se necesita en km².
#r.mapcalc 'CHA_A = CHA_A*0.000001' --o
#
#Para el cálculo del parámetro k, que depende del tipo de suelo y cobertura
#se usan dos mapas reclasificados, ya generados. Se supone que los cambios de cobertura
#sólo son hacia zona urbana
#Cobertura
#r.reclass i=USV_serie_V o=Cob rules=/home/marco/CVM_SIG/Shells/cob.rec --o
#r.mapcalc 'Cob = Cob*10' --o
#Tipo de suelo
#r.reclass input=Edafologia o=Tipo_suel rules=/home/marco/CVM_SIG/Shells/tipo_suel.rec --o
#r.mapcalc 'Tipo_suel = Tipo_suel*1' --o
#
#
for year in 2015 2020 2025 2030 2035 2040
do
#
#Precipitación media (media ponderada)
#Se toma como constante (todos los mapas son iguales) pero se prepara para recibir mapas por cada año
r.statistics base=CHA cover="precip_$year" method=average output=CHA_Pm1 --o
r.stats -ln CHA_Pm1 |gawk  '{printf "%i %s %i\n", $1, "=", $2*1000}' > /home/marco/CVM_SIG/Shells/CHA_Pm.rec
r.reclass i=CHA o=CHA_Pm$year rules=/home/marco/CVM_SIG/Shells/CHA_Pm.rec --o
r.mapcalc 'CHA_Pm'$year' = CHA_Pm'$year'*0.001' --o
#
#
#Parámetro k
#Cobertura
r.mapcalc 'Cob_'$year' = if(Group9_0_urban_'$year'==1 ||  Group9_0_urban_'$year'==3 || Group9_0_urban_'$year'==4 || Group9_0_urban_'$year'==5 || Group9_0_urban_'$year'==6 || Group9_0_urban_'$year'==7 || Group9_0_urban_'$year'==8,60,Cob)' --o
#Tipo de suelo
#El tipo de suelo según su permeabilidad, es un reclasificado de la capa de Edafología Serie II del INEGI, 
#la reclasificación se hizo de acuerdo a las características hidrológicas de cada suelo reportadas en 
#Lecture Notes on the Major Soils of the World. http://www.fao.org/docrep/003/Y1899E/Y1899E00.HTM
r.mapcalc 'Tipo_suelo'$year' = if(Group9_0_urban_'$year'==1 || Group9_0_urban_'$year'==3 || Group9_0_urban_'$year'==4 || Group9_0_urban_'$year'==5 || Group9_0_urban_'$year'==6 || Group9_0_urban_'$year'==7 || Group9_0_urban_'$year'==8,4,Tipo_suel)' --o
#k
#Los valores k se obtuvieron de la tabla 3.1.14 de UNESCO, 2006. Evaluación de los Recursos Hídricos.
#Elaboración del balance hídrico integral por cuencas hidrográficas.
#Documentos técnicos del PHI-LAC, N°4.
r.mapcalc 'k1 = (Cob_'$year')+Tipo_suelo'$year'' --o
r.reclass input=k1 o="k_$year" rules=/home/marco/CVM_SIG/Shells/param_k.rec --o
r.mapcalc 'k_'$year' = k_'$year'*0.1' --o
#
#Coeficiente de escurrimiento
#Para K <= 0.15
#   Ce = K (P-250) 12000
#Para k > 0.15
#   Ce = K (P-250) 12000 + (K-0.15) / 1.5
r.mapcalc 'Ce = if(k_'$year' <= 0.15,(k_'$year'*((precip_'$year'-250)/2000)),((k_'$year'*((precip_'$year'-250)/2000))+((k_'$year'-0.15)/1.5)))' --o
r.mapcalc 'Ce = int(Ce*1000)' --o
r.statistics base=CHA cover=Ce method=average output=Ce_cuenca --o
r.stats -ln Ce_cuenca |
gawk '{printf "%i %s %i\n", $1, "=", $2}' > /home/marco/CVM_SIG/Shells/CHA_C.rec
r.reclass i=CHA o=CHA_C rules=/home/marco/CVM_SIG/Shells/CHA_C.rec --o
r.mapcalc 'CHA_Ce'$year' = CHA_C*0.0001' --o
#
#Volumen medio de escurrimiento anual
#
#Vm = C Pm A
# Volumen en Millones de m³ o hectómetros cúbicos (hm³)
#r.mapcalc 'CHA_Vm_00_'$year' = (CHA_Ce'$year' * CHA_Pm'$year' * CHA_A)' --o
#r.colors map="CHA_Vm_00_$year" rules=/home/marco/CVM_SIG/Shells/CHA_Vm.clr
#
r.mapcalc 'CHA_Vm = (CHA_Ce'$year' * CHA_Pm'$year' * CHA_A)' --o
r.stats.zonal -r base=CHA cover=CHA_Vm method=max output=CHA_Vm_00_$year --o
r.colors map=CHA_Vm_00_$year color=rainbow
r.stats -ln CHA_Vm_00_$year separator=, > /home/marco/CVM_SIG/outputs/Escurrimiento/CHA_Vm_00_$year.csv
#
#
#
echo "Año $year Escenario E00 completado"
#
done


