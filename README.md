# Analysis_NIPT_metacentrum
In this repository, you can find scripts for basecalling, alignment and wisecondorX analysis of nanopore data (PromethiON). This repository also includes scripts for statistic analysis. Everything is written in Python.

## INSTRUCTIONS

IMPORTANT: PBS -J settings. 

        Minimap2 is counting files and folders from zero
                - PBS -J 0-23 for 24 samples
        WisecondorX is counting files and folders from 1
                - PBS -J 1-24 for 24 samples

## NANOPORE NIPT PIPELINE – ULTIMÁTNÍ CHEAT SHEET
### FÁZE 1: Dorado (Basecalling)
Cíl: Převod surových signálů .pod5 na čtení .fastq.

#### Co musíš mít ve složce basecalling:
Skript: dorado_basecall.sh

Data: Složka s pod5 daty (např. pod5_pass/run1_pass.pod5)

Výstupní složka: basecall_results (vytvoří se, nebo ji připrav)

Logy: Složka run_logs

Software: Složka dorado-1.0.0-linux-x64 obsahující složky bin a models
    bin - dorado
    models - dna_r10.4.1_e8.2_400bps_sup@v5.2.0/
           - methylation - dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mC_5hmC/

#### Nastavení a Spuštění:
Ve skriptu: Uprav cesty v sekci 1, zkontroluj názvy modelů a nezapomeň nastavit svůj e-mail v hlavičce (#PBS -M). Pokud chceš metylaci, odstraň # před --modified-bases-models a použij příslušný model.

Kde otevřít terminál: Ve složce basecalling

##### Spuštění:

        qsub -v RUN_NUMBER="run1" dorado_basecall.sh

### FÁZE 2: Minimap2 (Alignment) + MultiQC
Cíl: Zarovnání .fastq na referenci a tvorba .bam / .bai souborů.

#### Co musíš mít ve složce alignment:
Skript: alignment_minimap2.sh

Reference: Referenční genom (např. hg38.fa).
        (stažený z Ensemblu nebo UCSC, musí být indexovaný minimap2 - pokud není, minimap2 si ho vytvoří při prvním spuštění)

#### Nastavení a Spuštění:
Ve skriptu: Uprav cesty, doplň e-mail a pozor na číslování! Nastav #PBS -J 0-X (kde X je počet vzorků mínus 1, např. 0-23 pro 24 vzorků). Moduly nech zafixované (např. minimap2/2.26).

Kde otevřít terminál: Ve složce alignment

##### Spuštění:

        qsub -v RUN_NUMBER="run1" alignment_minimap2.sh

#### Kontrola kvality (MultiQC):
Po doběhnutí analýzy přejdi do výstupní složky (např. alignment/alignment_output_run1), kde se nachází výsledky všech vzorků, a vygeneruj si souhrnný report:

        module add multiqc
        multiqc .

MultiQC se podívá do všech podsložek, najde tam mosdepth summary a nanostat a vytvoří přehledný report s grafy pro všechny vzorky v jednom souboru (multiqc_report.html).

### FÁZE 3: WisecondorX (NIPT Analýza)
Cíl: Detekce chromozomálních aberací a NIPT reporty.

###### IMPORTANT: Před prvním spuštěním analýzu musím instalovat conda environment: 

        conda env create -f environment.yml

### Co musíš mít ve složce wisecondorX (Předletová příprava):
Skript: skript_wisecondorX.sh

Skript: uvod_kontrola.py

Prostředí: environment.yml

Reference: Soubor reference.npz

#### Krok 3.0: WisecondorX (Tvorba reference)
Cíl: Vytvoření "zlatého standardu" (reference) ze zdravých vzorků.
        - referenci mohu vytvořit pomocí skriptu newRef.sh
        - vytvoří mi referenci ze souborů v ALL_NPZ složce (ve složce wisecondorX)
        - uloží se do složky references (ve wisecondorX) jako reference_{velikost}kb_datum.npz
        - pro použití je potřeba ji přesunout do wisecondorX složky a přejmenovat na reference.npz (můžu si napsat někam poznámku o původním jménu)
        - můžu vytvořit pouze jednu referenci a používat ji dokola, nebo můžu reference aktualizovat

Kde otevřít terminál: Složka wisecondorX

Vstup: Všechny dostupné .npz soubory zdravých vzorků uložené ve složce ALL_NPZ.

##### Co spouštím:

        qsub newRef.sh

Výstup: Soubory reference_1000kb_[DATUM].npz jsou uložené ve složce references.

#### Krok 3.1: Vygenerování seznamu vzorků
Kde otevřít terminál: Ve složce alignment_results (kde leží hotové BAMy).

##### Co spouštím:

        find "$PWD"/alignment_output_*/ -name "barcode*.bam" | awk -F/ '{
            run_dir=$(NF-1); 
            run_num=run_dir; gsub("alignment_output_", "", run_num); 
            bam_file=$NF; 
            barcode=bam_file; gsub(".bam", "", barcode); 
            print barcode"-run-"run_num " " $0 " " run_num
        }' > /storage/praha1/home/TVUJ_LOGIN/wisecondorX/samples_seznam_wisecondorx.txt

