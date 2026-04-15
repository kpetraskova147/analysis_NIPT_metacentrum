
# pustíš to pomocí:
# chmod +x run_pipeline.sh
# ./run_pipeline.sh

#!/bin/bash

# =================================================================
# 0. NASTAVENÍ LOGOVÁNÍ A BAREV
# =================================================================
LOG_FILE="$(pwd)/pipeline_log_$(date +%Y%m%d_%H%M%S).txt"

# Definice barev pro výstup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funkce pro logování (píše na obrazovku I do souboru)
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_err() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# Začátek logu
echo "=== ANALÝZA SPUŠTĚNA: $(date) ===" > "$LOG_FILE"

# =================================================================
# 1. KONFIGURACE - UPRAV ZDE
# =================================================================

REF_NPZ="./reference.npz"

# Cesta ke složce s R skriptem a pomocnými soubory
SEQFF_DIR="."
SEQFF_SCRIPT_NAME="seqff.r"

# Názvy prostředí
ENV_WISE="wisecondorX"
ENV_SEQFF="seqff_env"

# Inicializace Condy
eval "$(conda shell.bash hook)"

# =================================================================
# 2. VALIDACE PŘED STARTEM
# =================================================================
log_step "Provádím pre-flight kontrolu souborů..."

# Kontrola reference
if [ ! -f "$REF_NPZ" ]; then
    log_err "CRITICAL: Referenční soubor '$REF_NPZ' neexistuje!"
    log_err "Analýza nemůže pokračovat bez reference."
    exit 1
fi

# Kontrola R skriptu a pomocných souborů
if [ ! -f "$SEQFF_DIR/$SEQFF_SCRIPT_NAME" ]; then
    log_err "CRITICAL: R skript nenalezen v '$SEQFF_DIR/$SEQFF_SCRIPT_NAME'!"
    exit 1
fi

# Kontrola, zda existuje alespoň jeden pomocný soubor pro SeqFF (prevence chyb Rka)
if ! ls "$SEQFF_DIR"/pd4615*.rdata 1> /dev/null 2>&1; then
    log_err "CRITICAL: Ve složce '$SEQFF_DIR' chybí pomocné .rdata soubory pro SeqFF!"
    exit 1
fi

log_info "Všechny konfigurační soubory nalezeny."

# =================================================================
# 3. PŘÍPRAVA PROSTŘEDÍ (AUTO-INSTALL)
# =================================================================
log_step "Kontrola Conda prostředí..."

if conda info --envs | grep -q "^$ENV_SEQFF"; then
    log_info "Prostředí $ENV_SEQFF nalezeno."
else
    log_warn "Prostředí $ENV_SEQFF nenalezeno. Zahajuji automatickou instalaci..."
    conda create -n "$ENV_SEQFF" -c conda-forge -c bioconda \
        r-base r-argparse r-stringr r-dplyr bioconductor-rsamtools -y >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log_err "FATAL: Selhala instalace prostředí $ENV_SEQFF. Zkontroluj log."
        exit 1
    fi
    log_info "Prostředí $ENV_SEQFF úspěšně vytvořeno."
fi

# =================================================================
# 4. HLAVNÍ ANALYTICKÁ SMYČKA
# =================================================================

