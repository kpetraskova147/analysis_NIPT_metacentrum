#!/bin/bash
# =============================================================================
# PBS HLAVIČKA PRO ŘÍDICÍ SKRIPT (Běží jen chvilku, pouze rozdává úkoly)
# =============================================================================
#PBS -N MinKNOW-MASTER_Pipeline
#PBS -l select=1:ncpus=1:mem=2gb
#PBS -l walltime=0:10:00
#PBS -q default
#PBS -j oe
#PBS -m ae
#PBS -M petraskkar@natur.cuni.cz

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
set -euo pipefail
trap "clean_scratch" TERM EXIT

if [ -z "${RUN_NUMBER:-}" ] || [ -z "${DATUM:-}" ]; then
    echo "Chyba: Zadej RUN_NUMBER i DATUM!" >&2
    echo "Spuštění: qsub -v RUN_NUMBER=run1,DATUM=2026-03-26 MinKNOW-run_pipeline.sh" >&2
    exit 1
fi

# =============================================================================
# 1. NASTAVENÍ CEST K VAŠIM SKRIPTŮM
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar"

# Názvy vašich finálních skriptů (Zkontrolujte si, že se jmenují přesně takto)
#SCRIPT_ALIGN="${BASE_DIR}/alignment/MinKNOW-alignment.sh"
SCRIPT_STATS="${BASE_DIR}/alignment/MinKNOW-alignment_statistics.sh"
SCRIPT_WISECONDORX="${BASE_DIR}/wisecondorX/MinKNOW-wisecondorX.sh"

# Log
MASTER_LOG="${BASE_DIR}/MinKNOW-master_pipeline_history.txt"

# =============================================================================
# 2. PŘÍSNÁ KONTROLA VSTUPNÍCH SOUBORŮ A SLOŽEK
# =============================================================================
echo "Provádím kontrolu prostředí a vstupních dat..." >> "$MASTER_LOG"

ENTER_ITEMS=(
#    "$SCRIPT_ALIGN"
    "$SCRIPT_STATS"
    "$SCRIPT_WISECONDORX"
    "$BASE_DIR/alignment/reference_genome_Hg38/hg38.mmi"
    "$BASE_DIR/alignment/reference_genome_Hg38/hg38.analysisSet.fa"
)

MISSING_ITEMS=0

for ITEM in "${ENTER_ITEMS[@]}"; do
    if [ ! -e "$ITEM" ]; then
        echo "KRITICKÁ CHYBA: Chybí soubor nebo složka: $ITEM" >&2
        MISSING_ITEMS=1
    fi
done

if [ "$MISSING_ITEMS" -eq 1 ]; then
    echo "Pipeline zastavena: Před spuštěním prosím doplňte chybějící soubory!" >&2
    exit 1
fi
echo "Kontrola v pořádku. Všechny soubory jsou na svém místě." >> "$MASTER_LOG"

# =============================================================================
# 3. SPOUŠTĚNÍ AUTOMATICKÉ PIPELINE (ZÁVISLOSTI)
# =============================================================================
echo "=================================================================" | tee -a "$MASTER_LOG"
echo "Startuji plně automatickou pipeline pro run: ${RUN_NUMBER}" | tee -a "$MASTER_LOG"
echo "=================================================================" | tee -a "$MASTER_LOG"

# 1. Alignment
#JOB_ALIGN=$(qsub -W depend=afterok:"${JOB_DORADO}" -v RUN_NUMBER="${RUN_NUMBER}" "${SCRIPT_ALIGN}")
#JOB_ALIGN=$(qsub -v RUN_NUMBER="${RUN_NUMBER}" "${SCRIPT_ALIGN}")
#echo "[1] Alignment zařazen:            ${JOB_ALIGN}" | tee -a "$MASTER_LOG"

# 2. Statistiky
JOB_STATS=$(qsub -W depend=afterok:"${JOB_ALIGN}" -v RUN_NUMBER="${RUN_NUMBER}" "${SCRIPT_STATS}")
echo "[2] Statistiky zařazeny:          ${JOB_STATS} (čeká na dokončení 1)" | tee -a "$MASTER_LOG"

# 3. MultiQC Report
RESULTS_DIR="${BASE_DIR}/RESULTS/sup-statistics_results/sup-statistics_output_${RUN_NUMBER}"
JOB_MULTIQC=$(echo "module add multiqc; cd ${RESULTS_DIR}; multiqc . -o multiqc_report" | \
    qsub -W depend=afterok:"${JOB_STATS}" \
         -N "MultiQC_${RUN_NUMBER}" \
         -l select=1:ncpus=2:mem=8gb:scratch_local=5gb \
         -l walltime=0:30:00 \
         -q default -j oe \
         -o "${BASE_DIR}/alignment/pbs_outputs_statistics/")
echo "[3] MultiQC Report zařazen:      ${JOB_MULTIQC} (čeká na dokončení 2)" | tee -a "$MASTER_LOG"

# 4. WisecondorX
JOB_WISECONDORX=$(qsub -W depend=afterok:"${JOB_STATS}" -v RUN_NUMBER="${RUN_NUMBER}",DATUM="${DATUM}" "${SCRIPT_WISECONDORX}")
echo "[4] WisecondorX zařazen:         ${JOB_WISECONDORX} (čeká na dokončení 3)" | tee -a "$MASTER_LOG"

# =============================================================================
# 4. ZÁPIS DO CENTRÁLNÍHO DENÍKU PIPELINE
# =============================================================================
{
    echo "=================================================="
    echo "DATUM SPUŠTĚNÍ : $(date)"
    echo "RUN            : ${RUN_NUMBER} | DATUM VZORKŮ: ${DATUM}"
#    echo "1. Alignment ID: ${JOB_ALIGN}"
    echo "2. Statistiky ID: ${JOB_STATS}"
    echo "3. MultiQC ID  : ${JOB_MULTIQC}"
    echo "4. Wisecondor ID: ${JOB_WISECONDORX}"
    echo "=================================================="
} >> "$MASTER_LOG"