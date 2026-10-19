import pandas as pd
import numpy as np
import scipy.stats as stats

# 1. Načtení dat (upravte název souboru podle sebe, např. vaše CSV tabulka)
# Očekáváme sloupce: 'Sample', 'Method' (hodnoty 'Manual' a 'Automat'), 'Ratio'
df = pd.read_csv("fragment_ratios_all.csv")

# 2. Převedení do wide formátu, abychom měli páry vedle sebe pro každého pacienta
df_wide = df.pivot(index='Sample', columns='Method', values='Ratio').reset_index()

# Kontrola, zda máme sloupce Manual a Automat
if 'Manual' not in df_wide.columns or 'Automat' not in df_wide.columns:
    print("Chyba: Tabulka musí obsahovat sloupce 'Manual' a 'Automat' v metodě.")
else:
    # Výpočet diferencí (rozdílů) pro každého pacienta
    diff = df_wide['Manual'] - df_wide['Automat']

    # 3. Shapiro-Wilkův test normality diferencí
    shapiro_stat, p_value_norm = stats.shapiro(diff)
    
    print("==========================================")
    print("VÝSLEDEK SHAPIRO-WILKOVA TESTU NORMALITY:")
    print("==========================================")
    print(f"Testová statistika (W): {shapiro_stat:.4f}")
    print(f"P-hodnota (p-value):     {p_value_norm:.4e}")
    print("------------------------------------------")

    # 4. Doporučení testu
    if p_value_norm < 0.05:
        print("ZÁVĚR: Rozdíly NEMAJÍ normální rozdělení (p < 0.05).")
        print("-> Pro diplomovou práci MUSÍTE použít PÁROVÝ WILCOXONŮV TEST.")
        
        # Pro jistotu spočítáme i samotný Wilcoxon
        stat, p_val = stats.wilcoxon(df_wide['Manual'], df_wide['Automat'])
        print(f"Výsledek Wilcoxonova testu: p = {p_val:.4e}")
    else:
        print("ZÁVĚR: Rozdíly SPLŇUJí normální rozdělení (p >= 0.05).")
        print("-> Pro diplomovou práci MŮŽETE použít PÁROVÝ T-TEST.")
        
        # Pro jistotu spočítáme i párový t-test
        stat, p_val = stats.ttest_rel(df_wide['Manual'], df_wide['Automat'])
        print(f"Výsledek párového t-testu: p = {p_val:.4e}")
    print("==========================================")