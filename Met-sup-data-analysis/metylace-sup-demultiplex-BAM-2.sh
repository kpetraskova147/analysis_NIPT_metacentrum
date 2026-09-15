#!/bin/bash
#PBS -N Met-SUP_2_Demux
#PBS -l select=1:ncpus=8:mem=250gb:scratch_local=1500gb
#PBS -l walltime=12:00:00
#PBS -q default
#PBS -j oe
#PBS -m ae
#PBS -M petraskkar@natur.cuni.cz

# =============================================================================
# KROK 2: DEMULTIPLEXING METYLAČNÍCH DAT (BAM -> rozdělené BAMy)
# =============================================================================
set -e

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: Zadej RUN_NUMBER!" >&2
    exit 1
fi

BASE_DIR="/storage/brno12-cerit/home/petraskkar"
INPUT_BAM="$BASE_DIR/RESULTS/Met-SUP-basecall_results/BAM-Met-SUP_barcoded_${RUN_NUMBER}/Met-SUP-unaligned_barcoded.bam"
FINAL_OUTPUT_DIR="$BASE_DIR/RESULTS/Met-SUP-basecall_results/Met-SUP-demux_${RUN_NUMBER}"
DORADO_BIN="$BASE_DIR/basecalling/dorado-2.0.0-linux-x64/bin/dorado"
KIT="SQK-NBD114-24"

# Přesun do Scratche
cd "$SCRATCHDIR"
cp "$INPUT_BAM" ./input.bam
mkdir -p "$SCRATCHDIR/demultiplexed"

echo "Rozděluji velký BAM na menší podle barcodů (Ponechávám formát BAM!)..."
# ZDE JE ZMĚNA: Chybí parametr --emit-fastq. Dorado díky tomu automaticky vytvoří rozdělené BAM soubory!
"$DORADO_BIN" demux \
    --kit-name "$KIT" \
    --output-dir "$SCRATCHDIR/demultiplexed" \
    ./input.bam

echo "Přejmenovávám a kopíruji výsledky..."
mkdir -p "$FINAL_OUTPUT_DIR"
cd "$SCRATCHDIR/demultiplexed/$KIT"

shopt -s nullglob
for FILE in *.bam; do
    # Oříznutí jména (odstranění názvu kitu) a vytvoření nového
    CLEAN_NAME=$(basename "$FILE" .bam | sed "s/^${KIT}_//")
    NEW_FILENAME="${RUN_NUMBER}-Met-SUP_${CLEAN_NAME}.bam"
    cp "$FILE" "$FINAL_OUTPUT_DIR/$NEW_FILENAME"
done
shopt -u nullglob

echo "Demultiplexing BAMů dokončen!"
clean_scratch