#!/bin/bash

# Zkontrolujeme, zda skripty v dané složce vůbec existují, než je spustíme
if [ ! -f "spoj_grafy-cfDNA-pod_sebou.sh" ] || [ ! -f "spoj_grafy-cfDNA-vedle_sebe.sh" ]; then
    echo "Chyba: Nemohu najít jeden ze skriptů (spoj_grafy-cfDNA-pod_sebou.sh nebo spoj_grafy-cfDNA-vedle_sebe.sh)."
    echo "Ujisti se, že spouštíš tento skript ze stejné složky, kde jsou tyto dva skripty."
    exit 1
fi

# Cyklus, který proběhne pro čísla 1, 2, 3 a 4
for i in {1..4}; do
    CURRENT_RUN="run${i}"
    echo "======================================"
    echo "Odesílám úlohy pro $CURRENT_RUN..."
    echo "======================================"

    # Odeslání prvního skriptu (pod sebou). Posíláme RUN i RUN_NUMBER pro jistotu
    qsub -v RUN="$CURRENT_RUN",RUN_NUMBER="$CURRENT_RUN" spoj_grafy-cfDNA-pod_sebou.sh
    
    # Odeslání druhého skriptu (vedle sebe)
    qsub -v RUN="$CURRENT_RUN",RUN_NUMBER="$CURRENT_RUN" spoj_grafy-cfDNA-vedle_sebe.sh

    echo "Úlohy pro $CURRENT_RUN byly odeslány."
    echo ""
done

echo "Všechny úlohy (celkem 8) byly úspěšně zařazeny do qsub fronty!"