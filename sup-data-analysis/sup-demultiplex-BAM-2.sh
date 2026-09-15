#!/bin/bash
# =============================================================================
# PBS HLAVIČKA
# =============================================================================
#PBS -N sup_2_Demux
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
INPUT_BAM="$BASE_DIR/RESULTS/sup-basecall_results/BAM-sup_barcoded_${RUN_NUMBER}/sup-unaligned_barcoded.bam"
FINAL_OUTPUT_DIR="$BASE_DIR/RESULTS/sup-basecall_results/sup-basecall_output_${RUN_NUMBER}"

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
    --kit-name "$KIT" \
    --emit-fastq \
    --output-dir "$SCRATCHDIR/demultiplexed" \
    "$SCRATCHDIR/sup-unaligned_barcoded.bam"

# =============================================================================
# 5. FILTROVÁNÍ, PŘEJMENOVÁNÍ A KOMPRESE
# =============================================================================
echo "Filtrování (<50 bp) a komprese FASTQ..."

cd "$SCRATCHDIR/demultiplexed"

# Dorado vytvoří podsložku s názvem Kitu - přesuneme se do ní
if [ -d "$KIT" ]; then
    cd "$KIT"
fi

shopt -s nullglob
for FILE in *.fastq *.fastq.gz *.fq *.fq.gz; do
    [ -f "$FILE" ] || continue
    
    # Očištění názvu od jména kitu a přípony
    CLEAN_NAME=$(basename "$FILE" | sed -E "s/^${KIT}_//; s/\.fastq\.gz$//; s/\.fastq$//; s/\.fq\.gz$//; s/\.fq$//")
    NEW_FILENAME="${RUN_NUMBER}-sup_${CLEAN_NAME}.fastq.gz"
    
    # Filtrace a komprese s přesunem do nadřazené složky
    if [[ "$FILE" == *.gz ]]; then
        zcat "$FILE" | awk 'BEGIN {OFS="\n"} {header=$0; getline seq; getline qheader; getline qseq; if (length(seq) >= 50) {print header, seq, qheader, qseq}}' | gzip > "$SCRATCHDIR/demultiplexed/$NEW_FILENAME"
    else
        awk 'BEGIN {OFS="\n"} {header=$0; getline seq; getline qheader; getline qseq; if (length(seq) >= 50) {print header, seq, qheader, qseq}}' "$FILE" | gzip > "$SCRATCHDIR/demultiplexed/$NEW_FILENAME"
    fi
    
    rm "$FILE"
done
shopt -u nullglob

# =============================================================================
# 6. KOPÍROVÁNÍ VÝSLEDKŮ A ÚKLID
# =============================================================================
echo "Kopíruji čisté FASTQ výsledky..."
mkdir -p "$FINAL_OUTPUT_DIR"
cp "$SCRATCHDIR/demultiplexed/"*.fastq.gz "$FINAL_OUTPUT_DIR/"

echo "Demultiplexing HOTOVÝ!"
clean_scratch