#!/bin/bash
# =============================================================================
# 0. PBS PARAMETRY
# =============================================================================
#PBS -N SUP-WisecondorX_Analysis
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
    # data: cesta k nim: RESULTS/alignment_results/alignment_output_run1/run1-barcodeXX/.bam a .bam.bai
        # pokud spouštím tuto analýzu na data, u kterých nebylo spuštěno dorado, můžeš upravit cestu a nahrát je jinam
    # vytvoř složku wisecondorX a v ní:
        # 1. skript: skript_wisecondorX.sh 
        # 2. prostředí: environment.yml - pro vytvoření prostředí s verzemi knihoven, které se nebudou měnit (dobrá kooperace, stálé prostředí)
                # !! je třeba instalovat před spuštěním analýzy příkazem: conda install --file environment.yml
        # 3. reference - složka references - složka references_${DATUM} se soubory "reference_${REF_SIZE}kb.npz"
                # referenci mohu vytvořit pomocí skriptu newRef.sh
        # 4. složka wisecondorx (ke stažení na: https://github.com/kpetraskova147/WisecondorX-LAB-NIPT.git) a v ní:
               # ├── __init__.py
               # ├── main.py                 # <--- Spouštěcí bod programu
               # ├── convert_tools.py
               # ├── predict_control.py
               # ├── predict_tools.py
               # ├── ... (všechny ostatní .py soubory ze složky src/wisecondorx z oficiálního repozitáře: https://github.com/CenterForMedicalGeneticsGhent/wisecondorX)
        # 5. VOLITELNÉ: skript: uvod_kontrola.py - spíše pro mou kontrolu jestli mám vše připravené, nemusím spouštět
        # Terminál otevři ve složce wisecondorx, kde máš uložen tento skript (skript_wisecondorX.sh)

# Před spuštěním:
    # 1. Ve složce wisecondorX musíš mít: skript_wisecondorX.sh, environment.yml (+ uvod_kontrola.py - VOLITELNÉ)
    # 2. Uprav PBS -M a PBS -J podle počtu vzorků a svého emailu.
    # 3. Uprav ve 3. kapitole: BASE_DIR, INPUT_BAM_BAI_DIR, OUTPUT_DIR a REFERENCE podle své struktury dat.
    # 4. Uprav absolutní cestu k prostředí v části 4. PŘÍPRAVA PROSTŘEDÍ, pokud se ti nedaří aktivovat prostředí podle jména.
          # absolutní cesta - conda info --envs 
          # vyhledat wisecondorX_env a zkopírovat cestu, která je v 2.sloupci (např. /auto/brno2/home/petraskkar/.conda/envs/wisecondorX_env)
    # 5. Uprav ve 5. kapitole: SKLON a POSUN podle rovnice z Excelu (y = ax + b) z grafu poměru FF Y (Atila) vs Ratio (FF_ratio_from_length.sh).

# Spuštění: 
    # 0. pouze jednou - instalace prostředí: conda install --file environment.yml
    # (1. python3 uvod_kontrola.py - VOLITELNÉ, kontrola vstupních dat navíc a jestli mám vše zadané)
    # 2. qsub -v RUN_NUMBER="run1",DATUM="2026-03-26" skript_wisecondorX.sh

    # DATUM = datum u reference, kterou chci použít (vytvořeno pomocí skriptu newRef.sh) - např. 2026-03-26

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
mkdir -p "pbs_outputs"
set -euo pipefail
trap "clean_scratch" TERM EXIT

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: RUN_NUMBER není nastaven." >&2
    exit 1
fi

if [ -z "${DATUM:-}" ]; then
    echo "Chyba: DATUM není nastaveno." >&2
    exit 1
fi

if [ -z "${PBS_ARRAY_INDEX:-}" ]; then
    echo "Chyba: PBS_ARRAY_INDEX není nastaven." >&2
    exit 1
fi

BARCODE=$(printf "barcode%02d" "$PBS_ARRAY_INDEX")
export BARCODE

export ANALYSIS_TYPE="SUP"

SAMPLE_NAME="${RUN_NUMBER}-sup_${BARCODE}"

# =============================================================================
# 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST)
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar"
WORK_DIR="$BASE_DIR/wisecondorX"

mkdir -p "$WORK_DIR/pbs_outputs"

