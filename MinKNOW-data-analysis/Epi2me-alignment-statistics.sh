#!/bin/bash
# =============================================================================
# PBS HLAVIČKA - POUZE TVORBA GRAFU (Epi2Me length.hist)
# =============================================================================
#PBS -N Epi2me-LengthPlot
#PBS -l select=1:ncpus=1:mem=4gb:scratch_local=1gb
#PBS -l walltime=0:30:00
#PBS -q default
#PBS -j oe
#PBS -m ae
#PBS -M petraskkar@natur.cuni.cz
#PBS -J 1-24
#PBS -o /storage/brno12-cerit/home/petraskkar/alignment/pbs_outputs_statistics/

# =============================================================================
# 0. KONTROLA PROMĚNNÝCH A NASTAVENÍ CEST
# =============================================================================
set -euo pipefail

if [ -z "${RUN_NUMBER:-}" ]; then
    echo "Chyba: RUN_NUMBER není nastaven. Spusťte pomocí: qsub -v RUN_NUMBER=run1 ..." >&2
    exit 1
fi

BARCODE=$(printf "barcode%02d" "$PBS_ARRAY_INDEX")
SAMPLE_NAME="${RUN_NUMBER}-Epi2Me_${BARCODE}"

BASE_DIR="/storage/brno12-cerit/home/petraskkar"
INPUT_DIR="$BASE_DIR/RESULTS/Epi2me-statistics_results/Epi2me-statistics_output_${RUN_NUMBER}/${BARCODE}-histograms"
HIST_FILE="$INPUT_DIR/length.hist"

# Pokud soubor neexistuje, skript se pro tento vzorek bezpečně ukončí
if [ ! -s "$HIST_FILE" ]; then
    echo "CHYBA: Soubor $HIST_FILE neexistuje nebo je prázdný!" >&2
    exit 1
fi

# =============================================================================
# 1. PŘÍPRAVA PROSTŘEDÍ
# =============================================================================
module purge
module load mambaforge
eval "$(conda shell.bash hook)"
conda activate $BASE_DIR/conda_envs/env_stats_alignment

# =============================================================================
# 2. TVORBA GRAFU V PYTHONU
# =============================================================================
echo "Generuji cfDNA graf pro $SAMPLE_NAME..."

export HIST_FILE
export SAMPLE_NAME
export INPUT_DIR

python3 - << 'EOF'
import os
import matplotlib.pyplot as plt
import numpy as np

hist_file = os.environ.get("HIST_FILE")
sample_name = os.environ.get("SAMPLE_NAME")
out_dir = os.environ.get("INPUT_DIR")

x, y = [], []

# Načtení dat ve formátu "start \t end \t count"
with open(hist_file, "r") as f:
    for line in f:
        parts = line.strip().split()
        if len(parts) >= 3:
            try:
                # Vypočítá střed binu pro X osu
                x_mid = (float(parts[0]) + float(parts[1])) / 2
                count = int(parts[2])
                x.append(x_mid)
                y.append(count)
            except ValueError:
                continue

x = np.array(x)
y = np.array(y)

# Omezení na cfDNA oblast
mask = (x >= 50) & (x <= 1000)
x_cfdna, y_cfdna = x[mask], y[mask]

plt.figure(figsize=(12, 6), dpi=300)
plt.bar(x_cfdna, y_cfdna, width=x_cfdna * 0.008, color="#3ea38f", edgecolor="none", align="center")
plt.xscale("log")
ticks = [50, 100, 143, 166, 200, 330, 500, 1000]
plt.xticks(ticks, [str(t) for t in ticks], fontsize=10)
plt.minorticks_off()
plt.axvline(143, color="#d95f02", linestyle="--", linewidth=1.2, label="Fetal sub-peak (~143 bp)")
plt.axvline(166, color="#7570b3", linestyle="--", linewidth=1.2, label="Mono-nukleosome (~166 bp)")
plt.axvline(330, color="#444444", linestyle=":", linewidth=1.2, label="Di-nukleosome (~330 bp)")

plt.title(f"cfDNA Read Length Distribution - {sample_name}", fontsize=13, fontweight="bold")
plt.xlabel("Read length (bp)")
plt.ylabel("Number of reads")
plt.xlim(50, 1000)
plt.grid(axis="y", linestyle=":", alpha=0.6)
plt.legend()
plt.tight_layout()

# Uložení přímo do složky k původnímu histogramu
out_png = os.path.join(out_dir, f"cfDNA_length_histogram_{sample_name}.png")
plt.savefig(out_png)
plt.close()
EOF

echo "Hotovo! Graf uložen do: $INPUT_DIR"