#!/bin/bash
# =============================================================================
# PBS HLAVIČKA - Nastavení zdrojů pro reorganizaci a kompresi dat
# =============================================================================
#PBS -N data_remodeling
#PBS -l select=1:ncpus=2:mem=20gb:scratch_local=10gb
#PBS -l walltime=04:00:00
#PBS -q default
#PBS -j oe
#PBS -m ae
#PBS -M petraskkar@natur.cuni.cz

# =============================================================================
# 0. KONTROLA VSTUPNÍ PROMĚNNÉ (VOLBA RUN NUMBER)
# =============================================================================
set -euo pipefail

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "CHYBA: RUN_NUMBER není nastaven!" >&2
    echo "Správné spuštění: qsub -v RUN_NUMBER=\"run3\" remodeling.sh" >&2
    exit 1
fi

# =============================================================================
# 1. NASTAVENÍ UŽIVATELE A CEST
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar/RESULTS/basecall_results"

SRC_DIR="$BASE_DIR/demultiplex_basecall_${RUN_NUMBER}"
DEST_DIR="$BASE_DIR/basecall_output_${RUN_NUMBER}"

# =============================================================================
# 2. ZPRACOVÁNÍ A REORGANIZACE
# =============================================================================
echo "Zahajuji reorganizaci dat pro: $RUN_NUMBER"
echo "Zdroj: $SRC_DIR"
echo "Cíl: $DEST_DIR"

mkdir -p "$DEST_DIR"

if [ ! -d "$SRC_DIR" ]; then
    echo "KRITICKÁ CHYBA: Zdrojová složka $SRC_DIR neexistuje!" >&2
    exit 1
fi

shopt -s nullglob
for FILE in "$SRC_DIR"/*.fastq; do
    [ -f "$FILE" ] || continue

    FILENAME=$(basename "$FILE")
    
    # Vyřízneme přesný název barcodu nezávisle na zbytku jména
    BARCODE=$(echo "$FILENAME" | grep -o 'barcode[0-9][0-9]')
    
    if [ -z "$BARCODE" ]; then
        echo "Varování: V názvu $FILENAME nebyl nalezen barcode. Přeskakuji."
        continue
    fi

    echo "Zpracovávám a komprimuji: $BARCODE"

    TARGET_DIR="$DEST_DIR/$BARCODE"
    mkdir -p "$TARGET_DIR"

    # --- PŘEJMENOVÁNÍ A KOMPRESE V JEDNOM KROKU ---
    # Sestavíme zcela nový název ve formátu runX_barcodeYY.fastq.gz
    FINAL_GZ_NAME="${RUN_NUMBER}_${BARCODE}.fastq.gz"

    # Zkomprimujeme původní soubor a uložíme ho rovnou pod novým jménem
    gzip -c "$FILE" > "$TARGET_DIR/$FINAL_GZ_NAME"

    if [ -f "$SRC_DIR/demultiplex_info.txt" ]; then
        cp "$SRC_DIR/demultiplex_info.txt" "$TARGET_DIR/basecall_info.txt"
    fi

done
shopt -u nullglob

echo "---------------------------------------------------"
echo "Všechny soubory pro $RUN_NUMBER byly úspěšně roztříděny, přejmenovány a zabaleny."