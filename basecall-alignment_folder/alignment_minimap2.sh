#!/bin/bash
# =============================================================================
# PBS HLAVIČKA
# =============================================================================
#PBS -N Minimap2_and_Stats
#PBS -l select=1:ncpus=16:mem=64gb:scratch_local=400gb
#PBS -l walltime=12:00:00
#PBS -q default
#PBS -j oe
#PBS -m ae
#PBS -M tvoje.adresa@email.cz
#PBS -J 0-23

# -q gpu: Zařazení do GPU fronty.
# -j oe: Sloučení standardního výstupu (o) a chyb (e)do jednoho souboru pro snadnější kontrolu.
# -m ae: Odesílání emailů při ukončení (a) nebo selhání (e) úlohy. Ujisti se, že máš správně nastavenou emailovou adresu v PBS konfiguraci, aby ti dorazily notifikace.
# -J 0-23: Spuštění pole úloh pro zpracování 24 vzorků (indexy 0-23). Uprav podle počtu svých vzorků.

# =============================================================================
# INSTRUKCE
# =============================================================================
        # Vytvoř si složku alignment a v ní:
        # 1. SKRIPT: 'alignment_minimap2.sh'
        # 2. REFERENČNÍ GENOM: např. hg38.fa (stažený z Ensemblu nebo UCSC, musí být indexovaný minimap2 - pokud není, minimap2 si ho vytvoří při prvním spuštění)

        # Nastavení: upravím cesty v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).
        #          : upravím PBS -J pro počet vzorků (0-23 = 24 vzorků), které chci zpracovat a mailovou adresu pro notifikace.

        # Ve skriptu je nastavení zaslání mailu při ukončení nebo selhání úlohy - nastav svou mailovou adresu v PBS hlavičce (řádek #PBS -M v PBS hlavička)

        # Spuštění: qsub -v RUN_NUMBER="run1" alignment_minimap2.sh

        # MULTIQC
        # Po doběhnutí analýzu mohu spustit MultiQC pro přehled všech vzorků: multiqc . -o multiqc_report (spustím v OUTPUT_DIR, kde jsou všechny výsledky z jednotlivých vzorků)
        # MultiQC se podívá do všech podsložek, najde tam mosdepth summary a nanostat a vytvoří přehledný report s grafy pro všechny vzorky v jednom souboru (multiqc_report.html).
        # Spuštění MultiQC:
        # 1. Přejdu do složky s výsledky (STATS_DIR) - cd /storage/praha1/home/TVUJ_LOGIN/RESULTS/statistics_results/statistics_output_run1 
        # 2. Načtu program: module add multiqc
        # 3. Spustím: multiqc . -o multiqc_report


# =============================================================================
# 1. NASTAVENÍ UŽIVATELE (UPRAV TUTO ČÁST)
# =============================================================================

# Základní adresář, kde běží má analýza a mám zde uložena data
# ÚPRAVA: TVUJ_LOGIN (můj osobní login na Metacentru), praha1 (cluster, kde běží analýza a mám data)
BASE_DIR="/storage/praha1/home/TVUJ_LOGIN"

# Umístění vstupních dat - FASTQ soubory (výsledek z Dorada)
# číslo runu, v názvu složky s výsledky z Dorada (např. bassecall_output_123, kde 123 je číslo runu)
INPUT_FASTQ="$BASE_DIR/RESULTS/basecall_results/basecall_output_${RUN_NUMBER}"

# Umístění referenčního genomu (FASTA soubor)
REF_GENOME="$BASE_DIR/reference_genomes_hg38/hg38.analysisSet.fa"

# Kam uložit výsledky (BAM, BAI)
OUTPUT_DIR="$BASE_DIR/RESULTS/alignment_results/alignment_output_${RUN_NUMBER}"

# Kam uložit statistiky (samtools stats, nanostat, mosdepth)
STATS_DIR="$BASE_DIR/RESULTS/statistics_results/statistics_output_${RUN_NUMBER}"

# Úložiště pro centrální logovací soubor - záznam o průběhu spuštěných úloh, uzlech a datech všech již projetých souborů.
mkdir -p "$BASE_DIR/alignment/run_logs"
CENTRAL_LOG="$BASE_DIR/alignment/run_logs/alignment_history.txt"

