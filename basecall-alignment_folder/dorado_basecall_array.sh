#!/bin/bash
# =============================================================================
# PBS HLAVIČKA - Nastavení zdrojů pro PromethION
# =============================================================================
#PBS -N Dorado_Basecall_Array
#PBS -J 1-24
#PBS -l select=1:ncpus=8:mem=64gb:ngpus=1:scratch_local=800gb
#PBS -l walltime=12:00:00
#PBS -q gpu
#PBS -j oe
#PBS -m ae
#PBS -M petraskkar@natur.cuni.cz
#PBS -o /storage/brno12-cerit/home/petraskkar/basecalling/pbs_outputs/

# -j oe: Sloučení standardního výstupu (o) a chyb (e)do jednoho souboru pro snadnější kontrolu.
# -m ae: Odesílání emailů při ukončení (a) nebo selhání (e) úlohy. Ujisti se, že máš správně nastavenou emailovou adresu v PBS konfiguraci, aby ti dorazily notifikace.

# =============================================================================
# INSTRUKCE
# =============================================================================
        # Vytvoř složku RESULTS a v ní složku basecall_results (pro výsledky z Dorada) + alignment_results, wisecondorX_results, statistics_results
        # DATA: složku pod5_pass s mými .pod5 soubory - ve složkách: run1_pod5_pass, run2_pod5_pass, ...
        # Vytvoř si složku basecalling a v ní:
        # 1. SKRIPT: 'dorado_basecall_array.sh'   (neni-roztrideny-barcodes-dorado_basecall.sh, slozky-barcodes-dorado_basecall.sh)
        # 2. DATA: složku pod5_pass s mými .pod5 soubory - ve složkách: run1_pod5_pass, run2_pod5_pass, ... - upravit cestu k nim / mít soubory v BASE_DIR
        # 3. SLOŽKA dorado-1.0.0-linux-x64 - (SOFTWARE) složka bin - soubor dorado
        #                                  - (MODELY) složka models - dna_r10.4.1_e8.2_400bps_sup@v5.2.0/    - lidský genom
        #                                                          (- dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mC_5hmC/   - methylace)
        # 4. Uprav PBS -J pro počet barcode (např. -J 1-24 pro 24 barcodů)
        # 5. složka pbs_outputs pro uložení výstupů z PBS (logy, chyby)

        # pozn.: pokud chci sledovat metylaci, musím odstranit # před --modified-bases-models a použít model s metylací 
        #        (dna_r10.4.1_e8.2_400bps_sup@v5.0.0_5mC_5hmC@v1) v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).

        # Nastavení: upravím cesty v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).

        # Ve skriptu je nastavení zaslání mailu při ukončení nebo selhání úlohy - nastav svou mailovou adresu v PBS hlavičce (řádek #PBS -M) 

        # Spuštění: qsub -v RUN_NUMBER="run1" dorado_basecall_array.sh       (neni-roztrideny-barcodes-dorado_basecall.sh, slozky-barcodes-dorado_basecall.sh)

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================

set -euo pipefail   # přísnější režim pro lepší detekci chyb, -e: skript se zastaví při jakékoliv chybě, -u: chyba při použití nedefinované proměnné, -o pipefail: chyba v jakékoliv části pipy způsobí selhání celé pipy

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: RUN_NUMBER není nastaven." >&2
    echo "Spuštění: qsub -v RUN_NUMBER=run1 dorado_basecall_array.sh" >&2
    exit 1
fi

if [ -z "${PBS_ARRAY_INDEX:-}" ]; then
    echo "Chyba: PBS_ARRAY_INDEX není nastaven." >&2
    exit 1
fi

BARCODE=$(printf "barcode%02d" "$PBS_ARRAY_INDEX")  # vytvoří název barcode01, barcode02, ... podle indexu pole

# =============================================================================
# 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST)
# =============================================================================

# Základní adresář, kde běží má analýza a mám zde uložena data
# ÚPRAVA: TVUJ_LOGIN (můj osobní login na metacentru), praha1 (cluster, kde běží analýza a mám data)
BASE_DIR="/storage/brno12-cerit/home/petraskkar"

# Vstupní data (.pod5)
WORK_DIR="$BASE_DIR/basecalling"
INPUT_ROOT="$BASE_DIR/${RUN_NUMBER}_pod5_pass"
INPUT_DIR="$INPUT_ROOT/$BARCODE"

# Výstupní data (.fastq)
OUTPUT_ROOT="$BASE_DIR/RESULTS/basecall_results"
RUN_OUTPUT_DIR="$OUTPUT_ROOT/basecall_output_${RUN_NUMBER}"
FINAL_OUTPUT_DIR="$RUN_OUTPUT_DIR/$BARCODE"

# Cesta k softwaru Dorado
DORADO_BIN="$WORK_DIR/dorado-1.0.0-linux-x64/bin/dorado"
MODEL_DIR="$WORK_DIR/dorado-1.0.0-linux-x64/models"
MODEL="$MODEL_DIR/dna_r10.4.1_e8.2_400bps_sup@v5.2.0"
KIT="SQK-NBD114-24"

# Logy
RUN_LOG_DIR="$WORK_DIR/run_logs"
CENTRAL_LOG="$RUN_LOG_DIR/basecall_history.txt"

