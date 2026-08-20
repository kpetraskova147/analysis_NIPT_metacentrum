#!/bin/bash
# =============================================================================
# PBS HLAVIČKA - Nastavení zdrojů pro PromethION
# =============================================================================
#PBS -N BAM_Basecall
#PBS -l select=1:ncpus=4:ngpus=1:mem=200gb:scratch_local=2500gb:gpu_mem=40gb
#PBS -l walltime=48:00:00
#PBS -q gpu
#PBS -j oe
#PBS -m ae
#PBS -M petraskkar@natur.cuni.cz


# -q gpu: Zařazení do GPU fronty.
# -j oe: Sloučení standardního výstupu (o) a chyb (e)do jednoho souboru pro snadnější kontrolu.
# -m ae: Odesílání emailů při ukončení (a) nebo selhání (e) úlohy. Ujisti se, že máš správně nastavenou emailovou adresu v PBS konfiguraci, aby ti dorazily notifikace.

# =============================================================================
# INSTRUKCE
# =============================================================================
        # Vytvoř složku RESULTS a v ní složku basecall_results (pro výsledky z Dorada) + alignment_results, wisecondorX_results, statistics_results
        # DATA: složku pod5_pass s mými .pod5 soubory - ve složkách: run1_pod5_pass, run2_pod5_pass, ...
        # Vytvoř si složku basecalling a v ní:
        # 1. SKRIPT: 'demultiplex_dorado_basecall_array.sh'   (neni-roztrideny-barcodes-dorado_basecall.sh, slozky-barcodes-dorado_basecall.sh)
        # 2. SLOŽKA dorado-1.0.0-linux-x64 - (SOFTWARE) složka bin - soubor dorado
        #                                  - (MODELY) složka models - dna_r10.4.1_e8.2_400bps_sup@v5.2.0/    - lidský genom
        #                                                          (- dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mC_5hmC/   - methylace)

        # pozn.: pokud chci sledovat metylaci, musím odstranit # před --modified-bases-models a použít model s metylací 
        #        (dna_r10.4.1_e8.2_400bps_sup@v5.0.0_5mC_5hmC@v1) v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).

        # Nastavení: upravím cesty v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).

        # Ve skriptu je nastavení zaslání mailu při ukončení nebo selhání úlohy - nastav svou mailovou adresu v PBS hlavičce (řádek #PBS -M) 

        # Spuštění: qsub -v RUN_NUMBER="run1" demultiplex_dorado_basecall_array.sh
        
# =============================================================================
# 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST)
# =============================================================================

# Základní adresář, kde běží má analýza a mám zde uložena data
# ÚPRAVA: TVUJ_LOGIN (můj osobní login na metacentru), praha1 (cluster, kde běží analýza a mám data)
BASE_DIR="/storage/brno12-cerit/home/petraskkar"

# Kde jsou vstupní data (.pod5)
INPUT_POD5_DIR="$BASE_DIR/${RUN_NUMBER}_pod5_pass"   # ${RUN_NUMBER}_pod5_pass = složka s pod5 soubory z konkrétního runu (run1_pod5_pass, ...)

# Kam půjde výsledek (.bam)
OUTPUT_DIR="$BASE_DIR/RESULTS/basecall_results"
FINAL_OUTPUT_DIR="$OUTPUT_DIR/BAM_basecall_${RUN_NUMBER}"

# Úložiště pro centrální logovací soubor - záznam o průběhu spuštěných úloh, uzlech a datech všech již projetých souborů.
mkdir -p "$BASE_DIR/basecalling/run_logs"           # vytvoříme složku pro logy, pokud neexistuje
CENTRAL_LOG="$BASE_DIR/basecalling/run_logs/BAM_basecall_history.txt"

# Cesta k softwaru Dorado
DORADO_DIR="$BASE_DIR/basecalling/dorado-1.0.0-linux-x64"
DORADO_BIN="$DORADO_DIR/bin/dorado"

# Model: Pro PromethION R10.4.1 používám SUP (super accuracy) basecalling.
DORADO_MODEL="$DORADO_DIR/models/dna_r10.4.1_e8.2_400bps_sup@v5.2.0"
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
# Pokud metylaci CHCEŠ, odkomentuj tento řádek (smaž # a mezeru na začátku řádku):
# METYLACE="--modified-bases-models dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mC_5hmC@v1"


# =============================================================================
# 2. PŘÍPRAVA PROSTŘEDÍ
# =============================================================================

# Kontrola existence scratche (dočasné virtuální úložiště)
test -n "$SCRATCHDIR" || { echo >&2 "Chyba: SCRATCHDIR není nastaven!"; exit 1; }   # exit 1 = chrání má data v domovském adresáři před nechtěným smazáním.

# Přechod do scratche a kopírování souborů
cd $SCRATCHDIR || { echo >&2 "Chyba: Nepodařilo se vstoupit do SCRATCHDIR"; exit 2; }
cp -r $INPUT_POD5_DIR $SCRATCHDIR/
cp -r $DORADO_DIR $SCRATCHDIR/

# Lokální cesty k doradu ve scratchi
LOCAL_DORADO_DIR="$SCRATCHDIR/dorado-1.0.0-linux-x64"
LOCAL_DORADO_BIN="$LOCAL_DORADO_DIR/bin/dorado"
LOCAL_DORADO_MODEL="$LOCAL_DORADO_DIR/models/dna_r10.4.1_e8.2_400bps_sup@v5.2.0"
LOCAL_METYLACE="$LOCAL_DORADO_DIR/models/dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mC_5hmC@v1"

