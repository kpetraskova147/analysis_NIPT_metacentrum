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
set -euo pipefail
trap "clean_scratch" TERM EXIT   # přísnější režim pro lepší detekci chyb, -e: skript se zastaví při jakékoliv chybě, -u: chyba při použití nedefinované proměnné, -o pipefail: chyba v jakékoliv části pipy způsobí selhání celé pipy

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
RUN_INPUT_DIR="$BASE_DIR/${RUN_NUMBER}-newref-bam,bai"
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

# Cesta k hist souboru pro aktuální vzorek
HIST_FOLDER="$BASE_DIR/RESULTS/Epi2me-statistics_results/Epi2me-statistics_output_${RUN_NUMBER}/${BARCODE}-histograms"
HIST_FILE="$HIST_FOLDER/length.hist"

# Logy
RUN_LOG_DIR="$WORK_DIR/Epi2me-run_logs"
CENTRAL_LOG="$RUN_LOG_DIR/Epi2me-wisecondorX_history.txt"

# Cesta k prostředí mambaforge, kde je nainstalován WisecondorX - lze zjistit příkazem `conda info --envs` nebo `conda env list` - najdu wisecondorX_env
ENVIRONMENT_PATH="/storage/brno12-cerit/home/petraskkar/conda_envs/wisecondorX_env"

# Cesta k hlavnímu skriptu WisecondorX (main.py) v prostředí wisecondorX_env
STORAGE_WISE_ENV="/storage/brno12-cerit/home/petraskkar/wisecondorX/WisecondorX-LAB-NIPT/wisecondorx"

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
    if conda activate $ENVIRONMENT_PATH; then
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
python3 "${STORAGE_WISE_ENV}/main.py" convert "./${LOCAL_BAM}" "./${TMP_BASE}"

# KROK 2: Predict
echo "Krok 2: Predict pro ${BARCODE}" | tee -a "$JOB_LOG"

if [ -f "$HIST_FILE" ]; then
    # Chytré vytažení Ratia (zvládá hlavičku "RL" i starý formát)
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
    echo "KRITICKÁ CHYBA: Soubor $HIST_FILE nebyl nalezen! Analýza pro vzorek $BARCODE se ukončuje." | tee -a "$JOB_LOG"
    exit 1
fi

echo ">> Zjištěný poměr (Ratio): $RATIO" | tee -a "$JOB_LOG"

# -----------------------------------------------------------------------------
# ZDE ZADEJ ROVNICI Z EXCELU (y = ax + b)
# Příklad: Pokud v Excelu vyšlo y = 25.4x - 5.2, zadej SKLON="25.4" a POSUN="-5.2"
# -----------------------------------------------------------------------------
SKLON="0.5015"   # Doplň reálné číslo (a)
POSUN="-0.0565"   # Doplň reálné číslo (b)

# Matematický výpočet samotné FF (přes awk, pro práci s desetinnými čísly)
MY_FF=$(awk -v r="$RATIO" -v s="$SKLON" -v p="$POSUN" 'BEGIN { 
    raw_ff = (r * s) + p; 
    if(raw_ff < 0) raw_ff = 0;     # Pojistka proti záporným číslům
    ff_percent = raw_ff * 100;      # Převod na procenta
    if(ff_percent < 0) ff_percent = 0;
    printf "%.2f", ff_percent
}')

echo ">> Zjištěný poměr (Ratio): $RATIO" | tee -a "$JOB_LOG"
echo ">> Vypočítaná fetální frakce: ${MY_FF} %" | tee -a "$JOB_LOG"

# EXPORT DO SYSTÉMU (Tímto se hodnota předá upravenému python skriptu)

# 1. Extract the three critical metrics using awk
# We remove commas and decimals to allow Bash integer comparison
RAW_READS=$(grep "Number of reads:" "$NANOSTAT_FILE" | awk '{print $4}' | sed 's/,//g' | cut -d'.' -f1)
MED_LEN=$(grep "Median read length:" "$NANOSTAT_FILE" | awk '{print $4}' | cut -d'.' -f1)
MED_QUAL=$(grep "Median read quality:" "$NANOSTAT_FILE" | awk '{print $4}' | cut -d'.' -f1)
AVG_IDENTITY=$(grep "Average percent identity:" "$NANOSTAT_FILE" | awk '{print $4}') 

# 2. Evaluate against thresholds
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

echo ">> Sequencing QC Status: $SEQ_QC_STATUS" | tee -a "$JOB_LOG"
echo ">> Basecalling Accuracy: $AVG_IDENTITY %" | tee -a "$JOB_LOG"

# 3. Export to environment for Python/R to pick up
export SEQ_QC_STATUS
export AVG_IDENTITY 

export CURRENT_FF="$MY_FF"

# Zvol rozložení legendy: "bottom" (pod boxplotem) nebo "right" (vpravo vedle boxplotu)
export LEGEND_PLACEMENT="bottom"

for REF_SIZE in ${REF_SIZES}; do
    echo "--- Počítám rozlišení: ${REF_SIZE} kb ---" | tee -a "$JOB_LOG"
    
    CURRENT_REF="reference_${REF_SIZE}kb.npz"
    OUT_PLOTS_DIR="plots_${REF_SIZE}kb"
    mkdir -p "$OUT_PLOTS_DIR"
    PREFIX="${OUT_PLOTS_DIR}/${RUN_NUMBER}_${BARCODE}_${REF_SIZE}kb"
    # Výsledek bude např. plots_1000kb/run1_barcode05_1000kb

    # Výstup v PNG
    python3 "${STORAGE_WISE_ENV}/main.py" predict "./${TMP_NPZ}" "./${CURRENT_REF}" "${PREFIX}" \
        --plot \
        --bed \
        --ylim "-1.5 1.0"
    # Volání mého R skriptu pro vykreslení grafů
    done

