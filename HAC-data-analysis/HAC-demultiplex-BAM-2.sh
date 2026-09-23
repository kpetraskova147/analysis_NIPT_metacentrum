#!/bin/bash
# =============================================================================
# PBS HLAVIČKA
# =============================================================================
#PBS -N HAC_2_Demux
#PBS -l select=1:ncpus=8:mem=200gb:scratch_local=1500gb
#PBS -l walltime=24:00:00
#PBS -j oe
#PBS -m ae
#PBS -M petraskkar@natur.cuni.cz

#PBS -o /storage/brno12-cerit/home/petraskkar/basecalling/pbs_outputs/
#PBS -e /storage/brno12-cerit/home/petraskkar/basecalling/pbs_outputs/

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
mkdir -p /storage/brno12-cerit/home/petraskkar/basecalling/pbs_outputs/
set -e

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: Zadej RUN_NUMBER!" >&2
    exit 1
fi

# =============================================================================
# 1. NASTAVENÍ UŽIVATELE
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar"
INPUT_BAM="$BASE_DIR/RESULTS/HAC-basecall_results/BAM-HAC_barcoded_${RUN_NUMBER}/HAC-unaligned_barcoded.bam"
FINAL_OUTPUT_DIR="$BASE_DIR/RESULTS/HAC-basecall_results/HAC-basecall_output_${RUN_NUMBER}"

DORADO_DIR="$BASE_DIR/basecalling/dorado-2.0.0-linux-x64"
LOCAL_DORADO_BIN="$SCRATCHDIR/dorado-2.0.0-linux-x64/bin/dorado"
KIT="SQK-NBD114-24"

# =============================================================================
# 3. PŘESUN DO SCRATCHE
# =============================================================================
cd $SCRATCHDIR
cp -r $DORADO_DIR $SCRATCHDIR/
cp "$INPUT_BAM" $SCRATCHDIR/
# Záměrně zde neděláme mkdir demultiplexed - necháme to na Doradu

# =============================================================================
# 4. DEMULTIPLEXING
# =============================================================================
echo "Rozděluji data podle hotových štítků..."
"$LOCAL_DORADO_BIN" demux \
    --no-classify \
    --emit-fastq \
    --output-dir "$SCRATCHDIR/demultiplexed" \
    "$SCRATCHDIR/HAC-unaligned_barcoded.bam"

# =============================================================================
# 5. FILTROVÁNÍ, PŘEJMENOVÁNÍ A KOMPRESE
# =============================================================================
echo "Filtrování (<50 bp) a komprese FASTQ..."

cd "$SCRATCHDIR/demultiplexed"

# Příkaz find prohledá VŠECHNY podsložky a najde jakýkoliv fastq soubor
find . -type f \( -name "*.fastq" -o -name "*.fastq.gz" \) | while read FILE; do
    
    # Bezpečnostní pojistka: Pokud soubor nepatří žádnému barcodu (např. unclassified), přeskočíme ho
    if [[ ! "$FILE" =~ barcode[0-9]+ ]]; then
        echo "Přeskakuji soubor bez barcodu: $FILE"
        continue
    fi
    
    # Univerzální očištění jména: Vytáhne z cesty a názvu čistě jen slovo "barcodeXX"
    CLEAN_NAME=$(echo "$FILE" | sed -E 's/.*(barcode[0-9]+).*/\1/')
    NEW_FILENAME="${RUN_NUMBER}-HAC_${CLEAN_NAME}.fastq.gz"
    
    echo "Zpracovávám: $FILE -> $NEW_FILENAME"
    
    # Filtrace a komprese s přesunem rovnou do hlavní složky demultiplexed
    if [[ "$FILE" == *.gz ]]; then
        zcat "$FILE" | awk 'BEGIN {OFS="\n"} \
        {header=$0; getline seq; getline qheader; getline qseq; \
        if (length(seq) >= 50) {print header, seq, qheader, qseq}}' | gzip > "$SCRATCHDIR/demultiplexed/$NEW_FILENAME"
    else
        awk 'BEGIN {OFS="\n"} \
        {header=$0; getline seq; getline qheader; getline qseq; \
        if (length(seq) >= 50) {print header, seq, qheader, qseq}}' "$FILE" | gzip > "$SCRATCHDIR/demultiplexed/$NEW_FILENAME"
    fi
    
    # Smažeme původní soubor, aby nám ve scratchi nedošlo místo
    rm "$FILE"
done

# =============================================================================
# 6. KOPÍROVÁNÍ VÝSLEDKŮ A ÚKLID
# =============================================================================
echo "Kopíruji čisté FASTQ výsledky..."
mkdir -p "$FINAL_OUTPUT_DIR"
cp "$SCRATCHDIR/demultiplexed/"*.fastq.gz "$FINAL_OUTPUT_DIR/"

echo "Demultiplexing HOTOVÝ!"
clean_scratch