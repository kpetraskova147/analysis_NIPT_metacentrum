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
        # 1. skript: FF_ratio_from_length.sh

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
# Chceme, abys RUN_NUMBER zadala už při spouštění (např.: RUN_NUMBER=run1 bash skript.sh)
if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: Proměnná RUN_NUMBER není nastavena." >&2
    echo "Příkaz v terminálu: qsub -v RUN_NUMBER="run1" FF_ratio_from_length.sh" >&2
    exit 1
fi

# =============================================================================
# 1. NASTAVENÍ SLOŽEK
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar/RESULTS"

INPUT_DIR="$BASE_DIR/statistics_results/statistics_output_${RUN_NUMBER}"

OUTPUT_DIR="$BASE_DIR/fragment_ratios_results"
OUTPUT_CSV="$OUTPUT_DIR/fragment_ratios_${RUN_NUMBER}_$(date '+%Y-%m-%d').csv"

LOG_FILE="$OUTPUT_DIR/fragment_ratios_log_${RUN_NUMBER}_$(date '+%Y-%m-%d').txt"

mkdir -p "$OUTPUT_DIR"

# =============================================================================
# 2. VÝPOČET POMĚRŮ
# =============================================================================
echo "Začínám zpracovávat .hist soubory..." >> "$LOG_FILE"

# Vytvoření hlavičky v CSV tabulce
echo "Sample,Ratio" > "$OUTPUT_CSV"

# Cyklus projde všechny soubory končící na .hist v zadané složce
for file in "$INPUT_DIR"/*hist*; do

    # Pojistka: pokud by složka byla prázdná, cyklus se ukončí
    [ -e "$file" ] || continue
    
    # Vytáhne čistý název vzorku bez cesty a bez koncovky .hist
    SAMPLE_NAME=$(basename "$file" | sed 's/\.hist.*//')
    
    # Výpočet poměru pomocí tvého awk příkazu
    RATIO=$(awk '{ 
        if($1 >= 130 && $1 <= 148) { short += $3 } 
        else if($1 >= 162 && $1 <= 174) { long += $3 } 
    } 
    END { 
        if(long > 0) { printf "%.4f", short / long } 
        else { printf "0.0000" } 
    }' "$file")
    
    # Zápis jednoho řádku do CSV souboru
    echo "${SAMPLE_NAME},${RATIO}" >> "$OUTPUT_CSV"
    
    # Výpis do terminálu, abys viděla, že to něco dělá
    echo "Zpracováno: $SAMPLE_NAME -> $RATIO"
    
done

echo "================================================="
echo "Hotovo! Tabulku najdeš zde: $OUTPUT_CSV"
echo "================================================="