INPUT_BAM_DIR="$BASE_DIR/RESULTS/sup-alignment_results"
RUN_INPUT_DIR="$INPUT_BAM_DIR/sup-alignment_output_${RUN_NUMBER}"
BAM_FILE="$RUN_INPUT_DIR/$SAMPLE_NAME.bam"
BAI_FILE="$RUN_INPUT_DIR/$SAMPLE_NAME.bam.bai"

HIST_FOLDER="$BASE_DIR/RESULTS/sup-statistics_results/sup-statistics_output_${RUN_NUMBER}/$SAMPLE_NAME"
HIST_FILE="$HIST_FOLDER/lengths_$SAMPLE_NAME.txt"
NANOSTAT_FILE="$HIST_FOLDER/nanostat_$SAMPLE_NAME.txt"

REF_DIR="$WORK_DIR/references/reference_${DATUM}"
REF_SIZES="1000 500 100"

OUTPUT_DIR="$BASE_DIR/RESULTS"
RUN_OUTPUT_DIR="$OUTPUT_DIR/sup-wisecondorX_results/wisecondorX_output_${RUN_NUMBER}-sup"
FINAL_OUTPUT_DIR="$RUN_OUTPUT_DIR/$SAMPLE_NAME"
PLOTS_OUTPUT_DIR="$RUN_OUTPUT_DIR/PLOTS_$SAMPLE_NAME"
EVALUATION_DIR="$OUTPUT_DIR/1-EVALUATION_sup/${RUN_NUMBER}_evaluation-sup/$SAMPLE_NAME"
PLOTS_EVALUATION="$EVALUATION_DIR/PLOTS_${RUN_NUMBER}_sup"

NPZ_OUTPUT_DIR="$WORK_DIR/sup-ALL_NPZ"
RUN_LOG_DIR="$WORK_DIR/run_logs"
CENTRAL_LOG="$RUN_LOG_DIR/wisecondorX_history-sup.txt"

ENVIRONMENT_PATH="/storage/brno12-cerit/home/petraskkar/conda_envs/wisecondorX_env"
STORAGE_WISE_ENV="/storage/brno12-cerit/home/petraskkar/wisecondorX/WisecondorX-LAB-NIPT/wisecondorx"

mkdir -p "$OUTPUT_DIR" "$RUN_OUTPUT_DIR" "$NPZ_OUTPUT_DIR" "$RUN_LOG_DIR"

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
JOB_LOG="$SCRATCHDIR/wisecondorX_info_sup.txt"

{
    echo "------------------------------------------------------------------"
    echo "Run: $RUN_NUMBER | Barcode: $BARCODE | Datum: $(date '+%Y-%m-%d')"
    echo "Uzel: $(hostname -f) | Scratch: $SCRATCHDIR"
    echo "Vstup: $RUN_INPUT_DIR | Výstup: $FINAL_OUTPUT_DIR"
    echo "Array index: $PBS_ARRAY_INDEX"
} | tee -a "$JOB_LOG"

echo "Spouštím úlohu: $RUN_NUMBER / $BARCODE dne: $(date '+%Y-%m-%d')" >> "$CENTRAL_LOG"

cp "$BAM_FILE" .
cp "$BAI_FILE" .
cp "$REF_DIR"/reference_*kb.npz .

LOCAL_BAM=$(basename "$BAM_FILE")

# =============================================================================
# 4. PŘÍPRAVA PROSTŘEDÍ
# =============================================================================
module load mambaforge
eval "$(conda shell.bash hook)"

set +u
if conda activate wisecondorX_env; then
    echo "--- Prostředí wisecondorX_env úspěšně aktivováno. ---" | tee -a "$JOB_LOG"
else
    if conda activate $ENVIRONMENT_PATH; then
        echo "--- Prostředí úspěšně aktivováno pomocí absolutní cesty. ---" | tee -a "$JOB_LOG"
    else
        echo "KRITICKÁ CHYBA: Prostředí se nepodařilo aktivovat!" >&2
        exit 1
    fi
fi
set -u

# =============================================================================
# 5. SPUŠTĚNÍ ANALÝZY - CONVERT + PREDICT
# =============================================================================
TMP_BASE="$SAMPLE_NAME"
TMP_NPZ="$SAMPLE_NAME.npz"          

python3 "${STORAGE_WISE_ENV}/main.py" convert "./${LOCAL_BAM}" "./${TMP_BASE}"

