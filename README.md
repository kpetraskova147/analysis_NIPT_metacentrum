# Analysis_NIPT_metacentrum
In this repository, you can find scripts for basecalling, alignment and wisecondorX analysis of nanopore data (PromethiON). This repository also includes scripts for statistic analysis. Everything is written in Python.

## Umístění souborů
- [Nahrávání dat](nahravani_dat.md) - rady, jak efektivně nahrát data na metacentrum
- [Basecalling + alignment na metacentru](basecall-alignment_folder)
        * tato složka obsahuje: 
                - alignment_minimap2.sh - starý skript, alignment se statistikou dohromady, nějaké problémy se vyskytovaly
                - demultiplex_dorado_basecall.sh - v případě, že nezaškrtnu demultiplexing při sekvenaci (lepší zaškrtnout, moc velký soubor, problémy)
                - **dorado_basecall_array.sh** - multiplexing během sekvenace - rychlé zpracování, top
                - **only_alignment_minimap2.sh** - alignment výsledků z dorada
                - **statistics_alignment.sh** - statistické údaje pro statistiku runu (jako z Epi2me)
- [wisecondorX](wisecondorX_folder)
        * tato složka obsahuje:
                - **wisecondorX_env.yml** - prostředí pro instalaci mamby (jako conda) pro analýzu
                - epi2me-data-samples_seznam_for_PBS.txt - vytvoření seznamu vzorků k analýze, můžu si psát poznámky
                - **newRef.sh** - vytvoření nové reference
                - samples_seznam_for_PBS.txt - vytvoření seznamu vzorků k analýze, můžu si psát poznámky
                - **skript_wisecondorX.sh** - skript pro convert a predict, vytvoření grafů
                - ***uvod_kontrola.py*** - kontrola před spuštěním analýzy, nepovinné
#### Skripty navíc:
- [Analýza dat s HAC kvalitou (bez dorada)](HAC-data-analysis) - upravený skript pro alignment (HAC-alignment.sh), statistiku (statistics_alignment-HAC.sh) a wisecondorX (wisecondorX-HAC.sh), všechno ostatní stejné (newRef.sh, wisecondorX_env.yml)
- [Analýza dat z Epi2me](Epi2me-data-analysis) - upravený skript pro wisecondorX analýzu (convert, predict), všechno ostatní stejné (newRef.sh, wisecondorX_env.yml)

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

Pokud chceš analyzovat data bez Dorada (HAC kvalita) a zároveň z Epi2Me, stačí mít ve (stejných) složkách i skripty pro HAC a Epi2me - cesty jsou upraveny.

##### INSTRUKCE
Na storage: 
- vytvoř složku RESULTS
- vstupní data s pod5 soubory ve složce: run1_pod5_pass, run2_pod5_pass ...
- vytvoř složku basecalling a v ní:
    - 1. skript: dorado_basecall_array.sh
    - 2. složka: dorado-2.0.0-linux-x64 (ke stažení zde: https://github.com/nanoporetech/dorado/tree/release-v2.0) a v ní:
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
- data: cesta k nim: RESULTS/basecalling_results/basecalling_output_run1/barcode01-xx/.fastq
        - pokud spouštím tuto analýzu na data, u kterých nebylo spuštěno dorado, mohu upravit cestu a nahrát je jinam
- vytvoř složku alignment a v ní:
  
   - 1. skript: only_alignment_minimap2.sh
   - 2. referenční genom: složka "reference_genome_Hg38" - soubor "hg38.mmi" (indexovaný genom)

         - genom musí být indexován, pokud chci, aby analýza probíhala rychleji
  
         - genom hg38.analysisSet.fa stažený z Ensemblu nebo UCSC indexuji v terminálu na metacentru příkazem: 

                                module add minimap2
                                minimap2 -x map-ont -d hg38.mmi hg38.analysisSet.fa

   - 3. skript: statistics_alignment.sh - pro vytvoření statistiky pro délku fragmentů, kvality atd.
   - 4. prostředí: env_statistics_alignment.yml

- Nastavení: Uprav PBS -J pro počet barcode (např. -J 1-24 pro 24 barcodů)
           : Uprav cesty k datům v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST), pokud jsou jiné
           : Uprav svůj mail v PBS -M → zaslání mailu po ukončení / selhání úlohy

##### Spuštění:
Terminál otevřít ve složce "alignment"
Příkaz (číslo runu se samozřejmě mění):

        qsub -v RUN_NUMBER="run1" only_alignment_minimap2.sh (HAC-alignment.sh)

