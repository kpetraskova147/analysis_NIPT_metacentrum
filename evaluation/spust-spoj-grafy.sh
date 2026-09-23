#!/bin/bash
#PBS -N spust-spoj-grafy
#PBS -o /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/
#PBS -e /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/

mkdir -p /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/


# Zajištění, že jsme ve správné složce (pokud to spouštíte přes qsub)
cd "$PBS_O_WORKDIR" 2>/dev/null || true

# Sjednocení proměnné RUN_NUMBER do RUN, aby fungovalo obojí
RUN="${RUN:-$RUN_NUMBER}"

# Kontrola, zda máme vše potřebné
if [ -z "$RUN" ] || [ -z "$TYPE" ]; then
    echo "CHYBA: Musíte zadat RUN_NUMBER a TYPE (např. qsub -v RUN_NUMBER=run1,TYPE=fast ...)"
    exit 1
fi

# 1. Opravené podmínky (přidáno středník a 'then')
if [ ! -f "spoj_grafy-cfDNA+genome-vedle_sebe.sh" ]; then
    echo "CHYBA: Nelze najít skript: spoj_grafy-cfDNA+genome-vedle_sebe.sh"
    exit 1
fi

if [ ! -f "spoj_grafy-cfDNA_genome-pod_sebou.sh" ]; then
    echo "CHYBA: Nelze najít skript: spoj_grafy-cfDNA_genome-pod_sebou.sh"
    exit 1
fi

if [ ! -f "spoj_grafy-cfDNA_genome-vedle_sebe.sh" ]; then
    echo "CHYBA: Nelze najít skript: spoj_grafy-cfDNA_genome-vedle_sebe.sh"
    exit 1
fi

echo "======================================"
echo "Odesílám úlohy pro $RUN (Typ: $TYPE)..."
echo "======================================"

# 2. Opravené předávání proměnných do qsub (přidán TYPE, použit sjednocený RUN)
qsub -v RUN="$RUN",TYPE="$TYPE" spoj_grafy-cfDNA_genome-pod_sebou.sh
qsub -v RUN="$RUN",TYPE="$TYPE" spoj_grafy-cfDNA+genome-vedle_sebe.sh
qsub -v RUN="$RUN",TYPE="$TYPE" spoj_grafy-cfDNA_genome-vedle_sebe.sh

echo "Úlohy pro $RUN byly úspěšně odeslány do fronty (celkem 3)."