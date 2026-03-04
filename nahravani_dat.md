NAHRÁNÍ OBJEMNÝCH SOUBORŮ (MOJE DATA) NA METACENTRUM
RCLONE – INSTALACE, NASTAVENÍ – windows systém – pouze jednou
https://rclone.org/downloads/ - Intel/AMD - 64 Bit pro běžný počítač
1. Spuštění
1.	Otevřete složku, kde máte rozbalený stažený soubor rclone.exe.
2.	Do adresního řádku (cesta k souboru) napište cmd a stiskněte Enter. Otevře se terminál.
2. Základní nastavení (Konfigurace)
V terminálu napište: rclone config a postupujte podle těchto kroků:
•	n) New remote
•	name: meta
•	type: sftp
•	host: storage-brno12-cerit.metacentrum.cz (brno12-cerit kdyžtak změnit – musí odpovídat aktuálnímu úložišti na metacentru)
•	user: TVUJ-LOGIN
•	port: (Enter – nechat prázdné)
•	y) Yes type in my own password: Napište y, vyťukejte heslo (nebude vidět!) a potvrďte Enterem.
o	Heslo musí být stejné jako mám na metacentru, ne ale v CASU – mohu to změnit/resetovat:
	https://metavo.metacentrum.cz/cs/myaccount/heslo.html
	Klikni na ten odkaz (nebo tlačítko) Profil -> Autentizace - Změna hesla, o kterém se tam píše.
	Resetovat heslo
	Počkej 10-15 minut – než si to poví všechny servery
•	U všeho ostatního mačkejte Enter, dokud se nevrátíte na začátek, pak dejte q (Quit).

ZIPOVÁNÍ (7zip)
❌ Nezipujte (Ztráta času), pokud:
•	Máte pár velkých souborů (videa (.mp4), velké databáze, obrazy disků).
•	Vaše soubory už jsou komprimované 
o	.fastq.gz, .bam, .tar.gz, .zip, .jpg, .mp4, .pdf, .docx 
o	Dalším zipováním je už nezmenšíte, jen zahřejete procesor notebooku. Pokud je dáte do ZIPu s kompresí, ztratíte hodinu času a výsledný soubor bude menší třeba jen o 1 %.
•	Máte rozumný počet souborů (stovky až jednotky tisíc). Rclone to zvládne rychle.
✅ Zazipujte (S kompresí), pokud:
•	Zipování s kompresí (tedy snaha o co největší zmenšení souborů) dává smysl pouze v situacích, kdy je vaším hlavním nepřítelem nedostatek místa nebo velmi pomalý internet, a zároveň máte k dispozici výkonný počítač.
✅ Zazipujte (Bez komprese!), pokud:
•	Tisíce malých textových souborů, logů, konfigurační soubory, zdrojové kódy.
•	Režim „Store“ („Bez komprese“) je v podstatě technika, kdy soubory pouze „zabalíte do jednoho pytle“, aniž byste se je snažila zmenšit.
o	Proč: Windows i síťové protokoly se "zadrhávají" na neustálém otevírání a zavírání každého malého souboru zvlášť. Jeden velký balík poletí po síti mnohem rychleji.
Shrnutí pro váš případ
Zkuste nejdříve poslat data tak, jak jsou (nezazipovaná). Rclone vám díky parametru -P ukáže rychlost. Pokud uvidíte, že rychlost v MB/s je stabilní a odpovídá vašemu připojení, zipování vůbec neřešte. Pokud by se rychlost "plazila" v jednotkách kB/s (což se děje právě u těch tisíců drobků), pak je čas na ten rychlý ZIP bez komprese.
✅ Zipování bez komprese! – proč je to můj nej kámoš při práci s MetaCentrem:
Jak to funguje technicky?
Při běžném zipování musí procesor vašeho notebooku u každého souboru hledat opakující se vzorce a složitě je přepočítávat, aby ušetřil místo. V režimu Store procesor tyto výpočty úplně přeskočí. Pouze vezme data a naskládá je za sebe do jednoho .zip (nebo .tar) souboru.
Proč je to rychlejší?
•	Šetří váš notebook: Protože procesor nic nepřepočítává, notebook se nezahřívá, netočí větráky naplno a „balení“ proběhne tak rychle, jak jen dovolí rychlost vašeho disku.
•	Okamžitý přenos: Rclone pak posílá jeden velký soubor. Síťové spojení u SFTP je mnohem stabilnější, když teče jeden proud dat, než když se musí tisíckrát za sekundu ptát: „Můžu poslat tenhle malý soubor? A co tenhle?“
Programy
•	7-Zip: V kolonce „Úroveň komprese“ (Compression level) vyberte „Ukládání“ (Store).
•	WinRAR: V kolonce „Metoda komprese“ vyberte „Bez komprese“ (Store).
•	Linux/MetaCentrum terminál: Pokud budete balit data na serveru, používá se příkaz tar -cvf archiv.tar slozka/. To „f“ znamená, že se to jen poskládá do souboru bez komprese (pro kompresi by tam bylo „z“).

