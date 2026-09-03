#!/bin/bash
#PBS -N Instalace_Prostredi
#PBS -l select=1:ncpus=2:mem=16gb
#PBS -l walltime=2:00:00
#PBS -q default
#PBS -j oe

set -e
set -x

echo "1. Úklid starých zbytků..."
rm -rf /storage/brno12-cerit/home/petraskkar/conda_envs/env_stats_alignment

echo "2. ZÁCHRANA PŘED PLNÝM DISKEM: Přesměrování paměti na brno12..."
# Vytvoříme novou složku pro mezipaměť na prostorném disku
mkdir -p /storage/brno12-cerit/home/petraskkar/conda_cache
# Řekneme Condě/Mambě, ať odteď stahuje všechny dočasné soubory sem
export CONDA_PKGS_DIRS="/storage/brno12-cerit/home/petraskkar/conda_cache"

echo "3. Obejítí rozbitých serverů MetaCentra (pro jistotu)..."
export CONDARC="/storage/brno12-cerit/home/petraskkar/alignment/bypass.condarc"
echo "channels:" > $CONDARC
echo "  - conda-forge" >> $CONDARC
echo "  - bioconda" >> $CONDARC
echo "allow_other_channels: false" >> $CONDARC

echo "4. Načítám Mambu..."
module purge
module load mambaforge
eval "$(conda shell.bash hook)"

echo "5. Finální instalace..."
mamba env create --prefix /storage/brno12-cerit/home/petraskkar/conda_envs/env_stats_alignment -f /storage/brno12-cerit/home/petraskkar/alignment/env_stats_alignment.yml

echo "HOTOVO! Prostředí je skutečně připraveno a disk nás už nezastaví."