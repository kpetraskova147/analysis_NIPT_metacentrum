#!/bin/bash

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
# Chceme, abys RUN_NUMBER zadala už při spouštění (např.: RUN_NUMBER=run1 bash skript.sh)
if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: Proměnná RUN_NUMBER není nastavena." >&2
    echo "Spusť skript v terminálu takto: RUN_NUMBER=\"run1\" bash jmeno_skriptu.sh" >&2
    exit 1
fi

# =============================================================================
# 1. NASTAVENÍ SLOŽEK
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar/RESULTS"

# Skript si sám dosadí tvůj zadaný run (např. HAC-statistics_output_run1)
INPUT_DIR="$BASE_DIR/HAC-statistics_results/HAC-statistics_output_${RUN_NUMBER}"

OUTPUT_DIR="$BASE_DIR/HAC-fragment_ratios_results"
mkdir -p "$OUTPUT_DIR"

OUTPUT_CSV="$OUTPUT_DIR/HAC-fragment_ratios_${RUN_NUMBER}_$(date '+%Y-%m-%d').csv"
LOG_FILE="$OUTPUT_DIR/HAC-fragment_ratios_log_${RUN_NUMBER}_$(date '+%Y-%m-%d').txt"

# =============================================================================
# 2. ANALÝZA
# =============================================================================
echo "Spuštění analýzy pro $RUN_NUMBER..." > "$LOG_FILE"
echo "Sample,Ratio" > "$OUTPUT_CSV"

# Najde všechny .txt soubory uvnitř zadané složky
find "$INPUT_DIR" -type f -name "*.txt" | sort | while read -r file; do
    
    # Vytáhne už jen číslo barcodu (např. barcode01) a přidá k němu zadaný run
    BARCODE=$(echo "$file" | grep -o 'barcode[0-9]*' | head -n 1)
    SAMPLE_NAME="${RUN_NUMBER}_${BARCODE}"
    
    # "Chytrý" výpočet poměru, který umí číst formát "RL" i starý formát z Epi2me
    RATIO=$(awk '{ 
        # Rozpoznání formátu sloupců
        if ($1 == "RL") { len = $2; count = $3 }
        else if ($1 ~ /^[0-9]+$/) { len = $1; count = $3 }
        else { len = 0; count = 0 } # Ignoruje hlavičky nebo prázdné řádky

        # Sčítání do kategorií
        if(len >= 100 && len <= 150) { short += count } 
        else if(len >= 160 && len <= 200) { long += count } 
    } 
    END { 
        if(long > 0) { printf "%.4f", short / long } 
        else { printf "0.0000" } 
    }' "$file")
    
    # Zápis do logu a do CSV tabulky
    echo "Údaje: ${SAMPLE_NAME}, Poměr: ${RATIO} zkopírovány." >> "$LOG_FILE"
    echo "${SAMPLE_NAME},${RATIO}" >> "$OUTPUT_CSV"
    
done

# =============================================================================
# 3. ZPRÁVA O DOKONČENÍ
# =============================================================================
echo "================================================="
echo "Analýza dokončena. Výsledky jsou v: $OUTPUT_CSV"
echo "================================================="