UNZIP (metacentrum – Linux terminál)
•	Na tento krok nesmím zapomenout! Zazipované soubory by nebylo možné zpracovat
•	Pro .zip soubory: unzip jmeno_souboru.zip
•	Tip: Pokud chceš rozbalovat do konkrétní složky: unzip jmeno_souboru.zip -d cilova_slozka

NAHRÁNÍ DAT NA METACENTRUM – PŘÍKAZY 
Spuštění terminálu
1.	Otevřete složku, kde máte rozbalený stažený soubor rclone.exe.
2.	Do adresního řádku (cesta k souboru) napište cmd a stiskněte Enter. Otevře se terminál.
V terminálu:
rclone copy "C:\Cesta\K\Vasi\Slozce" meta:nazev-slozky -P
•	"C:\...": Cesta ve Vašem notebooku. 
o	Pokud ji nechcete vypisovat, můžete soubor/složku do okna terminálu jednoduše přetáhnout myší a cesta se tam napíše sama.
•	meta: Složka, kam má rclone uložit data na metacentru
•	-P: Ukáže Vám v reálném čase, jak rychle data tečou a kdy to bude hotové.
Pozn.: Rclone umí nahrát data i z externího disku připojeného k počítači (HDD, SSD, USB flashka, …). Musím pouze pozměnit cestu k datům: 
•	rclone copy "D:\MojeData\Slozka" meta:slozka -P
Rychlost externího disku: * Pokud máte starší pomalý disk (HDD) připojený přes USB, může rclone chvíli trvat, než si soubory "očuchá" (porovná velikosti), než začne samotné nahrávání. To je normální.
Přerušení nahrávání – ERROR 
Pokud přenos spadne, šipkou nahoru vyvolejte v terminálu poslední příkaz a pusťte ho znovu.
Rclone během chvilky pozná, co už na MetaCentru je, a plynule naváže tam, kde skončil.
Nahrávání více složek
Přímo jedním příkazem dvě různé složky rclone nahrát neumí (vždy bere jeden zdroj a jeden cíl), ale můžete to vyřešit velmi elegantně dvěma způsoby:
1. Postupné nahrávání (Doporučeno)
Příkazy pro jednotlivé složky oddělím středníkem. Windows je spustí hned po sobě.
•	rclone copy "D:\cesta-ke-Slozka1" meta:folder -P ; rclone copy "D:\cesta-ke-Slozka2" meta:folder -P
2. Nahrání "Nadřazené" složky
•	Máte-li na disku D: složku Data a v ní složky Data1 a Data2, zadejte jako zdroj pouze D:\Data
•	Rclone prohledá celý disk a nahraje obě složky (i všechno ostatní, co tam je)
3. Dvě okna najednou (Paralelně)
Protože rclone skoro nezatěžuje procesor, můžete udělat toto:
1.	Otevřete si dva terminály (CMD).
2.	V každém spusťte nahrávání jiné složky.
3.	Budou se nahrávat současně. Tohle je super, pokud máte rychlý internet, protože tím maximálně využijete šířku pásma.
MetaCentrum – přehled  
1. Přenos souborů (Rclone)
•	Nahrání dat: rclone copy "C:\Data-v-ntb" meta:/storage/brno12-cerit/home/petraskkar/ -P
•	Stažení do ntb: rclone copy meta:/storage/brno12-cerit/home/petraskkar/vysledky "C:\Vysledky" -P
•	Externí disk: rclone copy "D:\Data-na-disku" meta:/storage/brno12-cerit/home/petraskkar/ -P 
•	Výpadky: Pokud spadne Wi-Fi, příkaz pusť znovu – rclone plynule naváže.
•	Zipovat?: Jen u >10 000 malých souborů (použij režim "Store/Ukládat").
3. Práce na serveru (SSH)
•	Unzip!! Unzip data.zip
