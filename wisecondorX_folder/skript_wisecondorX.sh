#!/bin/bash
# =============================================================================
# 0. PBS PARAMETRY
# =============================================================================
#PBS -N WisecondorX_Analysis
#PBS -l select=1:ncpus=8:mem=16gb:scratch_local=20gb
#PBS -l walltime=6:00:00
#PBS -o systemove_logy/
#PBS -e systemove_logy/
#PBS -m ae

#PBS -M petraskkar@natur.cuni.cz
#PBS -J 1-24
#PBS -o /storage/brno12-cerit/home/petraskkar/basecalling/pbs_outputs/

# =============================================================================
# Skript pro analýzu WisecondorX na clusteru Metacentrum
# =============================================================================
        # Tento skript je navržen pro spuštění jako PBS job array, kde každý vzorek 
        #   je zpracováván samostatně. Skript provádí dvě hlavní operace: konverzi BAM souboru 
        #   do NPZ formátu a následnou analýzu (predict) pomocí WisecondorX. Výstupy jsou 
        #   organizovány do struktury složek podle vzorků a runů, což usnadňuje přehlednost výsledků. 

        # Terminál otevři ve složce wisecondorx, kde máš uložen tento skript (skript_wisecondorX.sh) a další potřebné soubory (samples_seznam_wisecondorx.txt, reference.npz atd.).

        # Před spuštěním:
        # 1. Ve složce wisecondorX musíš mít: skript_wisecondorX.sh, samples_seznam_wisecondorx.txt, reference.npz, environment.yml
        # 2. Uprav PBS -M a PBS -J podle počtu vzorků a svého emailu.
        # 3. Uprav ve 3. kapitole: BASE_DIR, INPUT_BAM_BAI_DIR, OUTPUT_DIR a REFERENCE podle své struktury dat.

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
mkdir -p "pbs_outputs"

set -euo pipefail   # přísnější režim pro lepší detekci chyb, -e: skript se zastaví při jakékoliv chybě, -u: chyba při použití nedefinované proměnné, -o pipefail: chyba v jakékoliv části pipy způsobí selhání celé pipy

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: RUN_NUMBER není nastaven." >&2
    echo "Spuštění: qsub -v RUN_NUMBER=run1 dorado_basecall_array.sh" >&2
    exit 1
fi

if [ -z "${PBS_ARRAY_INDEX:-}" ]; then
    echo "Chyba: PBS_ARRAY_INDEX není nastaven." >&2
    exit 1
fi

BARCODE=$(printf "barcode%02d" "$PBS_ARRAY_INDEX")  # vytvoří název barcode01, barcode02, ... podle indexu pole

# =============================================================================
# 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST)
# =============================================================================

# Základní adresář, kde běží má analýza a mám zde uložena data
# ÚPRAVA: TVUJ_LOGIN (můj osobní login na metacentru), praha1 (cluster, kde běží analýza a mám data)
BASE_DIR="/storage/brno12-cerit/home/petraskkar"
WORK_DIR="$BASE_DIR/wisecondorX"

# Vstupní data (.bam a .bai soubory)
INPUT_BAM_DIR="$BASE_DIR/RESULTS/alignment_results"
RUN_INPUT_DIR="$INPUT_BAM_DIR/alignment_output_${RUN_NUMBER}"
BAM_FILE="$RUN_INPUT_DIR/${BARCODE}.bam"
BAI_FILE="$RUN_INPUT_DIR/${BARCODE}.bam.bai"

# Výstupní složka pro výsledky WisecondorX (NPZ a grafy)
OUTPUT_DIR="$BASE_DIR/RESULTS/wisecondorX_results"
RUN_OUTPUT_DIR="$OUTPUT_DIR/wisecondorX_output_${RUN_NUMBER}"                                         # Kam půjde výsledek (.npz a grafy)
FINAL_OUTPUT_DIR="$RUN_OUTPUT_DIR/$BARCODE"                                                                 # Kam půjde výsledek pro tento konkrétní vzorek (podadresář s názvem barcode01, barcode02, ...)

# Cesta k referenci
REFERENCE="$BASE_DIR/wisecondorX/reference.npz"

# Uložení všech NPZ souborů pro případné vytvoření nové reference
NPZ_OUTPUT_DIR="$OUTPUT_DIR/ALL_NPZ"
NPZ_FILE="$NPZ_OUTPUT_DIR/${RUN_NUMBER}_${BARCODE}.npz"

mkdir -p "$FINAL_OUTPUT_DIR"
mkdir -p "$NPZ_OUTPUT_DIR"

# =============================================================================
# 2. PŘÍPRAVA PROSTŘEDÍ
# =============================================================================
cd $PBS_O_WORKDIR
mkdir -p "systemove_logy"
mkdir -p "pbs_outputs"

module load conda

# Kontrola, zda prostředí existuje. Pokud ne, musím ho instalovat z environment.yml
if ! conda info --envs | grep -q "wisecondorX_env"; then
    echo "--- Prostředí wisecondorX_env nebylo nalezeno. Je třeba ho instalovat. ---"
    exit 1
fi

conda activate wisecondorX_env

# =============================================================================
# 3. NAČTENÍ DAT ZE SAMPLES.TXT (3 sloupce - ID, BAM cesta, RUN)
# =============================================================================
LINE=$(sed -n "${PBS_ARRAY_INDEX}p" samples_seznam_wisecondorx.txt)
SAMPLE_ID=$(echo $LINE | awk '{print $1}')  # barcode01-run-1
BAM_PATH=$(echo $LINE | awk '{print $2}')   # alignment_output_run1/barcode01.bam

# Bezpečnostní pojistka proti prázdným řádkům
if [ -z "$SAMPLE_ID" ] || [ -z "$BAM_PATH" ]; then
    echo "CHYBA: Chybí data pro index $PBS_ARRAY_INDEX (prázdný řádek?)"
    exit 1
fi

# sed = filtruju text, -n = nevypisuj všechny řádky, pouze ty, které odpovídají indexu pole (PBS_ARRAY_INDEX), p = print
# awk = rozděluje řádek na sloupce, {print $1} = vypíše první sloupec (ID), {print $2} = vypíše druhý sloupec (BAM cesta)

# =============================================================================
# 4. SPUŠTĚNÍ ANALÝZY - CONVERT + PREDICT
# =============================================================================

echo "Start: ${BARCODE} z runu ${RUN_NUMBER}"

# KROK 1: Convert
WisecondorX convert "${BAM_PATH}" "${NPZ_FILE}"

# KROK 2: Predict
WisecondorX predict "${NPZ_FILE}" "${REFERENCE}" "${FINAL_OUTPUT_DIR}/${SAMPLE_ID}.npz" \
    --outdir "${FINAL_OUTPUT_DIR}" \
    --cpus 8 \
    --plot \
    --bed

echo "Hotovo: ${BARCODE}"