# =============================================================================
# 2. AUTOMATICKÝ VÝBĚR SOUBORU (Array Logic) - naklonování vzorků pro rychlejší analýzu
# =============================================================================

# 1. Načteme všechny fastq soubory ze vstupní složky do pole (array seznamu)
FILES=(${INPUT_FASTQ}/*.fastq)

# 2. Vybereme soubor pro tuto konkrétní úlohu podle indexu pole ($PBS_ARRAY_INDEX)
INPUT_FILE=${FILES[$PBS_ARRAY_INDEX]}

# 3. Kontrola, zda jsme nevybrali prázdno (pokud je index mimo rozsah)
if [ -z "$INPUT_FILE" ]; then
    echo "CHYBA: Index $PBS_ARRAY_INDEX je mimo rozsah dostupných souborů! UPRAV PBS -J nebo zkontroluj počet souborů ve složce." | tee -a $CENTRAL_LOG
    exit 1
fi

# 4. Získáme čisté jméno vzorku (např. z 'cesta/barcode05.fastq' udělá 'barcode05')
SAMPLE_NAME=$(basename "$INPUT_FILE" .fastq)

# =============================================================================
# 3. PŘÍPRAVA PROSTŘEDÍ
# =============================================================================

# Načtení modulů pro minimap2 (alignment) a samtools, mosdepth, nanostat (statistika)
module add minimap2
module add samtools
module add mosdepth
module add nanostat

# Kontrola existence SCRATCHDIRu a přechod do něj
test -n "$SCRATCHDIR" || { echo >&2 "Chyba: SCRATCHDIR není nastaven!"; exit 1; }
cd $SCRATCHDIR || { echo >&2 "Chyba: Nelze vstoupit do scratche!"; exit 2; }

# Logování pro kontrolu - logovací soubor bude obsahovat informace o spuštění úlohy, uzlu a cestě ke scratchi
# 1. Centrální logovací soubor pro všechny úlohy v hlavní složce
echo "=== START ALIGNMENTU ===" >> $CENTRAL_LOG
echo "Spouštím úlohu: $RUN_NUMBER dne: $(date)" >> $CENTRAL_LOG
echo "Uzel: $(hostname -f)" >> $CENTRAL_LOG
echo "Scratch adresář: $SCRATCHDIR" >> $CENTRAL_LOG
echo "Referenční genom: $(basename $REF_GENOME)" >> $CENTRAL_LOG

# 2. Logovací soubor specifický pro tuto úlohu ve scratchi - smaže se po úspěšném dokončení, ale pokud dojde k chybě, zůstane pro kontrolu
echo "=== START ALIGNMENTU ===" | tee alignment_info.txt
echo "Spouštím úlohu: $RUN_NUMBER dne: $(date)" | tee -a alignment_info.txt
echo "Uzel: $(hostname -f)" | tee -a alignment_info.txt
echo "Scratch adresář: $PWD" | tee -a alignment_info.txt
echo "Referenční genom: $(basename $REF_GENOME)" | tee -a alignment_info.txt

# =============================================================================
# 4. KOPÍROVÁNÍ VSTUPU DO SCRATCHE
# =============================================================================

echo "[1/4] Kopíruji data..." | tee -a alignment_info.txt
cp $INPUT_FILE ./input.fastq
cp $REF_GENOME ./hg38.analysisSet.fa

if [ ! -f "input.fastq" ] || [ ! -f "hg38.analysisSet.fa" ]; then
    echo "CHYBA: Vstupní soubory chybí!" | tee -a alignment_info.txt
    exit 1
fi

# =============================================================================
# 5. ALIGNMENT (MINIMAP2 -> SORT)
# =============================================================================

echo "[2/4] Spouštím Minimap2..." | tee -a alignment_info.txt
minimap2 -ax map-ont -t 16 --MD -R "@RG\tID:${SAMPLE_NAME}\tSM:${SAMPLE_NAME}" ./hg38.analysisSet.fa ./input.fastq \
| samtools view -b - \
| samtools sort -o "${SAMPLE_NAME}".bam -

# Výstup z minimap2 jde přímo do samtools view, který ho převádí na BAM, a ten jde rovnou do samtools sort, který ho seřadí a uloží.
#      | = Neukládej výstup na disk, rovnou ho přepošli dalšímu příkazu. "-" na konci = vstupní data hledej z předchozího příkazu "|".
# -ax map-ont: Preset pro Oxford Nanopore data - dlouhé ready s vyšší chybovostí.
#     a = výstup v SAM (čitelný pro člověka, velký, pomalý) formátu, x = preset pro typ dat (map-ont pro ONT).
# -t 16: Použít 16 jader procesoru pro rychlejší běh.
# samtools view -b -: Převést výstup z minimap2 (SAM) na BAM (čitelný pro počítač, malý, rychlý) formát.
# samtools sort -o SAMPLE_NAME.bam -: Seřadit BAM soubor a uložit jako SAMPLE_NAME.bam.

echo "Indexuji BAM - vznik BAM.BAI..." | tee -a alignment_info.txt
samtools index "${SAMPLE_NAME}".bam

# =============================================================================
# 6. GENERAVÁNÍ DAT PRO STATISTIKU
# =============================================================================

echo "[3/4] Počítám a rozděluji statistiky (Samtools, NanoStat, Mosdepth)..." | tee -a alignment_info.txt

# --- A) STATISTIKY PRO FETÁLNÍ FRAKCI ---
samtools stats "${SAMPLE_NAME}".bam > full_stats.tmp        # kompletní statistika, dočasný soubor
grep "^RL" full_stats.tmp > ${SAMPLE_NAME}_lengths.txt      # délky readů pro další analýzu (např. pro výpočet fetální frakce, z řádků RL = read length)
grep -E "^(SN|CO|FFQ)" full_stats.tmp > ${SAMPLE_NAME}_quality_coverage.txt     # kvalita a pokrytí pro další analýzu (z řádků SN, CO, FFQ)
# SN (Summary - obsahuje error rate/accuracy)
# CO (Coverage - pokrytí)
# FFQ (Quality - kvalita prvního fragmentu)

# --- B) OBECNÉ STATISTIKY KVALITY (NanoStat a Mosdepth) ---
# NanoStat (vytvoří soubor s celkovým přehledem kvality readů)
NanoStat --bam "${SAMPLE_NAME}.bam" -t 16 > "${SAMPLE_NAME}_nanostat.txt"

# Mosdepth (vytvoří soubory s výpočtem pokrytí pro MultiQC)
mosdepth -n -t 4 "${SAMPLE_NAME}_coverage" "${SAMPLE_NAME}.bam"

# =============================================================================
# 7. KOPÍROVÁNÍ VÝSLEDKŮ
# =============================================================================

echo "[4/4] Kopíruji výsledky..." | tee -a alignment_info.txt

mkdir -p $OUTPUT_DIR

# Kopírujeme BAM, BAI
cp "${SAMPLE_NAME}".bam $OUTPUT_DIR/
cp "${SAMPLE_NAME}".bam.bai $OUTPUT_DIR/

# Kopírujeme statistiky pro fetální frakci (samtools)
cp ${SAMPLE_NAME}_lengths.txt $STATS_DIR/
cp ${SAMPLE_NAME}_quality_coverage.txt $STATS_DIR/

# Kopírujeme obecné statistiky kvality (nanostat, mosdepth)
cp "${SAMPLE_NAME}_nanostat.txt" $STATS_DIR/
cp "${SAMPLE_NAME}_coverage.mosdepth.summary.txt" $STATS_DIR/

# Kopírujeme logovací soubor pro tuto úlohu
cp alignment_info.txt $OUTPUT_DIR/${SAMPLE_NAME}_alignment_info.txt

# Úklid
if [ -s "$OUTPUT_DIR/${SAMPLE_NAME}.bam" ]; then
    echo "ÚSPĚCH: Hotovo. Mažu scratch." | tee -a alignment_info.txt
    clean_scratch
else
    echo "CHYBA: Soubor se nezkopíroval! Data zůstávají ve scratchi. Přenes je manuálně do $OUTPUT_DIR" | tee -a alignment_info.txt
    exit 1
fi