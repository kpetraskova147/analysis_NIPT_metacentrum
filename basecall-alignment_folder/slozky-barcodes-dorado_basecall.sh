#!/bin/bash
# =============================================================================
# PBS HLAVIČKA - Nastavení zdrojů pro PromethION
# =============================================================================
#PBS -N Dorado_Basecall
#PBS -l select=1:ncpus=8:mem=64gb:ngpus=1:scratch_local=800gb
#PBS -l walltime=8:00:00
#PBS -q gpu
#PBS -j oe
#PBS -m ae
#PBS -M tvojeadresa@blabla.cz

# -q gpu: Zařazení do GPU fronty.
# -j oe: Sloučení standardního výstupu (o) a chyb (e)do jednoho souboru pro snadnější kontrolu.
# -m ae: Odesílání emailů při ukončení (a) nebo selhání (e) úlohy. Ujisti se, že máš správně nastavenou 
#        emailovou adresu v PBS konfiguraci, aby ti dorazily notifikace.

# =============================================================================
# INSTRUKCE
# =============================================================================
        # Vytvoř složku RESULTS a v ní složku basecall_results (pro výsledky z Dorada) + alignment_results, wisecondorX_results, statistics_results
        # DATA: složku pod5_pass s mými .pod5 soubory - ve složkách: run1_pod5_pass, run2_pod5_pass, ...
        # Vytvoř si složku basecalling a v ní:
        # 1. SKRIPT: 'dorado_basecall.sh'   (nebo neni-roztrideny-barcodes-dorado_basecall.sh, slozky-barcodes-dorado_basecall.sh)
        # 2. SLOŽKA PRO CENTRAL LOGOVACÍ SOUBOR: run_logs
        # 3. SLOŽKA dorado-1.0.0-linux-x64 - (SOFTWARE) složka bin - soubor dorado
        #                                  - (MODELY) složka models - dna_r10.4.1_e8.2_400bps_sup@v5.2.0/    - lidský genom
        #                                                          (- dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mC_5hmC/   - methylace)
        # pozn.: pokud chci sledovat metylaci, musím odstranit # před --modified-bases-models a použít model s metylací 
        #        (dna_r10.4.1_e8.2_400bps_sup@v5.0.0_5mC_5hmC@v1) v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).

        # Nastavení: upravím cesty v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).

        # Ve skriptu je nastavení zaslání mailu při ukončení nebo selhání úlohy - nastav svou mailovou adresu v PBS hlavičce (řádek #PBS -M) 

        # Spuštění: qsub -v RUN_NUMBER="run1" dorado_basecall.sh    (nebo neni-roztrideny-barcodes-dorado_basecall.sh, slozky-barcodes-dorado_basecall.sh)


# =============================================================================
# 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST)
# =============================================================================

# Základní adresář, kde běží má analýza a mám zde uložena data
# ÚPRAVA: TVUJ_LOGIN (můj osobní login na metacentru), praha1 (cluster, kde běží analýza a mám data)
BASE_DIR="/storage/brno12-cerit/home/TVUJ_LOGIN"

# Kde jsou vstupní data (.pod5)
INPUT_POD5_DIR="$BASE_DIR/pod5_pass/${RUN_NUMBER}_pod5_pass"   

# Kam půjde výsledek (.fastq)
OUTPUT_DIR="$BASE_DIR/RESULTS/basecall_results"
FINAL_OUTPUT_DIR="$OUTPUT_DIR/basecall_output_${RUN_NUMBER}"

# Cesta k softwaru Dorado
DORADO_BIN="$BASE_DIR/basecalling/dorado-1.0.0-linux-x64/bin/dorado"

# Úložiště pro centrální logovací soubor
mkdir -p "$BASE_DIR/basecalling/run_logs"           
CENTRAL_LOG="$BASE_DIR/basecalling/run_logs/basecall_history.txt"

# Model
MODEL="$BASE_DIR/dorado-1.0.0-linux-x64/models/dna_r10.4.1_e8.2_400bps_sup@v5.2.0"
    # dna: Je to pro DNA (ne RNA).
    # r10.4.1: Typ póru (flow cell), kterou používáš.
    # e8.2: Verze motorového proteinu (chemie).
    # 400bps: Rychlost sekvenace (400 bází za sekundu).
    # sup: Super Accuracy. Model sekvenace s nejvyšší přesností, ale hodně pomalý.
    # @v5.2.0: Verze modelu. Můžeš zkontrolovat, zda je dostupná novější verze na GitHubu Dorado.
    # GitHub Dorado modely: 

# Kit (Native Barcoding 24)

KIT="SQK-NBD114-24"

KIT_NAME="--kit-name $KIT"     # KIT_NAME = pro vymazání KIT_NAME z názvu složky s výsledky

