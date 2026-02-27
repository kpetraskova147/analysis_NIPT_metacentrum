#!/bin/bash
# =============================================================================
# 0. PBS PARAMETRY
# =============================================================================
#PBS -N WisecondorX_Analysis
#PBS -l select=1:ncpus=8:mem=16gb:scratch_local=20gb
#PBS -l walltime=12:00:00
#PBS -o systemove_logy/
#PBS -e systemove_logy/
#PBS -m ae

#PBS -M tvoje.adresa@email.cz
#PBS -J 1-24

# =============================================================================
# Skript pro analýzu WisecondorX na clusteru Metacentrum
# =============================================================================
        # Tento skript je navržen pro spuštění jako PBS job array, kde každý vzorek 
        #   je zpracováván samostatně. Skript provádí dvě hlavní operace: konverzi BAM souboru 
        #   do NPZ formátu a následnou analýzu (predict) pomocí WisecondorX. Výstupy jsou 
        #   organizovány do struktury složek podle vzorků a runů, což usnadňuje přehlednost výsledků. 

        # Terminál otevři ve složce wisecondorx, kde máš uložen tento skript (skript_wisecondorX.sh) a další potřebné soubory (samples_seznam_wisecondorx.txt, reference.npz atd.).

        # Před spuštěním:
        # 1. Ve složce wisecondorX musíš mít: skript_wisecondorX.sh, samples_seznam_wisecondorx.txt, reference.npz, environment.yml
        # 2. Uprav PBS -M a PBS -J podle počtu vzorků a svého emailu.
        # 3. Uprav ve 3. kapitole: BASE_DIR, INPUT_BAM_BAI_DIR, OUTPUT_DIR a REFERENCE podle své struktury dat.
 

# =============================================================================
# 1. PŘÍPRAVA PROSTŘEDÍ
# =============================================================================
cd $PBS_O_WORKDIR
mkdir -p systemove_logy

module load conda
conda activate wisecondorX_env

# =============================================================================
# 2. NAČTENÍ DAT ZE SAMPLES.TXT (3 sloupce - ID, BAM cesta, RUN)
# =============================================================================
LINE=$(sed -n "${PBS_ARRAY_INDEX}p" samples_seznam_wisecondorx.txt)
SAMPLE_ID=$(echo $LINE | awk '{print $1}')  # barcode01-run-1
BAM_PATH=$(echo $LINE | awk '{print $2}')   # alignment_output_run1/barcode01.bam
RUN_NUMBER=$(echo $LINE | awk '{print $3}')    # 1

# Bezpečnostní pojistka proti prázdným řádkům
if [ -z "$SAMPLE_ID" ] || [ -z "$BAM_PATH" ] || [ -z "$RUN_NUMBER" ]; then
    echo "CHYBA: Chybí data pro index $PBS_ARRAY_INDEX (prázdný řádek?)"
    exit 1
fi

# =============================================================================
# 3. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST)
# =============================================================================

# Základní adresář, kde běží má analýza a mám zde uložena data
# ÚPRAVA: TVUJ_LOGIN (můj osobní login na metacentru), praha1 (cluster, kde běží analýza a mám data)
BASE_DIR="/storage/praha1/home/TVUJ_LOGIN"

# Umístění vstupních dat (.bam soubory - Minimap2)
INPUT_BAM_BAI_DIR="$BASE_DIR/alignment/alignment_results"
BAM_PATH="${INPUT_BAM_BAI_DIR}/${BAM_PATH}"

# Výstupní složka pro výsledky WisecondorX (NPZ a grafy)
OUTPUT_DIR="$BASE_DIR/wisecondorX/"                                         # Kam půjde výsledek (.npz a grafy)
FINAL_OUTPUT_DIR="$OUTPUT_DIR/wisecondorX_${RUN_NUMBER}_${SAMPLE_ID}"
mkdir -p "${FINAL_OUTPUT_DIR}"

# Cesta k referenci
REFERENCE="$BASE_DIR/wisecondorX/reference.npz"

# Uložení všech NPZ souborů pro případné vytvoření nové reference
NPZ_OUTPUT_DIR="$OUTPUT_DIR/ALL_NPZ"
mkdir -p "${NPZ_OUTPUT_DIR}"
NPZ_FILE="${NPZ_OUTPUT_DIR}/${RUN_NUMBER}_${SAMPLE_ID}.npz"


# =============================================================================
# 4. SPUŠTĚNÍ ANALÝZY - CONVERT + PREDICT
# =============================================================================

echo "Start: ${SAMPLE_ID} z runu ${RUN_NUMBER}"

# KROK 1: Convert
WisecondorX convert "${BAM_PATH}" "${NPZ_FILE}"

# KROK 2: Predict
WisecondorX predict "${NPZ_FILE}" "${REFERENCE}" "${FINAL_OUTPUT_DIR}/${SAMPLE_ID}.result.npz" \
    --outdir "${FINAL_OUTPUT_DIR}" \
    --cpus 8 \
    --plot \
    --bed

echo "Hotovo: ${SAMPLE_ID}"
