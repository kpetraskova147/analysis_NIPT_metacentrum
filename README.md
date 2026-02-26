# Analysis_NIPT_metacentrum
In this repository, you can find scripts for basecalling, alignment and wisecondorX analysis of nanopore data (PromethiON). This repository include also scripts for statistic analysis. Everything is written in Python.

### Basecalling - dorado
You need to upload your data to metacentrum. Input data are in HAC quality (pod5 files) from nanopore sequencing.
##### Input data - how this script works:
Create a folder named "basecalling" and in it:

    1. Script: dorado_basecall.sh
    2. DATA: folder "pod5_pass" and folder with your data in it: run1_pass.pod5, run2_pass.pod5
    3. OUTPUT FOLDER: basecall_results
    4. FOLDER FOR LOGS FILES: run_logs
    5. FOLDER WITH dorado-1.0.0-linux-x64 - bin - dorado
                                          - models - dna_r10.4.1_e8.2_400bps_sup@v5.2.0/
                                                   - methylation - dna_r10.4.1_e8.2_400bps_sup@v5.2.0_5mC_5hmC/

Dorado-1.0.0-linux-x64 dispozici ke stažení na:
Nastavení: upravím cesty v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).
Ve skriptu je nastavení zaslání mailu při ukončení nebo selhání úlohy - nastav svou mailovou adresu v PBS hlavičce (řádek #PBS -M) 
pozn.: pokud chci sledovat metylaci, musím odstranit # před --modified-bases-models a použít model s metylací - (dna_r10.4.1_e8.2_400bps_sup@v5.0.0_5mC_5hmC@v1) v 1. NASTAVENÍ UŽIVATELE (UPRAV POUZE TUTO ČÁST).
Spuštění: 
        
        qsub dorado_basecall.sh


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
