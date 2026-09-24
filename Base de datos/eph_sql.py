"""
eph_sql.py  -  Descarga la EPH (INDEC) y la carga en una base SQLite.

Diseñado para PCs con poca RAM: procesa UN trimestre a la vez, lee solo las columnas
necesarias y guarda todo en disco (SQLite). Es incremental: si lo volvés a correr,
solo baja los trimestres que todavía no están cargados.

Uso (desde una terminal / CMD):
    python eph_sql.py cargar      # baja microdatos + canastas y arma eph.db
    python eph_sql.py pobreza     # imprime pobreza/indigencia por semestre
    python eph_sql.py exportar    # genera bases_eph_2016-2025.dta para Stata
    python eph_sql.py exportar 2023   # idem pero solo desde 2023 (menos RAM)

Reproducibilidad:
  - Todo se guarda en la misma carpeta que el script (eph.db, .dta y zips temporales).
  - El periodo analizado queda fijo en PRIMER_TRIM / ULTIMO_TRIM.
  - Si algo falla, el script termina con código de error y un resumen (no falla en silencio).
  - Dependencias: ver requirements.txt (pandas, xlrd, openpyxl).
"""
import io
import sqlite3
import sys
import time
import zipfile
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import pandas as pd

# ----------------------------------------------------------------------------
# CONFIGURACIÓN
# ----------------------------------------------------------------------------
CARPETA = Path(__file__).resolve().parent     # el script, la base (eph.db) y el .dta viven en la misma carpeta
DB = CARPETA / "eph.db"
ZIPS = CARPETA / "zips"
PRIMER_TRIM = (2016, 3)      # 2016-T2 no se pudo ubicar; las canastas arrancan en 2017 igual
ULTIMO_TRIM = (2025, 4)      # periodo fijo => resultados reproducibles
BORRAR_ZIP = True            # False = deja los zip en disco (re-cargar sin internet)

URL_EPH = "https://www.indec.gob.ar/ftp/cuadros/menusuperior/eph/"
URL_POB = "https://www.indec.gob.ar/ftp/cuadros/sociedad/"
UA = {"User-Agent": "Mozilla/5.0"}

# Excepciones de nombre de archivo (el INDEC no siempre respeta el patrón).
# Se completan una sola vez mirando el link en la web y quedan versionadas en git.
EPH_ALIAS = {
    (2016, 2): ["EPH_usu_2doTrim_2016_xls.zip"],     # solo existe en xls
}
CANASTA_ALIAS = {
    # clave: (año de datos, primer trimestre del semestre)
    # (2019, 3): ["cuadros_informe_pobreza_03_20.xls", "NOMBRE_REAL.xls"],
    # (2026, 1): ["NOMBRE_REAL_1S2026.xls"],        # solo si ULTIMO_TRIM incluye 2026
}

# Valores de control (GBA, canasta moderada) para verificar el parseo de canastas
CONTROL = {(2024, 4, 1): 324971.71, (2023, 4, 1): 132853.30}

# Variables que se guardan de la base individual
VARS = [
    "codusu", "ano4", "trimestre", "nro_hogar", "componente",
    "itf", "ipcf", "pondera", "pondih", "region", "aglomerado",
    "ch03", "ch04", "ch06",
    "ch10", "ch11", "ch12",
    "estado",
]
VARS_SET = set(VARS)
LIMITE = ULTIMO_TRIM[0] * 10 + ULTIMO_TRIM[1]     # ej. 20254

ERRORES = []      # se llena durante la carga; define el código de salida


def registrar_error(msg):
    ERRORES.append(msg)
    print(f"   !! {msg}")


# ----------------------------------------------------------------------------
# SQL: esquema y vistas
# ----------------------------------------------------------------------------
SQL_TABLAS = """
CREATE TABLE IF NOT EXISTS individuos (
    codusu TEXT, ano4 INTEGER, trimestre INTEGER, nro_hogar INTEGER, componente INTEGER,
    itf REAL, ipcf REAL, pondera REAL, pondih REAL, region INTEGER, aglomerado INTEGER,
    ch03 INTEGER, ch04 INTEGER, ch06 INTEGER, ch10 INTEGER, ch11 INTEGER, ch12 INTEGER,
    estado INTEGER
);
CREATE INDEX IF NOT EXISTS ix_ind_periodo ON individuos (ano4, trimestre);
CREATE TABLE IF NOT EXISTS cargados (
    ano4 INTEGER, trimestre INTEGER, filas INTEGER, fecha TEXT,
    PRIMARY KEY (ano4, trimestre)
);
CREATE TABLE IF NOT EXISTS canastas (
    ano INTEGER, trimestre INTEGER, region INTEGER,
    lp_extrema REAL, lp_moderada REAL,
    PRIMARY KEY (ano, trimestre, region)
);
"""