# Logování pro kontrolu - logovací soubor bude obsahovat informace o spuštění úlohy, uzlu a cestě ke scratchi
# 1. Centrální logovací soubor pro všechny úlohy v hlavní složce
echo "------------------------------------------------------------------" >> $CENTRAL_LOG
echo "Spouštím úlohu: $RUN_NUMBER dne: $(date)" >> $CENTRAL_LOG
echo "Uzel: $(hostname -f)" >> $CENTRAL_LOG
echo "Scratch adresář: $SCRATCHDIR" >> $CENTRAL_LOG

# 2. Logovací soubor specifický pro tuto úlohu ve scratchi - smaže se po úspěšném dokončení, ale pokud dojde k chybě, zůstane pro kontrolu
echo "----------------------------------------------------------------" > BAM_basecall_info.txt
echo "Spouštím úlohu: $RUN_NUMBER dne: $(date)" | tee -a BAM_basecall_info.txt
echo "Uzel: $(hostname -f)" | tee -a BAM_basecall_info.txt
echo "Scratch adresář: $PWD" | tee -a BAM_basecall_info.txt
# Kontrola kopírování dat do scratche
TARGET_POD5="$SCRATCHDIR/$(basename $INPUT_POD5_DIR)"
echo "--- Kontrola scratche po kopírování ---" | tee -a BAM_basecall_info.txt
if [ -d "$TARGET_POD5" ]; then
    FILE_COUNT=$(ls -1 "$TARGET_POD5"/*.pod5 2>/dev/null | wc -l)
    DIR_SIZE=$(du -sh "$TARGET_POD5" | cut -f1)
    echo "Složka $(basename $INPUT_POD5_DIR) OK." | tee -a BAM_basecall_info.txt
    echo "Počet .pod5 souborů: $FILE_COUNT" | tee -a BAM_basecall_info.txt
    echo "Celková velikost: $DIR_SIZE" | tee -a BAM_basecall_info.txt
else
    echo "KRITICKÁ CHYBA: Složka s daty se do scratche nepřekopírovala!" | tee -a BAM_basecall_info.txt
    exit 1
fi

# =============================================================================
# 3. BASECALLING (DORADO)
# =============================================================================

echo "[2/3] Spouštím Dorado Basecaller..." | tee -a BAM_basecall_info.txt

# Sestavení příkazu.
# Pokud chceš zapnout metylaci, odmaž znak '#' na začátku řádku --modified-bases
# Výstup jde rovnou do fastq souboru.

$LOCAL_DORADO_BIN basecaller \
$LOCAL_DORADO_MODEL \
"$SCRATCHDIR/$(basename $INPUT_POD5_DIR)" \
--recursive \
--min-qscore 9 \
$KIT_NAME \
$METYLACE \
--device cuda:0 \
> temporary_unaligned.bam

# --recursive \ = Prohledá všechny pod5 soubory v adresáři a podadresářích (složkách).
# --min-qscore 9 \ = Filtruje slabé čtení. Qscore 9 je poměrně přísný filtr, ale pro vysokou kvalitu dat je to dobrá volba.
# --emit-fastq \ = Vypne generování BAM souborů (generuji až v další analýze). 
# --device cuda:0 \ = Určuje, že chceme použít GPU pro zrychlení basecallingu. cuda:0 znamená první GPU v systému.

# =============================================================================
# 4. KOPÍROVÁNÍ VÝSLEDKŮ A ÚKLID
# =============================================================================

echo "[3/3] Kopíruji výsledky zpět na storage..." | tee -a BAM_basecall_info.txt

# Vytvoření výstupní složky, pokud neexistuje
mkdir -p $FINAL_OUTPUT_DIR        # mkdir -p: vytvoří složku, pokud neexistuje

# Kopírování výsledného souboru a logu z scratche zpět do storage
cp -r "$SCRATCHDIR/temporary_unaligned.bam" "$FINAL_OUTPUT_DIR/${RUN_NUMBER}_unaligned.bam"
cp "$SCRATCHDIR/BAM_basecall_info.txt" "$FINAL_OUTPUT_DIR/BAM_basecall_info.txt"

# Kontrola, zda se soubor final_reads.fastq zkopíroval správně. 
# - pokud ano, smažeme scratch, pokud ne, necháme data ve scratchi pro kontrolu.
if [ -s "$FINAL_OUTPUT_DIR/${RUN_NUMBER}_unaligned.bam" ]; then
    echo "Kopírování úspěšné. Výsledky jsou v basecall_output_${RUN_NUMBER}. Mažu scratch." | tee -a BAM_basecall_info.txt
    clean_scratch
else
    echo "CHYBA: Soubor se nezkopíroval! Data zůstávají ve scratchi pro kontrolu." | tee -a BAM_basecall_info.txt
    # Schratch není smazán, abych mohla zkontrolovat chybu.
    exit 1
fi      # fi - konec kontroly kopírování (podmínky if, převrácené if)

echo "Hotovo: $RUN_NUMBER dne: $(date)" | tee -a "$FINAL_OUTPUT_DIR/BAM_basecall_info.txt"
