#!/bin/bash
# =============================================================================
# 0. PBS PARAMETRY
# =============================================================================
#PBS -N Epi2me-WisecondorX_Analysis
#PBS -l select=1:ncpus=9:mem=32gb:scratch_local=20gb
#PBS -l walltime=6:00:00
#PBS -j oe
#PBS -m ae

#PBS -M petraskkar@natur.cuni.cz
#PBS -J 1-24
#PBS -o /storage/brno12-cerit/home/petraskkar/wisecondorX/pbs_outputs/
#PBS -e /storage/brno12-cerit/home/petraskkar/wisecondorX/pbs_outputs/


# =============================================================================
# INSTRUKCE
# =============================================================================
# Na storage: 
    # vytvoř složku RESULTS (pokud ještě není vytvořena)
    # data: cesta k nim: Epi2me_run1/run1-barcodeXX/.bam a .bam.bai
        # pokud spouštím tuto analýzu na data, u kterých nebylo spuštěno dorado, můžeš upravit cestu a nahrát je jinam
    # vytvoř složku wisecondorX a v ní:
        # 1. skript: skript_wisecondorX.sh 
        # 2. prostředí: environment.yml - pro vytvoření prostředí s verzemi knihoven, které se nebudou měnit (dobrá kooperace, stálé prostředí)
                # !! je třeba instalovat před spuštěním analýzy příkazem: conda install --file environment.yml
        # 3. reference - složka references - složka references_${DATUM} se soubory "reference_${REF_SIZE}kb.npz"
                # referenci mohu vytvořit pomocí skriptu newRef.sh
        # 4. složka wisecondorx a v ní:
               # ├── __init__.py
               # ├── main.py                 # <--- Spouštěcí bod programu
               # ├── convert_tools.py
               # ├── predict_control.py
               # ├── predict_tools.py
               # ├── ... (všechny ostatní .py soubory ze složky src/wisecondorx z oficiálního repozitáře: https://github.com/CenterForMedicalGeneticsGhent/wisecondorX)
               # └── include/                # Složka include
               #     └── CBS.R               # Tvůj funkční R skript
        # 5. VOLITELNÉ: skript: uvod_kontrola.py - spíše pro mou kontrolu jestli mám vše připravené, nemusím spouštět
        # Terminál otevři ve složce wisecondorx, kde máš uložen tento skript (Epi2me-wisecondorX.sh)

# Před spuštěním:
    # 1. Ve složce wisecondorX musíš mít: Epi2me-wisecondorX.sh, reference.npz, environment.yml (+ uvod_kontrola.py - VOLITELNÉ)
    # 2. Uprav PBS -M a PBS -J podle počtu vzorků a svého emailu.
    # 3. Uprav ve 3. kapitole: BASE_DIR, INPUT_BAM_BAI_DIR, OUTPUT_DIR a REFERENCE podle své struktury dat.
    # 4. Uprav absolutní cestu k prostředí v části 4. PŘÍPRAVA PROSTŘEDÍ, pokud se ti nedaří aktivovat prostředí podle jména.
          # absolutní cesta - conda info --envs 
          # vyhledat wisecondorX_env a zkopírovat cestu, která je v 2.sloupci (např. /auto/brno2/home/petraskkar/.conda/envs/wisecondorX_env)

# Spuštění: 
    # 0. pouze jednou - instalace prostředí: conda install --file environment.yml
    # (1. python3 uvod_kontrola.py - VOLITELNÉ, kontrola vstupních dat navíc a jestli mám vše zadané)
    # 2. qsub -v RUN_NUMBER="run1",DATUM="2026-03-26" Epi2me-wisecondorX.sh

    # DATUM = datum u reference, kterou chci použít (vytvořeno pomocí skriptu newRef.sh) - např. 2026-03-26

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
mkdir -p "pbs_outputs"
set -euo pipefail   # přísnější režim pro lepší detekci chyb, -e: skript se zastaví při jakékoliv chybě, -u: chyba při použití nedefinované proměnné, -o pipefail: chyba v jakékoliv části pipy způsobí selhání celé pipy

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: RUN_NUMBER není nastaven." >&2
    echo "Spuštění: qsub -v RUN_NUMBER=run1,DATUM=2026-03-26 Epi2me-wisecondorX.sh" >&2
    exit 1
fi

if [ -z "${DATUM:-}" ]; then
    echo "Chyba: DATUM není nastaveno." >&2
    echo "Spuštění: qsub -v RUN_NUMBER=run1,DATUM="2026-03-26" Epi2me-wisecondorX.sh" >&2
    exit 1
fi

if [ -z "${PBS_ARRAY_INDEX:-}" ]; then
    echo "Chyba: PBS_ARRAY_INDEX není nastaven." >&2
    exit 1
fi

