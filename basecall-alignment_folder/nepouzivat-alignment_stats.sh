#!/bin/bash
# =============================================================================
# PBS HLAVIČKA
# =============================================================================
#PBS -N Minimap2_and_Stats
#PBS -l select=1:ncpus=16:mem=64gb:scratch_local=80gb:os=debian11
#PBS -l walltime=6:00:00
#PBS -q default
#PBS -j oe
#PBS -m ae

#PBS -M petraskkar@natur.cuni.cz
#PBS -J 1-24
#PBS -o /storage/brno12-cerit/home/petraskkar/alignment/pbs_outputs/

# -q gpu: Zařazení do GPU fronty.
# -j oe: Sloučení standardního výstupu (o) a chyb (e) do jednoho souboru pro snadnější kontrolu.
# -m ae: Odesílání emailů při ukončení (a) nebo selhání (e) úlohy. Ujisti se, že máš správně nastavenou emailovou adresu v PBS konfiguraci, aby ti dorazily notifikace.
# -J 1-24: Spuštění pole úloh pro zpracování 24 vzorků (indexy 1-24). Uprav podle počtu svých vzorků.

# více cpus - rychlejší a více věcí na ráz, je to rychlejší, ale náročnější na paměť - musím mít více mem 
# select=1 - pošle moji úlohu na jeden server - ekosystém serverů, které jsou propojené a mají společný přístup k datům, takže můžu využít více CPU a paměti na jednom serveru.
# ncpu = procesory, které chci využít pro svou úlohu - více CPU znamená, že mi může probíhat více úloh najednou
# mem = RAM, paměť, kterou chci využít pro svou úlohu - více paměti znamená, že můžu zpracovat větší data nebo více dat najednou, extrémně rychlé disky pro dočasnou paměť
# scratch = SSD disk
# 2 Gb mem na 1 CPU - standardní poměr

# =============================================================================
# INSTRUKCE
# =============================================================================
        # Vytvoř si složku alignment a v ní:
        # 1. SKRIPT: 'alignment_minimap2.sh'
        # 2. REFERENČNÍ GENOM: hg38.mmi - např. hg38.analysisSet.fa (stažený z Ensemblu nebo UCSC, musí být indexovaný minimap2 - hg38.mmi - ke staženína gitHubu)
        # Nastavení: upravím cesty v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).
        #          : upravím PBS -J pro počet vzorků (1-24 = 24 vzorků), které chci zpracovat a mailovou adresu pro notifikace.

        # Ve skriptu je nastavení zaslání mailu při ukončení nebo selhání úlohy - nastav svou mailovou adresu v PBS hlavičce (řádek #PBS -M v PBS hlavička)

        # Spuštění: qsub -v RUN_NUMBER="run1" alignment_minimap2.sh

        # MULTIQC
        # Po doběhnutí analýzu mohu spustit MultiQC pro přehled všech vzorků: multiqc . -o multiqc_report (spustím v OUTPUT_DIR, kde jsou všechny výsledky z jednotlivých vzorků)
        # MultiQC se podívá do všech podsložek, najde tam mosdepth summary a nanostat a vytvoří přehledný report s grafy pro všechny vzorky v jednom souboru (multiqc_report.html).
        # Spuštění MultiQC:
        # 1. Přejdu do složky s výsledky (OUTPUT_DIR) - cd /storage/brno12-cerit/home/petraskkar/RESULTS/alignment/alignment_output_run1 
        # 2. Načtu program: module add multiqc
        # 3. Spustím: multiqc .

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
mkdir -p "pbs_outputs"

set -euo pipefail   # přísnější režim pro lepší detekci chyb, -e: skript se zastaví při jakékoliv chybě, -u: chyba při použití nedefinované proměnné, -o pipefail: chyba v jakékoliv části pipy způsobí selhání celé pipy
# jakmile cokoliv neprojde, skript se zastaví a nepokračuje dál

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: RUN_NUMBER není nastaven." >&2
    echo "Spuštění: qsub -v RUN_NUMBER=run1 alignment_minimap2.sh" >&2
    exit 1
fi

