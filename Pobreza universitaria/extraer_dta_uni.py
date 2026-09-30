"""
extraer_dta_uni.py - Consulta eph.db y guarda SOLO lo necesario para
pobreza_universitaria.do (universitarios, todos los semestres con canasta).

Genera un archivo chico para Stata:
  universitarios.dta -> una fila por estudiante universitario, con su DECIL de ingreso
                        per capita familiar (IPCF) calculado sobre TODA la poblacion EPH.

Detalle metodologico (importante, esta todo en este script):
  - Los deciles se calculan POR TRIMESTRE (no por semestre), porque con inflacion no se pueden
    mezclar pesos de dos trimestres en una misma distribucion.
  - Poblacion de referencia: todas las personas con IPCF > 0, ponderadas por PONDIH
    (igual criterio que INDEC: decil 0 = hogar sin ingresos, queda afuera de los 10 deciles).
  - decil = 0 para estudiantes en hogares sin ingresos; vacio si IPCF faltante.
"""

import sqlite3
from pathlib import Path
import numpy as np
import pandas as pd

AQUI = Path(__file__).resolve().parent
DB = AQUI.parent / "Base de datos" / "eph.db"     # ajustar si la base esta en otro lugar
SALIDA_UNI = AQUI / "universitarios.dta"

SQL_UNI = """
SELECT ano4, trimestre, period, region, ch04 AS sexo, ch06 AS edad, ch10, ch11, ch12,
       estado, pondera, pondih, ipcf, ing_eq, lp_moderada, lp_extrema, pobre, indigente
FROM v_pobreza
WHERE ch10 = 1 AND ch12 = 7      -- asiste actualmente, nivel universitario
  AND pobre IS NOT NULL          -- solo periodos con canasta (desde 2017)
"""

# Poblacion de referencia para los deciles: se lee de la tabla base
SQL_POB = """
SELECT ano4, trimestre, ipcf, pondih
FROM individuos
WHERE ipcf > 0 AND pondih > 0
  AND ano4 * 10 + trimestre IN ({periodos})
"""


def cortes_deciles(x, w):
    """Los 9 puntos de corte ponderados: el menor ipcf donde la poblacion acumulada llega a k/10."""
    o = np.argsort(x, kind="mergesort")
    x, w = x[o], w[o]
    acum = np.cumsum(w) / w.sum()
    idx = np.searchsorted(acum, np.arange(1, 10) / 10, side="left")
    return x[np.minimum(idx, len(x) - 1)]


def asignar_decil(x, cortes):
    """1..10. Mismo ipcf => mismo decil (los miembros de un hogar comparten ipcf)."""
    return np.searchsorted(cortes, x, side="left") + 1


if not DB.exists():
    raise SystemExit(f"No encuentro la base en {DB}. Ajustar la variable DB.")

con = sqlite3.connect(f"{DB.as_uri()}?mode=ro", uri=True)
uni = pd.read_sql_query(SQL_UNI, con)

periodos = sorted({int(a) * 10 + int(t) for a, t in uni[["ano4", "trimestre"]].drop_duplicates().values})
pob = pd.read_sql_query(SQL_POB.format(periodos=",".join(map(str, periodos))), con)
con.close()

# --- deciles de la poblacion, trimestre por trimestre ------------------------
uni["decil"] = np.nan
desvio_max = 0.0            # control: cada decil de la poblacion deberia pesar ~10%
for (a, t), g in pob.groupby(["ano4", "trimestre"]):
    x = g["ipcf"].to_numpy(float)
    w = g["pondih"].to_numpy(float)
    cortes = cortes_deciles(x, w)
    d = asignar_decil(x, cortes)
    for k in range(1, 11):
        desvio_max = max(desvio_max, abs(w[d == k].sum() / w.sum() - 0.10))
    # estudiantes de ese trimestre
    m_u = (uni["ano4"] == a) & (uni["trimestre"] == t) & (uni["ipcf"] > 0)
    uni.loc[m_u, "decil"] = asignar_decil(uni.loc[m_u, "ipcf"].to_numpy(float), cortes)

uni.loc[uni["ipcf"] == 0, "decil"] = 0          # hogar sin ingresos

uni.to_stata(SALIDA_UNI, write_index=False, version=118)

print(f"{len(uni):,} filas -> {SALIDA_UNI}")
print(uni.groupby("period").size().to_string())
print(f"\nControl deciles: desvio maximo de la poblacion por decil respecto de 10% = {desvio_max:.3f}")
print(f"Estudiantes con decil 0 (hogar sin ingresos): {(uni['decil'] == 0).sum():,}")
print(f"Estudiantes sin decil (ipcf faltante):        {uni['decil'].isna().sum():,}")
