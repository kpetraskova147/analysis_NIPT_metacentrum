#!/bin/bash
#PBS -N Instalace_stats_env
#PBS -l select=1:ncpus=2:mem=16gb
#PBS -l walltime=2:00:00
#PBS -q default
#PBS -j oe

echo "1. Přesouvám se do pracovní složky alignment..." >> /storage/brno12-cerit/home/petraskkar/conda_envs/instal_stats_env_log.txt
cd /storage/brno12-cerit/home/petraskkar/alignment

echo "2. Mažu poškozené zbytky prostředí..." >> /storage/brno12-cerit/home/petraskkar/conda_envs/instal_stats_env_log.txt
rm -rf /storage/brno12-cerit/home/petraskkar/conda_envs/env_stats_alignment

echo "3. Načítám Mambu..." >> /storage/brno12-cerit/home/petraskkar/conda_envs/instal_stats_env_log.txt
module purge
module load mambaforge
eval "$(conda shell.bash hook)"

echo "4. Zahajuji čistou instalaci z YML..." >> /storage/brno12-cerit/home/petraskkar/conda_envs/instal_stats_env_log.txt
mamba env create --prefix /storage/brno12-cerit/home/petraskkar/conda_envs/env_stats_alignment -f env_stats_alignment.yml

echo "HOTOVO! Prostředí je připraveno." >> /storage/brno12-cerit/home/petraskkar/conda_envs/instal_stats_env_log.txt