BARCODE=$(printf "barcode%02d" "$PBS_ARRAY_INDEX")  # vytvoří název barcode01, barcode02, ... podle indexu pole

# =============================================================================
# 1. NASTAVENÍ (UPRAV POUZE TUTO ČÁST)
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar"
WORK_DIR="$BASE_DIR/wisecondorX"

mkdir -p "$WORK_DIR/pbs_outputs"

# Vstupní data (.bam a .bai soubory)
INPUT_BAM_DIR="$BASE_DIR/${RUN_NUMBER}-newref-bam,bai"
BAM_FILE="$RUN_INPUT_DIR/${BARCODE}.sorted.aligned.bam"
BAI_FILE="$RUN_INPUT_DIR/${BARCODE}.sorted.aligned.bai"

# Cesta k referenci
REF_DIR="$WORK_DIR/references/reference_${DATUM}"
REF_SIZES="1000 500 100"

# Výstupní složka pro výsledky WisecondorX (NPZ a grafy)
OUTPUT_DIR="$BASE_DIR/RESULTS/Epi2me-wisecondorX_results"
RUN_OUTPUT_DIR="$OUTPUT_DIR/Epi2me-wisecondorX_output_${RUN_NUMBER}"
FINAL_OUTPUT_DIR="$RUN_OUTPUT_DIR/${RUN_NUMBER}-Epi2me_${BARCODE}"
PLOTS_OUTPUT_DIR="$RUN_OUTPUT_DIR/PLOTS_${RUN_NUMBER}"

# Uložení všech NPZ souborů do složky ALL_NPZ pro případné vytvoření nové reference
NPZ_OUTPUT_DIR="$WORK_DIR/Epi2me-ALL_NPZ"

# Logy
RUN_LOG_DIR="$WORK_DIR/Epi2me-run_logs"
CENTRAL_LOG="$RUN_LOG_DIR/Epi2me-wisecondorX_history.txt"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$RUN_OUTPUT_DIR"
mkdir -p "$NPZ_OUTPUT_DIR"
mkdir -p "$RUN_LOG_DIR"

# =============================================================================
# 2. KONTROLA VSTUPNÍCH DAT A PROSTŘEDÍ
# =============================================================================

if [ ! -s "$BAM_FILE" ]; then
    echo "CHYBA: Soubor $BAM_FILE neexistuje nebo je prázdný!" >&2
    exit 1
fi

if [ ! -s "$BAI_FILE" ]; then
    echo "CHYBA: Soubor $BAI_FILE neexistuje nebo je prázdný!" >&2
    exit 1
fi

for REF_SIZE in ${REF_SIZES}; do
    if [ ! -s "$REF_DIR/reference_${REF_SIZE}kb.npz" ]; then
        echo "CHYBA: Soubor reference_${REF_SIZE}kb.npz neexistuje nebo je prázdný!" >&2
        exit 1
    fi
done

# =============================================================================
# 3. PŘESUN DO SCRATCHE, INFO DO LOGŮ
# =============================================================================

cd "$SCRATCHDIR"

JOB_LOG="$SCRATCHDIR/Epi2me-wisecondorX_info.txt"

{
    echo "------------------------------------------------------------------"
    echo "Run: $RUN_NUMBER"
    echo "Barcode: $BARCODE"
    echo "Datum: $(date '+%Y-%m-%d')"
    echo "Uzel: $(hostname -f)"
    echo "Scratch: $SCRATCHDIR"
    echo "Vstup: $RUN_INPUT_DIR"
    echo "Výstup: $FINAL_OUTPUT_DIR"
    echo "Array index: $PBS_ARRAY_INDEX"
} | tee -a "$JOB_LOG"

{
    echo "------------------------------------------------------------------"
    echo "Spouštím úlohu: $RUN_NUMBER / $BARCODE dne: $(date '+%Y-%m-%d')"
    echo "Uzel: $(hostname -f)"
    echo "Scratch adresář: $SCRATCHDIR"
    echo "Array index: $PBS_ARRAY_INDEX"
} >> "$CENTRAL_LOG"

echo "Kopíruji data na scratch..." | tee -a "$JOB_LOG"
cp "$BAM_FILE" .
cp "$BAI_FILE" .
cp "$REF_DIR"/reference_*kb.npz .

# Lokální názvy pro rychlejší výpočet
LOCAL_BAM=$(basename "$BAM_FILE")

# =============================================================================
# 4. PŘÍPRAVA PROSTŘEDÍ
# =============================================================================

echo "Inicializuji Mamba prostředí..." | tee -a "$JOB_LOG"
module load mambaforge
eval "$(conda shell.bash hook)"

set +u
if conda activate wisecondorX_env; then
    echo "--- Prostředí wisecondorX_env úspěšně aktivováno. ---" | tee -a "$JOB_LOG"
