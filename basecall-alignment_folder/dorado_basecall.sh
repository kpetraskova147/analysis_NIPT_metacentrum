#!/bin/bash
# =============================================================================
# PBS HLAVIČKA - Nastavení zdrojů pro PromethION
# =============================================================================
#PBS -N Dorado_Basecall
#PBS -l select=1:ncpus=16:mem=64gb:ngpus=1:gpu_cap=cuda80:scratch_local=1000gb
#PBS -l walltime=24:00:00
#PBS -q gpu
#PBS -j oe
#PBS -m ae
#PBS -M tvoje.adresa@email.cz


# -q gpu: Zařazení do GPU fronty.
# -j oe: Sloučení standardního výstupu (o) a chyb (e)do jednoho souboru pro snadnější kontrolu.
# -m ae: Odesílání emailů při ukončení (a) nebo selhání (e) úlohy. Ujisti se, že máš správně nastavenou emailovou adresu v PBS konfiguraci, aby ti dorazily notifikace.

# =============================================================================
# INSTRUKCE
# =============================================================================
        # Vytvoř složku alignment a v ní složku basecalling_results (pro výsledky z Dorada)
        # Vytvoř si složku basecalling a v ní:
        # 1. SKRIPT: 'dorado_basecall.sh'
        # 2. DATA: složku pod5_pass s mými .pod5 soubory - ve složkách: run1_pod5_pass, run2_pod5_pass, ...
        # 3. VÝSTUPNÍ SLOŽKA: basecall_results
        # 4. SLOŽKA PRO CENTRAL LOGOVACÍ SOUBOR: run_logs
        # 5. SLOŽKA dorado-1.0.0-linux-x64 - (SOFTWARE) složka bin - soubor dorado
        #                                  - (MODELY) složka models - dna_r10.4.1_e8.2_400bps_sup@v5.2.0/    - lidský genom
        #                                                          (- dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mC_5hmC/   - methylace)
        # pozn.: pokud chci sledovat metylaci, musím odstranit # před --modified-bases-models a použít model s metylací 
        #        (dna_r10.4.1_e8.2_400bps_sup@v5.0.0_5mC_5hmC@v1) v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).

        # Nastavení: upravím cesty v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).

        # Ve skriptu je nastavení zaslání mailu při ukončení nebo selhání úlohy - nastav svou mailovou adresu v PBS hlavičce (řádek #PBS -M) 

        # Spuštění: qsub -v RUN_NUMBER="run1" dorado_basecall.sh


# =============================================================================
# 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST)
# =============================================================================

# Základní adresář, kde běží má analýza a mám zde uložena data
# ÚPRAVA: TVUJ_LOGIN (můj osobní login na metacentru), praha1 (cluster, kde běží analýza a mám data)
BASE_DIR="/storage/praha1/home/TVUJ_LOGIN"

# Kde jsou vstupní data (.pod5)
INPUT_POD5_DIR="$BASE_DIR/basecalling/pod5_pass/${RUN_NUMBER}_pod5_pass"   # ${RUN_NUMBER}_pod5_pass = složka s pod5 soubory z konkrétního runu (run1_pod5_pass, ...)

# Kam půjde výsledek (.fastq)
OUTPUT_DIR="$BASE_DIR/alignment/basecall_results"
FINAL_OUTPUT_DIR="$OUTPUT_DIR/basecall_output_${RUN_NUMBER}"

# Cesta k softwaru Dorado
DORADO_BIN="$BASE_DIR/software/dorado-1.0.0-linux-x64/bin/dorado"

# Úložiště pro centrální logovací soubor - záznam o průběhu spuštěných úloh, uzlech a datech všech již projetých souborů.
mkdir -p "$BASE_DIR/run_logs"           # vytvoříme složku pro logy, pokud neexistuje
CENTRAL_LOG="$BASE_DIR/run_logs/basecall_history.txt"

# Model: Pro PromethION R10.4.1 používám SUP (super accuracy) basecalling.
MODEL="dna_r10.4.1_e8.2_400bps_sup@v5.2.0"
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

# Přechod do scratche, pokud selže, skript se ukončí s chybou (bezpečnost)
cd $SCRATCHDIR || { echo >&2 "Chyba: Nepodařilo se vstoupit do SCRATCHDIR"; exit 2; }

# Logování pro kontrolu - logovací soubor bude obsahovat informace o spuštění úlohy, uzlu a cestě ke scratchi
# 1. Centrální logovací soubor pro všechny úlohy v hlavní složce
echo "------------------------------------------------------------------" >> $CENTRAL_LOG
echo "Spouštím úlohu: $RUN_NUMBER dne: $(date)" >> $CENTRAL_LOG
echo "Uzel: $(hostname -f)" >> $CENTRAL_LOG
echo "Scratch adresář: $SCRATCHDIR" >> $CENTRAL_LOG

