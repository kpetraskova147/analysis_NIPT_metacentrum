#!/bin/bash
# =============================================================================
# PBS HLAVIČKA - STATISTIKY - mosdepth a nanostat
# =============================================================================
#PBS -N HAC-Stats_Mosdepth_Nano
#PBS -l select=1:ncpus=8:mem=32gb:scratch_local=40gb
#PBS -l walltime=4:00:00
#PBS -q default
#PBS -j oe
#PBS -m ae

#PBS -M petraskkar@natur.cuni.cz
#PBS -J 1-24
#PBS -o /storage/brno12-cerit/home/petraskkar/alignment/pbs_outputs_statistics/
#PBS -e /storage/brno12-cerit/home/petraskkar/alignment/pbs_outputs_statistics/

# =============================================================================
# INSTRUKCE
# =============================================================================
        # Vytvoř si složku alignment a v ní:
        # 1. SKRIPT: 'statistics_alignment.sh'
        # Nastavení: upravím cesty v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).
        #          : upravím PBS -J pro počet vzorků (1-24 = 24 vzorků), které chci zpracovat a mailovou adresu pro notifikace.
        #          : upravím PBS -o pro uložení výstupů z PBS do složky pbs_outputs
        #          : upravím PBS -M - mailová adresa pro zaslání mailu při ukončení nebo selhání úlohy (nastav svou mailovou adresu)
    
        # V sekci 3 je zakomentovaná část pro načítaní modulů pro mosdepth a nanostat, protože na nové verzi metacentra (Debian 12) nejsou tyto moduly zatím nainstalované, 
        #   proto je potřeba vytvořit dočasné conda prostředí s těmito dvěma programy, které se po dokončení úlohy smaže. Pokud by se v budoucnu nainstalovaly moduly 
        #   pro mosdepth a nanostat, stačí tento krok odkomentovat a místo toho načíst příslušné moduly.

        # Spuštění: qsub -v RUN_NUMBER="run1" statistics_alignment.sh

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
mkdir -p "pbs_outputs_statistics"
set -euo pipefail

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: RUN_NUMBER není nastaven." >&2
    echo "Spuštění: qsub -v RUN_NUMBER=run1 HAC-statistics_alignment.sh" >&2
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

mkdir -p "$BASE_DIR/alignment/pbs_outputs_statistics"

# Vstup nyní bere z minulé složky alignmentu (BAM soubory)
BAM_INPUT_DIR="$BASE_DIR/RESULTS/HAC-alignment_results/HAC-alignment_output_${RUN_NUMBER}"
INPUT_BAM="$BAM_INPUT_DIR/${RUN_NUMBER}_${BARCODE}.bam"
INPUT_BAI="$BAM_INPUT_DIR/${RUN_NUMBER}_${BARCODE}.bam.bai"

# Výsledky ze statistiky
STATS_OUTPUT_DIR="$BASE_DIR/RESULTS/HAC-statistics_results"
RUN_STATS_OUTPUT_DIR="$STATS_OUTPUT_DIR/HAC-statistics_output_${RUN_NUMBER}"
FINAL_stats_OUTPUT_DIR="$RUN_STATS_OUTPUT_DIR/${RUN_NUMBER}-HAC_${BARCODE}"

LOG_DIR="$BASE_DIR/alignment/run_logs_statistics"
CENTRAL_LOG="$LOG_DIR/HAC-alignment_statistics_history.txt"

mkdir -p "$LOG_DIR" 
mkdir -p "$STATS_OUTPUT_DIR" 
mkdir -p "$RUN_STATS_OUTPUT_DIR"

# =============================================================================
# 2. KONTROLA VSTUPNÍCH DAT A PROSTŘEDÍ
# =============================================================================
if [ ! -s "$INPUT_BAM" ]; then
    echo "CHYBA: BAM soubor neexistuje! (Byl alignment úspěšný?)" | tee -a $CENTRAL_LOG
    exit 1
fi

if [ ! -s "$INPUT_BAI" ]; then
    echo "CHYBA: BAI soubor neexistuje! (Byl alignment úspěšný?)" | tee -a $CENTRAL_LOG
    exit 1
fi

if [ -z "${SCRATCHDIR:-}" ]; then
    echo "Chyba: SCRATCHDIR není nastaven." >&2
    exit 1
fi

SAMPLE_NAME="${RUN_NUMBER}-HAC_${BARCODE}"

# =============================================================================
# 3. PŘÍPRAVA PROSTŘEDÍ
# =============================================================================
module purge

# --- Aktivace mého prostředí (env_stats_alignment) ---
module load mambaforge
eval "$(conda shell.bash hook)"

conda activate $BASE_DIR/conda_envs/env_stats_alignment