unset CURRENT_FF

echo "Hotovo: ${BARCODE}" | tee -a "$JOB_LOG"

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
    ORIG_PLOTS="plots_${REF_SIZE}kb/${RUN_NUMBER}_${BARCODE}_${REF_SIZE}kb.plots"
    ORIG_BED="plots_${REF_SIZE}kb/${RUN_NUMBER}_${BARCODE}_${REF_SIZE}kb_aberrations.bed"

    # Pokud složka s grafy existuje, přesune se celá a rovnou se přejmenuje
    if [ -d "$ORIG_PLOTS" ]; then
        mv "$ORIG_PLOTS" "$PLOTS_OUTPUT_DIR/${REF_SIZE}kb_${RUN_NUMBER}_${BARCODE}.plots"
    fi

    # Přesun genome_wide.png - 1000kb do více přístupné složky
    if [ "$REF_SIZE" == "1000" ] && [ -f "$PLOTS_OUTPUT_DIR/1000kb_${RUN_NUMBER}_${BARCODE}.plots/genome_wide.png" ]; then
        mv "$PLOTS_OUTPUT_DIR/1000kb_${RUN_NUMBER}_${BARCODE}.plots/genome_wide.png" "$EVALUATION_DIR/1000kb_genome_${RUN_NUMBER}_${BARCODE}.png"
    fi
    
    if [ -d "$PLOTS_OUTPUT_DIR/${REF_SIZE}kb_${RUN_NUMBER}_${BARCODE}.plots" ]; then
        mv "$PLOTS_OUTPUT_DIR/${REF_SIZE}kb_${RUN_NUMBER}_${BARCODE}.plots" "$PLOTS_EVALUATION"
    fi

    # Přesun souboru aberrations.bed (název zůstává stejný)
    if [ -f "$ORIG_BED" ]; then
        mv "$ORIG_BED" "$EVALUATION_DIR"
    fi
done

# 2. Zkopíruje zbytek dat do hlavní výstupní složky pro tento vzorek
cp -r plots_* "$FINAL_OUTPUT_DIR/"
cp "$JOB_LOG" "$FINAL_OUTPUT_DIR/wisecondorX_info.txt"

# Záloha původního konvertovaného .npz pro případné vytvoření nové reference
cp "$TMP_NPZ" "$NPZ_OUTPUT_DIR/"

# Přesun dat ze statistiky do evaluation složky
cp "${NANOSTAT_FILE}" "$EVALUATION_DIR/"
cp "${HIST_FOLDER}/plots_${RUN_NUMBER}_${BARCODE}/cfDNA_log_histogram.png" "$EVALUATION_DIR/cfDNA_length_${RUN_NUMBER}_${BARCODE}.png"
cp "${HIST_FOLDER}/NanoPlot-report.html" "$EVALUATION_DIR/NanoPlot-report_${RUN_NUMBER}_${BARCODE}.html"

# =============================================================================
# 7. KONTROLA ÚSPĚŠNÉHO ZKOPÍROVÁNÍ (pro všechna 3 rozlišení)
# =============================================================================
KOPIROVANI_OK=true

# 1. Kontrola pro různé REF_SIZES
for REF_SIZE in ${REF_SIZES}; do
    # Kontrolujeme aberrations.bed v jeho NOVÉM umístění ve složce EVALUATION
    if [ ! -s "$EVALUATION_DIR/${RUN_NUMBER}_${BARCODE}_${REF_SIZE}kb_aberrations.bed" ]; then
        KOPIROVANI_OK=false
    fi
done

# Kontrola dalších souborů
STATIC_FILES=(
    "$EVALUATION_DIR/1000kb_genome_${RUN_NUMBER}_${BARCODE}.png"
    "$EVALUATION_DIR/cfDNA_length_${RUN_NUMBER}_${BARCODE}.png"
    "$EVALUATION_DIR/nanostat_${RUN_NUMBER}_${BARCODE}.txt"
    "$EVALUATION_DIR/NanoPlot-report.html"
    )
    
for CHECK_FILES in "${STATIC_FILES[@]}"; do
    if [ ! -f "$CHECK_FILES" ]; then
        KOPIROVANI_OK=false
        echo "Chybí soubor: $(basename "$CHECK_FILES")" >> "$FINAL_OUTPUT_DIR/wisecondorX_info.txt"
    fi
done

if [ "$KOPIROVANI_OK" = true ] && [ -f "$FINAL_OUTPUT_DIR/wisecondorX_info.txt" ]; then
    {
        echo "Hotovo: $RUN_NUMBER / $BARCODE dne: $(date +%Y-%m-%d)"
        echo "Kopírování všech výsledků úspěšné. Mažu scratch."
    } | tee -a "$FINAL_OUTPUT_DIR/wisecondorX_info.txt"
    
    clean_scratch
else
    echo "KRITICKÁ CHYBA: Některé výsledky chybí, kopírování selhalo. Data zůstávají chráněna ve scratchi!" | tee -a "$FINAL_OUTPUT_DIR/wisecondorX_info.txt" >&2
    exit 1
fi