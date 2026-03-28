#!/bin/bash
# ==============================================================================
# Skript pro vytvoření referenčního souboru pro WisecondorX
# ==============================================================================
# INSTRUKCE:
    # # Vytvoř si složku wisecondorX a v ní:
        # 1. SKRIPT: 'newRef.sh'
        # 2. složka "ALL_NPZ" s npz soubory pro vytvoření reference 
        # (do této složky se průběžně přidávají všechny npz soubory ze spuštěných runů 
        # je nutná manuální selekce zdravých jedinců)
        # Výstup: uloží se do složky "references" jako reference_1000kb_[DATUM].npz
        # pro použití je potřeba ji přesunout do wisecondorX složky a přejmenovat na reference.npz 
        # (+ si napsat někam poznámku o původním názvu)
        # Spuštění: terminál ve složce wisecondorX
            # qsub newRef.sh

# ==============================================================================
# 1. KONFIGURACE CONDA PROSTŘEDÍ
# ==============================================================================

# Uprav cestu k tvému storage
WORK_DIR="/storage/brno12-cerit/home/petraskkar/wisecondorX"
cd "$WORK_DIR"

module load conda

# Kontrola, zda prostředí existuje. Pokud ne, musím ho instalovat z environment.yml
if ! conda info --envs | grep -q "wisecondorX_env"; then
    echo "--- Prostředí wisecondorX_env nebylo nalezeno. Probíhá instalace. ---"
    conda install --file environment.yml
else
    echo "--- Prostředí wisecondorX_env již existuje. Aktivace. ---"
fi

conda activate wisecondorX_env
echo "--- Prostředí wisecondorX_env aktivováno. ---"

# ==============================================================================
# 2. PARAMETRY ANALÝZY
# ==============================================================================
CORES=8
INPUT_DIR="${WORK_DIR}/ALL_NPZ"
OUTPUT_DIR="${WORK_DIR}/references"
REF_SIZES="1000 500 200 100"    # Velikosti binů v kb
# cores = cpus

# Vytvoření výstupní složky, pokud neexistuje
mkdir -p "${OUTPUT_DIR}"

# ==============================================================================
# 3. VLASTNÍ VÝPOČET (SMYČKA)
# ==============================================================================
DNESNI_DATUM=$(date +%Y-%m-%d)
for REF in ${REF_SIZES}
do
    echo "------------------------------------------------------------------"
    echo "Dne $DNESNI_DATUM vytvářím referenci pro rozlišení: ${REF} kb"
    echo "------------------------------------------------------------------"

    # Spuštění WisecondorX
    # "${INPUT_DIR}"/*.npz vezme všechny .npz soubory v dané složce
    WisecondorX newref "${INPUT_DIR}"/*.npz \
        "${OUTPUT_DIR}/reference_${REF}kb_${DNESNI_DATUM}.npz" \
        --binsize ${REF}000 \
        --cpus ${CORES}

    if [ $? -eq 0 ]; then
        echo "Úspěšně vytvořeno: reference_${REF}kb_${DNESNI_DATUM}.npz"
    else
        echo "Chyba při vytváření reference pro ${REF} kb!"
    fi
done

echo "------------------------------------------------------------------"
echo "Referenční soubor byl vytvořen a uložen do: ${OUTPUT_DIR} jako reference_${REF}kb_${DNESNI_DATUM}.npz"