if [ -z "${PBS_ARRAY_INDEX:-}" ]; then
    echo "Chyba: PBS_ARRAY_INDEX není nastaven." >&2
    exit 1
fi

BARCODE=$(printf "barcode%02d" "$PBS_ARRAY_INDEX")  # vytvoří název barcode01, barcode02, ... podle indexu pole

# =============================================================================
# 1. NASTAVENÍ UŽIVATELE (UPRAV TUTO ČÁST)
# =============================================================================

# číslo runu, v názvu složky s výsledky z Dorada (např. bassecall_output_123, kde 123 je číslo runu)

# Základní adresář, kde běží má analýza a mám zde uložena data
# ÚPRAVA: TVUJ_LOGIN (můj osobní login na Metacentru), brno12-cerit (cluster, kde běží analýza a mám data)
BASE_DIR="/storage/brno12-cerit/home/petraskkar"

FASTQ_FILE=".fastq.gz"

# Umístění vstupních dat - FASTQ soubory (výsledek z Dorada)
INPUT_DIR="$BASE_DIR/RESULTS/basecall_results"
RUN_INPUT_DIR="$INPUT_DIR/basecall_output_${RUN_NUMBER}"
INPUT_FILE="$RUN_INPUT_DIR/$BARCODE/${RUN_NUMBER}_${BARCODE}${FASTQ_FILE}"   # cesta ke konkrétnímu FASTQ souboru pro tento barcode

# Umístění referenčního genomu (FASTA soubor)
REF_GENOME="$BASE_DIR/alignment/reference_genome_Hg38/hg38.mmi"   # indexovaný referenční genom pro minimap2
# Kam uložit výsledky ze statistiky
BAM_OUTPUT_DIR="$BASE_DIR/RESULTS/alignment_results"
RUN_bam_OUTPUT_DIR="$BAM_OUTPUT_DIR/alignment_output_${RUN_NUMBER}"
FINAL_bam_OUTPUT_DIR="$RUN_bam_OUTPUT_DIR/$BARCODE"

# Výsledky ze statistiky
STATS_OUTPUT_DIR="$BASE_DIR/RESULTS/statistics_results"
RUN_STATS_OUTPUT_DIR="$STATS_OUTPUT_DIR/statistics_output_${RUN_NUMBER}"
FINAL_stats_OUTPUT_DIR="$RUN_STATS_OUTPUT_DIR/$BARCODE"

# Úložiště pro centrální logovací soubor - záznam o průběhu spuštěných úloh, uzlech a datech všech již projetých souborů.
LOG_DIR="$BASE_DIR/alignment/run_logs"
CENTRAL_LOG="$LOG_DIR/alignment_history.txt"

mkdir -p "$LOG_DIR"
mkdir -p "$BAM_OUTPUT_DIR"
mkdir -p "$STATS_OUTPUT_DIR"
mkdir -p "$RUN_bam_OUTPUT_DIR"
mkdir -p "$RUN_STATS_OUTPUT_DIR"

# =============================================================================
# 2.KONTROLA VSTUPNÍCH DAT A PROSTŘEDÍ
# =============================================================================
if [ -z "$INPUT_FILE" ]; then
    echo "CHYBA: Index $PBS_ARRAY_INDEX je mimo rozsah dostupných souborů! UPRAV PBS -J nebo zkontroluj počet souborů ve složce." | tee -a $CENTRAL_LOG
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "Chyba: neexistuje vstupní barcode adresář: $INPUT_DIR" >&2
    exit 1
fi

if [ ! -f "$REF_GENOME" ]; then
    echo "Chyba: referenční genom neexistuje: $REF_GENOME" >&2
    exit 1
fi

if [ -z "${SCRATCHDIR:-}" ]; then
    echo "Chyba: SCRATCHDIR není nastaven." >&2
    exit 1
fi

# Čisté jméno vzorku (např. z 'cesta/barcode05.fastq' udělá 'barcode05')
SAMPLE_NAME=$RUN_NUMBER"_"$BARCODE

# =============================================================================
# 3. PŘÍPRAVA PROSTŘEDÍ
# =============================================================================

