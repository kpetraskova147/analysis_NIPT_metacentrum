#!/bin/bash

# Kontrola proměnné
if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: RUN_NUMBER není nastaven." >&2
    exit 1
fi

# Definice cest
BASE_DIR="/storage/brno12-cerit/home/petraskkar"
RUN_DIR="${BASE_DIR}/RESULTS/statistics_results"
SAMPLES_DIR="${RUN_DIR}/statistics_output_${RUN_NUMBER}"

# 1. Vyčištění a načtení systémového modulu MultiQC
module purge
module load multiqc

# 2. Ověření funkčnosti
multiqc --version

# 3. Přechod do složky s výsledky a spuštění reportu
cd "$SAMPLES_DIR"
multiqc . -o multiqc_report

echo "MultiQC report byl úspěšně vygenerován ve složce: $SAMPLES_DIR/multiqc_report"