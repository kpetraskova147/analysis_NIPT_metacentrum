#!/bin/bash
#PBS -N seq_qc-2x-pdf-podsebou
#PBS -l select=1:ncpus=1:mem=8gb
#PBS -l walltime=00:10:00
#PBS -o /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/
#PBS -e /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/

mkdir -p /storage/brno12-cerit/home/petraskkar/RESULTS/1-EVALUATION/pbs_outputs/


BASE_DIR="/storage/brno12-cerit/home/petraskkar/RESULTS"
INPUT_DIR="${BASE_DIR}/1-EVALUATION/${RUN}_evaluation-seq_qc"

# Výsledné soubory (změněn název na podsebou)
OUTPUT_DIR="${BASE_DIR}/2-COMPARISON/${RUN}_comparison"
OUTPUT_FILE_CFDNA="${OUTPUT_DIR}/${RUN}_cfDNA_length-grafy-podsebou.pdf"
OUTPUT_FILE_GENOME="${OUTPUT_DIR}/${RUN}_genome-1000kb_grafy-podsebou.pdf"

mkdir -p "$OUTPUT_DIR"

# ========================================================================================
# 1. PYTHON SKRIPT
# ========================================================================================
python3 - <<EOF
import os
from PIL import Image

run = "$RUN"
input_dir = "$INPUT_DIR"
output_file_cfdna = "$OUTPUT_FILE_CFDNA"
output_file_genome = "$OUTPUT_FILE_GENOME"

pages_cfdna = []
pages_genome = []

# Projdeme dvojice (1,13), (2,14) až (12,24)
for i in range(1, 13):
    bc1_str = f"barcode{i:02d}"
    bc2_str = f"barcode{i+12:02d}"
    
    # ---------------------------------------------------------
    # 1. Zpracování cfDNA grafů (POD SEBOU)
    # ---------------------------------------------------------
    file1_cfdna = f"{input_dir}/{bc1_str}_{run}/cfDNA_length_{run}_{bc1_str}.png"
    file2_cfdna = f"{input_dir}/{bc2_str}_{run}/cfDNA_length_{run}_{bc2_str}.png"
    
    img1_cfdna = Image.open(file1_cfdna) if os.path.exists(file1_cfdna) else None
    img2_cfdna = Image.open(file2_cfdna) if os.path.exists(file2_cfdna) else None
    
    w1_c, h1_c = img1_cfdna.size if img1_cfdna else (0, 0)
    w2_c, h2_c = img2_cfdna.size if img2_cfdna else (0, 0)
    
    if img1_cfdna or img2_cfdna:
        # Maximální šířka a součet výšek (osa Y)
        max_w_c = max(w1_c, w2_c)
        total_h_c = h1_c + h2_c + (40 if img1_cfdna and img2_cfdna else 0)
        
        page_cfdna = Image.new('RGB', (max_w_c if max_w_c > 0 else 800, total_h_c if total_h_c > 0 else 600), 'white')
        
        if img1_cfdna:
            page_cfdna.paste(img1_cfdna, (0, 0)) # Nahoře
        if img2_cfdna:
            page_cfdna.paste(img2_cfdna, (0, h1_c + 40 if img1_cfdna else 0)) # Pod ním dolů
            
        pages_cfdna.append(page_cfdna)

    # ---------------------------------------------------------
    # 2. Zpracování 1000kb_genome grafů (POD SEBOU)
    # ---------------------------------------------------------
    file1_genome = f"{input_dir}/{bc1_str}_{run}/1000kb_genome_{run}_{bc1_str}.png"
    file2_genome = f"{input_dir}/{bc2_str}_{run}/1000kb_genome_{run}_{bc2_str}.png"
    
    img1_genome = Image.open(file1_genome) if os.path.exists(file1_genome) else None
    img2_genome = Image.open(file2_genome) if os.path.exists(file2_genome) else None
    
    w1_g, h1_g = img1_genome.size if img1_genome else (0, 0)
    w2_g, h2_g = img2_genome.size if img2_genome else (0, 0)
    
    if img1_genome or img2_genome:
        # Maximální šířka a součet výšek (osa Y)
        max_w_g = max(w1_g, w2_g)
        total_h_g = h1_g + h2_g + (40 if img1_genome and img2_genome else 0)
        
        page_genome = Image.new('RGB', (max_w_g if max_w_g > 0 else 800, total_h_g if total_h_g > 0 else 600), 'white')
        
        if img1_genome:
            page_genome.paste(img1_genome, (0, 0)) # Nahoře
        if img2_genome:
            page_genome.paste(img2_genome, (0, h1_g + 40 if img1_genome else 0)) # Pod ním dolů
            
        pages_genome.append(page_genome)

# ---------------------------------------------------------
# Uložení obou PDF
# ---------------------------------------------------------
if pages_cfdna:
    pages_cfdna[0].save(output_file_cfdna, "PDF", resolution=100.0, save_all=True, append_images=pages_cfdna[1:])
    print(f"Hotovo! cfDNA PDF uloženo jako: {output_file_cfdna}")
else:
    print("Chyba: Nebyly nalezeny žádné cfDNA grafy!")

if pages_genome:
    pages_genome[0].save(output_file_genome, "PDF", resolution=100.0, save_all=True, append_images=pages_genome[1:])
    print(f"Hotovo! Genome PDF uloženo jako: {output_file_genome}")
else:
    print("Chyba: Nebyly nalezeny žádné genome grafy!")

EOF