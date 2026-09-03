#!/bin/bash

# !! NENÍ HOTOVÉ !! - DODĚLAT KONTROLY VSTUPNÍCH SOUBORŮ, LOGOVÁNÍ, ENVIRONMENTU

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
mkdir -p "pbs_outputs"
set -euo pipefail   # přísnější režim pro lepší detekci chyb, -e: skript se zastaví při jakékoliv chybě, -u: chyba při použití nedefinované proměnné, -o pipefail: chyba v jakékoliv části pipy způsobí selhání celé pipy

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: RUN_NUMBER není nastaven." >&2
    echo "Spuštění: qsub -v RUN_NUMBER=run1,DATUM=2026-03-26 skript_wisecondorX.sh" >&2
    exit 1
fi

if [ -z "${DATUM:-}" ]; then
    echo "Chyba: DATUM není nastaveno." >&2
    echo "Spuštění: qsub -v RUN_NUMBER=run1,DATUM="2026-03-26" skript_wisecondorX.sh" >&2
    exit 1
fi

# =============================================================================
# 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST)
# =============================================================================

BASE_DIR="/storage/brno12-cerit/home/petraskkar"
SCRIPT_DORADO="${BASE_DIR}/basecalling/dorado_basecall_array.sh"
SCRIPT_ALIGN="${BASE_DIR}/alignment/alignment_minimap2.sh"
SCRIPT_STATS="${BASE_DIR}/alignment/statistics_alignment.sh"
SCRIPT_MULTIQC="${BASE_DIR}/alignment/multiqc-run.sh"
SCRIPT_WISECONDORX="${BASE_DIR}/wisecondorX/seq-qc_wisecondorX.sh"

# =============================================================================
# 2. KONTROLA VSTUPNÍCH SOUBORŮ
# =============================================================================

ENTER_FILES=(
    "$BASE_DIR/basecalling/dorado_basecall_array.sh"
    "$BASE_DIR/alignment/alignment_minimap2.sh"
    "$BASE_DIR/alignment/statistics_alignment.sh"
    "$BASE_DIR/alignment/multiqc-run.sh"
    "$BASE_DIR/wisecondorX/seq-qc_wisecondorX.sh"
    "$BASE_DIR/basecalling/dorado-1.0.0-linux-x64/bin/dorado"
    "$BASE_DIR/basecalling/dorado-1.0.0-linux-x64/models/dna_r10.4.1_e8.2_400bps_sup@v5.2.0"
    "$BASE_DIR/basecalling/dorado-1.0.0-linux-x64/models/dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mC_5hmC"
    "$BASE_DIR/${RUN_NUMBER}_pod5_pass"
    "$BASE_DIR/hg38.mmi - kde?"
    .......
    )
    
for CHECK_FILES in "${ENTER_FILES[@]}"; do
    if [ ! -f "$CHECK_FILES" ]; then
        echo "Chybí soubor: $(basename "$CHECK_FILES")" >> "run_pipeline.log"
    fi
done

# =============================================================================
# 2. ANALÝZA
# =============================================================================

echo "=========================================="
echo "Starting pipeline pipeline for: ${RUN_NUMBER}"
echo "=========================================="

# 1. Basecalling & initial processing (Single job)
# Submits dorado_basecall.sh and captures its Job ID
JOB_DORADO=$(qsub -v RUN_NUMBER="${RUN_NUMBER}" "${SCRIPT_DORADO}")
echo "[Queued] 1. Dorado Basecalling: ${JOB_DORADO}"

# 2. Alignment (Array job)
# Starts ONLY after JOB_DORADO finishes with return code 0 (success)
JOB_ALIGN=$(qsub -W depend=afterok:"${JOB_DORADO}" \
                 -v RUN_NUMBER="${RUN_NUMBER}" \
                 "${SCRIPT_ALIGN}")
echo "[Queued] 2. Alignment Array:    ${JOB_ALIGN} (depends on ${JOB_DORADO})"

# 3. Mosdepth, NanoPlot & cfDNA Stats (Array job)
# Starts ONLY after all array subjobs in JOB_ALIGN succeed
JOB_STATS=$(qsub -W depend=afterok:"${JOB_ALIGN}" \
                 -v RUN_NUMBER="${RUN_NUMBER}" \
                 "${SCRIPT_STATS}")
echo "[Queued] 3. Statistics Array:   ${JOB_STATS} (depends on ${JOB_ALIGN})"

# 4. MultiQC Report (Single lightweight job)
# Automatically runs MultiQC once all 24 sample stats have finished
RESULTS_DIR="${BASE_DIR}/RESULTS/statistics_results/statistics_output_${RUN_NUMBER}"
JOB_MULTIQC=$(qsub -W depend=afterok:"${JOB_STATS}" \
                   -N "MultiQC_${RUN_NUMBER}" \
                   -l select=1:ncpus=2:mem=8gb:scratch_local=5gb \
                   -l walltime=0:30:00 \
                   -q default \
                   -o "${SCRIPT_STATS}/pbs_outputs_statistics/" \
                   -e "${SCRIPT_STATS}/pbs_outputs_statistics/" \
                   -- /bin/bash -c "module load multiqc && cd ${RESULTS_DIR} && multiqc . -o multiqc_report")
echo "[Queued] 4. MultiQC Report:     ${JOB_MULTIQC} (depends on ${JOB_STATS})"

# 5. WisecondorX
JOB_WISECONDORX=$(qsub -W depend=afterok:"${JOB_STATS}" \
                       -v RUN_NUMBER="${RUN_NUMBER}",DATUM="${DATUM}" \
                       "${SCRIPT_WISECONDORX}")
echo "[Queued] 5. WisecondorX:        ${JOB_WISECONDORX} (depends on ${JOB_STATS})"

