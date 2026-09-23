#!/bin/bash
#PBS -N porovnani-4-metod-ctverec
#PBS -l select=1:ncpus=1:mem=8gb
#PBS -l walltime=00:15:00
#PBS -o /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/
#PBS -e /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/

# Přechod do pracovní složky
cd $PBS_O_WORKDIR

mkdir -p /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/

BASE_DIR="/storage/brno12-cerit/home/petraskkar/RESULTS"

# Cesty ke čtyřem různým hodnocením
INPUT_DIR1="${BASE_DIR}/1-EVALUATION_sup/${RUN}_evaluation-sup"
INPUT_DIR2="${BASE_DIR}/1-EVALUATION_fast/${RUN}_evaluation-fast"
INPUT_DIR3="${BASE_DIR}/1-EVALUATION_HAC/${RUN}_evaluation-HAC"
INPUT_DIR4="${BASE_DIR}/1-EVALUATION_MinKNOW/${RUN}_evaluation-MinKNOW"

OUTPUT_DIR="${BASE_DIR}/2-COMPARISON/${RUN}_comparison"
OUTPUT_FILE1="${OUTPUT_DIR}/${RUN}_metody-cfDNA_length-kolaz.pdf"
PDF_OUTPUT1="${OUTPUT_DIR}/${RUN}_metody-genome-1000kb-kolaz.pdf"

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

output_file = "$OUTPUT_FILE1"
pdf_output = "$PDF_OUTPUT1"

pages_cfdna = []
pages_genome = []

spacing = 40  # Velikost mezery mezi obrázky

# Projdeme všech 24 barcodů
for i in range(1, 25):
    bc = f"barcode{i:02d}"
    
# --- 1. Zpracování cfDNA grafů ---
    file1 = f"{input_dir1}/{run}-sup_{bc}/cfDNA-length-{run}-sup_{bc}.png"
    file2 = f"{input_dir2}/{run}-fast_{bc}/cfDNA-length-{run}-fast_{bc}.png"
    file3 = f"{input_dir3}/{run}-HAC_{bc}/cfDNA-length-{run}-HAC_{bc}.png"
    file4 = f"{input_dir4}/{run}-MinKNOW_{bc}/cfDNA-length-{run}-MinKNOW_{bc}.png"

    img1 = Image.open(file1) if os.path.exists(file1) else None
    img2 = Image.open(file2) if os.path.exists(file2) else None
    img3 = Image.open(file3) if os.path.exists(file3) else None
    img4 = Image.open(file4) if os.path.exists(file4) else None

    valid_imgs = [img for img in (img1, img2, img3, img4) if img]
    
    if valid_imgs:
        max_w = max(img.width for img in valid_imgs)
        max_h = max(img.height for img in valid_imgs)
        
        # Vytvoření plátna pro 2x2 mřížku
        total_w = (max_w * 2) + spacing
        total_h = (max_h * 2) + spacing
        page = Image.new('RGB', (total_w, total_h), 'white')
        
        if img1: page.paste(img1, (0, 0))                              # Vlevo nahoře
        if img2: page.paste(img2, (max_w + spacing, 0))                # Vpravo nahoře
        if img3: page.paste(img3, (0, max_h + spacing))                # Vlevo dole
        if img4: page.paste(img4, (max_w + spacing, max_h + spacing))  # Vpravo dole

        pages_cfdna.append(page)

    # --- 2. Zpracování 1000kb_genome grafů ---
    file_g1 = f"{input_dir1}/{run}-sup_{bc}/1000kb_genome-{run}-sup_{bc}.png"
    file_g2 = f"{input_dir2}/{run}-fast_{bc}/1000kb_genome-{run}-fast_{bc}.png"
    file_g3 = f"{input_dir3}/{run}-HAC_{bc}/1000kb_genome-{run}-HAC_{bc}.png"
    file_g4 = f"{input_dir4}/{run}-MinKNOW_{bc}/1000kb_genome-{run}-MinKNOW_{bc}.png"

    img_g1 = Image.open(file_g1) if os.path.exists(file_g1) else None
    img_g2 = Image.open(file_g2) if os.path.exists(file_g2) else None
    img_g3 = Image.open(file_g3) if os.path.exists(file_g3) else None
    img_g4 = Image.open(file_g4) if os.path.exists(file_g4) else None

    valid_imgs_g = [img for img in (img_g1, img_g2, img_g3, img_g4) if img]
    
    if valid_imgs_g:
        max_w = max(img.width for img in valid_imgs_g)
        max_h = max(img.height for img in valid_imgs_g)
        
        # Vytvoření plátna pro 2x2 mřížku
        total_w = (max_w * 2) + spacing
        total_h = (max_h * 2) + spacing
        page2 = Image.new('RGB', (total_w, total_h), 'white')
        
        if img_g1: page2.paste(img_g1, (0, 0))                               # Vlevo nahoře
        if img_g2: page2.paste(img_g2, (max_w + spacing, 0))                 # Vpravo nahoře
        if img_g3: page2.paste(img_g3, (0, max_h + spacing))                 # Vlevo dole
        if img_g4: page2.paste(img_g4, (max_w + spacing, max_h + spacing))   # Vpravo dole

        pages_genome.append(page2)

# Uložení cfDNA PDF
if pages_cfdna:
    pages_cfdna[0].save(output_file, "PDF", resolution=100.0, save_all=True, append_images=pages_cfdna[1:])
    print(f"Hotovo! cfDNA PDF uloženo jako: {output_file}")
else:
    print("Chyba: Nebyly nalezeny žádné cfDNA grafy!")

# Uložení Genome PDF
if pages_genome:
    pages_genome[0].save(pdf_output, "PDF", resolution=100.0, save_all=True, append_images=pages_genome[1:])
    print(f"Hotovo! Genome PDF uloženo jako: {pdf_output}")
else:
    print("Chyba: Nebyly nalezeny žádné genome grafy!")

EOF