#!/bin/bash
#PBS -N Instalace_Wisecondor
#PBS -l select=1:ncpus=2:mem=20gb
#PBS -l walltime=2:00:00
#PBS -q default
#PBS -j oe

echo "1. Přesouvám se do složky wisecondorX..." >> /storage/brno12-cerit/home/petraskkar/conda_envs/instal_wisecondorx_log.txt
cd /storage/brno12-cerit/home/petraskkar/wisecondorX

echo "2. Mažu poškozené zbytky prostředí..." >> /storage/brno12-cerit/home/petraskkar/conda_envs/instal_wisecondorx_log.txt
rm -rf /storage/brno12-cerit/home/petraskkar/conda_envs/wisecondorX_env

echo "3. Načítám Mambu..." >> /storage/brno12-cerit/home/petraskkar/conda_envs/instal_wisecondorx_log.txt
module purge
module load mambaforge
eval "$(conda shell.bash hook)"

echo "4. Zahajuji instalaci WisecondorX z vlastního GitHubu..." >> /storage/brno12-cerit/home/petraskkar/conda_envs/instal_wisecondorx_log.txt
mamba env create --prefix /storage/brno12-cerit/home/petraskkar/conda_envs/wisecondorX_env -f wisecondorX_env.yml

echo "HOTOVO! Prostředí WisecondorX je připraveno." >> /storage/brno12-cerit/home/petraskkar/conda_envs/instal_wisecondorx_log.txt