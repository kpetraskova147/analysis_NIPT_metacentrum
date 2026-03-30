#!/bin/bash
# =============================================================================
# PBS HLAVIČKA - STATISTIKY - debian11 (starší verze metacentra - pro mosdepth a nanostat)
# =============================================================================
#PBS -N Stats_Mosdepth_Nano
#PBS -l select=1:ncpus=8:mem=16gb:scratch_local=40gb:os=debian11
#PBS -l walltime=2:00:00
#PBS -q default
#PBS -j oe
#PBS -m ae
#PBS -M petraskkar@natur.cuni.cz
#PBS -J 1-24
#PBS -o /storage/brno12-cerit/home/petraskkar/alignment/pbs_outputs_statistics/

# =============================================================================
# INSTRUKCE
# =============================================================================
        # Vytvoř si složku alignment a v ní:
        # 1. SKRIPT: 'statistics_alignment.sh'
        # Nastavení: upravím cesty v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).
        #          : upravím PBS -J pro počet vzorků (1-24 = 24 vzorků), které chci zpracovat a mailovou adresu pro notifikace.
        #          : upravím PBS -o pro uložení výstupů z PBS do složky pbs_outputs
        #          : upravím PBS -M - mailová adresa pro zaslání mailu při ukončení nebo selhání úlohy (nastav svou mailovou adresu)

        # Spuštění: qsub -v RUN_NUMBER="run1" statistics_alignment.sh

        # MULTIQC
        # Po doběhnutí analýzu mohu spustit MultiQC pro přehled všech vzorků: multiqc . -o multiqc_report (spustím v OUTPUT_DIR, kde jsou všechny výsledky z jednotlivých vzorků)
        # MultiQC se podívá do všech podsložek, najde tam mosdepth summary a nanostat a vytvoří přehledný report s grafy pro všechny vzorky v jednom souboru (multiqc_report.html).
        # Spuštění MultiQC:
        # 1. Přejdu do složky s výsledky (OUTPUT_DIR) - cd /storage/brno12-cerit/home/petraskkar/RESULTS/alignment/alignment_output_run1 
        # 2. Načtu program: module add multiqc
        # 3. Spustím: multiqc .


# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
mkdir -p "pbs_outputs_statistics"
set -euo pipefail

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: RUN_NUMBER není nastaven." >&2
    echo "Spuštění: qsub -v RUN_NUMBER=run1 statistics_alignment.sh" >&2
    exit 1
fi
if [ -z "${PBS_ARRAY_INDEX:-}" ]; then
    echo "Chyba: PBS_ARRAY_INDEX není nastaven." >&2
    exit 1
fi

BARCODE=$(printf "barcode%02d" "$PBS_ARRAY_INDEX")

# =============================================================================
# 1. NASTAVENÍ UŽIVATELE A CEST
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar"

# Vstup nyní bere z minulé složky alignmentu (BAM soubory)
BAM_INPUT_DIR="$BASE_DIR/RESULTS/alignment_results/alignment_output_${RUN_NUMBER}/$BARCODE"
INPUT_BAM="$BAM_INPUT_DIR/${RUN_NUMBER}_${BARCODE}.bam"
INPUT_BAI="$BAM_INPUT_DIR/${RUN_NUMBER}_${BARCODE}.bam.bai"

# Výsledky ze statistiky
STATS_OUTPUT_DIR="$BASE_DIR/RESULTS/statistics_results"
RUN_STATS_OUTPUT_DIR="$STATS_OUTPUT_DIR/statistics_output_${RUN_NUMBER}"
FINAL_stats_OUTPUT_DIR="$RUN_STATS_OUTPUT_DIR/$BARCODE"

LOG_DIR="$BASE_DIR/alignment/statistics_run_logs"
CENTRAL_LOG="$LOG_DIR/alignment_statistics_history.txt"

mkdir -p "$LOG_DIR" 
mkdir -p "$STATS_OUTPUT_DIR" 
mkdir -p "$RUN_STATS_OUTPUT_DIR"

# =============================================================================
# 2. KONTROLA VSTUPNÍCH DAT A PROSTŘEDÍ
# =============================================================================
if [ ! -s "$INPUT_BAM" ]; then
    echo "CHYBA: BAM soubor neexistuje! (Byl alignment úspěšný?)" | tee -a $CENTRAL_LOG
    exit 1
fi

if [ ! -s "$INPUT_BAI" ]; then
    echo "CHYBA: BAI soubor neexistuje! (Byl alignment úspěšný?)" | tee -a $CENTRAL_LOG
    exit 1
fi

if [ -z "${SCRATCHDIR:-}" ]; then
    echo "Chyba: SCRATCHDIR není nastaven." >&2
    exit 1
fi

SAMPLE_NAME="${RUN_NUMBER}_${BARCODE}"

# =============================================================================
# 3. PŘÍPRAVA PROSTŘEDÍ (Zde už vše na Debianu 11 projde hladce)
# =============================================================================
module add samtools
module add mosdepth
module add nanostat

