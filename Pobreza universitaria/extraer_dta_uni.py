"""
extraer_universitarios.py - Consulta eph.db y guarda SOLO lo necesario para
pobreza_universitaria.do (universitarios, todos los semestres con canasta).

Uso (Anaconda Prompt, desde la carpeta de este proyecto):
    python extraer_universitarios.py
"""
import sqlite3
from pathlib import Path

import pandas as pd

AQUI = Path(__file__).resolve().parent
DB = AQUI.parent / "Base de datos" / "eph.db"     # ajustar si la base esta en otro lugar
SALIDA = AQUI / "universitarios.dta"

SQL = """
SELECT ano4, trimestre, period, region, ch04 AS sexo, ch06 AS edad, ch10, ch11, ch12,
       estado, pondera, pondih, ing_eq, lp_moderada, lp_extrema, pobre, indigente
FROM v_pobreza
WHERE ch10 = 1 AND ch12 = 7      -- asiste actualmente, nivel universitario
  AND pobre IS NOT NULL          -- solo periodos con canasta (desde 2017)
"""

if not DB.exists():
    raise SystemExit(f"No encuentro la base en {DB}. Ajustar la variable DB.")

con = sqlite3.connect(f"{DB.as_uri()}?mode=ro", uri=True)
df = pd.read_sql_query(SQL, con)
con.close()
df.to_stata(SALIDA, write_index=False, version=118)
print(f"{len(df):,} filas -> {SALIDA}")
print(df.groupby("period").size().to_string())
