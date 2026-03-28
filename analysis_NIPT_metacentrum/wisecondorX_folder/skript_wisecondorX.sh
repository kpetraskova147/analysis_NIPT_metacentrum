#!/bin/bash
# =============================================================================
# 0. PBS PARAMETRY
# =============================================================================
#PBS -N WisecondorX_Analysis
#PBS -l select=1:ncpus=9:mem=16gb:scratch_local=20gb
#PBS -l walltime=6:00:00
#PBS -o
#PBS -e
#PBS -m ae

#PBS -M petraskkar@natur.cuni.cz
#PBS -J 1-24
#PBS -o /storage/brno12-cerit/home/petraskkar/wisecondorX/pbs_outputs/

# =============================================================================
# INSTRUKCE
# =============================================================================
# Na storage: 
    # vytvoř složku RESULTS (pokud ještě není vytvořena)
    # data: cesta k nim: RESULTS/basecalling_results/basecalling_output_run1/barcode01-xx/.pod5
        # pokud spouštím tuto analýzu na data, u kterých nebylo spuštěno dorado, můžeš upravit cestu a nahrát je jinam
    # vytvoř složku wisecondorX a v ní:
        # 1. skript: skript_wisecondorX.sh 
        # 2. prostředí: environment.yml - pro vytvoření prostředí s verzemi knihoven, které se nebudou měnit (dobrá kooperace, stálé prostředí)
                # !! je třeba instalovat před spuštěním analýzy příkazem: conda install --file environment.yml
        # 3. reference - soubor "reference.npz"
                # referenci mohu vytvořit pomocí skriptu newRef.sh
        # 4. VOLITELNÉ: skript: uvod_kontrola.py - spíše pro mou kontrolu jestli mám vše připravené, nemusím spouštět
        # Terminál otevři ve složce wisecondorx, kde máš uložen tento skript (skript_wisecondorX.sh) a další potřebné soubory (samples_seznam_wisecondorx.txt, reference.npz atd.).

# Před spuštěním:
    # 1. Ve složce wisecondorX musíš mít: skript_wisecondorX.sh, reference.npz, environment.yml (+ uvod_kontrola.py - VOLITELNÉ)
    # 2. Uprav PBS -M a PBS -J podle počtu vzorků a svého emailu.
    # 3. Uprav ve 3. kapitole: BASE_DIR, INPUT_BAM_BAI_DIR, OUTPUT_DIR a REFERENCE podle své struktury dat.

# Spuštění: 
    # 0. pouze jednou - instalace prostředí: conda install --file environment.yml
    # (1. python3 uvod_kontrola.py - VOLITELNÉ, kontrola vstupních dat navíc a jestli mám vše zadané)
    # 2. qsub -v RUN_NUMBER="run1" skript_wisecondorX.sh

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
RUN_INPUT_DIR="$INPUT_BAM_DIR/alignment_output_${RUN_NUMBER}/$BARCODE"
BAM_FILE="$RUN_INPUT_DIR/${BARCODE}.bam"
BAI_FILE="$RUN_INPUT_DIR/${BARCODE}.bam.bai"

# Výstupní složka pro výsledky WisecondorX (NPZ a grafy)
OUTPUT_DIR="$BASE_DIR/RESULTS/wisecondorX_results"
RUN_OUTPUT_DIR="$OUTPUT_DIR/wisecondorX_output_${RUN_NUMBER}"
FINAL_OUTPUT_DIR="$RUN_OUTPUT_DIR/${RUN_NUMBER}_${BARCODE}.plots"                                                                 # Kam půjde výsledek pro tento konkrétní vzorek (podadresář s názvem barcode01, barcode02, ...)

# Cesta k referenci
REFERENCE="$WORK_DIR/reference.npz"

# Uložení všech NPZ souborů do složky ALL_NPZ pro případné vytvoření nové reference
NPZ_OUTPUT_DIR="$WORK_DIR/ALL_NPZ"

# Logy
RUN_LOG_DIR="$WORK_DIR/run_logs"
CENTRAL_LOG="$RUN_LOG_DIR/wisecondorX_history.txt"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$RUN_OUTPUT_DIR"
mkdir -p "$NPZ_OUTPUT_DIR"
mkdir -p "$RUN_LOG_DIR"

# =============================================================================
# 2. KONTROLA VSTUPNÍCH DAT A PROSTŘEDÍ
# =============================================================================

FILES_TO_CHECK=(
    "$BAM_FILE"
    "$BAI_FILE"
    "$REFERENCE"
)

for FILE in "${FILES_TO_CHECK[@]}"; do
    if [ ! -s "$FILE" ]; then
        echo "CHYBA: Soubor $FILE neexistuje nebo je prázdný!" >&2
        exit 1
    fi
done

# =============================================================================
# 3. PŘESUN DO SCRATCHE, INFO DO LOGŮ
# =============================================================================

cd "$SCRATCHDIR"

