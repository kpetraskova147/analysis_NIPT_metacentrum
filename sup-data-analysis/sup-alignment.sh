#!/bin/bash
# =============================================================================
# PBS HLAVIČKA - ALIGNMENT
# =============================================================================
#PBS -N sup-Minimap2_Align
#PBS -l select=1:ncpus=16:mem=32gb:scratch_local=80gb
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
        # 1. SKRIPT: 'sup-alignment.sh'
        # 2. REFERENČNÍ GENOM: hg38.mmi - např. hg38.analysisSet.fa (stažený z Ensemblu nebo UCSC, musí být indexovaný minimap2 - hg38.mmi - ke staženína gitHubu)
        # Nastavení: upravím cesty v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).
        #          : upravím PBS -J pro počet vzorků (1-24 = 24 vzorků), které chci zpracovat a mailovou adresu pro notifikace.
        #          : upravím PBS -o pro uložení výstupů z PBS do složky pbs_outputs
        #          : upravím PBS -M - mailová adresa pro zaslání mailu při ukončení nebo selhání úlohy (nastav svou mailovou adresu)

        # Spuštění: qsub -v RUN_NUMBER="run1" sup-alignment.sh

# =============================================================================
# 0. KONTROLA VSTUPNÍCH PROMĚNNÝCH
# =============================================================================
mkdir -p "pbs_outputs"
set -euo pipefail
trap "clean_scratch" TERM EXIT

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: RUN_NUMBER není nastaven." >&2
    echo "Spuštění: qsub -v RUN_NUMBER=run1 sup-alignment.sh" >&2
    exit 1
fi
if [ -z "${PBS_ARRAY_INDEX:-}" ]; then
    echo "Chyba: PBS_ARRAY_INDEX není nastaven." >&2
    exit 1
fi

BARCODE=$(printf "barcode%02d" "$PBS_ARRAY_INDEX")

# =============================================================================
# 1. NASTAVENÍ UŽIVATELE A CEST
# =============================================================================
BASE_DIR="/storage/brno12-cerit/home/petraskkar"
FASTQ_FILE=".fastq.gz"

mkdir -p "pbs_outputs"

# Umístění vstupních dat - FASTQ soubory (výsledek ze sekvenace)
INPUT_ROOT="$BASE_DIR/RESULTS/SUP-basecall_results"
INPUT_DIR="$INPUT_ROOT/SUP-basecall_output_${RUN_NUMBER}"

# Umístění referenčního genomu (komprimovaný FASTA soubor)
REF_GENOME="$BASE_DIR/alignment/reference_genome_Hg38/hg38.mmi"

# Umístění pro výsledky z alignmetu - BAM soubory
BAM_OUTPUT_DIR="$BASE_DIR/RESULTS"
RUN_OUTPUT_DIR="$BAM_OUTPUT_DIR/sup-alignment_results"
FINAL_bam_OUTPUT_DIR="$RUN_OUTPUT_DIR/sup-alignment_output_${RUN_NUMBER}"

# Logy z alignmetu
LOG_DIR="$BASE_DIR/alignment/run_logs"
CENTRAL_LOG="$LOG_DIR/sup-alignment_history.txt"

mkdir -p "$LOG_DIR" 
mkdir -p "$BAM_OUTPUT_DIR"
mkdir -p "$RUN_OUTPUT_DIR" 
mkdir -p "$FINAL_bam_OUTPUT_DIR"

