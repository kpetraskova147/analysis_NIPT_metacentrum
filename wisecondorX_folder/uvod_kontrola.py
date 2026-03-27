# ======================================================================================
# B. Script pro kontrolu před spuštěním analýzy WisecondorX

# INSTRUKCE:
# ======================================================================================
        # Kontroluje existenci souboru samples_seznam_wisecondorx.txt, ověřuje přítomnost BAM a BAI souborů,
        #   a vytváří log (záznam) s přehledem zanalyzovaných vzorků a případných errorů 
        #   pro mou informovanost o analýze v případě potřeby, potíží atd.

        # Tento skript není nutný pro samotnou analýzu, ale je užitečný pro kontrolu dat před spuštěním, 
        #   aby WisecondorX nespadl a také pro dokumentaci.

        # Před spuštěním analýzy se ujisti, že máš máš ve složce wisecondorX:
        #       environment.yml, skript_wisecondorX.sh a uvod_kontrola.py (tento soubor)
        # V případě potřeby uprav v tomto souboru (uvod_kontrola.py) cestu ke svým datům.
        # 
        # Skript spouštím příkazem : python3 uvod_kontrola.py před samotnou analýzou

# ======================================================================================
# PYTHON SKRIPT:
# ======================================================================================

import os
from datetime import datetime

def spustit_kontrolu():
    print("=== KONTROLA PŘED SPUŠTĚNÍM WISECONDORX ===")
    
    seznam_soubor = "samples_seznam_wisecondorx.txt"

# =====================================================================================================    
# 1. Kontrola existence seznamu vzorků, důležitých pro PBS funkce ve wisecondorx skriptu
# =======================================================================================================    

base_dir = "/storage/brno12-cerit/home/petraskkar"
input_dir = f"{base_dir}/RESULTS/alignment_results"

if not os.path.exists(seznam_soubor):
    print(f"CHYBA: Soubor '{seznam_soubor}' neexistuje!")
    print("Nejdříve v terminálu vygeneruj seznam příkazem 'find ... > samples_seznam_wisecondorx.txt'")
    return

vzorky = []
chybejici_bai = []
runy = {}

# =====================================================================================================    
# 2. Čtení a kontrola souborů ze samples_seznam_wisecondorx.txt
# =====================================================================================================    
   
with open(seznam_soubor, "r", encoding="utf-8") as f:       # with = automatické zavření souboru po přečtení, r = read, utf-8 umožní číst češtinu (háčky a čárky)
    for line in f:                                          # Smyčka: projde opakovaně každý řádek v souboru
        line = line.strip()                                 # Odstraní přebytečné mezery a enter na začátku a konci řádku - lepší čitelnost kódu pro Python 
        if not line or line.startswith("#"): continue       # Přeskočí (continue) prázdné řádky (not line) a komentáře (začínající #)
            
        parts = line.split()                                # Rozseká řádek na jednotlivé části podle mezer, př.: "ID Cesta Run Poznámka" -> ["ID", "Cesta", "Run", "Poznámka"]
        if len(parts) < 3:                                  # Kontrola minimálního počtu sloupců (částí)
            continue
        (s_id, s_path, r_num) = (parts[0], parts[1], parts[2])          # Formát: ID(0) Cesta(1) Run(2) - skript ignoruje mé poznámky, soustředí se na první 3 sloupce (data)
        poznamka = " ".join(parts[3:]) if len(parts) > 3 else ""        # Najde případnou poznámku (3. část a dál) a nahradí ji prázdným řetězcem 
                                                                            # " ".join(parts[3:]) = spojí všechny části od 4. sloupce dál (poznámka) do jednoho řetězce - jsou rozděleny kvůli line.split()
        # Spojení složky a cesty k souboru, aby vznikla úplná cesta k BAM souboru, kterou pak skript zkontroluje
        plna_cesta = os.path.join(input_dir, s_path)                                                                # if len(parts) > 3 else "" = nahradí poznámku prázdným řetězcem

        # Kontrola fyzické existence BAM a BAI
        if not os.path.exists(plna_cesta):                                  # plna_cesta = podívá se na cestu k souboru a následně zjistí, zda soubory existují fyzicky
            chybejici_bai.append(f"Chybí BAM: {plna_cesta}")
        if not os.path.exists(plna_cesta + ".bai"):
            chybejici_bai.append(f"Chybí BAI: {plna_cesta}.bai")
           
        # Popis sloupců + kontrola kolikrát běžel run
        vzorky.append({                 # .append = přidá mi na konec tyto věci:
            "id": s_id,
            "path": s_path,
            "run": r_num,
            "note": poznamka
        })
        runy[r_num] = runy.get(r_num, 0) + 1        # příkaz pro kontrolu kolikrát run už běžel

# =====================================================================================================    
# 3. Vyhodnocení chyb
# =====================================================================================================    
if chybejici_bai:
    print("\nNALEZENY CHYBY V DATECH:")
    for c in chybejici_bai[:10]: # Vypíše jen prvních 10 chyb, ať tě to nezahltí
        print(f"  - {c}")
    if len(chybejici_bai) > 10:
        print(f"  ... a {len(chybejici_bai)-10} dalších chyb.")
    print("\nAnalýza nemůže být spuštěna. Oprav cesty nebo doplň indexy.")
    exit()

# =====================================================================================================    
# 4. Potvrzení a zápis logu
# =====================================================================================================    
pocet = len(vzorky)
print(f"\nVše v pořádku! Nalezeno {pocet} vzorků.")
for r, count in sorted(runy.items()):
    print(f"Run {r}: {count} vzorků")

potvrzeni = input(f"\nJe počet {pocet} správný? Chceš vytvořit log? (ano/ne): ")
    
if potvrzeni.lower() == 'ano':
    cas_log = datetime.now().strftime("%Y-%m-%d_%H-%M")
    log_name = f"vstup_wisecondorx{cas_log}.log"
       
    with open(log_name, "w", encoding="utf-8") as log:
        log.write(f"=== ZÁZNAM O KONTROLE ANALÝZY ===\n")
        log.write(f"Čas: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        log.write(f"Celkový počet vzorků: {pocet}\n")
        log.write("-" * 65 + "\n")
        log.write(f"{'Index':<6} | {'ID vzorku':<25} | {'Run':<5} | {'Poznámka'}\n")
        log.write("-" * 65 + "\n")
            
        for i, v in enumerate(vzorky, 1):
            log.write(f"{i:03d}   | {v['id']:<25} | {v['run']:<5} | {v['note']}\n")
        # {i:03d} = index je na 3 místa tedy do 999 (pokud bych měla víc analýz, musím zvýšit číslo)

        log.write("=" * 65 + "\n")

    print(f"\nLog vytvořen: {log_name}")
    print(f"DALŠÍ KROK:")
    print(f"1. Otevři 'wisecondorX.sh' a nastav: #PBS -J 1-{pocet}")
    print(f"2. Pak v terminálu napiš: qsub wisecondorX.sh")
else:
    print("Analýza přerušena uživatelem.")

if __name__ == "__main__":
    spustit_kontrolu()