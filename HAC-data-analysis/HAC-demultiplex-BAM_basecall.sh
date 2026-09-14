#!/bin/bash
# =============================================================================
# PBS HLAVIČKA
# =============================================================================
#PBS -N HAC_demultiplex_Basecall
#PBS -q gpu
#PBS -l select=1:ncpus=8:mem=120gb:ngpus=1:scratch_local=2500gb
#PBS -l walltime=48:00:00
#PBS -j oe
#PBS -m ae
#PBS -M petraskkar@natur.cuni.cz

# =============================================================================
# INSTRUKCE
# =============================================================================
        # Vytvoř složku RESULTS a v ní složku basecall_results (pro výsledky z Dorada) + alignment_results, wisecondorX_results, statistics_results
        # DATA: složku pod5_pass s mými .pod5 soubory - ve složkách: run1_pod5_pass, run2_pod5_pass, ...
        # Vytvoř si složku basecalling a v ní:
        # 1. SKRIPT: 'HAC-demultiplex-BAM_basecall.sh'   (neni-roztrideny-barcodes-dorado_basecall.sh, slozky-barcodes-dorado_basecall.sh)
        # 2. SLOŽKA dorado-2.0.0-linux-x64 - (SOFTWARE) složka bin - soubor dorado
        #                                  - (MODELY) složka models - dna_r10.4.1_e8.2_400bps_hac@v5.2.0/    - lidský genom

        # Nastavení: upravím cesty v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).

        # Ve skriptu je nastavení zaslání mailu při ukončení nebo selhání úlohy - nastav svou mailovou adresu v PBS hlavičce (řádek #PBS -M) 

        # Spuštění: qsub -v RUN_NUMBER="run1" HAC-demultiplex-BAM_basecall.sh       (neni-roztrideny-barcodes-dorado_basecall.sh, slozky-barcodes-dorado_basecall.sh)

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
mkdir -p "pbs_outputs"

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: RUN_NUMBER není nastaven." >&2
    echo "Spuštění: qsub -v RUN_NUMBER=run1 HAC-demultiplex-BAM_basecall.sh" >&2
    exit 1
fi

# =============================================================================
# 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST)
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar"

#Vstupní data (.pod5)
INPUT_DIR="$BASE_DIR/${RUN_NUMBER}_pod5_pass"

OUTPUT_DIR="$BASE_DIR/RESULTS/HAC-basecall_results"
RUN_OUTPUT_DIR="$OUTPUT_DIR/HAC-basecall_output_${RUN_NUMBER}"
FINAL_OUTPUT_DIR="$RUN_OUTPUT_DIR"

DORADO_DIR="$BASE_DIR/basecalling/dorado-2.0.0-linux-x64"
DORADO_BIN="$DORADO_DIR/bin/dorado"
MODEL="$DORADO_DIR/models/dna_r10.4.1_e8.2_400bps_hac@v5.2.0"
KIT="SQK-NBD114-24"

# Na scratchi
LOCAL_DORADO_BIN="$SCRATCHDIR/dorado-2.0.0-linux-x64/bin/dorado"
LOCAL_MODEL="$SCRATCHDIR/dorado-2.0.0-linux-x64/models/dna_r10.4.1_e8.2_400bps_hac@v5.2.0"

# Logy
RUN_LOG_DIR="$BASE_DIR/basecalling/run_logs"
CENTRAL_LOG="$RUN_LOG_DIR/HAC-basecall_history.txt"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$RUN_OUTPUT_DIR"
mkdir -p "$FINAL_OUTPUT_DIR"
mkdir -p "$RUN_LOG_DIR"

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
echo "Kopíruji modely a pod5 data do scratche..."
cp -r $DORADO_DIR $SCRATCHDIR/
cp -r $INPUT_DIR $SCRATCHDIR/pod5_data

mkdir -p $SCRATCHDIR/demultiplexed

JOB_LOG="$SCRATCHDIR/HAC-basecall_info.txt"

{
    echo "------------------------------------------------------------------"
    echo "Run: $RUN_NUMBER (Model: HAC)"
    echo "Datum: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch: $SCRATCHDIR"
    echo "Vstup: $INPUT_DIR"
    echo "Výstup: $FINAL_OUTPUT_DIR"
} | tee -a "$JOB_LOG" >> "$CENTRAL_LOG"

# =============================================================================
# 4. BASECALLING (Uložení do velkého BAMu s vloženými štítky barcodů)
# =============================================================================
echo "Spouštím bezpečný Basecalling na GPU..."

"$LOCAL_DORADO_BIN" basecaller "$LOCAL_MODEL" "$SCRATCHDIR/pod5_data" \
    --kit-name "$KIT" \
    --min-qscore 9 \
    --device cuda:0 > "$SCRATCHDIR/unaligned_barcoded.bam"

# =============================================================================
# 5. DEMULTIPLEXING (Nyní Dorado už jen snadno přečte štítky)
# =============================================================================
echo "Basecalling dokončen (RAM uvolněna). Rozděluji data..."

"$LOCAL_DORADO_BIN" demux \
    --emit-fastq \
    --output-dir "$SCRATCHDIR/demultiplexed" \
    "$SCRATCHDIR/unaligned_barcoded.bam"

# =============================================================================
# 6. FILTROVÁNÍ, PŘEJMENOVÁNÍ A KOMPRESE
# =============================================================================
cd "$SCRATCHDIR/demultiplexed"

shopt -s nullglob
for FILE in *.fastq; do
    [ -f "$FILE" ] || continue
    
    # 1. Odstraní název kitu (zůstane např. barcode04.fastq)
    CLEAN_NAME="${FILE/${KIT}_/}"
    
    # 2. Vytvoří finální jméno (např. run1_barcode04.fastq.gz)
    NEW_FILENAME="${RUN_NUMBER}-HAC_${CLEAN_NAME}.gz"
    
    # 3. Vyfiltruje fragmenty a výsledek rovnou zabalí přes gzip
    echo "Filtrování (<50 bp) a komprese FASTQ" | tee -a "$JOB_LOG"
    awk 'BEGIN {OFS="\n"} \
        {header=$0; getline seq; getline qheader; getline qseq; \
        if (length(seq) >= 50) {print header, seq, qheader, qseq}}' \
        "$FILE" | gzip > "$NEW_FILENAME"
    
    rm "$FILE"
done
shopt -u nullglob

# =============================================================================
# 7. KOPÍROVÁNÍ VÝSLEDKŮ A ÚKLID
# =============================================================================
echo "Kopíruji vyfiltrovaná a zabalená data zpět na Storage..." | tee -a "$JOB_LOG"

cp "$SCRATCHDIR/demultiplexed/"*.fastq.gz "$FINAL_OUTPUT_DIR/"
cp "$JOB_LOG" "$FINAL_OUTPUT_DIR/HAC-basecall_info.txt"

if ls "$FINAL_OUTPUT_DIR/"*.fastq.gz 1> /dev/null 2>&1; then
    {
        echo "Hotovo: $RUN_NUMBER (Model: HAC) dne: $(date)"
        echo "Kopírování úspěšné. Mažu scratch."
    } | tee -a "$FINAL_OUTPUT_DIR/HAC-basecall_info.txt"
    clean_scratch
else
    echo "Chyba: kopírování výsledků selhalo, data zůstávají ve scratchi." | tee -a "$FINAL_OUTPUT_DIR/HAC-basecall_info.txt" >&2
    exit 1
fi