# =============================================================================
# 4. PŘESUN DO SCRATCHE
# =============================================================================
cd "$SCRATCHDIR"
JOB_LOG="$SCRATCHDIR/HAC-statistics_alignment_info.txt"
echo "[1/3] Kopíruji BAM a BAI do scratche..." > "$JOB_LOG"

cp "$INPUT_BAM" ./
cp "$INPUT_BAI" ./

TMP_BAM="./$(basename "$INPUT_BAM")"
TMP_BAI="./$(basename "$INPUT_BAI")"

# Logování pro kontrolu - logovací soubor bude obsahovat informace o spuštění úlohy, uzlu a cestě ke scratchi
# 1. Centrální logovací soubor pro všechny úlohy v hlavní složce
{
    echo "------------------------------------------------------------------"
    echo "ALIGNMENT_STATISTICS:Spouštím úlohu: $RUN_NUMBER / $BARCODE dne: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch adresář: $SCRATCHDIR"
    echo "Array index: $PBS_ARRAY_INDEX"
} >> "$CENTRAL_LOG"

# 2. Logovací soubor specifický pro tuto úlohu ve scratchi - smaže se po úspěšném dokončení, ale pokud dojde k chybě, zůstane pro kontrolu
{
    echo "------------------------------------------------------------------"
    echo "ALIGNMENT_STATISTICS:Run: $RUN_NUMBER"
    echo "Barcode: $BARCODE"
    echo "Datum: $(date)"
    echo "Uzel: $(hostname -f)"
    echo "Scratch: $SCRATCHDIR"
    echo "Vstup: $BAM_INPUT_DIR"
    echo "Výstup: $FINAL_stats_OUTPUT_DIR"
    echo "Array index: $PBS_ARRAY_INDEX"
} | tee -a "$JOB_LOG"

# =============================================================================
# 5. GENERAVÁNÍ DAT PRO STATISTIKU
# =============================================================================
echo "[2/3] Počítám a rozděluji statistiky..." | tee -a "$JOB_LOG"

LENGTH_FILE="lengths_${SAMPLE_NAME}.txt"
QUALITY_COVERAGE_FILE="quality_coverage_${SAMPLE_NAME}.txt"
NANOSTAT_FILE="nanostat_${SAMPLE_NAME}.txt"
MOSDEPTH_PREFIX="coverage_${SAMPLE_NAME}"
PLOTS_DIR="plots_${SAMPLE_NAME}"

mkdir -p "$PLOTS_DIR"

# --- A) STATISTIKY PRO FETÁLNÍ FRAKCI ---
samtools stats "$TMP_BAM" > full_stats.tmp
grep "^RL" full_stats.tmp > $LENGTH_FILE
grep -E "^(SN|CO|FFQ)" full_stats.tmp > $QUALITY_COVERAGE_FILE

# --- B) OBECNÉ STATISTIKY KVALITY (NanoStat a Mosdepth) ---
NanoStat --bam "$TMP_BAM" -t 8 > $NANOSTAT_FILE
mosdepth -n -t 8 "$MOSDEPTH_PREFIX" "$TMP_BAM"

# --- C) NANOSTAT / NANOPLOT REPORT ---
# Spustí NanoPlot a vytvoří kompletní HTML report i standardní grafy
NanoPlot --bam "$TMP_BAM" -t 8 --plots dot --loglength -o "$PLOTS_DIR"

# --- D) VLASTNÍ CÍLENÝ cfDNA LOG HISTOGRAM (50 - 1000 bp) ---
export LENGTH_FILE SAMPLE_NAME PLOTS_DIR
python3 - << 'EOF'
import os
import matplotlib.pyplot as plt
import numpy as np

length_file = os.environ.get("LENGTH_FILE")
sample_name = os.environ.get("SAMPLE_NAME")
plots_dir = os.environ.get("PLOTS_DIR")

lengths, counts = [], []

with open(length_file, "r") as f:
    for line in f:
        parts = line.strip().split("\t")
        if len(parts) >= 3 and parts[0] == "RL":
            lengths.append(int(parts[1]))
            counts.append(int(parts[2]))

lengths = np.array(lengths)
counts = np.array(counts)

# Omezení pouze na relevantní cfDNA oblast (50 až 1000 bp)
mask = (lengths >= 50) & (lengths <= 1000)
x = lengths[mask]
y = counts[mask]

plt.figure(figsize=(12, 6), dpi=300)

# Logaritmická osa X, ale s jemnými sloupci po 1 bp
plt.bar(x, y, width=x * 0.008, color="#3ea38f", edgecolor="none", align="center")
plt.xscale("log")

# Popisky klíčových délek přímo na ose
ticks = [50, 100, 143, 166, 200, 330, 500, 1000]
plt.xticks(ticks, [str(t) for t in ticks], fontsize=10)
plt.minorticks_off()

