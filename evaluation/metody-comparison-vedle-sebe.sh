#!/bin/bash
#PBS -N porovnani-3-metod-vedlesebe
#PBS -l select=1:ncpus=1:mem=8gb
#PBS -l walltime=00:15:00
#PBS -o /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/
#PBS -e /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/

# Přechod do pracovní složky
cd $PBS_O_WORKDIR

# Načtení proměnné z terminálu (výchozí run1)
RUN="${RUN:-run1}"

mkdir -p /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/

BASE_DIR="/storage/brno12-cerit/home/petraskkar/RESULTS"

# Cesty ke třem různým hodnocením
INPUT_DIR1="${BASE_DIR}/1-EVALUATION/${RUN}_evaluation-seq_qc"
INPUT_DIR2="${BASE_DIR}/1-EVALUATION_HAC/${RUN}_evaluation-HAC"
INPUT_DIR3="${BASE_DIR}/1-EVALUATION_Minknow/${RUN}_evaluation-Minknow"

OUTPUT_DIR="${BASE_DIR}/2-COMPARISON/${RUN}_comparison"
OUTPUT_FILE1="${OUTPUT_DIR}/${RUN}_metody-cfDNA_length-grafy-vedlesebe.pdf"
PDF_OUTPUT1="${OUTPUT_DIR}/${RUN}_metody-genome-1000kb_grafy-vedlesebe.pdf"

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

output_file = "$OUTPUT_FILE1"
pdf_output = "$PDF_OUTPUT1"

pages_cfdna = []
pages_genome = []

# Projdeme všech 24 barcodů
for i in range(1, 25):
    bc = f"barcode{i:02d}"
    
    # --- 1. Zpracování cfDNA grafů ---
    # Názvy upraveny přesně podle screenshotů pro každou metodu
    file1 = f"{input_dir1}/{bc}_{run}/cfDNA_length_{run}_{bc}.png"
    file2 = f"{input_dir2}/{bc}_{run}/cfDNA_length_HAC_{run}_{bc}.png"
    file3 = f"{input_dir3}/{bc}_{run}-Minknow/cfDNA_length-Minknow_{run}_{bc}.png"

    img1 = Image.open(file1) if os.path.exists(file1) else None
    img2 = Image.open(file2) if os.path.exists(file2) else None
    img3 = Image.open(file3) if os.path.exists(file3) else None
    
    w1, h1 = img1.size if img1 else (0, 0)
    w2, h2 = img2.size if img2 else (0, 0)
    w3, h3 = img3.size if img3 else (0, 0)
    
    if img1 or img2 or img3:
        # Dynamický výpočet šířky plátna
        widths = [w for w in (w1, w2, w3) if w > 0]
        total_w = sum(widths) + (len(widths) - 1) * 40 if widths else 800
        max_h = max(h1, h2, h3)
        
        page = Image.new('RGB', (total_w, max_h if max_h > 0 else 800), 'white')
        
        current_x = 0
        if img1:
            page.paste(img1, (current_x, 0))
            current_x += w1 + 40
        if img2:
            page.paste(img2, (current_x, 0))
            current_x += w2 + 40
        if img3:
            page.paste(img3, (current_x, 0))
            
        pages_cfdna.append(page)

    # --- 2. Zpracování 1000kb_genome grafů ---
    # Názvy upraveny přesně podle screenshotů pro každou metodu
    file4 = f"{input_dir1}/{bc}_{run}/1000kb_genome_HAC_{run}_{bc}.png"
    file5 = f"{input_dir2}/{bc}_{run}/1000kb_genome_HAC_{run}_{bc}.png"
    file6 = f"{input_dir3}/{bc}_{run}-Minknow/1000kb_genome-Minknow_{run}_{bc}.png"

    img4 = Image.open(file4) if os.path.exists(file4) else None
    img5 = Image.open(file5) if os.path.exists(file5) else None
    img6 = Image.open(file6) if os.path.exists(file6) else None

    w4, h4 = img4.size if img4 else (0, 0)
    w5, h5 = img5.size if img5 else (0, 0)
    w6, h6 = img6.size if img6 else (0, 0)
    
    if img4 or img5 or img6:
        # Dynamický výpočet šířky plátna
        widths2 = [w for w in (w4, w5, w6) if w > 0]
        total_w2 = sum(widths2) + (len(widths2) - 1) * 40 if widths2 else 800
        max_h2 = max(h4, h5, h6)
        
        page2 = Image.new('RGB', (total_w2, max_h2 if max_h2 > 0 else 800), 'white')
        
        current_x2 = 0
        if img4:
            page2.paste(img4, (current_x2, 0))
            current_x2 += w4 + 40
        if img5:
            page2.paste(img5, (current_x2, 0))
            current_x2 += w5 + 40
        if img6:
            page2.paste(img6, (current_x2, 0))
            
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