# Načtení modulů pro minimap2 (alignment) a samtools, mosdepth, nanostat (statistika)
module add minimap2
module add samtools
module add mosdepth
module add nanostat

# =============================================================================
# 4. PŘESUN DO SCRATCHE, INFO DO LOGŮ
# =============================================================================

cd "$SCRATCHDIR"
echo "[1/4] Kopíruji data do scratche..." | tee -a alignment_info.txt
cp $INPUT_FILE ./input${FASTQ_FILE}
cp $REF_GENOME ./hg38.mmi

JOB_LOG="$SCRATCHDIR/alignment_info.txt"
TMP_BAM="$SCRATCHDIR/${RUN_NUMBER}_${BARCODE}.bam"          # dočasný BAM soubor ve scratchi, před kompresí
TMP_BAM_BAI="$SCRATCHDIR/${RUN_NUMBER}_${BARCODE}.bam.bai"    # dočasný BAM.BAI soubor ve scratchi, před kopírováním zpět na storage

# Logování pro kontrolu - logovací soubor bude obsahovat informace o spuštění úlohy, uzlu a cestě ke scratchi
# 1. Centrální logovací soubor pro všechny úlohy v hlavní složce
{
    echo "------------------------------------------------------------------"
    echo "Spouštím úlohu: $RUN_NUMBER / $BARCODE dne: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch adresář: $SCRATCHDIR"
    echo "Array index: $PBS_ARRAY_INDEX"
    echo "Referenční genom: $(basename $REF_GENOME)"
} >> "$CENTRAL_LOG"

# 2. Logovací soubor specifický pro tuto úlohu ve scratchi - smaže se po úspěšném dokončení, ale pokud dojde k chybě, zůstane pro kontrolu
{
    echo "------------------------------------------------------------------"
    echo "Run: $RUN_NUMBER"
    echo "Barcode: $BARCODE"
    echo "Datum: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch: $SCRATCHDIR"
    echo "Vstup: $INPUT_FILE"
    echo "Výstup: $FINAL_bam_OUTPUT_DIR & $FINAL_stats_OUTPUT_DIR"
    echo "Array index: $PBS_ARRAY_INDEX"
    echo "Referenční genom: $(basename $REF_GENOME)"
} | tee -a "$JOB_LOG"

# =============================================================================
# 5. ALIGNMENT (MINIMAP2 -> SORT)
# =============================================================================

echo "[2/4] Spouštím Minimap2..." | tee -a alignment_info.txt
minimap2 -ax map-ont -t 16 --MD -R "@RG\tID:${SAMPLE_NAME}\tSM:${SAMPLE_NAME}" ./hg38.mmi ./input$FASTQ_FILE \
| samtools view -b - \
| samtools sort -o $TMP_BAM -

# Výstup z minimap2 jde přímo do samtools view, který ho převádí na BAM, a ten jde rovnou do samtools sort, který ho seřadí a uloží.
#      | = Neukládej výstup na disk, rovnou ho přepošli dalšímu příkazu. "-" na konci = vstupní data hledej z předchozího příkazu "|".
# -ax map-ont: Preset pro Oxford Nanopore data - dlouhé ready s vyšší chybovostí.
#     a = výstup v SAM (čitelný pro člověka, velký, pomalý) formátu, x = preset pro typ dat (map-ont pro ONT).
# -t 16: Použít 16 jader procesoru pro rychlejší běh.
# samtools view -b -: Převést výstup z minimap2 (SAM) na BAM (čitelný pro počítač, malý, rychlý) formát.
# samtools sort -o SAMPLE_NAME.bam -: Seřadit BAM soubor a uložit jako SAMPLE_NAME.bam.

echo "Indexuji BAM - vznik BAM.BAI..." | tee -a alignment_info.txt
samtools index $TMP_BAM

# =============================================================================
# 6. GENERAVÁNÍ DAT PRO STATISTIKU
# =============================================================================

echo "[3/4] Počítám a rozděluji statistiky (Samtools, NanoStat, Mosdepth)..." | tee -a alignment_info.txt

