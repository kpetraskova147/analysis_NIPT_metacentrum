#!/bin/bash
# =============================================================================
# 0. PBS PARAMETRY
# =============================================================================
#PBS -N WX_SeqFF_Analysis
#PBS -l select=1:ncpus=9:mem=32gb:scratch_local=20gb
#PBS -l walltime=6:00:00
#PBS -j oe
#PBS -m ae
#PBS -M petraskkar@natur.cuni.cz
#PBS -J 1-24

# =============================================================================
# 1. NASTAVENÍ (UPRAV POUZE TUTO ČÁST)
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar"
WORK_DIR="$BASE_DIR/wisecondorX"

# Názvy prostředí (podle kamaráda)
ENV_WISE="wisecondorX"
ENV_SEQFF="seqff_env"  # Pokud ho máš vytvořené
SEQFF_SCRIPT="$WORK_DIR/seqff.r"

# Vstupy a výstupy
INPUT_BAM_DIR="$BASE_DIR/RESULTS/alignment_results/alignment_output_${RUN_NUMBER}"
OUTPUT_DIR="$BASE_DIR/RESULTS/wisecondorX_results/wisecondorX_output_${RUN_NUMBER}"

# =============================================================================
# 2. PŘÍPRAVA A KONTROLA
# =============================================================================
set -euo pipefail

BARCODE=$(printf "barcode%02d" "$PBS_ARRAY_INDEX")
RUN_INPUT_DIR="$INPUT_BAM_DIR/$BARCODE"
BAM_FILE="$RUN_INPUT_DIR/${RUN_NUMBER}_${BARCODE}.bam"

# Kontrola, zda existuje BAM
if [ ! -s "$BAM_FILE" ]; then echo "CHYBA: $BAM_FILE chybí!" >&2; exit 1; fi

# Vytvoření složek na storage
FINAL_OUTPUT_DIR="$OUTPUT_DIR/${RUN_NUMBER}_${BARCODE}"
mkdir -p "$FINAL_OUTPUT_DIR"
mkdir -p "$WORK_DIR/pbs_outputs"

# Přesun na scratch a kopírování
cd "$SCRATCHDIR"
cp "$BAM_FILE" .
cp "$BAM_FILE.bai" . 2>/dev/null || echo "BAI chybí, ale snad to projde..."
cp "$WORK_DIR/references/reference_${DATUM}/reference_"*kb.npz .

LOCAL_BAM=$(basename "$BAM_FILE")
TMP_BASE="${RUN_NUMBER}_${BARCODE}_run"
TMP_NPZ="${TMP_BASE}.npz"
JOB_LOG="wisecondorX_info.txt"

# Inicializace Condy
module load mambaforge
eval "$(conda shell.bash hook)"

# =============================================================================
# 3. KROK 1: SeqFF (Pokud existuje skript i prostředí)
# =============================================================================
if [ -f "$SEQFF_SCRIPT" ]; then
    echo "Spouštím SeqFF..." | tee -a "$JOB_LOG"
    # Zkopírujeme si seqff.r k sobě na scratch (i s .rdata soubory pokud tam jsou)
    cp "$WORK_DIR"/*.rdata . 2>/dev/null || true
    
    set +u
    if conda activate "$ENV_SEQFF"; then
        Rscript "$SEQFF_SCRIPT" --hg38 -f "$LOCAL_BAM" -o "${RUN_NUMBER}_${BARCODE}_seqff.txt" >> "$JOB_LOG" 2>&1 || echo "SeqFF selhalo."
    fi
    set -u
fi

# =============================================================================
# 4. KROK 2: WisecondorX (Convert + Predict)
# =============================================================================
conda activate "$ENV_WISE"

echo "Spouštím WisecondorX Convert..." | tee -a "$JOB_LOG"
# Convert automaticky přidá .npz k TMP_BASE
WisecondorX convert "$LOCAL_BAM" "$TMP_BASE" >> "$JOB_LOG" 2>&1

sync && sleep 5 # Pojistka proti lagu disku

for REF_SIZE in 1000 500 100; do
    echo "--- Predict rozlišení: ${REF_SIZE} kb ---" | tee -a "$JOB_LOG"
    
    REF_FILE="reference_${REF_SIZE}kb.npz"
    OUT_DIR="plots_${REF_SIZE}kb"
    mkdir -p "$OUT_DIR"
    PREFIX="${OUT_DIR}/${RUN_NUMBER}_${BARCODE}_${REF_SIZE}kb"

    if [ -f "$TMP_NPZ" ]; then
        WisecondorX predict "$TMP_NPZ" "$REF_FILE" "$PREFIX" \
            --plot --bed --ylim "-1.5 1.5" >> "$JOB_LOG" 2>&1
    else
        echo "CHYBA: $TMP_NPZ neexistuje, Predict nelze spustit!" >> "$JOB_LOG"
    fi
done

# =============================================================================
# 5. KOPÍROVÁNÍ VÝSLEDKŮ ZPĚT
# =============================================================================
echo "Kopíruji výsledky na storage..." | tee -a "$JOB_LOG"
cp -r plots_* "$FINAL_OUTPUT_DIR/"
cp *.txt "$FINAL_OUTPUT_DIR/" 2>/dev/null || true # SeqFF a logy
cp "$TMP_NPZ" "$WORK_DIR/ALL_NPZ/" 2>/dev/null || true

# Finální úklid
clean_scratch