# =============================================================================
# 4. PŘESUN DO SCRATCHE
# =============================================================================
cd "$SCRATCHDIR"
JOB_LOG="$SCRATCHDIR/statistics_alignment_info.txt"
echo "[1/3] Kopíruji BAM a BAI do scratche..." > "$JOB_LOG"

cp "$INPUT_BAM" ./
cp "$INPUT_BAI" ./

TMP_BAM="./$(basename "$INPUT_BAM")"
TMP_BAI="./$(basename "$INPUT_BAI")"

# Logování pro kontrolu - logovací soubor bude obsahovat informace o spuštění úlohy, uzlu a cestě ke scratchi
# 1. Centrální logovací soubor pro všechny úlohy v hlavní složce
{
    echo "------------------------------------------------------------------"
    echo "ALIGNMENT_STATISTICS:Spouštím úlohu: $RUN_NUMBER / $BARCODE dne: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch adresář: $SCRATCHDIR"
    echo "Array index: $PBS_ARRAY_INDEX"
    echo "Referenční genom: $(basename $REF_GENOME)"
} >> "$CENTRAL_LOG"

# 2. Logovací soubor specifický pro tuto úlohu ve scratchi - smaže se po úspěšném dokončení, ale pokud dojde k chybě, zůstane pro kontrolu
{
    echo "------------------------------------------------------------------"
    echo "ALIGNMENT_STATISTICS:Run: $RUN_NUMBER"
    echo "Barcode: $BARCODE"
    echo "Datum: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch: $SCRATCHDIR"
    echo "Vstup: $INPUT_FILE"
    echo "Výstup: $FINAL_bam_OUTPUT_DIR & $FINAL_stats_OUTPUT_DIR"
    echo "Array index: $PBS_ARRAY_INDEX"
    echo "Referenční genom: $(basename $REF_GENOME)"
} | tee -a "$JOB_LOG"

# =============================================================================
# 5. GENERAVÁNÍ DAT PRO STATISTIKU
# =============================================================================
echo "[2/3] Počítám a rozděluji statistiky..." | tee -a "$JOB_LOG"

# --- A) STATISTIKY PRO FETÁLNÍ FRAKCI ---
samtools stats "$TMP_BAM" > full_stats.tmp
grep "^RL" full_stats.tmp > ${SAMPLE_NAME}lengths.txt
grep -E "^(SN|CO|FFQ)" full_stats.tmp > ${SAMPLE_NAME}_quality_coverage.txt

# --- B) OBECNÉ STATISTIKY KVALITY (NanoStat a Mosdepth) ---
NanoStat --bam "$TMP_BAM" -t 8 > "${SAMPLE_NAME}_nanostat.txt"
mosdepth -n -t 8 "${SAMPLE_NAME}_coverage" "$TMP_BAM"

# popis:
# SN (Summary - obsahuje error rate/accuracy)
# CO (Coverage - pokrytí)
# FFQ (Quality - kvalita prvního fragmentu)
# NanoStat (vytvoří soubor s celkovým přehledem kvality readů)
# Mosdepth (vytvoří soubory s výpočtem pokrytí pro MultiQC)

# =============================================================================
# 6. KONTROLA VÝSLEDKU STATISTIKY
# =============================================================================
echo "[Kontrola] Prověřuji výstupní statistiky..." | tee -a "$JOB_LOG"

FILES_TO_CHECK=(
    "${SAMPLE_NAME}_lengths.txt"
    "${SAMPLE_NAME}_quality_coverage.txt"
    "${SAMPLE_NAME}_nanostat.txt"
    "${SAMPLE_NAME}_coverage.mosdepth.summary.txt"
)

for FILE in "${FILES_TO_CHECK[@]}"; do
    if [ ! -s "$FILE" ]; then
        echo "KRITICKÁ CHYBA: Soubor $FILE neexistuje nebo je prázdný!" | tee -a "$JOB_LOG" >&2
        exit 1
    fi
done

# =============================================================================
# 7. KOPÍROVÁNÍ VÝSLEDKŮ A ÚKLID
# =============================================================================
echo "[3/3] Kopíruji výsledky do $FINAL_stats_OUTPUT_DIR..." | tee -a "$JOB_LOG"

mkdir -p "$FINAL_stats_OUTPUT_DIR"

cp ${SAMPLE_NAME}_lengths.txt "$FINAL_stats_OUTPUT_DIR/lengths_${SAMPLE_NAME}.txt"
cp ${SAMPLE_NAME}_quality_coverage.txt "$FINAL_stats_OUTPUT_DIR/quality_coverage_${SAMPLE_NAME}.txt"
cp ${SAMPLE_NAME}_nanostat.txt "$FINAL_stats_OUTPUT_DIR/nanostat_${SAMPLE_NAME}.txt"
cp ${SAMPLE_NAME}_coverage.mosdepth.summary.txt "$FINAL_stats_OUTPUT_DIR/coverage.mosdepth.summary_${SAMPLE_NAME}.txt"
cp $JOB_LOG "$FINAL_stats_OUTPUT_DIR/"

echo "ÚSPĚCH STATISTIKY: HOTOVO!" | tee -a "$FINAL_stats_OUTPUT_DIR/statistics_alignment_info.txt"
clean_scratch