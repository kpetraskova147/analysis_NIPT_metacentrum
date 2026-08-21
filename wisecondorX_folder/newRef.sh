#!/bin/bash
# ==============================================================================
# PBS PARAMETRY (Nezbytné pro Metacentrum!)
# ==============================================================================
#PBS -N WisecondorX_NewRef
#PBS -l select=1:ncpus=8:mem=32gb:scratch_local=50gb
#PBS -l walltime=12:00:00
#PBS -m ae
#PBS -M petraskkar@natur.cuni.cz

#PBS -o /storage/brno12-cerit/home/petraskkar/wisecondorX/run_logs/

# ==============================================================================
# Skript pro vytvoření referenčního souboru pro WisecondorX
# ==============================================================================
# INSTRUKCE:
    # # Vytvoř si složku wisecondorX a v ní:
        # 1. SKRIPT: 'newRef.sh'
        # 2. složka "ALL_NPZ" s npz soubory pro vytvoření reference 
        # (do této složky se průběžně přidávají všechny npz soubory ze spuštěných runů 
        # je nutná manuální selekce zdravých jedinců)
        
        # Výstup: uloží se do složky "references", složky reference_$DATUM jako reference_${REF_SIZ}kb.npz (reference_1000kb.npz, reference_500kb.npz, reference_100kb.npz)
        # Spuštění: terminál ve složce wisecondorX
            # qsub newRef.sh

# ==============================================================================
# 1. ZÁKLADNÍ NASTAVENÍ A KONTROLA
# ==============================================================================

mkdir -p /storage/brno12-cerit/home/petraskkar/wisecondorX/run_logs

set -euo pipefail
DATUM=$(date +%Y-%m-%d)
CORES=8         # cores = cpus

BASE_DIR="/storage/brno12-cerit/home/petraskkar"

INPUT_DIR="${BASE_DIR}/ALL_NPZ"

OUTPUT_DIR="${BASE_DIR}/wisecondorX/references"
FINAL_OUTPUT_DIR="${OUTPUT_DIR}/reference_${DATUM}"

# Cesta k prostředí mambaforge, kde je nainstalován WisecondorX - lze zjistit příkazem `conda info --envs` nebo `conda env list` - najdu wisecondorX_env
ENVIRONMENT_PATH="/storage/brno12-cerit/home/petraskkar/.conda/envs/wisecondorX_env"
# Cesta k hlavnímu skriptu WisecondorX (main.py) v prostředí wisecondorX_env
STORAGE_WISE_ENV="/storage/brno12-cerit/home/petraskkar/wisecondorX/WisecondorX-LAB-NIPT/wisecondorx/main.py"

# Nastavení rozlišení reference (velikost binů v kb)
# Pro WisecondorX se běžně používají hodnoty jako 1000 (1 Mb), 500 (500 kb), 100 (100 kb) atd.
# 100 kb mi vezme fragmenty o velikosti 100 kb - velmi jemné rozlišení, těžší na výsledky, ale může odhalit i menší změny.
# 500 kb je kompromis mezi citlivostí a stabilitou výsledků.
# 1000 kb je pro detekci aneuploidií často dostačující, ale pro jemnější analýzy může být vhodné použít menší biny.
REF_SIZES="1000 500 100"  # Můžeš přidat další hodnoty, pokud chceš více referencí s různými rozlišeními

mkdir -p "${FINAL_OUTPUT_DIR}"

if [ -z "${SCRATCHDIR:-}" ]; then
    echo "CHYBA: SCRATCHDIR není nastaven!" >&2
    exit 1
fi

# ==============================================================================
# 2. PŘESUN DO SCRATCHE A PŘÍPRAVA DAT
# ==============================================================================
echo "--- Start tvorby reference: ${DATUM} ---"
cd "$SCRATCHDIR"

echo "Kopíruji vstupní NPZ soubory kontrol na scratch..."
# Nakopírujeme všechny .npz zdravých jedinců na rychlý lokální disk
cp "${INPUT_DIR}"/*.npz .

# ==============================================================================
# 3. AKTIVACE PROSTŘEDÍ
# ==============================================================================

echo "Načítám mambaforge a inicializuji Conda prostředí..." | tee -a 
module load mambaforge

# Tato "magická" formulka je nutná pro běh Condy v neinteraktivních PBS skriptech
eval "$(conda shell.bash hook)"

set +u

# Skript se pokusí aktivovat prostředí podle jména
if conda activate wisecondorX_env; then
    echo "--- Prostředí wisecondorX_env úspěšně aktivováno. ---"
else
    echo "Prostředí nebylo nalezeno podle jména. Zkouším absolutní cestu..."
    # Záchranná brzda: použití absolutní cesty, kam se prostředí fyzicky nainstalovalo
    if conda activate $ENVIRONMENT_PATH; then
        echo "--- Prostředí úspěšně aktivováno pomocí absolutní cesty. ---"
    else
        echo "KRITICKÁ CHYBA: Prostředí se nepodařilo aktivovat ani absolutní cestou!" >&2
        exit 1
    fi
fi

set -u

# ==============================================================================
# 4. VLASTNÍ VÝPOČET (SMYČKA)
# ==============================================================================
# Generujeme reference pro různé binsizes z dat na scratchi

mkdir -p tmp_out

for REF in ${REF_SIZES}; do
    echo "------------------------------------------------------------------"
    echo "Dne $DATUM vytvářím referenci pro rozlišení: ${REF} kb"
    echo "------------------------------------------------------------------"
    
    # Používáme ${REF}, ne ${REF_SIZES}. Ukládáme bezpečně bokem do tmp_out.
    TMP_REF="tmp_out/reference_${REF}kb.npz"
    
    # WisecondorX newref používá *.npz ze scratche, ale výstup dává mimo dosah `*.npz`
    python3 "${STORAGE_WISE_ENV}" newref *.npz "${TMP_REF}" \
        --binsize ${REF}000 \
        --cpus ${CORES}
        
    # Pokud vše klaplo, ihned to překopírujeme domů na storage
    if [ -f "${TMP_REF}" ]; then
        cp "${TMP_REF}" "${FINAL_OUTPUT_DIR}/"
        echo "Úspěšně vytvořeno a zkopírováno: $(basename ${TMP_REF})"
    else
        echo "CHYBA při vytváření reference pro ${REF} kb!" >&2
        exit 1
    fi
done

echo "------------------------------------------------------------------"
echo "Všechny referenční soubory byly úspěšně vytvořeny a uloženy do: ${FINAL_OUTPUT_DIR}"
clean_scratch