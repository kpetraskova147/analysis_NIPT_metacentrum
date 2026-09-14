#!/bin/bash

# =============================================================================
# 1. NASTAVENÍ SLOŽKY
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar/FF_calculation"
INPUT_DIR="$BASE_DIR/Histogramy-Pavel_data-jak-PCR/Histogramy"

OUTPUT_CSV="$BASE_DIR/fragment_ratios_$(date '+%Y-%m-%d').csv"
LOG_FILE="$BASE_DIR/log-fragment_ratios_$(date '+%Y-%m-%d').txt"

# =============================================================================
# 2. VÝPOČET METRIK FRAGMENTACE
# =============================================================================
echo "Začínám zpracovávat .hist soubory..." > "$LOG_FILE"

# Hlavička tabulky: Původní poměr, Úzký poměr a Kumulativní podíl
echo "Sample,Ratio_classic,Ratio_narrow,F_short" > "$OUTPUT_CSV"

for file in "$INPUT_DIR"/*hist*; do

    [ -e "$file" ] || continue
    
    # Čistý název vzorku bez přípony
    SAMPLE_NAME=$(basename "$file" | sed -E 's/\.hist(\.txt)?$//')
    
    # Výpočet metrik v jednom průchodu AWK
    METRICS=$(awk '{
        # Ošetření formátu dat (s prefixem RL nebo jen čísla)
        if ($1 == "RL") { len = $2; count = $3 }
        else if ($1 ~ /^[0-9]+$/) { len = $1; count = $3 }
        else { len = 0; count = 0 }

        if (count > 0) {
            # 1. Klasická okna (100-150 / 160-200)
            if (len >= 100 && len <= 150) { short_classic += count }
            if (len >= 160 && len <= 200) { long_classic += count }

            # 2. Úzká okna (130-148 / 162-174)
            if (len >= 130 && len <= 148) { short_narrow += count }
            if (len >= 162 && len <= 174) { peak_narrow += count }

            # 3. Kumulativní mononukleozom (50-150 / 50-220)
            if (len >= 50 && len <= 150) { short_mono += count }
            if (len >= 50 && len <= 220) { total_mono += count }
        }
    } 
    END {
        r_classic = (long_classic > 0) ? (short_classic / long_classic) : 0
        r_narrow  = (peak_narrow > 0)  ? (short_narrow / peak_narrow)   : 0
        f_short   = (total_mono > 0)   ? (short_mono / total_mono)      : 0

        printf "%.4f,%.4f,%.4f", r_classic, r_narrow, f_short
    }' "$file")
    
    # Zápis do CSV
    echo "${SAMPLE_NAME},${METRICS}" >> "$OUTPUT_CSV"
    
    # Výpis na obrazovku a do logu
    echo "Zpracováno: ${SAMPLE_NAME} -> ${METRICS}" | tee -a "$LOG_FILE"
    
done

echo "================================================="
echo "Hotovo! Výsledky uloženy v: $OUTPUT_CSV"
echo "================================================="