# --- A) STATISTIKY PRO FETÁLNÍ FRAKCI ---
samtools stats $TMP_BAM > full_stats.tmp        # kompletní statistika, dočasný soubor
grep "^RL" full_stats.tmp > ${SAMPLE_NAME}_lengths.txt      # délky readů pro další analýzu (např. pro výpočet fetální frakce, z řádků RL = read length)
grep -E "^(SN|CO|FFQ)" full_stats.tmp > ${SAMPLE_NAME}_quality_coverage.txt     # kvalita a pokrytí pro další analýzu (z řádků SN, CO, FFQ)
# SN (Summary - obsahuje error rate/accuracy)
# CO (Coverage - pokrytí)
# FFQ (Quality - kvalita prvního fragmentu)

# --- B) OBECNÉ STATISTIKY KVALITY (NanoStat a Mosdepth) ---
# NanoStat (vytvoří soubor s celkovým přehledem kvality readů)
NanoStat --bam $TMP_BAM -t 16 > "${SAMPLE_NAME}_nanostat.txt"
# -t 16: Použít 16 jader procesoru pro rychlejší běh. (NCPUS)

# Mosdepth (vytvoří soubory s výpočtem pokrytí pro MultiQC)
mosdepth -n -t 4 "${SAMPLE_NAME}_coverage" "$TMP_BAM"

# =============================================================================
# 7. KONTROLA VÝSLEDKU ALIGNMENTU A STATISTIKY
# =============================================================================

echo "[Kontrola] Prověřuji výstupní soubory..." | tee -a "$JOB_LOG"

# Seznam souborů ke kontrole
FILES_TO_CHECK=(
    "$TMP_BAM"
    "$TMP_BAM_BAI"
    "${SAMPLE_NAME}_lengths.txt"
    "${SAMPLE_NAME}_quality_coverage.txt"
    "${SAMPLE_NAME}_nanostat.txt"
    "${SAMPLE_NAME}_coverage.mosdepth.summary.txt"
)

for FILE in "${FILES_TO_CHECK[@]}"; do
    if [ ! -s "$FILE" ]; then
        echo "KRITICKÁ CHYBA: Soubor $FILE neexistuje nebo je prázdný!" | tee -a "$JOB_LOG" >&2
        exit 1
    fi
done

# =============================================================================
# 8. KOPÍROVÁNÍ VÝSLEDKŮ
# =============================================================================

echo "[4/4] Kopíruji výsledky do $FINAL_bam_OUTPUT_DIR a $FINAL_stats_OUTPUT_DIR..." | tee -a alignment_info.txt

mkdir -p $FINAL_bam_OUTPUT_DIR
mkdir -p $FINAL_stats_OUTPUT_DIR

# Kopírujeme BAM, BAI
cp $TMP_BAM $FINAL_bam_OUTPUT_DIR/${SAMPLE_NAME}.bam
cp $TMP_BAM_BAI $FINAL_bam_OUTPUT_DIR/${SAMPLE_NAME}.bam.bai

# Kopírujeme statistiky pro fetální frakci (samtools)
cp ${SAMPLE_NAME}_lengths.txt $FINAL_stats_OUTPUT_DIR/lengths_${SAMPLE_NAME}.txt
cp ${SAMPLE_NAME}_quality_coverage.txt $FINAL_stats_OUTPUT_DIR/quality_coverage_${SAMPLE_NAME}.txt

# Kopírujeme obecné statistiky kvality (nanostat, mosdepth)
cp "${SAMPLE_NAME}_nanostat.txt" $FINAL_stats_OUTPUT_DIR/nanostat_${SAMPLE_NAME}.txt
cp "${SAMPLE_NAME}_coverage.mosdepth.summary.txt" $FINAL_stats_OUTPUT_DIR/coverage.mosdepth.summary_${SAMPLE_NAME}.txt

# Kopírujeme logovací soubor pro tuto úlohu
cp alignment_info.txt $FINAL_bam_OUTPUT_DIR/alignment_info.txt

echo "ÚSPĚCH: HOTOVO! Výsledky zkopírovány do $FINAL_bam_OUTPUT_DIR a $FINAL_stats_OUTPUT_DIR..." | tee -a $FINAL_bam_OUTPUT_DIR/alignment_info.txt

# Úklid
clean_scratch