# Adulto equivalente (INDEC). __LIMITE__ se reemplaza por ULTIMO_TRIM (ej. 20254),
# así nada posterior al periodo fijado entra en los cálculos aunque esté en la base.
SQL_VISTAS = """
DROP VIEW IF EXISTS v_ae;
CREATE VIEW v_ae AS
SELECT i.*,
  CASE
    WHEN ch06 IS NULL THEN 1.0
    WHEN ch06 < 1 THEN 0.35
    WHEN ch06 = 1 THEN 0.37 WHEN ch06 = 2 THEN 0.46 WHEN ch06 = 3 THEN 0.51
    WHEN ch06 = 4 THEN 0.55 WHEN ch06 = 5 THEN 0.60 WHEN ch06 = 6 THEN 0.64
    WHEN ch06 = 7 THEN 0.66 WHEN ch06 = 8 THEN 0.68 WHEN ch06 = 9 THEN 0.69
    WHEN ch04 = 1 THEN                                   -- varones
      CASE
        WHEN ch06 = 10 THEN 0.79 WHEN ch06 = 11 THEN 0.82 WHEN ch06 = 12 THEN 0.85
        WHEN ch06 = 13 THEN 0.90 WHEN ch06 = 14 THEN 0.96 WHEN ch06 = 15 THEN 1.0
        WHEN ch06 = 16 THEN 1.03 WHEN ch06 = 17 THEN 1.04
        WHEN ch06 BETWEEN 18 AND 29 THEN 1.02
        WHEN ch06 BETWEEN 30 AND 60 THEN 1.0
        WHEN ch06 BETWEEN 61 AND 75 THEN 0.83
        ELSE 0.74 END
    WHEN ch04 = 2 THEN                                   -- mujeres
      CASE
        WHEN ch06 = 10 THEN 0.70 WHEN ch06 = 11 THEN 0.72 WHEN ch06 = 12 THEN 0.74
        WHEN ch06 = 13 THEN 0.76 WHEN ch06 = 14 THEN 0.76 WHEN ch06 IN (15,16,17) THEN 0.77
        WHEN ch06 BETWEEN 18 AND 29 THEN 0.76
        WHEN ch06 BETWEEN 30 AND 45 THEN 0.77
        WHEN ch06 BETWEEN 46 AND 60 THEN 0.76
        WHEN ch06 BETWEEN 61 AND 75 THEN 0.67
        ELSE 0.63 END
    ELSE 1.0
  END AS ae
FROM individuos i
WHERE i.ano4 * 10 + i.trimestre <= __LIMITE__;

DROP VIEW IF EXISTS v_aef;
CREATE VIEW v_aef AS
SELECT v_ae.*,
  SUM(ae) OVER (PARTITION BY codusu, nro_hogar, ano4, trimestre) AS aef
FROM v_ae;

DROP VIEW IF EXISTS v_pobreza;
CREATE VIEW v_pobreza AS
SELECT h.*,
  CASE WHEN h.trimestre <= 2 THEN 1 ELSE 2 END                       AS semestre,
  h.ano4 || '-' || CASE WHEN h.trimestre <= 2 THEN 1 ELSE 2 END      AS period,
  h.itf / h.aef                                                      AS ingreso_oficial,
  h.itf / h.aef                                                      AS ing_eq,
  c.lp_moderada, c.lp_extrema,
  CASE WHEN c.lp_moderada IS NULL THEN NULL
       WHEN h.itf / h.aef < c.lp_moderada THEN 100.0 ELSE 0.0 END    AS pobre,
  CASE WHEN c.lp_extrema IS NULL THEN NULL
       WHEN h.itf / h.aef < c.lp_extrema THEN 100.0 ELSE 0.0 END     AS indigente
FROM v_aef h
LEFT JOIN canastas c
  ON  c.ano = h.ano4 AND c.trimestre = h.trimestre
  AND c.region = CASE h.region WHEN 43 THEN 2 WHEN 42 THEN 3 WHEN 40 THEN 4
                               WHEN 44 THEN 5 WHEN 41 THEN 6 ELSE h.region END;
""".replace("__LIMITE__", str(LIMITE))