JOB_LOG="$SCRATCHDIR/wisecondorX_info.txt"
TMP_NPZ="$SCRATCHDIR/${RUN_NUMBER}_${BARCODE}_run.npz"          # dočasný NPZ soubor ve scratchi - vstup
TMP_NPZ_RESULT="$SCRATCHDIR/${RUN_NUMBER}_${BARCODE}.npz"   # dočasný NPZ soubor s výsledkem predict, před kopírováním zpět na storage

{
    echo "------------------------------------------------------------------"
    echo "Run: $RUN_NUMBER"
    echo "Barcode: $BARCODE"
    echo "Datum: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch: $SCRATCHDIR"
    echo "Vstup: $RUN_INPUT_DIR"
    echo "Výstup: $FINAL_OUTPUT_DIR"
    echo "Array index: $PBS_ARRAY_INDEX"
} | tee -a "$JOB_LOG"

{
    echo "------------------------------------------------------------------"
    echo "Spouštím úlohu: $RUN_NUMBER / $BARCODE dne: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch adresář: $SCRATCHDIR"
    echo "Array index: $PBS_ARRAY_INDEX"
} >> "$CENTRAL_LOG"

echo "Kopíruji data na scratch..." | tee -a "$JOB_LOG"
cp "$BAM_FILE" .
cp "$BAI_FILE" .
cp "$REFERENCE" .

# Lokální názvy pro rychlejší výpočet
LOCAL_BAM=$(basename "$BAM_FILE")
LOCAL_REF=$(basename "$REFERENCE")

# =============================================================================
# 4. PŘÍPRAVA PROSTŘEDÍ
# =============================================================================

module load conda

# Kontrola, zda prostředí existuje. Pokud ne, musím ho instalovat z environment.yml
if ! conda info --envs | grep -q "wisecondorX_env"; then
    echo "--- Prostředí wisecondorX_env nebylo nalezeno. Instaluj pomocí: conda install --file environment.yml ---"
    exit 1
else
    echo "--- Prostředí wisecondorX_env již existuje. Aktivace. ---"
fi

conda activate wisecondorX_env
echo "--- Prostředí wisecondorX_env aktivováno. ---" | tee -a "$JOB_LOG"

# =============================================================================
# 5. SPUŠTĚNÍ ANALÝZY - CONVERT + PREDICT
# =============================================================================

echo "Start: ${BARCODE} z runu ${RUN_NUMBER}"

# KROK 1: Convert
echo "Krok 1: Convert BAM to NPZ pro ${BARCODE}" | tee -a "$JOB_LOG"
WisecondorX convert "${LOCAL_BAM}" "${TMP_NPZ}"

# KROK 2: Predict
echo "Krok 2: Predict pro ${BARCODE}" | tee -a "$JOB_LOG"
# Výstup v PNG
WisecondorX predict "${TMP_NPZ}" "${LOCAL_REF}" "$TMP_NPZ_RESULT" \
    --outdir "plots" \
    --cpus 8 \
    --plot \
    --bed \
    --ylim -1.5 1.5 \
    --title "Sample: ${RUN_NUMBER}_${BARCODE}"

echo "Hotovo: ${BARCODE}" | tee -a "$JOB_LOG"

# =============================================================================
# 6. KONTROLA VÝSLEDKU ALIGNMENTU A STATISTIKY
# =============================================================================

echo "[Kontrola] Prověřuji výstupní soubory..." | tee -a "$JOB_LOG"

# Seznam souborů ke kontrole
if [ ! -s "$TMP_NPZ_RESULT" ]; then
    echo "KRITICKÁ CHYBA: Soubor $TMP_NPZ_RESULT neexistuje!" | tee -a "$JOB_LOG" >&2
    exit 1
fi

# =============================================================================
# 7. KOPÍROVÁNÍ VÝSLEDKŮ
# =============================================================================

echo "Kopírování výsledků zpět na storage" | tee -a "$JOB_LOG"

mkdir -p "$FINAL_OUTPUT_DIR"
cp "$TMP_NPZ_RESULT" "$FINAL_OUTPUT_DIR/"
cp "$TMP_NPZ" "$NPZ_OUTPUT_DIR/"  # Uložení NPZ souboru do složky ALL_NPZ pro případné vytvoření nové reference
cp -r "plots" "$FINAL_OUTPUT_DIR/"  # Kopírování celé složky s grafy
cp "$JOB_LOG" "$FINAL_OUTPUT_DIR/wisecondorX_info.txt"

if [ -f "$FINAL_OUTPUT_DIR/$(basename "$TMP_NPZ_RESULT")" ] && [ -f "$FINAL_OUTPUT_DIR/wisecondorX_info.txt" ]; then
    {
        echo "Hotovo: $RUN_NUMBER / $BARCODE dne: $(date)"
        echo "Výsledný soubor: $FINAL_OUTPUT_DIR/$(basename "$TMP_NPZ_RESULT")"
        echo "Kopírování úspěšné. Mažu scratch."
    } | tee -a "$FINAL_OUTPUT_DIR/wisecondorX_info.txt"
    clean_scratch
else
    echo "Chyba: kopírování výsledků selhalo, data zůstávají ve scratchi." | tee -a "$FINAL_OUTPUT_DIR/wisecondorX_info.txt" >&2
    exit 1
fi