# 2. Logovací soubor specifický pro tuto úlohu ve scratchi - smaže se po úspěšném dokončení, ale pokud dojde k chybě, zůstane pro kontrolu
echo "----------------------------------------------------------------" | tee basecall_info.txt
echo "Spouštím úlohu: $RUN_NUMBER dne: $(date)" | tee -a basecall_info.txt
echo "Uzel: $(hostname -f)" | tee -a basecall_info.txt
echo "Scratch adresář: $PWD" | tee -a basecall_info.txt

echo "[1/3] Kopíruji vstupní pod5 data do scratche..." | tee -a basecall_info.txt
# Kopírujeme data ze storage do scratche pro rychlé čtení
cp -r $INPUT_POD5_DIR/* ./pod5_pass/

# =============================================================================
# 3. BASECALLING (DORADO)
# =============================================================================

echo "[2/3] Spouštím Dorado Basecaller..." | tee -a basecall_info.txt

# Sestavení příkazu.
# Pokud chceš zapnout metylaci, odmaž znak '#' na začátku řádku --modified-bases
# Výstup jde rovnou do fastq souboru.

$DORADO_BIN basecaller \
$MODEL \
./pod5_pass \
--recursive \
--min-qscore 9 \
$KIT_NAME \
$METYLACE \
--device cuda:0 \
> temporary_unaligned.bam

# ./pod5_pass = Cesta ke složce s pod5 soubory, které chceme basecallovat.
# --recursive \ = Prohledá všechny pod5 soubory v adresáři a podadresářích (složkách).
# --min-qscore 9 \ = Filtruje slabé čtení. Qscore 9 je poměrně přísný filtr, ale pro vysokou kvalitu dat je to dobrá volba.
# --emit-fastq \ = Vypne generování BAM souborů (generuji až v další analýze). 
# --device cuda:0 \ = Určuje, že chceme použít GPU pro zrychlení basecallingu. cuda:0 znamená první GPU v systému.

# =============================================================================
# 4. DEMULTIPLEXING (To je ten klíčový krok!)
# =============================================================================

echo "[3/4] Rozděluji data podle barcodů (Demultiplexing) do složky ${RUN_NUMBER}_demultiplex_output..."

mkdir ${RUN_NUMBER}_demultiplex_output # vytvoříme unikátní složku pro výstup z demultiplexingu, aby se nám data z různých úloh nemíchala}

# Dorado Demux vezme ten BAM a rozseká ho na soubory do složky ${RUN_NUMBER}_demultiplex_output
# --emit-fastq = generuje FASTQ soubory (místo BAM) pro každý barcode pro další analýzu (alignment).

$DORADO_BIN demux \
--output-dir ./${RUN_NUMBER}_demultiplex_output \
--emit-fastq \
temporary_unaligned.bam

# =============================================================================
# 5. PŘEJMENOVÁNÍ SOUBORŮ
# =============================================================================

echo "[4/5] Čistím názvy souborů (odstraňuji $KIT)..." | tee -a basecall_info.txt

cd ${RUN_NUMBER}_demultiplex_output

# Cyklus přes všechny fastq soubory
for FILE in *.fastq; do
    # Pokud soubor existuje (pojistka)
    [ -f "$FILE" ] || continue
    
    # Nový název: Ve jménu souboru nahradíme "SQK-NBD114-24_" za "nic"
    # ${PROMĚNNÁ/CO_NAHRADIT/ČÍM_NAHRADIT}
    NEW_NAME="${FILE/${KIT}_/}"
    
    # Přejmenování
    mv "$FILE" "$NEW_NAME"
done

# Vracíme se o úroveň výš (z demux složky zpět do rootu scratche)
cd ..

# =============================================================================
# 6. KOPÍROVÁNÍ VÝSLEDKŮ A ÚKLID
# =============================================================================

echo "[3/3] Kopíruji výsledky zpět na storage..." | tee -a basecall_info.txt

# Vytvoření výstupní složky, pokud neexistuje
mkdir -p $FINAL_OUTPUT_DIR        # mkdir -p: vytvoří složku, pokud neexistuje

# Kopírování výsledného souboru a logu z scratche zpět do storage
cp -r "$SCRATCHDIR/${RUN_NUMBER}_demultiplex_output" "$FINAL_OUTPUT_DIR/"
cp "$SCRATCHDIR/basecall_info.txt" "$FINAL_OUTPUT_DIR/basecall_info.txt"

# Kontrola, zda se soubor final_reads.fastq zkopíroval správně. 
# - pokud ano, smažeme scratch, pokud ne, necháme data ve scratchi pro kontrolu.
if [ -d "$FINAL_OUTPUT_DIR" ]; then
    echo "Kopírování úspěšné. Výsledky jsou v basecall_output_${RUN_NUMBER}. Mažu scratch." | tee -a basecall_info.txt
    clean_scratch
else
    echo "CHYBA: Soubor se nezkopíroval! Data zůstávají ve scratchi pro kontrolu." | tee -a basecall_info.txt
    # Schratch není smazán, abych mohla zkontrolovat chybu.
    exit 1
fi      # fi - konec kontroly kopírování (podmínky if, převrácené if)

echo "Hotovo: $RUN_NUMBER dne: $(date)" | tee -a basecall_info.txt