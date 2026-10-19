#!/bin/bash
# =============================================================================
# INSTRUKCE
# =============================================================================
# Na storage: 
    # vytvoř složku RESULTS (pokud ještě není vytvořena)
    # data: cesta k nim: RESULTS/statistics_results/statistics_output_runX/runX-barcodeXX
    #     : lengths_run1_barcode01.txt (případně .hist - z Epi2me → upravit .txt na .hist)
    #   pokud spouštím tuto analýzu na data, u kterých nebylo spuštěno dorado, můžeš upravit cestu a nahrát je jinam
    # vytvoř složku FF_calculation a v ní:
        # 1. skript: FF_ratio_120-150_163-169.sh

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: Proměnná RUN_NUMBER není nastavena." >&2
    echo "Příkaz v terminálu: qsub -v RUN_NUMBER="run1",TYPE="HAC" FF_ratio_120-150_163-169.sh" >&2
    exit 1
fi

if [ -z "${TYPE:-}" ]; then
    echo "Chyba: Proměnná TYPE není nastavena." >&2
    echo "Příkaz v terminálu: qsub -v RUN_NUMBER="run1",TYPE="HAC" FF_ratio_120-150_163-169.sh" >&2
    exit 1
fi

# =============================================================================
# 1. NASTAVENÍ SLOŽEK
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar"
RESULT_DIR="$BASE_DIR/RESULTS"

INPUT_DIR="$RESULT_DIR/${TYPE}-statistics_results/${TYPE}-statistics_output_${RUN_NUMBER}"

OUTPUT_DIR="$BASE_DIR/FF_calculation/${TYPE}-fragment_ratios_results"
OUTPUT_CSV="$OUTPUT_DIR/${TYPE}-fragment_ratios_${RUN_NUMBER}_120-150_163-169.csv"

LOG_FILE="$OUTPUT_DIR/${TYPE}-fragment_ratios_log_${RUN_NUMBER}_120-150_163-169.txt"
mkdir -p "$OUTPUT_DIR"

# =============================================================================
# 2. ANALÝZA
# =============================================================================
echo "Sample,Ratio" > "$OUTPUT_CSV"
# Najde všechny .txt soubory uvnitř zadané složky
find "$INPUT_DIR" -type f -name "lengths_*.txt" | sort | while read -r file; do
    # Vytáhne už jen číslo barcodu (např. barcode01) a přidá k němu zadaný run
    BARCODE=$(echo "$file" | grep -o 'barcode[0-9]*' | head -n 1)
    SAMPLE_NAME="${RUN_NUMBER}-${TYPE}_${BARCODE}"

# "Chytrý" výpočet poměru, který umí číst formát "RL" i starý formát z Epi2me
RATIO=$(awk '{ 
    # Rozpoznání formátu sloupců
    if ($1 == "RL") { len = $2; count = $3 }
    else if ($1 ~ /^[0-9]+$/) { 
        len = $1; 
        # Pokud má soubor jen 2 sloupce (Délka, Počet)        
        if (NF == 2) { count = $2 }      
        # Pokud má soubor 3 sloupce (např. Index, Délka, Počet)
        else { count = $3 } 
    }            
    # Ignoruje hlavičky nebo prázdné řádky
    else { len = 0; count = 0 }      

    # Sčítání do kategorií
    if (len > 0) {
        if(len >= 120 && len <= 150) { short += count } 
        else if(len >= 163 && len <= 169) { long += count } 
    }
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