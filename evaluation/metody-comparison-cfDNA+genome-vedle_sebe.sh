#!/bin/bash
#PBS -N methods-cfDNA_genome
#PBS -l select=1:ncpus=1:mem=8gb
#PBS -l walltime=00:15:00
#PBS -o /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/
#PBS -e /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/

mkdir -p /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/

cd $PBS_O_WORKDIR

BASE_DIR="/storage/brno12-cerit/home/petraskkar/RESULTS"

# Cesty ke čtyřem různým hodnocením
INPUT_DIR1="${BASE_DIR}/1-EVALUATION_sup/${RUN}_evaluation-sup"
INPUT_DIR2="${BASE_DIR}/1-EVALUATION_fast/${RUN}_evaluation-fast"
INPUT_DIR3="${BASE_DIR}/1-EVALUATION_HAC/${RUN}_evaluation-HAC"
INPUT_DIR4="${BASE_DIR}/1-EVALUATION_MinKNOW/${RUN}_evaluation-MinKNOW"

OUTPUT_DIR="${BASE_DIR}/2-COMPARISON/${RUN}_comparison"
# Jeden společný výstupní soubor
OUTPUT_FILE="${OUTPUT_DIR}/${RUN}-methods-cfDNA_genome-kombo.pdf"

mkdir -p "$OUTPUT_DIR"

# ========================================================================================
# 1. PYTHON SKRIPT
# ========================================================================================
python3 - <<EOF
import os
from PIL import Image

run = "$RUN"
input_dir1 = "$INPUT_DIR1"
input_dir2 = "$INPUT_DIR2"
input_dir3 = "$INPUT_DIR3"
input_dir4 = "$INPUT_DIR4"
output_file = "$OUTPUT_FILE"

pages = []
spacing = 40  # Mezera mezi grafy v pixelech

    # --- 1. Zpracování cfDNA grafů ---
    # Názvy upraveny přesně podle screenshotů pro každou metodu
    filec1 = f"{input_dir1}/{run}-sup_{bc}/cfDNA-length-{run}-sup_{bc}.png"
    filec2 = f"{input_dir3}/{run}-fast_{bc}/cfDNA-length-{run}-fast_{bc}.png"
    filec3 = f"{input_dir2}/{run}-HAC_{bc}/cfDNA-length-{run}-HAC_{bc}.png"
    filec4 = f"{input_dir4}/{run}-MinKNOW_{bc}/cfDNA-length-{run}-MinKNOW_{bc}.png"
    
   
    # --- Načtení obrázků ---
    img_c1 = Image.open(file_c1) if os.path.exists(file_c1) else None
    img_c2 = Image.open(file_c2) if os.path.exists(file_c2) else None
    img_c3 = Image.open(file_c3) if os.path.exists(file_c3) else None
    img_c4 = Image.open(file_c4) if os.path.exists(file_c4) else None
    
    valid_imgs = [img for img in (img_c1, img_c2, img_c3, img_c4) if img]
    
    if valid_imgs:
        # --- Výpočet rozměrů sloupců a řádků ---
        # Šířka levého sloupce (genome) a pravého (cfDNA)
        w_g = max((img.width for img in (img_c1, img_c3) if img), default=0)
        w_c = max((img.width for img in (img_c2, img_c4) if img), default=0)
        
        # Výška horního řádku (bc1) a dolního (bc13)
        h_row1 = max((img.height for img in (img_c1, img_c2) if img), default=0)
        h_row2 = max((img.height for img in (img_c3, img_c4) if img), default=0)
        
        # Celková velikost plátna pro tuto stránku
        total_w = w_g + spacing + w_c if (w_g and w_c) else w_g + w_c
        total_h = h_row1 + spacing + h_row2 if (h_row1 and h_row2) else h_row1 + h_row2
        
        page = Image.new('RGB', (total_w, total_h), 'white')
        
        # --- Vkládání do mřížky ---
        if img_c1: page.paste(img_c1, (0, 0))                             # Vlevo nahoře (sup)
        if img_c2: page.paste(img_c2, (w_g + spacing, 0))                 # Vpravo nahoře (fast)
        if img_c3: page.paste(img_c3, (0, h_row1 + spacing))              # Vlevo dole (HAC)
        if img_c4: page.paste(img_c4, (w_g + spacing, h_row1 + spacing))  # Vpravo dole (MinKNOW)

        pages.append(page)

# --- Uložení výsledného PDF ---
if pages:
    pages[0].save(output_file, "PDF", resolution=100.0, save_all=True, append_images=pages[1:])
    print(f"ÚSPĚCH! Kombinované PDF uloženo jako: {output_file}")
else:
    print("CHYBA: Nebyly nalezeny žádné grafy! Zkontrolujte cesty k souborům.")

EOF