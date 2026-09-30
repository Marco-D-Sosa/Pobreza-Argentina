"""
extraer_dta_descomp.py - Consulta eph.db y guarda SOLO lo necesario para
descomposicion_pobreza.do (todas las personas de los 2dos semestres con canasta).

Genera:
  descomposicion.dta  -> una fila por persona (trimestres 3 y 4 de cada anio, desde 2017) con:
                         ano4, trimestre, region, pondih, itf, aef, lp_moderada
                         (aef = adultos equivalentes del hogar; lp_moderada = linea de pobreza
                          oficial del trimestre y region de esa persona)
"""

import sqlite3
from pathlib import Path
import pandas as pd

AQUI = Path(__file__).resolve().parent
DB = AQUI.parent / "Base de datos" / "eph.db"     # ajustar si la base esta en otro lugar
SALIDA = AQUI / "descomposicion.dta"

SQL = """
SELECT ano4, trimestre, region, pondih, itf, aef, lp_moderada
FROM v_pobreza
WHERE trimestre IN (3, 4)          -- 2do semestre
  AND lp_moderada IS NOT NULL      -- solo periodos con canasta (desde 2017)
"""

if not DB.exists():
    raise SystemExit(f"No encuentro la base en {DB}. Ajustar la variable DB.")

con = sqlite3.connect(f"{DB.as_uri()}?mode=ro", uri=True)
df = pd.read_sql_query(SQL, con)
con.close()

df.to_stata(SALIDA, write_index=False, version=118)
print(f"{len(df):,} filas -> {SALIDA}")
print(df.groupby(["ano4", "trimestre"]).size().to_string())