# --- NASTAVENÍ METYLACE ---
METYLACE=""
# Pokud metylaci CHCEŠ, odkomentuj tento řádek a uprav cestu k modelu s metylací:
# METYLACE="--modified-bases-models $BASE_DIR/dorado-1.0.0-linux-x64/models/dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mC_5hmC@v1"

# =============================================================================
# 2. PŘÍPRAVA PROSTŘEDÍ (SCRATCH)
# =============================================================================

# Kontrola existence scratche a přechod do něj, pokud selže, skript se ukončí s chybou
test -n "$SCRATCHDIR" || { echo >&2 "Chyba: SCRATCHDIR není nastaven!"; exit 1; }  
cd $SCRATCHDIR || { echo >&2 "Chyba: Nepodařilo se vstoupit do SCRATCHDIR"; exit 2; }

# Zápis do centrálního logu domů na storage - logovací soubor bude obsahovat informace o spuštění úlohy, uzlu a cestě ke scratchi
# 1. Centrální logovací soubor pro všechny úlohy v hlavní složce run_logs
echo "------------------------------------------------------------------" >> $CENTRAL_LOG
echo "Spouštím úlohu: $RUN_NUMBER dne: $(date)" >> $CENTRAL_LOG
echo "Uzel: $(hostname -f)" >> $CENTRAL_LOG
echo "Scratch adresář: $SCRATCHDIR" >> $CENTRAL_LOG

# Lokální log ve scratchi - specifický pro tuto úlohu, smaže se po úspěšném dokončení, ale pokud dojde k chybě, zůstane pro kontrolu
echo "----------------------------------------------------------------" > basecall_info.txt
echo "Spouštím úlohu: $RUN_NUMBER dne: $(date)" | tee -a basecall_info.txt
echo "Uzel: $(hostname -f)" | tee -a basecall_info.txt
echo "Scratch adresář: $PWD" | tee -a basecall_info.txt


# =============================================================================
# 3. BASECALLING (DORADO SMYČKA)
# =============================================================================

echo "[2/3] Spouštím Dorado Basecaller pro jednotlivé barkody..." | tee -a basecall_info.txt

# Smyčka projde všechny podsložky barcode uvnitř nakopírovaných dat ve scratchi
for BARCODE_PATH in "$INPUT_POD5_DIR"/barcode*; do
    if [ ! -d "${BARCODE_PATH}" ]; then
        continue
    fi

    BARCODE_NAME=${RUN_NUMBER}_$(basename "${BARCODE_PATH}")
    echo "Zpracovávám: ${BARCODE_NAME}" | tee -a basecall_info.txt
    
    # Výsledek zapisujeme rovnou do scratche pod jménem barkodu (barcode01.fastq atd.)
    $DORADO_BIN basecaller \
        $MODEL \
        "${BARCODE_PATH}" \
        --recursive \
        --min-qscore 9 \
        $KIT_NAME \
        $METYLACE \
        --device cuda:0 \
        --emit-fastq > "${BARCODE_NAME}.fastq"

done

# =============================================================================
# 4. KOPÍROVÁNÍ VÝSLEDKŮ DOMŮ A ÚKLID
# =============================================================================

echo "[3/3] Kopíruji výsledky zpět na storage..." | tee -a basecall_info.txt

# Vytvoření výstupní složky, pokud neexistuje
mkdir -p $FINAL_OUTPUT_DIR        # mkdir -p: vytvoří složku, pokud neexistuje

# Kopírujeme VŠECHNY vygenerované fastq soubory a log zpět domů
cp "$SCRATCHDIR"/*.fastq "$FINAL_OUTPUT_DIR/"
cp "$SCRATCHDIR/basecall_info.txt" "$FINAL_OUTPUT_DIR/basecall_info.txt"

# Kontrola, zda se soubor final_reads.fastq zkopíroval správně. 
# - pokud ano, smažeme scratch, pokud ne, necháme data ve scratchi pro kontrolu.
if ls "$FINAL_OUTPUT_DIR"/*.fastq 1> /dev/null 2>&1; then
    echo "Kopírování úspěšné. Výsledky jsou v basecall_output_${RUN_NUMBER}. Mažu scratch." >> "$FINAL_OUTPUT_DIR/basecall_info.txt"
    clean_scratch!
else
    echo "CHYBA: Žádné fastq soubory se nezkopírovaly! Data zůstávají ve scratchi." >> "$FINAL_OUTPUT_DIR/basecall_info.txt"
        # Schratch není smazán, abych mohla zkontrolovat chybu.
    exit 1
fi     # fi - konec kontroly kopírování (podmínky if, převrácené if)

echo "Hotovo: $RUN_NUMBER dne: $(date)" | tee -a "$FINAL_OUTPUT_DIR/basecall_info.txt"