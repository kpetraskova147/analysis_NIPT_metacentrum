#!/bin/bash
# =============================================================================
# PBS HLAVIČKA
# =============================================================================
#PBS -N SUP-Dorado_Basecall_Array
#PBS -l select=1:ncpus=8:mem=64gb:ngpus=1:scratch_local=800gb
#PBS -l walltime=12:00:00
#PBS -q gpu
#PBS -j oe
#PBS -m ae
#PBS -M petraskkar@natur.cuni.cz
#PBS -J 1-24

# -j oe: Sloučení standardního výstupu (o) a chyb (e)do jednoho souboru pro snadnější kontrolu.
# -m ae: Odesílání emailů při ukončení (a) nebo selhání (e) úlohy. Ujisti se, že máš správně nastavenou emailovou adresu v PBS konfiguraci, aby ti dorazily notifikace.

# =============================================================================
# INSTRUKCE
# =============================================================================
        # Vytvoř složku RESULTS a v ní složku basecall_results (pro výsledky z Dorada) + alignment_results, wisecondorX_results, statistics_results
        # DATA: složku pod5_pass s mými .pod5 soubory - ve složkách: run1_pod5_pass, run2_pod5_pass, ...
        # Vytvoř si složku basecalling a v ní:
        # 1. SKRIPT: 'dorado_basecall_array.sh'   (neni-roztrideny-barcodes-dorado_basecall.sh, slozky-barcodes-dorado_basecall.sh)
        # 2. SLOŽKA dorado-1.0.0-linux-x64 - (SOFTWARE) složka bin - soubor dorado
        #                                  - (MODELY) složka models - dna_r10.4.1_e8.2_400bps_sup@v5.2.0/    - lidský genom
        #                                                          (- dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mC_5hmC/   - methylace)
        # !! Uprav PBS -J pro počet barcode (např. -J 1-24 pro 24 barcodů)

        # pozn.: pokud chci sledovat metylaci, musím odstranit # před --modified-bases-models a použít model s metylací 
        #        (dna_r10.4.1_e8.2_400bps_sup@v5.0.0_5mC_5hmC@v1) v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).

        # Nastavení: upravím cesty v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).

        # Ve skriptu je nastavení zaslání mailu při ukončení nebo selhání úlohy - nastav svou mailovou adresu v PBS hlavičce (řádek #PBS -M) 

        # Spuštění: qsub -v RUN_NUMBER="run1" dorado_basecall_array.sh       (neni-roztrideny-barcodes-dorado_basecall.sh, slozky-barcodes-dorado_basecall.sh)

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
mkdir -p "pbs_outputs"

set -euo pipefail

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: RUN_NUMBER není nastaven." >&2
    echo "Spuštění: qsub -v RUN_NUMBER=run1 sup-dorado_basecall_array.sh" >&2
    exit 1
fi

if [ -z "${PBS_ARRAY_INDEX:-}" ]; then
    echo "Chyba: PBS_ARRAY_INDEX není nastaven." >&2
    exit 1
fi

BARCODE=$(printf "barcode%02d" "$PBS_ARRAY_INDEX")

# =============================================================================
# 1. NASTAVENÍ UŽIVATELE A CESTY
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar"
WORK_DIR="$BASE_DIR/basecalling"

# Vstupní data (.pod5)
INPUT_ROOT="$BASE_DIR/${RUN_NUMBER}_pod5_pass"
INPUT_DIR="$INPUT_ROOT/$BARCODE"

# Výstupní data (.fastq)
OUTPUT_ROOT="$BASE_DIR/RESULTS/SUP-basecall_results"
FINAL_OUTPUT_DIR="$OUTPUT_ROOT/SUP-basecall_output_${RUN_NUMBER}"

# Dorado originál (na Storage)
DORADO_DIR="$WORK_DIR/dorado-2.0.0-linux-x64"
DORADO_BIN="$DORADO_DIR/bin/dorado"
MODEL="$DORADO_DIR/models/dna_r10.4.1_e8.2_400bps_sup@v5.2.0"
KIT="SQK-NBD114-24"