Po doběhnutí analýzy alignment spustit statistiku:
Instalace prostředí (jen jednou):

        conda install --file env_stats_alignment.yml

        možnost B (skript):
        qsub instalace_stats_env.sh

Příkaz:

        qsub -v RUN_NUMBER="run1" statistics_alignment.sh (HAC-statistics_alignment.sh)


#### Kontrola kvality (MultiQC):
Po doběhnutí analýzy mohu spustit MultiQC pro přehled všech vzorků
- MultiQC se podívá do všech podsložek, najde tam mosdepth summary a nanostat a vytvoří přehledný report s grafy pro všechny vzorky v jednom souboru (multiqc_report.html)
Spuštění MultiQC:
        1. Přejdu do složky s výsledky (OUTPUT_DIR) - cd /storage/brno12-cerit/home/petraskkar/RESULTS/alignment/alignment_output_run1 
        2. Aktivace prostředí: 
                
                module load mambaforge
                eval "$(conda shell.bash hook)"
                conda activate /storage/brno12-cerit/home/petraskkar/conda_envs/env_stats_alignment

        4. Spustím: 
        
                multiqc .

### FÁZE 3: WisecondorX (NIPT Analýza)
Cíl: Detekce chromozomálních aberací a NIPT reporty.
Skript provádí dvě hlavní operace: konverzi BAM souboru do NPZ formátu a následnou analýzu (predict) pomocí WisecondorX. 
Tento skript je navržen pro spuštění jako PBS job array, kde každý vzorek je zpracováván samostatně. Výstupy jsou organizovány do struktury složek podle vzorků a runů.

###### POZN.: problém s wisecondorX - official github. Neustále tam něco mění a přesouvají to na python (teď zjistili, že tam cesta nevede). Věčně to nefunguje - proto je vytvořený nový soukromý github: https://github.com/kpetraskova147/WisecondorX-LAB-NIPT.git se všemi důležitými skripty pro wisecondorX a osobními úpravami grafů dle libosti.

