#!/bin/bash
# =============================================================================
# PBS HLAVIČKA
# =============================================================================
#PBS -N fast_1_Basecall-demultiplex
#PBS -q gpu
#PBS -l select=1:ncpus=8:mem=64gb:ngpus=1:scratch_local=1500gb
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
# 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST)
# =============================================================================

BASE_DIR="/storage/brno12-cerit/home/petraskkar"
INPUT_DIR="$BASE_DIR/${RUN_NUMBER}_pod5_pass"
OUTPUT_DIR="$BASE_DIR/RESULTS/fast-basecall_results"
FINAL_BAM_DIR="$OUTPUT_DIR/BAM-fast_barcoded_${RUN_NUMBER}"

DORADO_DIR="$BASE_DIR/basecalling/dorado-2.0.0-linux-x64"
MODEL="$DORADO_DIR/models/dna_r10.4.1_e8.2_400bps_fast@v5.2.0"
DORADO_BIN="$DORADO_DIR/bin/dorado"

# Dorado ve scratchi
LOCAL_DORADO_BIN="$SCRATCHDIR/dorado-2.0.0-linux-x64/bin/dorado"
LOCAL_MODEL="$SCRATCHDIR/dorado-2.0.0-linux-x64/models/dna_r10.4.1_e8.2_400bps_fast@v5.2.0"
KIT="SQK-NBD114-24"

# =============================================================================
# 2. KONTROLA VSTUPNÍCH DAT A PROSTŘEDÍ
# =============================================================================

if [ ! -d "$INPUT_DIR" ]; then
    echo "Chyba: neexistuje vstupní barcode adresář: $INPUT_DIR" >&2
    exit 1
fi

if [ ! -x "$DORADO_BIN" ]; then
    echo "Chyba: Dorado neexistuje nebo není spustitelné: $DORADO_BIN" >&2
    exit 1
fi

if [ ! -d "$MODEL" ]; then
    echo "Chyba: model neexistuje: $MODEL" >&2
    exit 1
fi

if [ -z "${SCRATCHDIR:-}" ]; then
    echo "Chyba: SCRATCHDIR není nastaven." >&2
    exit 1
fi

# =============================================================================
# 3. PŘESUN DO SCRATCHE, INFO DO LOGŮ
# =============================================================================

cd $SCRATCHDIR
cp -r $DORADO_DIR $SCRATCHDIR/
cp -r $INPUT_DIR $SCRATCHDIR/pod5_data

# =============================================================================
# 4. BASECALLING (Uložení do velkého BAMu s vloženými štítky barcodů)
# =============================================================================

echo "Spouštím Basecalling na GPU a vkládám štítky barcodů..."
unset CUDA_VISIBLE_DEVICES

"$LOCAL_DORADO_BIN" basecaller "$LOCAL_MODEL" "$SCRATCHDIR/pod5_data" \
    --kit-name "$KIT" \
    --min-qscore 9 \
    --device cuda:0 > "$SCRATCHDIR/fast-unaligned_barcoded.bam"

# =============================================================================
# 5. KOPÍROVÁNÍ VÝSLEDKŮ A ÚKLID
# =============================================================================

echo "Kopíruji oštítkovaný BAM na storage..."
mkdir -p "$FINAL_BAM_DIR"
cp "$SCRATCHDIR/fast-unaligned_barcoded.bam" "$FINAL_BAM_DIR/"
clean_scratch