SQL_POBREZA_SEMESTRAL = """
SELECT period,
       ROUND(SUM(pobre     * pondih) / SUM(pondih), 2) AS pobreza,
       ROUND(SUM(indigente * pondih) / SUM(pondih), 2) AS indigencia,
       COUNT(*) AS personas_muestra
FROM v_pobreza
WHERE pobre IS NOT NULL AND pondih > 0
GROUP BY period ORDER BY period;
"""


def conectar():
    CARPETA.mkdir(parents=True, exist_ok=True)
    ZIPS.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(DB)
    con.executescript(SQL_TABLAS)
    return con


# ----------------------------------------------------------------------------
# Descarga
# ----------------------------------------------------------------------------
MAGIC_EXCEL = (b"\xd0\xcf\x11\xe0", b"PK\x03\x04")     # .xls (OLE2) y .xlsx (zip)


def es_excel(ruta):
    with open(ruta, "rb") as f:
        return f.read(4) in MAGIC_EXCEL


def trimestres():
    y, t = PRIMER_TRIM
    while (y, t) <= ULTIMO_TRIM:
        yield y, t
        t += 1
        if t == 5:
            y, t = y + 1, 1


def candidatos_eph(y, t):
    """INDEC cambió los nombres de archivo varias veces: alias fijos + variantes conocidas."""
    urls = [URL_EPH + a for a in EPH_ALIAS.get((y, t), [])]
    ord_ = {1: "1er", 2: "2do", 3: "3er", 4: "4to"}[t]
    for fmt in ("txt", "xls", "xlsx"):          # txt primero: es mucho más liviano
        for o in (str(t), ord_):
            for sep in ("_", ""):
                urls.append(f"{URL_EPH}EPH_usu_{o}{sep}Trim_{y}_{fmt}.zip")
    return urls


def bajar(urls, destino):
    for url in urls:
        try:
            with urlopen(Request(url, headers=UA), timeout=90) as r, open(destino, "wb") as f:
                while chunk := r.read(1 << 20):
                    f.write(chunk)
        except HTTPError:
            continue
        except URLError as e:
            print(f"   sin conexión / error de red: {e}")
            return None
        if zipfile.is_zipfile(destino):
            return url
        destino.unlink(missing_ok=True)      # devolvió una página HTML, no un zip
    return None


# ----------------------------------------------------------------------------
# Lectura de UN trimestre
# ----------------------------------------------------------------------------
def _buscar_individual(z):
    """Busca la base individual; soporta zips anidados."""
    for n in z.namelist():
        nl = n.lower()
        # "individual" en casi todos los trimestres; "personas" en 2020-T4
        if (("indiv" in nl or "personas" in nl) and "hogar" not in nl
                and nl.endswith((".txt", ".csv", ".xls", ".xlsx"))):
            return z, n
    for n in z.namelist():
        if n.lower().endswith(".zip"):
            r = _buscar_individual(zipfile.ZipFile(io.BytesIO(z.read(n))))
            if r:
                return r
    return None


def leer_individual(ruta_zip, y, t):
    with zipfile.ZipFile(ruta_zip) as z0:
        hallado = _buscar_individual(z0)
        if not hallado:
            raise ValueError(f"no encontré la base individual. Contenido: {z0.namelist()}")
        z, m = hallado
        filtro = lambda c: str(c).strip().lower() in VARS_SET
        if m.lower().endswith((".txt", ".csv")):
            with z.open(m) as f:
                df = pd.read_csv(f, sep=";", dtype=str, encoding="latin-1", usecols=filtro)
        else:
            df = pd.read_excel(io.BytesIO(z.read(m)), dtype=str, usecols=filtro)

    df.columns = [c.strip().lower() for c in df.columns]
    for v in VARS:
        if v not in df:
            df[v] = None
    df = df[VARS].copy()
    for c in VARS[1:]:
        df[c] = pd.to_numeric(df[c].astype(str).str.strip().str.replace(",", ".", regex=False),
                              errors="coerce")
    df["ano4"], df["trimestre"] = y, t
    return df


