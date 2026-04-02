# Analysis_NIPT_metacentrum
In this repository, you can find scripts for basecalling, alignment and wisecondorX analysis of nanopore data (PromethiON). This repository also includes scripts for statistic analysis. Everything is written in Python.

## INSTRUCTIONS

IMPORTANT: PBS -J settings. 

        Dorado, Minimap2 and WisecondorX is counting files and folders from 1
                - PBS -J 1-24 for 24 samples

ERROR:
        Pokud terminál napíše "qsub: script contains cr, lf" po zadání příkazu qsub ... (spuštění analýzy), zadám:

                dos2unix skript_name

        - musím přepsat kód z windowsu do linuxového prostředí (jiné konce řádků)

## NANOPORE NIPT PIPELINE – ULTIMÁTNÍ CHEAT SHEET
### FÁZE 1: Dorado (Basecalling)
Cíl: Převod surových signálů .pod5 na čtení .fastq.

Složky barcode01-xx s jednotlivými pod5 soubory (demultiplexing od nanoporu během sekvenace)
!!DEMULTIPLEXING JE TŘEBA PROVÉST UŽ BĚHEM SEKVENACE, JINAK ANALÝZA TRVÁ VELMI DLOUHO!!

Pokud chceš analyzovat data bez Dorada nebo z Epi2Me, nejideálnější je za mě mít data na různých storage na metacentru pro jednotlivé analýzy a ve skriptu upravit cestu, ať je v tom pořádek

##### INSTRUKCE
Na storage: 
- vytvoř složku RESULTS
- vstupní data s pod5 soubory ve složce: run1_pod5_pass, run2_pod5_pass ...
- vytvoř složku basecalling a v ní:
    - 1. skript: dorado_basecall_array.sh
    - 2. složka: dorado-1.0.0-linux-x64 a v ní:
                - (software) složka "bin" - soubor "dorado"
                - (modely) složka "models" - soubor "dna_r10.4.1_e8.2_400bps_sup@v5.2.0/"    - lidský genom
                                          (- soubor "- dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mC_5hmC/"   - methylace)
                                          pozn.: pokud chci sledovat metylaci, musím odstranit # před --modified-bases-models a použít model s metylací (dna_r10.4.1_e8.2_400bps_sup@v5.0.0_5mC_5hmC@v1) v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).
- Nastavení: Uprav PBS -J pro počet barcode (např. -J 1-24 pro 24 barcodů)
           : Uprav cesty k datům v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST), pokud jsou jiné
           : Uprav svůj mail v PBS -M → zaslání mailu po ukončení / selhání úlohy


        # Spuštění: qsub -v RUN_NUMBER="run1" dorado_basecall_array.sh

##### Spuštění:
Terminál otevřít ve složce "basecalling"
Příkaz (číslo runu se samozřejmě mění):

        qsub -v RUN_NUMBER="run1" dorado_basecall.sh

### FÁZE 2: Minimap2 (Alignment) + statistics + MultiQC
Cíl: Zarovnání .fastq na referenci a tvorba .bam / .bai souborů.
Potřebuji spustit dva skripty pro alignment (only_alignment_minimap2.sh) a statistiku (statistics_alignment.sh). Na metacentru dělají aktualizaci a bohužel zatím nejde spustit pouze jeden skript "alignment_minimap2.sh", což doufám, že v budoucnu možné bude - je tam problém s tím, že ještě nepřesunuli úplně vše do nové verze.

##### INSTRUKCE
Na storage: 
- vytvoř složku RESULTS (pokud ještě není vytvořena)
- data: cesta k nim: RESULTS/basecalling_results/basecalling_output_run1/barcode01-xx/.pod5
        - pokud spouštím tuto analýzu na data, u kterých nebylo spuštěno dorado, mohu upravit cestu a nahrát je jinam
- vytvoř složku alignment a v ní:
  
   - 1. skript: only_alignment_minimap2.sh
   - 2. referenční genom: složka "reference_genome_Hg38" - soubor "hg38.mmi" (indexovaný genom)

         - genom musí být indexován, pokud chci, aby analýza probíhala rychleji
  
         - genom hg38.analysisSet.fa stažený z Ensemblu nebo UCSC indexuji v terminálu na metacentru příkazem: 

                                module add minimap2
                                minimap2 -x map-ont -d hg38.mmi hg38.analysisSet.fa

   - 3. skript: statistics_alignment.sh - pro vytvoření statistiky pro délku fragmentů, kvality atd.

- Nastavení: Uprav PBS -J pro počet barcode (např. -J 1-24 pro 24 barcodů)
           : Uprav cesty k datům v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST), pokud jsou jiné
           : Uprav svůj mail v PBS -M → zaslání mailu po ukončení / selhání úlohy

##### Spuštění:
Terminál otevřít ve složce "alignment"
Příkaz (číslo runu se samozřejmě mění):

        qsub -v RUN_NUMBER="run1" only_alignment_minimap2.sh

Po doběhnutí analýzy alignment spustit statistiku:
Příkaz:

        qsub -v RUN_NUMBER="run1" statistics_alignment.sh


