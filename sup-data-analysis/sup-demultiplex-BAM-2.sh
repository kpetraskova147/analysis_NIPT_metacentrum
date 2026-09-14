#!/bin/bash
# =============================================================================
# PBS HLAVIČKA
# =============================================================================
#PBS -N SUP_2_Demux
#PBS -l select=1:ncpus=8:mem=200gb:scratch_local=1500gb
#PBS -l walltime=24:00:00
#PBS -j oe
#PBS -m ae
#PBS -M petraskkar@natur.cuni.cz

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================

set -e

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: Zadej RUN_NUMBER!" >&2
    exit 1
fi

# =============================================================================
# 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST)
# =============================================================================

BASE_DIR="/storage/brno12-cerit/home/petraskkar"
INPUT_BAM="$BASE_DIR/RESULTS/SUP-basecall_results/BAM-SUP_barcoded_${RUN_NUMBER}/SUP-unaligned_barcoded.bam"

FINAL_OUTPUT_DIR="$BASE_DIR/RESULTS/SUP-basecall_results/SUP-basecall_output_${RUN_NUMBER}"

DORADO_DIR="$BASE_DIR/basecalling/dorado-2.0.0-linux-x64"
LOCAL_DORADO_BIN="$SCRATCHDIR/dorado-2.0.0-linux-x64/bin/dorado"
KIT="SQK-NBD114-24"

# =============================================================================
# 3. PŘESUN DO SCRATCHE
# =============================================================================

cd $SCRATCHDIR
cp -r $DORADO_DIR $SCRATCHDIR/
cp "$INPUT_BAM" $SCRATCHDIR/
mkdir -p $SCRATCHDIR/demultiplexed

# =============================================================================
# 4. DEMULTIPLEXING
# =============================================================================
echo "Rozděluji data podle hotových štítků..."
"$LOCAL_DORADO_BIN" demux \
    --emit-fastq \
    --output-dir "$SCRATCHDIR/demultiplexed" \
    "$SCRATCHDIR/SUP-unaligned_barcoded.bam"

# =============================================================================
# 5. FILTROVÁNÍ, PŘEJMENOVÁNÍ A KOMPRESE
# =============================================================================
echo "Filtrování (<50 bp) a komprese FASTQ..."
cd "$SCRATCHDIR/demultiplexed"
shopt -s nullglob
for FILE in *.fastq; do
    [ -f "$FILE" ] || continue
    CLEAN_NAME="${FILE/${KIT}_/}"
    NEW_FILENAME="${RUN_NUMBER}-SUP_${CLEAN_NAME}.gz"
    
    awk 'BEGIN {OFS="\n"} {header=$0; getline seq; getline qheader; getline qseq; if (length(seq) >= 50) {print header, seq, qheader, qseq}}' "$FILE" | gzip > "$NEW_FILENAME"
    rm "$FILE"
done
shopt -u nullglob

# =============================================================================
# 6. KOPÍROVÁNÍ VÝSLEDKŮ A ÚKLID
# =============================================================================
echo "Kopíruji čisté FASTQ výsledky..."
mkdir -p "$FINAL_OUTPUT_DIR"
cp "$SCRATCHDIR/demultiplexed/"*.fastq.gz "$FINAL_OUTPUT_DIR/"
clean_scratch