def cargar_trimestre(con, y, t):
    if con.execute("SELECT 1 FROM cargados WHERE ano4=? AND trimestre=?", (y, t)).fetchone():
        return "ya cargado"
    zip_local = ZIPS / f"EPH_{y}_T{t}.zip"
    if not zip_local.exists():
        if bajar(candidatos_eph(y, t), zip_local) is None:
            raise FileNotFoundError("no se encontró el zip en el INDEC (agregar a EPH_ALIAS)")
    df = leer_individual(zip_local, y, t)
    with con:
        con.execute("DELETE FROM individuos WHERE ano4=? AND trimestre=?", (y, t))
        df.to_sql("individuos", con, if_exists="append", index=False, chunksize=20000)
        con.execute("INSERT OR REPLACE INTO cargados VALUES (?,?,?,?)",
                    (y, t, len(df), time.strftime("%Y-%m-%d %H:%M")))
    if BORRAR_ZIP:
        zip_local.unlink(missing_ok=True)
    return f"{len(df):,} filas"


# ----------------------------------------------------------------------------
# Canastas (líneas de pobreza e indigencia por región)
# Promedio de los 3 meses de cada trimestre.
# ----------------------------------------------------------------------------
REGIONES = {"gran buenos aires": 1, "pampeana": 2, "cuyo": 3, "noroeste": 4, "noreste": 6}


def parsear_canastas(ruta, ano, trims):
    xl = pd.ExcelFile(ruta)
    hoja = next((h for h in xl.sheet_names if "canasta" in h.lower() or "cba" in h.lower()),
                xl.sheet_names[0])
    raw = xl.parse(hoja, header=None)
    nombres = raw.iloc[:, 0].astype(str).str.strip()
    vals = raw.iloc[:, 1:7].apply(pd.to_numeric, errors="coerce")
    ok = nombres.ne("") & nombres.ne("nan") & nombres.ne("Región") & vals.iloc[:, 0].ge(3)
    nombres, vals = nombres[ok].reset_index(drop=True), vals[ok].reset_index(drop=True)
    if len(nombres) < 12:
        raise ValueError(f"esperaba 12 filas (6 CBA + 6 CBT) y encontré {len(nombres)}")
    filas = []
    for i in range(12):
        reg = REGIONES.get(nombres[i].lower(), 5)       # lo que no matchea = Patagonia
        col = "lp_extrema" if i < 6 else "lp_moderada"
        for k, trim in enumerate(trims):
            valor = vals.iloc[i, 3 * k:3 * k + 3].mean()
            filas.append((ano, trim, reg, col, float(valor)))
    return filas


def cargar_canastas(con):
    tareas = []   # (año de datos, trimestres, nombres de archivo candidatos)
    for yy in range(17, ULTIMO_TRIM[0] % 100 + 2):
        tareas.append((2000 + yy, (1, 2), [f"cuadros_informe_pobreza_09_{yy}.xls"]))
        tareas.append((2000 + yy - 1, (3, 4),
                       [f"cuadros_informe_pobreza_03_{yy}.xls", f"cuadros_informe_pobreza_04_{yy}.xls"]))
    destino = ZIPS / "canasta_tmp.xls"
    for ano, trims, archivos in tareas:
        etiqueta = f"{ano} S{1 if trims[0] == 1 else 2}"
        # fuera del periodo fijado, o anterior a 2017 (no hay canastas)
        if ano < 2017 or (ano, trims[1]) > ULTIMO_TRIM:
            continue
        if con.execute("SELECT COUNT(*) FROM canastas WHERE ano=? AND trimestre=?",
                       (ano, trims[0])).fetchone()[0] >= 6:
            continue
        archivos = CANASTA_ALIAS.get((ano, trims[0]), []) + archivos
        ok = None
        for a in archivos:
            try:
                with urlopen(Request(URL_POB + a, headers=UA), timeout=90) as r, open(destino, "wb") as f:
                    f.write(r.read())
            except (HTTPError, URLError):
                continue
            if es_excel(destino):          # si es una página HTML, prueba el siguiente nombre
                ok = a
                break
        if not ok:
            registrar_error(f"canastas {etiqueta}: no encontré un Excel válido (agregar a CANASTA_ALIAS)")
            continue
        try:
            filas = parsear_canastas(destino, ano, trims)
        except Exception as e:
            registrar_error(f"canastas {etiqueta} ({ok}): no pude leer el Excel -> {e}")
            continue
        tabla = pd.DataFrame(filas, columns=["ano", "trimestre", "region", "col", "valor"]) \
                  .pivot_table(index=["ano", "trimestre", "region"], columns="col", values="valor").reset_index()
        with con:
            con.executemany("INSERT OR REPLACE INTO canastas VALUES (?,?,?,?,?)",
                            tabla[["ano", "trimestre", "region", "lp_extrema", "lp_moderada"]].values.tolist())
        print(f"   canastas {etiqueta}: OK ({ok})")
    destino.unlink(missing_ok=True)


