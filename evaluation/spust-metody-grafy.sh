#!/bin/bash
#PBS -N spust-porovnani-metod
#PBS -o /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/
#PBS -e /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/

cd "$PBS_O_WORKDIR"

mkdir -p /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/

# Sjednocení proměnné RUN
RUN="${RUN:-$RUN_NUMBER}"

if [ -z "$RUN" ]; then
    echo "CHYBA: Musíte zadat RUN_NUMBER (např. qsub -v RUN_NUMBER=run1 spust-porovnani-metod.sh)"
    exit 1
fi

# Kontrola existence skriptů podle reálných názvů[cite: 7]
if [ ! -f "metody-comparison-pod-sebou.sh" ]; then
    echo "CHYBA: Nelze najít skript: metody-comparison-pod-sebou.sh"
    exit 1
fi

if [ ! -f "metody-comparison-vedle-sebe.sh" ]; then
    echo "CHYBA: Nelze najít skript: metody-comparison-vedle-sebe.sh"
    exit 1
fi

echo "======================================"
echo "Odesílám úlohy pro $RUN (Porovnání všech metod)..."
echo "======================================"

# Odeslání bez proměnné TYPE (u porovnání potřebujeme vždy všechny typy naráz)
qsub -v RUN="$RUN" metody-comparison-pod-sebou.sh
qsub -v RUN="$RUN" metody-comparison-vedle-sebe.sh

echo "Úlohy pro porovnání metod pro $RUN byly úspěšně odeslány do fronty (celkem 2)."