##### INSTRUKCE
Na storage: 
    - vytvoř složku RESULTS (pokud ještě není vytvořena)
    - data: cesta k nim: RESULTS/alignment_results/alignment_output_run1/run1-barcodeXX/.bam a .bam.bai
        - pokud spouštím tuto analýzu na data, u kterých nebylo spuštěno dorado, můžeš upravit cestu a nahrát je jinam
    - vytvoř složku wisecondorX a v ní:
        - 1. skript: skript_wisecondorX.sh 
        - 2. prostředí: wisecondroX_env.yml - pro vytvoření prostředí s verzemi knihoven, které se nebudou měnit (dobrá kooperace, stálé prostředí)
                 !! je třeba instalovat před spuštěním analýzy příkazem: conda install --file environment.yml
        - 3. reference - složka references - složka references_${DATUM} se soubory "reference_${REF_SIZE}kb.npz"
                 referenci mohu vytvořit pomocí skriptu newRef.sh
        - 4. složka wisecondorx (ke stažení na: https://github.com/kpetraskova147/WisecondorX-LAB-NIPT.git) a v ní:
                ├── __init__.py
                ├── main.py                 # <--- Spouštěcí bod programu
                ├── convert_tools.py
                ├── predict_control.py
                ├── predict_tools.py
                ├── ... (všechny ostatní .py soubory ze složky src/wisecondorx z oficiálního repozitáře: https://github.com/CenterForMedicalGeneticsGhent/wisecondorX)
        - Terminál otevři ve složce wisecondorx, kde máš uložen tento skript (skript_wisecondorX.sh)

#### Před spuštěním:
     1. Ve složce wisecondorX musíš mít: skript_wisecondorX.sh, wisecondorX_env.yml, ... (viz výše)
     2. Uprav PBS -M a PBS -J podle počtu vzorků a svého emailu.
     3. Uprav ve 3. kapitole: BASE_DIR, INPUT_BAM_BAI_DIR, OUTPUT_DIR a REFERENCE podle své struktury dat.
     4. Uprav absolutní cestu k prostředí v části 4. PŘÍPRAVA PROSTŘEDÍ, pokud se ti nedaří aktivovat prostředí podle jména.
           absolutní cesta - conda info --envs 
           vyhledat wisecondorX_env a zkopírovat cestu, která je v 2.sloupci (např. /auto/brno2/home/petraskkar/.conda/envs/wisecondorX_env)
     5. Uprav ve 5. kapitole: SKLON a POSUN podle rovnice z Excelu (y = ax + b) z grafu poměru FF Y (Atila) vs Ratio (skript - FF_ratio_from_length.sh (z length.hist souborů)).

###### Fetal Fraction (FF) Estimation Protocol
This protocol describes the determination of fetal fraction from cell-free DNA (cfDNA) size profiles using fragment length distribution and empirical linear calibration.

1. Fragment Ratio Calculation

Circulating cell-free DNA in maternal plasma consists of shorter fetal fragments (peaking around 143 bp) and longer maternal fragments (peaking around 166 bp). The relative ratio of short-to-long fragments serves as a proxy for fetal cfDNA abundance.

Mathematical Formula

        $$Ratio = \frac{\sum \text{Fragments with length } \in [100\text{ bp}, 150\text{ bp}]}{\sum \text{Fragments with length } \in [160\text{ bp}, 200\text{ bp}]}$$

        Short fragments: Sum of sequenced reads with fragment lengths between 100 bp and 150 bp (enriched for fetal-derived cfDNA).
        Long fragments: Sum of sequenced reads with fragment lengths between 160 bp and 200 bp (predominantly maternal mono-nucleosomal cfDNA).

2. Linear Calibration Model

To convert the calculated sample-specific $Ratio$ into an absolute Fetal Fraction ($FF$), a standard linear regression model calibrated against reference samples (e.g., male pregnancies quantified via chromosome Y read counts) is applied - measured by PCR.

Na storage: 
     vytvoř složku RESULTS (pokud ještě není vytvořena)
     data: cesta k nim: RESULTS/statistics_results/statistics_output_runX/runX-barcodeXX
         : lengths_run1_barcode01.txt (případně .hist - z Epi2me → upravit .txt na .hist)
         : pokud spouštím tuto analýzu na data, u kterých nebylo spuštěno dorado, můžeš upravit cestu a nahrát je jinam
     vytvoř složku FF_calculation a v ní:
         1. skript: FF_ratio_from_length.sh

##### Spuštění:
Terminál otevřít ve složce "FF_calculation"
Příkaz:

        qsub -v RUN_NUMBER="run1" FF_ratio_from_length.sh

##### Analysis 
Transfer data to the excel with data from Atila PCR. Create dot graph and Trade Line. Gain the Linear Regression Formula.

<img width="968" height="621" alt="FF_calibration" src="https://github.com/user-attachments/assets/ffe51688-fc5e-4013-a759-481d2005f0aa" />


Linear Regression Formula

        y = a * x + b
        FF = (Slope * Ratio) + Intercept

        y = Fetal Fraction ($FF$): The estimated proportion of fetal cfDNA.
        x = Fragment Ratio ($Ratio$): The computed predictor variable from fragment sizing.
        a = Slope ($Slope$): The rate of change in fetal fraction per unit change in fragment ratio.
        b = Y-Intercept ($Intercept$): The baseline offset value where the regression line intersects the Y-axis.

The fetal fraction was measured by using PCR within XY samples to reliably determine the amount of fetal fraction.

#### Tvorba reference
Ve složce wisecondorX:
- složka "ALL_NPZ" s npz soubory pro vytvoření reference (do této složky se průběžně přidávají všechny npz soubory ze spuštěných runů - je nutná manuální selekce zdravých jedinců)
- Výstup: uloží se do složky "references", složky reference_$DATUM jako reference_${REF_SIZ}kb.npz (reference_1000kb.npz, reference_500kb.npz, reference_100kb.npz)

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
   - Uprav absolutní cestu k prostředí v části 
   
   - PŘÍPRAVA PROSTŘEDÍ, pokud se ti nedaří aktivovat prostředí podle jména.
         * absolutní cesta - conda info --envs 
         * vyhledat wisecondorX_env a zkopírovat cestu, která je v 2.sloupci (např. /auto/brno2/home/petraskkar/.conda/envs/wisecondorX_env)

##### Spuštění:
Terminál otevřít ve složce "wisecondorX
Příkaz (číslo runu se samozřejmě mění):
 
                * module load mambaforge
                * eval "$(conda shell.bash hook)"

                * mamba install --file wisecondorX_env.yml (pouze 1, instalace prostředí)

        qsub -v RUN_NUMBER="run1",DATUM=2026-03-26" skript_wisecondorX.sh (HAC-wisecondorX.sh, Epi2me-wisecondorX.sh)

                * DATUM = datum u reference: reference_2026-03-26.npz





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

## STATISTIKA




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