if [ -f "$HIST_FILE" ]; then
    RATIO=$(awk '{ 
        if ($1 == "RL") { len = $2; count = $3 }
        else if ($1 ~ /^[0-9]+$/) { len = $1; count = $3 }
        else { len = 0; count = 0 }
        if(len >= 100 && len <= 150) { short += count } 
        else if(len >= 160 && len <= 200) { long += count } 
    } 
    END { 
        if(long > 0) { printf "%.4f", short / long } 
        else { printf "0.0000" } 
    }' "$HIST_FILE")
else
    echo "KRITICKÁ CHYBA: Soubor $HIST_FILE nebyl nalezen!" | tee -a "$JOB_LOG"
    exit 1
fi

SKLON="0.5015"  
POSUN="-0.0565"  

MY_FF=$(awk -v r="$RATIO" -v s="$SKLON" -v p="$POSUN" 'BEGIN { 
    raw_ff = (r * s) + p; 
    if(raw_ff < 0) raw_ff = 0; 
    ff_percent = raw_ff * 100; 
    if(ff_percent < 0) ff_percent = 0;
    printf "%.2f", ff_percent
}')

echo ">> Zjištěný poměr (Ratio): $RATIO | Vypočítaná fetální frakce: ${MY_FF} %" | tee -a "$JOB_LOG"

RAW_READS=$(grep "Number of reads:" "$NANOSTAT_FILE" | awk '{print $4}' | sed 's/,//g' | cut -d'.' -f1)
MED_LEN=$(grep "Median read length:" "$NANOSTAT_FILE" | awk '{print $4}' | cut -d'.' -f1)
MED_QUAL=$(grep "Median read quality:" "$NANOSTAT_FILE" | awk '{print $4}' | cut -d'.' -f1)
AVG_IDENTITY=$(grep "Average percent identity:" "$NANOSTAT_FILE" | awk '{print $4}') 

POOR_ACCURACY=$(awk -v id="$AVG_IDENTITY" 'BEGIN { if(id < 96.8) print 1; else print 0 }') 
SEQ_QC_STATUS="PASS"

if [ "$RAW_READS" -lt 3000000 ]; then
    SEQ_QC_STATUS="FAIL (Low Reads)"
elif [ "$MED_LEN" -lt 140 ] || [ "$MED_LEN" -gt 250 ]; then
    SEQ_QC_STATUS="FAIL (Contamination)"
elif [ "$MED_QUAL" -lt 15 ]; then
    SEQ_QC_STATUS="FAIL (Poor Quality)"
elif [ "$POOR_ACCURACY" -eq 1 ]; then
    SEQ_QC_STATUS="FAIL (Poor Accuracy)"
fi

export SEQ_QC_STATUS AVG_IDENTITY CURRENT_FF="$MY_FF" LEGEND_PLACEMENT="bottom"

for REF_SIZE in ${REF_SIZES}; do
    CURRENT_REF="reference_${REF_SIZE}kb.npz"
    OUT_PLOTS_DIR="plots_${REF_SIZE}kb"
    mkdir -p "$OUT_PLOTS_DIR"
    PREFIX="${OUT_PLOTS_DIR}/${SAMPLE_NAME}_${REF_SIZE}kb"

    python3 "${STORAGE_WISE_ENV}/main.py" predict "./${TMP_NPZ}" "./${CURRENT_REF}" "${PREFIX}" \
        --plot \
        --bed \
        --ylim "-1.5 1.0"
done

unset CURRENT_FF

# =============================================================================
# 6. KOPÍROVÁNÍ VÝSLEDKŮ
# =============================================================================

echo "Kopírování výsledků zpět na storage" | tee -a "$JOB_LOG"

mkdir -p "$FINAL_OUTPUT_DIR"
mkdir -p "$PLOTS_OUTPUT_DIR"
mkdir -p "$EVALUATION_DIR"
mkdir -p "$PLOTS_EVALUATION"