def verificar_canastas(con):
    for (a, t, r), esperado in CONTROL.items():
        if (a, t) > ULTIMO_TRIM:
            continue
        fila = con.execute("SELECT lp_moderada FROM canastas WHERE ano=? AND trimestre=? AND region=?",
                           (a, t, r)).fetchone()
        if fila is None:
            registrar_error(f"control {a}-T{t} región {r}: sin dato de canasta")
        elif abs(fila[0] - esperado) > 0.01:
            registrar_error(f"control {a}-T{t} región {r}: {fila[0]:.2f} != {esperado:.2f}")
        else:
            print(f"   control {a}-T{t} región {r}: OK ({esperado:,.2f})")


# ----------------------------------------------------------------------------
# Comandos
# ----------------------------------------------------------------------------
def cmd_cargar():
    con = conectar()
    for y, t in trimestres():
        try:
            print(f"{y}-T{t}: {cargar_trimestre(con, y, t)}")
        except Exception as e:
            registrar_error(f"{y}-T{t}: {e}")
    # limpia lo que quedara cargado fuera del periodo fijado (ej. 2026-T1 de corridas previas)
    with con:
        con.execute("DELETE FROM individuos WHERE ano4*10+trimestre > ?", (LIMITE,))
        con.execute("DELETE FROM cargados   WHERE ano4*10+trimestre > ?", (LIMITE,))
    print("Canastas:")
    cargar_canastas(con)
    verificar_canastas(con)
    con.executescript(SQL_VISTAS)
    con.execute("VACUUM")
    con.close()
    if ERRORES:
        print(f"\nTERMINÓ CON {len(ERRORES)} PROBLEMA(S):")
        for e in ERRORES:
            print(f"  - {e}")
        sys.exit(1)
    print("\nListo, sin errores. Probá:  python eph_sql.py pobreza")


def cmd_pobreza():
    con = conectar()
    con.executescript(SQL_VISTAS)
    print(pd.read_sql_query(SQL_POBREZA_SEMESTRAL, con).to_string(index=False))


def cmd_exportar(desde=2016):
    con = conectar()
    con.executescript(SQL_VISTAS)
    cols = ("codusu, ano4, trimestre, nro_hogar, componente, itf, ipcf, pondera, pondih, region, "
            "aglomerado, ch03, ch04, ch06, ch10, ch11, ch12, estado, semestre, period, aef, "
            "ingreso_oficial, ing_eq, lp_moderada, lp_extrema, pobre, indigente")
    df = pd.read_sql_query(f"SELECT {cols} FROM v_pobreza WHERE ano4 >= ?", con, params=(desde,))
    for c in ["ano4", "trimestre", "nro_hogar", "componente", "region", "aglomerado", "ch03", "ch04",
              "ch06", "ch10", "ch11", "ch12", "estado", "semestre"]:
        df[c] = df[c].astype("float32")
    salida = CARPETA / f"bases_eph_{desde}-{ULTIMO_TRIM[0]}.dta"
    df.to_stata(salida, write_index=False, version=118)
    print(f"Exportado: {salida}  ({len(df):,} filas)")


if __name__ == "__main__":
    accion = sys.argv[1] if len(sys.argv) > 1 else "cargar"
    if accion == "cargar":
        cmd_cargar()
    elif accion == "pobreza":
        cmd_pobreza()
    elif accion == "exportar":
        cmd_exportar(int(sys.argv[2]) if len(sys.argv) > 2 else 2016)
    else:
        print(__doc__)
