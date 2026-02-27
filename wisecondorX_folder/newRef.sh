#!/usr/bin/env bash

# ==============================================================================
# 1. KONFIGURACE CONDA PROSTŘEDÍ
# ==============================================================================
ENV_NAME="wisecondor_env"

# Najdeme základní cestu ke Condě, abychom mohli aktivovat prostředí uvnitř skriptu
CONDA_BASE=$(conda info --base)
source "${CONDA_BASE}/etc/profile.d/conda.sh"

# Kontrola, zda prostředí existuje. Pokud ne, pokusí se ho vytvořit z environment.yml
if ! conda info --envs | grep -q "$ENV_NAME"; then
    echo "--- Prostředí $ENV_NAME nebylo nalezeno. Vytvářím ho ze souboru environment.yml... ---"
    conda env create -f environment.yml
    if [ $? -ne 0 ]; then
        echo "Chyba: Nepodařilo se vytvořit prostředí. Zkontrolujte, zda existuje environment.yml."
        exit 1
    fi
fi

# Aktivace prostředí
conda activate $ENV_NAME
echo "--- Prostředí $ENV_NAME aktivováno. ---"

# ==============================================================================
# 2. PARAMETRY ANALÝZY
# ==============================================================================
CORES=8
INPUT_DIR="path/to/converts_ref" # ZMĚŇ na cestu ke složce s referenčními .npz
OUTPUT_DIR="path/to/references" # ZMĚŇ na cestu, kam chceš uložit výsledné reference
REF_SIZES="1000 500 200 100"    # Velikosti binů v kb

# Vytvoření výstupní složky, pokud neexistuje
mkdir -p "${OUTPUT_DIR}"

# ==============================================================================
# 3. VLASTNÍ VÝPOČET (SMYČKA)
# ==============================================================================
for REF in ${REF_SIZES}
do
    echo "------------------------------------------------------------------"
    echo "Právě vytvářím referenci pro rozlišení: ${REF} kb"
    echo "------------------------------------------------------------------"

    # Přepočet kb na báze (např. 100 -> 100000)
    BINSIZE=$((REF * 1000))

    # Spuštění WisecondorX
    # "${INPUT_DIR}"/*.npz vezme všechny .npz soubory v dané složce
    WisecondorX newref "${INPUT_DIR}"/*.npz \
        "${OUTPUT_DIR}/reference.${REF}kb.npz" \
        --binsize ${BINSIZE} \
        --cpus ${CORES}

    if [ $? -eq 0 ]; then
        echo "Úspěšně vytvořeno: reference.${REF}kb.npz"
    else
        echo "Chyba při vytváření reference pro ${REF} kb!"
    fi
done

echo "------------------------------------------------------------------"
echo "Všechny úkoly byly dokončeny."