for dp_dir in Run/DP-*; do
    if [ -d "$dp_dir" ]; then
        log_step "Vstupuji do složky: $dp_dir"
        
        align_dir="$dp_dir/alignment"
        
        if [ -d "$align_dir" ]; then
            # Hledáme složky barcode*
            # Používáme nullglob, aby cyklus neproběhl, pokud nic nenajde
            shopt -s nullglob
            barcodes=("$align_dir"/barcode*)
            shopt -u nullglob

            if [ ${#barcodes[@]} -eq 0 ]; then
                log_warn "Ve složce $align_dir nebyly nalezeny žádné složky barcode*."
                continue
            fi

            for barcode_dir in "${barcodes[@]}"; do
                
                sample_name=$(basename "$barcode_dir")
                log_info ">>> Zpracovávám vzorek: $sample_name <<<"
                
                # --- Hledání BAM souboru ---
                bam_file=$(find "$barcode_dir" -maxdepth 1 -name "*.bam" | head -n 1)
                
                if [ -z "$bam_file" ]; then
                    log_err "SKIP: Ve složce $barcode_dir není žádný .bam soubor."
                    continue
                fi

                # Převod na absolutní cestu
                bam_file=$(readlink -f "$bam_file")
                barcode_abs_path=$(readlink -f "$barcode_dir")
                
                # Definice výstupů
                seqff_out="${barcode_abs_path}/${sample_name}_seqff.txt"
                npz_out="${barcode_abs_path}/${sample_name}.npz"
                predict_out_prefix="${barcode_abs_path}/${sample_name}_output"

                # --- Validace BAM souboru (velikost) ---
                if [ ! -s "$bam_file" ]; then
                     log_err "SKIP: BAM soubor $bam_file je prázdný (velikost 0)!"
                     continue
                fi

                # ==========================================
                # KROK 1: SeqFF
                # ==========================================
                if [ -f "$seqff_out" ]; then
                    log_info "SeqFF výstup již existuje, přeskakuji."
                else
                    log_step "Spouštím SeqFF (Rscript)..."
                    
                    # Deaktivace, aktivace správného prostředí
                    conda deactivate
                    conda activate "$ENV_SEQFF"
                    
                    # Spuštění
                    (
                        cd "$SEQFF_DIR" || exit
                        Rscript "$SEQFF_SCRIPT_NAME" --hg38 -f "$bam_file" -o "$seqff_out" >> "$LOG_FILE" 2>&1
                    )
                    
                    # Kontrola chyby Rka
                    if [ $? -ne 0 ]; then
                        log_err "CHYBA: SeqFF selhal pro vzorek $sample_name! (Viz log)"
                        # Zde se rozhodujeme: Chceme pokračovat s Wisecondorem i když SeqFF selhal?
                        # Obvykle jsou nezávislé. Pokud je SeqFF kritický, dej 'continue'.
                        # Zatím necháme běžet dál, ale chyba je zalogována.
                    else
                        log_info "SeqFF dokončen úspěšně."
                    fi
                fi

                # ==========================================
                # KROK 2: WisecondorX - Convert
                # ==========================================
                log_step "Přepínám na prostředí $ENV_WISE..."
                conda deactivate
                conda activate "$ENV_WISE"

                if [ -f "$npz_out" ]; then
                    log_info "NPZ soubor již existuje, přeskakuji convert."
                else
                    log_step "Spouštím WisecondorX Convert..."
                    WisecondorX convert "$bam_file" "$npz_out" >> "$LOG_FILE" 2>&1
                    
                    if [ $? -ne 0 ]; then
                        log_err "FATAL: Convert selhal pro $sample_name. Přeskakuji zbytek vzorku."
                        continue # Jde na další barcode, tento je rozbitý
                    fi
                fi

                # ==========================================
                # KROK 3: WisecondorX - Predict
                # ==========================================
                log_step "Spouštím WisecondorX Predict..."
                WisecondorX predict "$npz_out" "$REF_NPZ" "$predict_out_prefix" --seed 1 --bed --plot >> "$LOG_FILE" 2>&1
                
                if [ $? -ne 0 ]; then
                    log_err "CHYBA: Predict selhal pro $sample_name. Zkontroluj referenci nebo data."
                else
                    log_info "Vzorek $sample_name kompletně hotov."
                fi

            done
        else
            log_warn "Složka alignment nenalezena v $dp_dir"
        fi
    fi
done

echo "==================================================" | tee -a "$LOG_FILE"
log_info "Celá analýza dokončena. Podrobnosti v souboru: $LOG_FILE"
run_analysis.sh