# Na scratchi
LOCAL_DORADO_BIN="$SCRATCHDIR/dorado-2.0.0-linux-x64/bin/dorado"
LOCAL_MODEL="$SCRATCHDIR/dorado-2.0.0-linux-x64/models/dna_r10.4.1_e8.2_400bps_sup@v5.2.0"

# Logy
RUN_LOG_DIR="$WORK_DIR/run_logs"
CENTRAL_LOG="$RUN_LOG_DIR/SUP-basecall_history.txt"
JOB_LOG_DIR="$FINAL_OUTPUT_DIR/run_logs"
JOB_LOG="$SCRATCHDIR/SUP-basecall_info.txt"

mkdir -p "$FINAL_OUTPUT_DIR"
mkdir -p "$RUN_LOG_DIR"
mkdir -p "$JOB_LOG_DIR"

# =============================================================================
# 2. KONTROLA VSTUPŮ
# =============================================================================
if [ ! -d "$INPUT_DIR" ]; then
    echo "Chyba: neexistuje vstupní barcode adresář: $INPUT_DIR" >&2
    exit 1
fi

if [ -z "${SCRATCHDIR:-}" ]; then
    echo "Chyba: SCRATCHDIR není nastaven." >&2
    exit 1
fi

# =============================================================================
# 3. PŘESUN DO SCRATCHE (ZÁSADNÍ PRO GPU VÝKON)
# =============================================================================
cd "$SCRATCHDIR"

echo "[1/4] Kopíruji Dorado modely a data do Scratche..." | tee -a "$JOB_LOG"
cp -r "$DORADO_DIR" "$SCRATCHDIR/"
mkdir -p "$SCRATCHDIR/pod5_data"
cp -r "$INPUT_DIR/"* "$SCRATCHDIR/pod5_data/"

TMP_FASTQ_GZ="$SCRATCHDIR/${RUN_NUMBER}-SUP_${BARCODE}.fastq.gz"

{
    echo "------------------------------------------------------------------"
    echo "Run: $RUN_NUMBER | Barcode: $BARCODE"
    echo "Datum: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch: $SCRATCHDIR"
} | tee -a "$JOB_LOG" >> "$CENTRAL_LOG"

nvidia-smi | tee -a "$JOB_LOG" >> "$CENTRAL_LOG"

# =============================================================================
# 4. BASECALLING S FILTRACÍ
# =============================================================================
echo "[2/4] Basecalling, filtrace (<50 bp) a komprese pro $BARCODE" | tee -a "$JOB_LOG"

# Dorado čte data, rovnou z nich dělá FASTQ a posílá je do AWK filtru. 
# Ten zahodí vše pod 50 bp a pošle to rovnou do komprese GZIP.
"$LOCAL_DORADO_BIN" basecaller "$LOCAL_MODEL" "$SCRATCHDIR/pod5_data" \
    --recursive \
    --min-qscore 9 \
    --kit-name "$KIT" \
    --device cuda:0 \
    --emit-fastq | \
awk 'BEGIN {OFS="\n"} \
    {header=$0; getline seq; getline qheader; getline qseq; \
    if (length(seq) >= 50) \
    {print header, seq, qheader, qseq}}' | \
gzip > "$TMP_FASTQ_GZ"

# =============================================================================
# 5. KONTROLA A KOPÍROVÁNÍ VÝSLEDKŮ
# =============================================================================
if [ ! -s "$TMP_FASTQ_GZ" ]; then
    echo "Chyba: Výsledný soubor je prázdný nebo se nevytvořil!" | tee -a "$JOB_LOG" >&2
    cp "$JOB_LOG" "$FINAL_OUTPUT_DIR/SUP-basecall_info_${BARCODE}.txt"
    exit 1
fi

echo "[4/4] Kopírování výsledků zpět na storage" | tee -a "$JOB_LOG"
cp "$TMP_FASTQ_GZ" "$FINAL_OUTPUT_DIR/"
cp "$JOB_LOG" "$FINAL_OUTPUT_DIR/SUP-basecall_info_${BARCODE}.txt"

echo "Hotovo: $RUN_NUMBER / $BARCODE dne: $(date)" | tee -a "$FINAL_OUTPUT_DIR/SUP-basecall_info_${BARCODE}.txt"
clean_scratch