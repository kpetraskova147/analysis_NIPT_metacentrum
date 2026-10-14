#!/bin/bash

# Zabezpečení proti chybě "No space left on device" při generování grafů
export MPLCONFIGDIR=~/.cache/matplotlib

SAMPLES=(
    "run3-MinKNOW_barcode20"
    "run3-MinKNOW_barcode04"
    "run4-MinKNOW_barcode01"
    "run3-MinKNOW_barcode09"
    "run4-MinKNOW_barcode09"
    "run4-MinKNOW_barcode05"
)

BASE_DIR="/storage/brno12-cerit/home/petraskkar/RESULTS/MinKNOW-statistics_results"

echo "Začínám analýzu inflexních bodů pro vybrané vzorky..."
echo "======================================================"

for SAMPLE in "${SAMPLES[@]}"; do
    RUN_NAME=$(echo "$SAMPLE" | cut -d'-' -f1)
    FILE_PATH="${BASE_DIR}/MinKNOW-statistics_output_${RUN_NAME}/${SAMPLE}/lengths_${SAMPLE}.txt"
    CLEAN_FILE="clean_${SAMPLE}.txt"

    if [ -f "$FILE_PATH" ]; then
        echo "Zpracovávám: $SAMPLE"
        
        # Extrakce pouze 2. a 3. sloupce (ignoruje text "RL") a uložení do dočasného souboru
        awk '{print $2 "\t" $3}' "$FILE_PATH" > "$CLEAN_FILE"
        
        # Spuštění Python skriptu na vyčištěných datech
        python find_optimal_peaks.py "$CLEAN_FILE"
        
        # Smazání dočasného čistého souboru po dokončení výpočtu
        rm "$CLEAN_FILE"
        
        echo "------------------------------------------------------"
    else
        echo "CHYBA: Soubor nenalezen: $FILE_PATH"
        echo "------------------------------------------------------"
    fi
done

echo "Analýza všech 6 vzorků byla dokončena!"