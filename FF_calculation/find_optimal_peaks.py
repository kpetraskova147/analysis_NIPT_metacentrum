import sys
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import savgol_filter, find_peaks

def load_data(filepath):
    lengths, counts = [], []
    with open(filepath, 'r') as f:
        for line in f:
            parts = line.strip().split()
            # Přizpůsobení vašemu formátu: přeskočí hlavičku RL
            if not parts or parts[0] == 'RL':
                continue
            try:
                # Ošetření pro 2 nebo 3 sloupce (jak máte v awk)
                l = int(parts[0])
                c = int(parts[2]) if len(parts) >= 3 else int(parts[1])
                # Zajímá nás jen relevantní oblast pro cfDNA
                if 50 <= l <= 250:
                    lengths.append(l)
                    counts.append(c)
            except ValueError:
                continue
    return np.array(lengths), np.array(counts)

def analyze_peaks(filepath, sample_name):
    lengths, counts = load_data(filepath)
    
    if len(lengths) == 0:
        print("Chyba: Soubor neobsahuje validní data v rozmezí 50-250 bp.")
        return

    # 1. Vyhlazení dat (odstranění šumu) pomocí Savitzky-Golay filtru
    smoothed = savgol_filter(counts, window_length=11, polyorder=3)
    
    # 2. Výpočet derivací (změna směrnice křivky)
    dy = np.gradient(smoothed)      # První derivace (hledá extrémy)
    ddy = np.gradient(dy)           # Druhá derivace (hledá inflexní body / ramena)

    # 3. Detekce mateřského píku (nejvyšší bod v rozmezí 150-180 bp)
    mat_mask = (lengths >= 150) & (lengths <= 180)
    mat_peak_idx = np.argmax(smoothed[mat_mask])
    mat_peak_len = lengths[mat_mask][mat_peak_idx]

    # 4. Správná detekce fetálního sub-píku / ramena (cílíme přesně do oblasti ~143 bp)
    # Hledáme lokální maximum v rozmezí 135-150 bp, kde se reálně nachází cffDNA
    fet_mask = (lengths >= 130) & (lengths <= 150)
    if np.any(fet_mask):
        fet_peak_idx = np.argmax(smoothed[fet_mask]) # nebo můžeme vázat na derivaci v tomto okně
        fet_peak_len = lengths[fet_mask][fet_peak_idx]
    else:
        fet_peak_len = 143

    # Návrh matematicky optimálních oken (± 5 až 6 bp od středu píku)
    fetal_window = (fet_peak_len - 6, fet_peak_len + 5)
    mat_window = (mat_peak_len - 6, mat_peak_len + 6)

    print(f"--- Výsledky pro {sample_name} ---")
    print(f"Střed fetálního ramena detekován na: {fet_peak_len} bp")
    print(f"Střed mateřského píku detekován na: {mat_peak_len} bp")
    print(f"-> Navrhované fetální okno: {fetal_window[0]}-{fetal_window[1]} bp")
    print(f"-> Navrhované mateřské okno: {mat_window[0]}-{mat_window[1]} bp")

    # Vykreslení pro vizuální kontrolu
    plt.figure(figsize=(10, 6))
    plt.plot(lengths, counts, color='lightgray', label='Surová data', alpha=0.6)
    plt.plot(lengths, smoothed, color='teal', label='Vyhlazená data', linewidth=2)
    
    # Zvýraznění nalezených oken
    plt.axvspan(fetal_window[0], fetal_window[1], color='orange', alpha=0.3, label='Optimální fetální okno')
    plt.axvspan(mat_window[0], mat_window[1], color='blue', alpha=0.2, label='Optimální mateřské okno')
    
    plt.axvline(fet_peak_len, color='darkorange', linestyle='--', label=f'Fet. střed: {fet_peak_len} bp')
    plt.axvline(mat_peak_len, color='darkblue', linestyle='--', label=f'Mat. střed: {mat_peak_len} bp')

    # Přidání číselných popisků hranic oken přímo do grafu
    y_max = np.max(smoothed)
    plt.text(fet_peak_len, y_max * 0.4, f"  Okno:\n  {fetal_window[0]}–{fetal_window[1]} bp", 
             color='darkorange', fontsize=9, fontweight='bold', va='center')
    plt.text(mat_peak_len, y_max * 0.6, f"  Okno:\n  {mat_window[0]}–{mat_window[1]} bp", 
             color='darkblue', fontsize=9, fontweight='bold', va='center')

    plt.xlim(100, 200)
    plt.title(f"Detekce optimálních oken pro výpočet frakce - {sample_name}")
    plt.xlabel("Délka fragmentu (bp)")
    plt.ylabel("Počet readů")
    plt.legend(loc='upper right')
    plt.grid(True, linestyle=':', alpha=0.7)
    plt.savefig(f"optimal_windows_{sample_name}.png", dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Graf byl uložen jako optimal_windows_{sample_name}.png\n")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Použití: python find_optimal_peaks.py <cesta_k_souboru.txt>")
    else:
        file_path = sys.argv[1]
        name = file_path.split('/')[-1].replace('.hist', '').replace('.txt', '')
        analyze_peaks(file_path, name)