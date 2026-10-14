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
        # 1. skript: FF_ratio_136-146_162-174.sh

# Spuštění na MetaCentru např. příkazem:
# qsub -v RUN_NUMBER="run3",TYPE="sup" FF_ratio_136-146_162-174.sh

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: Proměnná RUN_NUMBER není nastavena." >&2
    echo "Příkaz v terminálu: qsub -v RUN_NUMBER=\"run3\",TYPE=\"sup\" FF_ratio_136-146_162-174.sh" >&2
    exit 1
fi

if [ -z "${TYPE:-}" ]; then
    echo "Chyba: Proměnná TYPE není nastavena." >&2
    echo "Příkaz v terminálu: qsub -v RUN_NUMBER=\"run3\",TYPE=\"sup\" FF_ratio_136-146_162-174.sh" >&2
    exit 1
fi

# =============================================================================
# 1. NASTAVENÍ SLOŽEK
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar"
RESULT_DIR="$BASE_DIR/RESULTS"

# Cesta odpovídající vašemu strukturovanému úložišti
INPUT_DIR="$RESULT_DIR/${TYPE}-statistics_results/${TYPE}-statistics_output_${RUN_NUMBER}"

OUTPUT_DIR="$BASE_DIR/FF_calculation/${TYPE}-fragment_ratios_results"
OUTPUT_CSV="$OUTPUT_DIR/${TYPE}-fragment_ratios_${RUN_NUMBER}_$(date '+%Y-%m-%d').csv"
LOG_FILE="$OUTPUT_DIR/${TYPE}-fragment_ratios_log_${RUN_NUMBER}_$(date '+%Y-%m-%d').txt"

mkdir -p "$OUTPUT_DIR"

# =============================================================================
# 2. VÝPOČET POMĚRŮ PRO VŠECHNY VZORKY V RUNU
# =============================================================================
echo "Spuštění analýzy pro ${RUN_NUMBER} (${TYPE})í..." > "$LOG_FILE"
echo "Sample,Ratio" > "$OUTPUT_CSV"

# Najde všechny soubory začínající na lengths_ uvnitř vnořených složek
find "$INPUT_DIR" -type f -name "lengths_*.txt" | sort | while read -r file; do
    
    # Vytáhne název barcodu (např. barcode01 nebo barcode20)
    BARCODE=$(echo "$file" | grep -o 'barcode[0-9]*' | head -n 1)
    SAMPLE_NAME="${RUN_NUMBER}_${TYPE}_${BARCODE}"
    
    # Výpočet poměru pomocí awk (Zohledňuje formát RL i čistá čísla a aplikuje vaše okna)
    # Fetální okno: 136–146 bp, Mateřské okno: 162–174 bp
    RATIO=$(awk '{ 
        # Rozpoznání formátu sloupců (podpora pro RL i číselné indexy)
        if ($1 == "RL") { len = $2; count = $3 }
        else if ($1 ~ /^[0-9]+$/) { 
            len = $1; 
            if (NF == 2) { count = $2 }      
            else { count = $3 } 
        }             
        else { len = 0; count = 0 }      

        # Sčítání do definovaných oken
        if (len > 0) {
            if (len >= 136 && len <= 146) { short += count } 
            else if (len >= 162 && len <= 174) { long += count }
        }
    } 
    END { 
        if(long > 0) { printf "%.4f", short / long } 
        else { printf "0.0000" } 
    }' "$file")
    
    # Zápis do logu a do výsledné CSV tabulky
    echo "Zpracováno: ${SAMPLE_NAME}, Poměr (fetální/mateřské okno): ${RATIO}" >> "$LOG_FILE"
    echo "${SAMPLE_NAME},${RATIO}" >> "$OUTPUT_CSV"
    echo "Zpracováno: ${SAMPLE_NAME} -> Poměr: ${RATIO}"
    
done

# =============================================================================
# 3. ZPRÁVA O DOKONČENÍ
# =============================================================================
echo "================================================="
echo "Analýza dokončena!"
echo "Výsledná tabulka: $OUTPUT_CSV"
echo "Log soubor: $LOG_FILE"
echo "================================================="