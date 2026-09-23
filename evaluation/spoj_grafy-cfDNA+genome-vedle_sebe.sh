#!/bin/bash
#PBS -N cfDNA_genome
#PBS -l select=1:ncpus=1:mem=8gb
#PBS -l walltime=00:10:00
#PBS -o /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/
#PBS -e /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/

mkdir -p /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/

cd $PBS_O_WORKDIR

BASE_DIR="/storage/brno12-cerit/home/petraskkar/RESULTS"

# Zde předpokládám, že TYPE je předán přes qsub -v (např. TYPE="sup")
INPUT_DIR="${BASE_DIR}/1-EVALUATION_${TYPE}/${RUN}_evaluation-${TYPE}"

OUTPUT_DIR="${BASE_DIR}/2-COMPARISON/${RUN}_comparison"
# Jeden společný výstupní soubor
OUTPUT_FILE="${OUTPUT_DIR}/${TYPE}_${RUN}_genome-cfDNA_kombo.pdf"

mkdir -p "$OUTPUT_DIR"

# ========================================================================================
# 1. PYTHON SKRIPT
# ========================================================================================
python3 - <<EOF
import os
from PIL import Image

run = "$RUN"
type = "$TYPE"
input_dir = "$INPUT_DIR"
output_file = "$OUTPUT_FILE"

pages = []
spacing = 40  # Mezera mezi grafy v pixelech

# Projdeme dvojice (1,13), (2,14) až (12,24)
for i in range(1, 13):
    bc1_str = f"barcode{i:02d}"
    bc2_str = f"barcode{i+12:02d}"
    
    # --- Definice cest ke grafům ---
    # Nahoře (vzorek 1-12)
    file_g1 = f"{input_dir}/{run}-{type}_{bc1_str}/1000kb_genome-{run}-{type}_{bc1_str}.png"
    file_c1 = f"{input_dir}/{run}-{type}_{bc2_str}/1000kb_genome-{run}-{type}_{bc2_str}.png"
    
    # Dole (vzorek 13-24)
    file_g2 = f"{input_dir}/{run}-{type}_{bc1_str}/cfDNA-length-{run}-{type}_{bc1_str}.png"
    file_c2 = f"{input_dir}/{run}-{type}_{bc2_str}/cfDNA-length-{run}-{type}_{bc2_str}.png"
    
    # --- Načtení obrázků ---
    img_g1 = Image.open(file_g1) if os.path.exists(file_g1) else None
    img_c1 = Image.open(file_c1) if os.path.exists(file_c1) else None
    img_g2 = Image.open(file_g2) if os.path.exists(file_g2) else None
    img_c2 = Image.open(file_c2) if os.path.exists(file_c2) else None
    
    valid_imgs = [img for img in (img_g1, img_c1, img_g2, img_c2) if img]
    
    if valid_imgs:
        # --- Výpočet rozměrů sloupců a řádků ---
        # Šířka levého sloupce (genome) a pravého (cfDNA)
        w_g = max((img.width for img in (img_g1, img_g2) if img), default=0)
        w_c = max((img.width for img in (img_c1, img_c2) if img), default=0)
        
        # Výška horního řádku (bc1) a dolního (bc13)
        h_row1 = max((img.height for img in (img_g1, img_c1) if img), default=0)
        h_row2 = max((img.height for img in (img_g2, img_c2) if img), default=0)
        
        # Celková velikost plátna pro tuto stránku
        total_w = w_g + spacing + w_c if (w_g and w_c) else w_g + w_c
        total_h = h_row1 + spacing + h_row2 if (h_row1 and h_row2) else h_row1 + h_row2
        
        page = Image.new('RGB', (total_w, total_h), 'white')
        
        # --- Vkládání do mřížky ---
        if img_g1: page.paste(img_g1, (0, 0))                             # Vlevo nahoře (Genome 1)
        if img_c1: page.paste(img_c1, (w_g + spacing, 0))                 # Vpravo nahoře (Genome 13)
        if img_g2: page.paste(img_g2, (0, h_row1 + spacing))              # Vlevo dole (cfDNA 1)
        if img_c2: page.paste(img_c2, (w_g + spacing, h_row1 + spacing))  # Vpravo dole (cfDNA 13)

        pages.append(page)

# --- Uložení výsledného PDF ---
if pages:
    pages[0].save(output_file, "PDF", resolution=100.0, save_all=True, append_images=pages[1:])
    print(f"ÚSPĚCH! Kombinované PDF uloženo jako: {output_file}")
else:
    print("CHYBA: Nebyly nalezeny žádné grafy! Zkontrolujte cesty k souborům.")

EOF