#### Krok 3.2: Kontrola a vytvoření logu
Kde otevřít terminál: Nyní se přesuň do složky wisecondorX

##### Co spouštím:

        python3 uvod_kontrola.py

#### Krok 3.3: Spuštění výpočtu
Ve skriptu: Pokud Python nevyhodil chyby, otevři skript_wisecondorX.sh. Zkontroluj cesty, uprav e-mail a nastav #PBS -J 1-X (zde se naopak začíná od 1, přesně podle počtu, který ti nahlásil Python).

Kde otevřít terminál: Stále ve složce wisecondorX

##### Spuštění:

        qsub skript_wisecondorX.sh




## ERRORS

### BASECALLING
If your data stays in a SCRATCH folder, you need to copy them manually before your time runs out.

    Pokud úloha selže v posledním kroku a v logu se objeví hláška, že "data zůstala ve scratchi pro kontrolu", znamená to, že samotný výpočet (basecalling) proběhl úspěšně, ale selhal finální přesun na /storage. Data lze zachránit manuálně, pokud je systémový čistící skript ještě nesmazal.
    
    Postup záchrany dat:
    
    1. Najdi adresu uzlu a cestu ke scratchi
    
    Otevři si centrální log (run_logs/basecall_history.txt) nebo standardní chybový výstup PBS (Dorado_Basecall.oXXXXXX).
    
    Najdi si název výpočetního uzlu (např. gpu12.cerit-sc.cz) a přesnou cestu do scratche (např. /scratch/login/job_123456.meta-pbs.metacentrum.cz).
    
    2. Připoj se na konkrétní uzel
    Z čelního uzlu MetaCentra se přihlas přímo na výpočetní uzel pomocí SSH:
    
        Bash
        ssh TVUJ_LOGIN@nazev_uzlu
    
    3. Zkontroluj a zkopíruj data
    Přejdi do adresáře scratche:
        
        Bash
        cd /cesta/do/scratche
    
    Zkontroluj obsah (např. pomocí ls -la) a překopíruj složku demultiplex_output na trvalé úložiště pod správným názvem runu:
    
        Bash
        cp -r demultiplex_output /storage/praha1/home/TVUJ_LOGIN/basecall_results/basecall_output_runX
   
    4. Ukliď po sobě (Kritické!)
    Po úspěšném zkopírování dat musíš dočasnou složku na výpočetním uzlu smazat, aby neblokovala místo ostatním uživatelům:
    
        Bash
        rm -rf /cesta/do/scratche
    
    5. Odhlas se z uzlu zpět na bezpečný čelní server:
        Bash
        exit
        
    Důležité upozornění: MetaCentrum má nastavené procesy tak, že po skončení nebo pádu úlohy většinou automaticky spouští čistící epilog skripty. Pokud se na uzel přes SSH už nedostaneš, nebo tam složka scratche není, data byla nenávratně smazána a celou úlohu je nutné spustit znovu.


### ALIGNMENT
Pokud vzorek při alignmentu spadne (např. vzorek č. 5 byl moc velký a 64 GB RAM mu nestačilo):

    Úloha se okamžitě ukončí a MetaCentrum ti pošle e-mail s upozorněním na selhání (protože máš nastaveno #PBS -m ae).
    Ostatní vzorky (0-4 a 6-23) poběží normálně dál a dokončí se.

Co musíš udělat ty: 

    Musíš ručně otevřít chybový log, zjistit, že došla paměť, otevřít PBS skript, přepsat #PBS -l mem=64gb na 128gb a ručně spustit jen tento jeden vzorek.
    (v PBS nemusíš pouštět znovu celé pole 0-23, ale můžeš poslat jen ten jeden chybějící vzorek pomocí qsub -J 5-5 alignment.sh.)