# 1. Přesun a přejmenování celých složek s grafy + přesun aberration.bed
for REF_SIZE in ${REF_SIZES}; do
    # Názvy, jak je vygeneroval WisecondorX ve scratchi
    ORIG_PLOTS="plots_${REF_SIZE}kb/${SAMPLE_NAME}_${REF_SIZE}kb.plots"
    ORIG_BED="plots_${REF_SIZE}kb/${SAMPLE_NAME}_${REF_SIZE}kb_aberrations.bed"

    # Pokud složka s grafy existuje, přesune se celá a rovnou se přejmenuje
    if [ -d "$ORIG_PLOTS" ]; then
        mv "$ORIG_PLOTS" "$PLOTS_OUTPUT_DIR/${REF_SIZE}kb-${SAMPLE_NAME}.plots"
    fi

    # Přesun genome_wide.png - 1000kb do více přístupné složky
    if [ "$REF_SIZE" == "1000" ] && [ -f "$PLOTS_OUTPUT_DIR/1000kb-${SAMPLE_NAME}.plots/genome_wide.png" ]; then
        mv "$PLOTS_OUTPUT_DIR/1000kb-${SAMPLE_NAME}.plots/genome_wide.png" "$EVALUATION_DIR/1000kb_genome-${SAMPLE_NAME}.png"
    fi

    if [ -d "$PLOTS_OUTPUT_DIR/${REF_SIZE}kb-${SAMPLE_NAME}.plots" ]; then
        mv "$PLOTS_OUTPUT_DIR/${REF_SIZE}kb-${SAMPLE_NAME}.plots" "$PLOTS_EVALUATION"
    fi

    # Přesun souboru aberrations.bed (název zůstává stejný)
    if [ -f "$ORIG_BED" ]; then
        mv "$ORIG_BED" "$EVALUATION_DIR/${SAMPLE_NAME}_${REF_SIZE}kb_aberrations.bed"
    fi
done

# 2. Zkopíruje zbytek dat do hlavní výstupní složky pro tento vzorek
cp -r plots_* "$FINAL_OUTPUT_DIR/"
cp "$JOB_LOG" "$FINAL_OUTPUT_DIR/wisecondorX_info-sup.txt"

# Záloha původního konvertovaného .npz pro případné vytvoření nové reference
cp "$TMP_NPZ" "$NPZ_OUTPUT_DIR/"

# Přesun dat ze statistiky do evaluation složky
cp "${NANOSTAT_FILE}" "$EVALUATION_DIR/"
cp "${HIST_FOLDER}/plots_${SAMPLE_NAME}/cfDNA-sup_log_histogram.png" "$EVALUATION_DIR/cfDNA-length-${SAMPLE_NAME}.png"
cp "${HIST_FOLDER}/plots_${SAMPLE_NAME}/NanoPlot-report-sup.html" "$EVALUATION_DIR/NanoPlot-report-${SAMPLE_NAME}.html"

# =============================================================================
# 7. KONTROLA ÚSPĚŠNÉHO ZKOPÍROVÁNÍ (pro všechna 3 rozlišení)
# =============================================================================
KOPIROVANI_OK=true

# 1. Kontrola pro různé REF_SIZES
for REF_SIZE in ${REF_SIZES}; do
    # Kontrolujeme aberrations.bed v jeho NOVÉM umístění ve složce EVALUATION
    if [ ! -s "$EVALUATION_DIR/${SAMPLE_NAME}_${REF_SIZE}kb_aberrations.bed" ]; then
        KOPIROVANI_OK=false
    fi
done

# Kontrola dalších souborů
STATIC_FILES=(
    "$EVALUATION_DIR/1000kb_genome-${SAMPLE_NAME}.png"
    "$EVALUATION_DIR/cfDNA-length-${SAMPLE_NAME}.png"
    "$EVALUATION_DIR/nanostat_${SAMPLE_NAME}.txt"
    "$EVALUATION_DIR/NanoPlot-report-${SAMPLE_NAME}.html"
    )
    
for CHECK_FILES in "${STATIC_FILES[@]}"; do
    if [ ! -f "$CHECK_FILES" ]; then
        KOPIROVANI_OK=false
        echo "Chybí soubor: $(basename "$CHECK_FILES")" >> "$FINAL_OUTPUT_DIR/wisecondorX_info-sup.txt"
    fi
done

if [ "$KOPIROVANI_OK" = true ] && [ -f "$FINAL_OUTPUT_DIR/wisecondorX_info-sup.txt" ]; then
    {
        echo "Hotovo: $RUN_NUMBER / $BARCODE dne: $(date +%Y-%m-%d)"
        echo "Kopírování všech výsledků úspěšné. Mažu scratch."
    } | tee -a "$FINAL_OUTPUT_DIR/wisecondorX_info-sup.txt"
    
    clean_scratch
else
    echo "KRITICKÁ CHYBA: Některé výsledky chybí, kopírování selhalo. Data zůstávají chráněna ve scratchi!" | tee -a "$FINAL_OUTPUT_DIR/wisecondorX_info-sup.txt" >&2
    exit 1
fi