#### Kontrola kvality (MultiQC):
Po doběhnutí analýzy mohu spustit MultiQC pro přehled všech vzorků
- MultiQC se podívá do všech podsložek, najde tam mosdepth summary a nanostat a vytvoří přehledný report s grafy pro všechny vzorky v jednom souboru (multiqc_report.html)
Spuštění MultiQC:
        1. Přejdu do složky s výsledky (OUTPUT_DIR) - cd /storage/brno12-cerit/home/petraskkar/RESULTS/alignment/alignment_output_run1 
        2. Načtu program: module add multiqc
        3. Spustím: multiqc .

### FÁZE 3: WisecondorX (NIPT Analýza)
Cíl: Detekce chromozomálních aberací a NIPT reporty.
Skript provádí dvě hlavní operace: konverzi BAM souboru do NPZ formátu a následnou analýzu (predict) pomocí WisecondorX. 
Tento skript je navržen pro spuštění jako PBS job array, kde každý vzorek je zpracováván samostatně. Výstupy jsou organizovány do struktury složek podle vzorků a runů.

##### INSTRUKCE
Na storage: 
- vytvoř složku RESULTS (pokud ještě není vytvořena)
- data: cesta k nim: RESULTS/basecalling_results/basecalling_output_run1/barcode01-xx/.pod5
        - pokud spouštím tuto analýzu na data, u kterých nebylo spuštěno dorado, můžeš upravit cestu a nahrát je jinam
- vytvoř složku wisecondorX a v ní:
  - 1. skript: skript_wisecondorX.sh 
  - 2. prostředí: environment.yml - pro vytvoření prostředí s verzemi knihoven, které se nebudou měnit (dobrá kooperace, stálé prostředí)

       - !! je třeba instalovat před spuštěním analýzy příkazem: 

                module add mambaforge

                mamba env create -f environment.yml
                
  - 3. reference - soubor "reference.npz"
  
       - referenci mohu vytvořit pomocí skriptu newRef.sh
  - 4. VOLITELNÉ: skript: uvod_kontrola.py - spíše pro mou kontrolu jestli mám vše připravené, nemusím spouštět

#### Tvorba reference
Ve složce wisecondorX:
- složka "ALL_NPZ" s npz soubory pro vytvoření reference (do této složky se průběžně přidávají všechny npz soubory ze spuštěných runů - je nutná manuální selekce zdravých jedinců)
- Výstup: uloží se do složky "references" jako reference_1000kb_[DATUM].npz
- pro použití je potřeba ji přesunout do wisecondorX složky a přejmenovat na reference.npz (+ si napsat někam poznámku o původním názvu)
- můžu vytvořit pouze jednu referenci a používat ji dokola, nebo můžu reference aktualizovat

##### Spuštění:
Terminál otevřít ve složce "wisecondorX"
Příkaz:

        qsub newRef.sh

#### WisecondorX analýza
- Nastavení
   - Uprav PBS -J pro počet barcode (např. -J 1-24 pro 24 barcodů)
   - Uprav cesty k datům v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST), pokud jsou jiné
   - Uprav svůj mail v PBS -M → zaslání mailu po ukončení / selhání úlohy

##### Spuštění:
Terminál otevřít ve složce "alignment"
Příkaz (číslo runu se samozřejmě mění):
 
        conda install --file environment.yml (pouze 1, instalace prostředí)

        (1. python3 uvod_kontrola.py - VOLITELNÉ, kontrola vstupních dat a jestli mám vše zadané, ale kontrola i v skript_wisecondorX.sh)

        qsub -v RUN_NUMBER="run1" skript_wisecondroX.sh




### VOLITELNÉ:
#### Krok 3.2: Kontrola a vytvoření logu - uvod_kontrola.sh
Tento skript slouží ke kontrole, zda mám vše nastavené správně. Není ale potřeba, je to spíš volitelné. Kontroly jsou i ve skript_wisecondorX.sh - je to spíš pro informaci, že jsem na nic nezapomněla

Spuštění:
Terminál otevřít ve složce "wisecondroX"
Příkaz:

        python3 uvod_kontrola.py


#### Krok 3.1: Vygenerování seznamu vzorků
Není důležité, vhodné pouze pokud bych chtěl nadpis grafu se jménem pacienta ale bylo by to zbytečně komplikované

##### Co spouštím:

A) alignment proveden na metacentru:
        find "$PWD"/alignment_output_*/ -name "barcode*.bam" | awk -F/ '{
            run_dir=$(NF-1); 
            run_num=run_dir; gsub("alignment_output_", "", run_num); 
            bam_file=$NF; 
            barcode=bam_file; gsub(".bam", "", barcode); 
            print barcode"-run-"run_num " " $0 " " run_num
        }' > /storage/praha1/home/TVUJ_LOGIN/wisecondorX/samples_seznam_wisecondorx.txt

B) Alignment z epi2me:
        find "$PWD" -type f -name "*.bam" | awk -F/ '{
        bam_path = $0;
        barcode = $(NF-1); 
        run_num = "epi2me_run1"; 
        print barcode " " bam_path " " run_num
        }' > /storage/praha1/home/TVUJ_LOGIN/wisecondorX/samples_seznam_wisecondorx.txt





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