# Biologické reference
plt.axvline(143, color="#d95f02", linestyle="--", linewidth=1.2, label="Fetal sub-peak (~143 bp)")
plt.axvline(166, color="#7570b3", linestyle="--", linewidth=1.2, label="Mono-nukleosom (~166 bp)")
plt.axvline(330, color="#444444", linestyle=":", linewidth=1.2, label="Di-nukleosom (~330 bp)")

plt.title(f"cfDNA Read Length Distribution (Log Scale) - {sample_name}", fontsize=13, fontweight="bold")
plt.xlabel("Read length (bp)", fontsize=11)
plt.ylabel("Number of reads", fontsize=11)
plt.xlim(50, 1000)
plt.grid(axis="y", linestyle=":", alpha=0.6)
plt.legend(loc="upper right", frameon=True)

plt.tight_layout()
plt.savefig(f"{plots_dir}/cfDNA_log_histogram.png")
plt.close()
EOF

# popis:
# SN (Summary - obsahuje error rate/accuracy)
# CO (Coverage - pokrytí)
# FFQ (Quality - kvalita prvního fragmentu)
# NanoStat (vytvoří soubor s celkovým přehledem kvality readů)
# Mosdepth (vytvoří soubory s výpočtem pokrytí pro MultiQC)
# NanoPlot (vytvoří grafy pro délku readů a kvalitu)

# --- D) PROMAZÁNÍ NEPOTŘEBNÝCH SOUBORŮ Z PLOTS_DIR ---
# Přesuneme jen požadované soubory do dočasné složky, zbytek smažeme
mkdir -p "${PLOTS_DIR}_clean"

# 1. NanoStats.txt
cp "$PLOTS_DIR/NanoStats.txt" "${PLOTS_DIR}_clean/NanoStats-HAC.txt" 2>/dev/null || true

# 2. NanoPlot-report.html
cp "$PLOTS_DIR/NanoPlot-report.html" "${PLOTS_DIR}_clean/NanoPlot-report-HAC.html" 2>/dev/null || true

# 3. LengthvsQualityScatterPlot
cp "$PLOTS_DIR"/LengthvsQualityScatterPlot*dot.png "${PLOTS_DIR}_clean/" 2>/dev/null || true

# 4. cfDNA_log_histogram.png
cp "$PLOTS_DIR/cfDNA_log_histogram.png" "${PLOTS_DIR}_clean/cfDNA-HAC_log_histogram.png" 2>/dev/null || true

# Nahradíme původní složku vyčištěnou složkou
rm -rf "$PLOTS_DIR"
mv "${PLOTS_DIR}_clean" "$PLOTS_DIR"

# =============================================================================
# 6. KONTROLA VÝSLEDKU STATISTIKY
# =============================================================================
echo "[Kontrola] Prověřuji výstupní statistiky..." | tee -a "$JOB_LOG"

FILES_TO_CHECK=(
    "$LENGTH_FILE"
    "$QUALITY_COVERAGE_FILE"
    "$NANOSTAT_FILE"
    "$MOSDEPTH_PREFIX.mosdepth.summary.txt"
    "$PLOTS_DIR/NanoPlot-report-HAC.html"
    "$PLOTS_DIR/NanoStats-HAC.txt"
    "$PLOTS_DIR/cfDNA-HAC_log_histogram.png"
)

for FILE in "${FILES_TO_CHECK[@]}"; do
    if [ ! -s "$FILE" ]; then
        echo "KRITICKÁ CHYBA: Soubor $FILE neexistuje nebo je prázdný!" | tee -a "$JOB_LOG" >&2
        exit 1
    fi
done

# =============================================================================
# 7. KOPÍROVÁNÍ VÝSLEDKŮ A ÚKLID
# =============================================================================
echo "[3/3] Kopíruji výsledky do $FINAL_stats_OUTPUT_DIR..." | tee -a "$JOB_LOG"

mkdir -p "$FINAL_stats_OUTPUT_DIR"

# Samtools, Mosdepth a NanoStat
cp "$LENGTH_FILE" "$FINAL_stats_OUTPUT_DIR/"
cp "$QUALITY_COVERAGE_FILE" "$FINAL_stats_OUTPUT_DIR/"
cp "$NANOSTAT_FILE" "$FINAL_stats_OUTPUT_DIR/"
cp "$MOSDEPTH_PREFIX.mosdepth.summary.txt" "$FINAL_stats_OUTPUT_DIR/"

# Kopírování vyčištěné složky plots_${SAMPLE_NAME} (obsahuje pouze vybrané soubory)
cp -r "$PLOTS_DIR" "$FINAL_stats_OUTPUT_DIR/"

cp "$JOB_LOG" "$FINAL_stats_OUTPUT_DIR/"

echo "ÚSPĚCH STATISTIKY: HOTOVO!" | tee -a "$FINAL_stats_OUTPUT_DIR/HAC-statistics_alignment_info.txt"
rm -rf "$SCRATCHDIR"/*