# =============================================================================
# 2. KONTROLA VSTUPNÍCH DAT A PROSTŘEDÍ
# =============================================================================
if ! ls "$INPUT_DIR"/*.fastq.gz 1> /dev/null 2>&1; then
    echo "CHYBA: Ve složce $INPUT_DIR nebyly nalezeny žádné .fastq.gz soubory!" | tee -a $CENTRAL_LOG
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

SAMPLE_NAME=${RUN_NUMBER}-sup"_"${BARCODE}

# =============================================================================
# 3. PŘÍPRAVA PROSTŘEDÍ - načtení modulu minimap2 pro alignment
# =============================================================================

module purge
module add minimap2

# =============================================================================
# 4. PŘESUN DO SCRATCHE, INFO DO LOGŮ
# =============================================================================
cd "$SCRATCHDIR"
echo "[1/3] Slučuji všechny FASTQ soubory z barcodu do scratche..." > sup-alignment_info.txt

# Tento příkaz vezme všechny soubory a "vylije" je do jednoho
cat "$INPUT_DIR"/*"$BARCODE"*"$FASTQ_FILE" > ./input.fastq.gz
cp "$REF_GENOME" ./hg38.mmi

JOB_LOG="$SCRATCHDIR/sup-alignment_info.txt"
TMP_BAM="$SCRATCHDIR/${RUN_NUMBER}_${BARCODE}.bam"              # dočasný BAM soubor ve scratchi
TMP_BAM_BAI="$SCRATCHDIR/${RUN_NUMBER}_${BARCODE}.bam.bai"      # dočasný indexovaný BAM soubor ve scratchi

# Logování pro kontrolu - logovací soubor bude obsahovat informace o spuštění úlohy, uzlu a cestě ke scratchi
# 1. Centrální logovací soubor pro všechny úlohy v hlavní složce
{
    echo "------------------------------------------------------------------"
    echo "ALIGNMENT:Spouštím úlohu: $RUN_NUMBER / $BARCODE dne: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch adresář: $SCRATCHDIR"
    echo "Array index: $PBS_ARRAY_INDEX"
    echo "Referenční genom: $(basename $REF_GENOME)"
} >> "$CENTRAL_LOG"

# 2. Logovací soubor specifický pro tuto úlohu ve scratchi - smaže se po úspěšném dokončení, ale pokud dojde k chybě, zůstane pro kontrolu
{
    echo "------------------------------------------------------------------"
    echo "ALIGNMENT:Run: $RUN_NUMBER"
    echo "Barcode: $BARCODE"
    echo "Datum: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch: $SCRATCHDIR"
    echo "Vstup: $INPUT_DIR"
    echo "Výstup: $FINAL_bam_OUTPUT_DIR"
    echo "Array index: $PBS_ARRAY_INDEX"
    echo "Referenční genom: $(basename $REF_GENOME)"
} | tee -a "$JOB_LOG"


# =============================================================================
# 5. ALIGNMENT (MINIMAP2 -> SORT)
# =============================================================================
echo "[2/3] Spouštím Minimap2 (ukládám do dočasného SAM)..." | tee -a "$JOB_LOG"
TMP_SAM="$SCRATCHDIR/${RUN_NUMBER}_${BARCODE}.sam"

minimap2 -ax map-ont -t 16 --MD \
    -R "@RG\tID:${SAMPLE_NAME}\tSM:${SAMPLE_NAME}" \
    ./hg38.mmi \
    ./input.fastq.gz > "$TMP_SAM"

echo "Přepínám moduly: Vypínám Minimap2, zapínám Samtools..." | tee -a "$JOB_LOG"
module purge
module add samtools/1.14-gcc-10.2.1-oyuzddu

echo "Převádím SAM na BAM a třídím..." | tee -a "$JOB_LOG"
samtools view -b "$TMP_SAM" | samtools sort -o $TMP_BAM -

echo "Mažu dočasný SAM soubor - úspora místa" | tee -a "$JOB_LOG"
rm "$TMP_SAM"

echo "Indexuji BAM - vznik BAM.BAI..." | tee -a "$JOB_LOG"
samtools index $TMP_BAM


# -ax map-ont: Preset pro Oxford Nanopore data - dlouhé ready s vyšší chybovostí.
#     a = výstup v SAM (čitelný pro člověka, velký, pomalý) formátu, x = preset pro typ dat (map-ont pro ONT).
# -t 16: Použít 16 jader procesoru pro rychlejší běh.
# samtools view -b -: Převést výstup z minimap2 (SAM) na BAM (čitelný pro počítač, malý, rychlý) formát.
# samtools sort -o SAMPLE_NAME.bam -: Seřadit BAM soubor a uložit jako SAMPLE_NAME.bam.

# =============================================================================
# 6. KONTROLA VÝSLEDKU ALIGNMENTU
# =============================================================================
echo "[Kontrola] Prověřuji výstupní soubory..." | tee -a "$JOB_LOG"
for FILE in "$TMP_BAM" "$TMP_BAM_BAI"; do
    if [ ! -s "$FILE" ]; then
        echo "KRITICKÁ CHYBA: Soubor $FILE neexistuje nebo je prázdný!" | tee -a "$JOB_LOG" >&2
        exit 1
    fi
done

# =============================================================================
# 7. KOPÍROVÁNÍ VÝSLEDKŮ A ÚKLID
# =============================================================================
echo "[3/3] Kopíruji výsledky do $FINAL_bam_OUTPUT_DIR..." | tee -a "$JOB_LOG"

cp "$TMP_BAM" "$FINAL_bam_OUTPUT_DIR/${SAMPLE_NAME}.bam"
cp "$TMP_BAM_BAI" "$FINAL_bam_OUTPUT_DIR/${SAMPLE_NAME}.bam.bai"
cp "$JOB_LOG" "$FINAL_bam_OUTPUT_DIR/sup-alignment_info.txt"

echo "ÚSPĚCH: HOTOVO! Výsledky zkopírovány do $FINAL_bam_OUTPUT_DIR" | tee -a "$FINAL_bam_OUTPUT_DIR/sup-alignment_info.txt"
rm -rf $SCRATCHDIR/*