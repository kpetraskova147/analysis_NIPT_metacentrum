#!/bin/bash

# =============================================================================
# 1. NASTAVENÍ SLOŽKY
# =============================================================================
# Zadej cestu ke složce, kde máš všechny .hist soubory nasypané
BASE_DIR="/storage/brno12-cerit/home/petraskkar/wisecondorX"
WORK_DIR="$BASE_DIR/FF_ratio-Pavel_data"
INPUT_DIR="$WORK_DIR/Histogramy-Pavel_data-jak-PCR"

# Jak se má jmenovat výsledná tabulka (uloží se do stejné složky)
OUTPUT_CSV="$WORK_DIR/fragment_ratios.csv"

LOG_FILE="$WORK_DIR/log-fragment_ratios.txt"

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