else
    echo "Prostředí nebylo nalezeno podle jména. Zkouším absolutní cestu..."
    if conda activate /auto/brno2/home/petraskkar/.conda/envs/wisecondorX_env; then
        echo "--- Prostředí úspěšně aktivováno pomocí absolutní cesty. ---" | tee -a "$JOB_LOG"
    else
        echo "KRITICKÁ CHYBA: Prostředí se nepodařilo aktivovat ani absolutní cestou!" >&2
        exit 1
    fi
fi
set -u

echo "--- Prostředí wisecondorX_env aktivováno. ---" | tee -a "$JOB_LOG"

# =============================================================================
# 5. SPUŠTĚNÍ ANALÝZY - CONVERT + PREDICT
# =============================================================================

echo "Start: ${BARCODE} z runu ${RUN_NUMBER}"

LOCAL_BAM=$(basename "$BAM_FILE")
TMP_BASE="${RUN_NUMBER}_${BARCODE}"
TMP_NPZ="${RUN_NUMBER}_${BARCODE}.npz"          # dočasný NPZ soubor ve scratchi - vstup

# KROK 1: Convert
echo "Krok 1: Convert BAM to NPZ pro ${BARCODE}" | tee -a "$JOB_LOG"
python3 $WORK_DIR/wisecondorx/main.py convert "./${LOCAL_BAM}" "./${TMP_BASE}"

# KROK 2: Predict
echo "Krok 2: Predict pro ${BARCODE}" | tee -a "$JOB_LOG"

for REF_SIZE in ${REF_SIZES}; do
    echo "--- Počítám rozlišení: ${REF_SIZE} kb ---" | tee -a "$JOB_LOG"
    
    CURRENT_REF="reference_${REF_SIZE}kb.npz"
    OUT_PLOTS_DIR="plots-Epi2me_${REF_SIZE}kb"
    mkdir -p "$OUT_PLOTS_DIR"
    PREFIX="${OUT_PLOTS_DIR}/${RUN_NUMBER}_${BARCODE}_${REF_SIZE}kb"
    # Výsledek bude např. plots_1000kb/run1_barcode05_1000kb

    # Výstup v PNG
    python3 $WORK_DIR/wisecondorx/main.py predict "./${TMP_NPZ}" "./${CURRENT_REF}" "${PREFIX}" \
        --plot \
        --bed \
        --ylim "-1.5 1.0"
done

echo "Hotovo: ${BARCODE}" | tee -a "$JOB_LOG"

# =============================================================================
# 6. KOPÍROVÁNÍ VÝSLEDKŮ
# =============================================================================

echo "Kopírování výsledků zpět na storage" | tee -a "$JOB_LOG"

mkdir -p "$FINAL_OUTPUT_DIR"
mkdir -p "$PLOTS_OUTPUT_DIR"

# Zkopíruje všechny tři složky s grafy do složky pro tento vzorek
cp -r plots-Epi2me_* "$FINAL_OUTPUT_DIR/"
cp "$JOB_LOG" "$FINAL_OUTPUT_DIR/Epi2me-wisecondorX_info.txt"

# Přesun pouze grafů do složky {RUN_OUTPUT_DIR}_plots
mv "$FINAL_OUTPUT_DIR/${RUN_NUMBER}_${BARCODE}" "$PLOTS_OUTPUT_DIR/"

# Záloha původního konvertovaného .npz do složky ALL_NPZ pro případné vytvoření nové reference
cp "$TMP_NPZ" "$NPZ_OUTPUT_DIR/"

# =============================================================================
# 7. KONTROLA ÚSPĚŠNÉHO ZKOPÍROVÁNÍ (pro všechna 3 rozlišení)
# =============================================================================
KOPIROVANI_OK=true

for REF_SIZE in ${REF_SIZES}; do
    # Zkontrolujeme existenci hlavního výsledkového souboru .bed v dané podsložce na storage
    if [ ! -s "$FINAL_OUTPUT_DIR/plots-Epi2me_${REF_SIZE}kb/${RUN_NUMBER}-Epi2me_${BARCODE}_${REF_SIZE}kb_aberrations.bed" ]; then
        KOPIROVANI_OK=false
    fi
done

if [ "$KOPIROVANI_OK" = true ] && [ -f "$FINAL_OUTPUT_DIR/Epi2me-wisecondorX_info.txt" ]; then
    {
        echo "Hotovo: $RUN_NUMBER / $BARCODE dne: $(date +%Y-%m-%d)"
        echo "Kopírování všech rozlišení úspěšné. Mažu scratch."
    } | tee -a "$FINAL_OUTPUT_DIR/Epi2me-wisecondorX_info.txt"
    clean_scratch
else
    echo "Chyba: Některé výsledky chybí, kopírování selhalo. Data zůstávají ve scratchi." | tee -a "$FINAL_OUTPUT_DIR/Epi2me-wisecondorX_info.txt" >&2
    exit 1
fi