METYLACE=""
# Pokud metylaci CHCEŠ, odkomentuj tento řádek (smaž # a mezeru na začátku řádku):
# METYLACE="--modified-bases-models dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mC_5hmC@v1"

mkdir -p "$RUN_LOG_DIR"
mkdir -p "$RUN_OUTPUT_DIR"

# =============================================================================
# 2. KONTROLA VSTUPNÍCH DAT A PROSTŘEDÍ
# =============================================================================

if [ ! -d "$INPUT_ROOT" ]; then
    echo "Chyba: neexistuje vstupní root adresář: $INPUT_ROOT" >&2
    exit 1
fi

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

cd "$SCRATCHDIR"

JOB_LOG="$SCRATCHDIR/basecall_info.txt"
TMP_FASTQ="$SCRATCHDIR/${RUN_NUMBER}_${BARCODE}.fastq"          # dočasný FASTQ soubor ve scratchi, před kompresí
TMP_FASTQ_GZ="$SCRATCHDIR/${RUN_NUMBER}_${BARCODE}.fastq.gz"    # dočasný gzipovaný FASTQ soubor ve scratchi, před kopírováním zpět na storage

{
    echo "------------------------------------------------------------------"
    echo "Run: $RUN_NUMBER"
    echo "Barcode: $BARCODE"
    echo "Datum: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch: $SCRATCHDIR"
    echo "Vstup: $INPUT_DIR"
    echo "Výstup: $FINAL_OUTPUT_DIR"
    echo "Array index: $PBS_ARRAY_INDEX"
} | tee "$JOB_LOG"

{
    echo "------------------------------------------------------------------"
    echo "Spouštím úlohu: $RUN_NUMBER / $BARCODE dne: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch adresář: $SCRATCHDIR"
    echo "Array index: $PBS_ARRAY_INDEX"
} >> "$CENTRAL_LOG"

echo "[1/4] Kontrola GPU" | tee -a "$JOB_LOG"
nvidia-smi | tee -a "$JOB_LOG"

echo "[2/4] Basecalling pro $BARCODE" | tee -a "$JOB_LOG"

# =============================================================================
# 4. BASECALLING (DORADO)
# =============================================================================

BASECALL_CMD=(
    "$DORADO_BIN" basecaller
    "$MODEL"
    "$INPUT_DIR"
    --recursive
    --min-qscore 9
    --kit-name "$KIT"
    --device cuda:0
    --emit-fastq
)
# ./"$INPUT_DIR" = Cesta ke složce s pod5 soubory, které chceme basecallovat.
# --recursive \ = Prohledá všechny pod5 soubory v adresáři a podadresářích (složkách).
# --min-qscore 9 \ = Filtruje slabé čtení. Qscore 9 je poměrně přísný filtr, ale pro vysokou kvalitu dat je to dobrá volba.
# --emit-fastq \ = Vypne generování BAM souborů (generuji až v další analýze). 
# --device cuda:0 \ = Určuje, že chceme použít GPU pro zrychlení basecallingu. cuda:0 znamená první GPU v systému.

if [ -n "$METYLACE" ]; then
    # shellcheck disable=SC2206
    BASECALL_CMD+=( $METYLACE )
fi

# Spuštění basecallingu a přesměrování výstupu do dočasného FASTQ souboru ve scratchi
"${BASECALL_CMD[@]}" > "$TMP_FASTQ"

# =============================================================================
# 5. KONTROLA VÝSLEDKU BASECALLINGU
# =============================================================================

if [ ! -s "$TMP_FASTQ" ]; then
    echo "Chyba: basecaller nevytvořil FASTQ soubor pro $BARCODE." | tee -a "$JOB_LOG" >&2
    exit 1
fi

echo "[3/4] Komprese FASTQ" | tee -a "$JOB_LOG"
gzip -f "$TMP_FASTQ"

if [ ! -s "$TMP_FASTQ_GZ" ]; then
    echo "Chyba: nepodařilo se vytvořit gzip soubor pro $BARCODE." | tee -a "$JOB_LOG" >&2
    exit 1
fi

# =============================================================================
# 6. KOPÍROVÁNÍ VÝSLEDKŮ
# =============================================================================

echo "[4/4] Kopírování výsledků zpět na storage" | tee -a "$JOB_LOG"

mkdir -p "$FINAL_OUTPUT_DIR"
cp "$TMP_FASTQ_GZ" "$FINAL_OUTPUT_DIR/"
cp "$JOB_LOG" "$FINAL_OUTPUT_DIR/basecall_info.txt"

if [ -f "$FINAL_OUTPUT_DIR/$(basename "$TMP_FASTQ_GZ")" ] && [ -f "$FINAL_OUTPUT_DIR/basecall_info.txt" ]; then
    {
        echo "Hotovo: $RUN_NUMBER / $BARCODE dne: $(date)"
        echo "Výsledný soubor: $FINAL_OUTPUT_DIR/$(basename "$TMP_FASTQ_GZ")"
        echo "Kopírování úspěšné. Mažu scratch."
    } | tee -a "$FINAL_OUTPUT_DIR/basecall_info.txt"
    clean_scratch!
else
    echo "Chyba: kopírování výsledků selhalo, data zůstávají ve scratchi." | tee -a "$JOB_LOG" >&2
    exit 1
fi