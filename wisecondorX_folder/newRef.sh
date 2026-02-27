#!/bin/bash
# ==============================================================================
# PBS PARAMETRY
# ==============================================================================
#PBS -N WisecondorX_NewRef
#PBS -l select=1:ncpus=8:mem=32gb:scratch_local=20gb
#PBS -l walltime=3:00:00
#PBS -o systemove_logy/
#PBS -e systemove_logy/
#PBS -m ae

# ==============================================================================
# Skript pro vytvoření referenčního souboru pro WisecondorX

# INSTRUKCE:
# ==============================================================================
        # Tento skript je navržen pro spuštění na clusteru Metacentrum a slouží 
            # k vytvoření referenčního souboru pro WisecondorX. Skript prochází všechny 
            # .npz soubory ve specifikované složce, které obsahují data z BAM souborů, 
            # a vytváří referenční soubor pro různé velikosti binů (1000 kb, 500 kb, 200 kb, 100 kb). 
            # Výstupní referenční soubor je pojmenován podle velikosti binů a aktuálního data.
        
        # Před spuštěním:
        # 1. Uprav BASE_DIR v 2. kapitole (PARAMETRY ANALÝZY)

# ==============================================================================
# 1. KONFIGURACE CONDA PROSTŘEDÍ
# ==============================================================================
cd $PBS_O_WORKDIR
mkdir -p systemove_logy

module load conda

# Kontrola, zda prostředí existuje. Pokud ne, musím ho instalovat z environment.yml
if ! conda info --envs | grep -q "wisecondorX_env"; then
    echo "--- Prostředí wisecondorX_env nebylo nalezeno. Je třeba ho instalovat. ---"
fi

conda activate wisecondorX_env
echo "--- Prostředí wisecondorX_env aktivováno. ---"

# ==============================================================================
# 2. PARAMETRY ANALÝZY
# ==============================================================================
CORES=8
BASE_DIR="/storage/praha1/home/TVUJ_LOGIN"
INPUT_DIR="${BASE_DIR}/wisecondorX/ALL_NPZ"
OUTPUT_DIR="${BASE_DIR}/wisecondorX/references"
REF_SIZES="1000 500 200 100"    # Velikosti binů v kb

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