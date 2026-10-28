# 🗑️ App Uninstaller & Ghost Hunter

Disinstallatore robusto per Windows con GUI Matrix e CLI, rilevamento di applicazioni "fantasma", backup del registro e punto di ripristino.

## ✨ Feature

- ✅ **Due versioni incluse**: GUI (Matrix) e CLI (terminale)
- ✅ **Lista applicazioni**: legge tutte le app installate dal registro
- ✅ **Ghost Hunter**: rileva app disinstallate male (file mancanti) e le segna in rosso
- ✅ **Deep Scan**: cerca le cartelle di installazione per evitare falsi positivi
- ✅ **Disinstallazione intelligente**: gestisce correttamente i path con spazi
- ✅ **Pulisci Fantasmi**: rimuove le voci di registro orfane con un click
- ✅ **Backup del Registro**: esporta HKLM\SOFTWARE, HKCU, HKCR
- ✅ **Punto di ripristino**: crea un checkpoint prima delle modifiche
- ✅ **Codifica colori**: Verde (OK), Rosso (Fantasma), Grigio (Sistema)
- ✅ **Log su file** (`Uninstaller_*.log`)

## 📋 Requisiti

- **Windows 10 / 11**
- **PowerShell 7+** (scarica da https://aka.ms/powershell)
- **Privilegi di amministratore** (necessari per disinstallare e creare punti di ripristino)

## 🚀 Quick start

```powershell
git clone https://github.com/fabrytoolbox/App-Uninstaller-Tool.git
cd App-Uninstaller-Tool
Unblock-File .\App-Uninstaller-GUI.ps1
Unblock-File .\App-Uninstaller-CLI.ps1

Poi scegli come avviarlo:

Doppio click su avvia.bat (ti chiede GUI o CLI)

Oppure lancia direttamente:

.\App-Uninstaller-GUI.ps1   # GUI Matrix
.\App-Uninstaller-CLI.ps1   # CLI testuale

🎯 Casi d'uso
Disinstallare app che non compaiono più nelle Impostazioni di Windows

Pulire il registro da voci orfane di app disinstallate male

Fare un backup del registro prima di operazioni rischiose

Creare un punto di ripristino prima di modifiche al sistema

🖥️ GUI Matrix
Interfaccia grafica in stile Matrix:

DataGrid con lista applicazioni e colori di stato

Pulsanti per Refresh, Punto Ripristino, Backup Registro, Deep Scan, Pulisci Fantasmi, Uninstall

Log integrato in fondo alla finestra

⌨️ CLI
Menu testuale interattivo:

1: Mostra lista applicazioni (con stato)

2: Disinstalla applicazione per indice

3: Pulisci fantasmi

4: Backup del Registro

5: Crea punto di ripristino

6: Apri log

0: Esci

⚠️ Attenzione
Non eliminare app di sistema (sono grigie e protette).

I fantasmi sono app che non esistono più sul disco ma hanno ancora la voce nel registro. Rimuoverli è sicuro.

Il backup del registro è fortemente consigliato prima di qualsiasi modifica.

La creazione del punto di ripristino richiede che la Protezione del Sistema sia attiva su C: (Pannello di Controllo → Sistema).

🐛 Problemi comuni
"Accesso negato"
Il tool richiede privilegi di amministratore. Accetta il prompt UAC.

"La disinstallazione fallisce"
Alcune app richiedono l'interazione dell'utente o hanno installer corrotti. Controlla il log per i dettagli.

"L'app è segnata come Fantasma ma esiste"
Usa il pulsante DEEP SCAN (o l'opzione 3 nella CLI) per cercare la cartella di installazione in tutto il disco.

"Impossibile creare il punto di ripristino"
La Protezione del Sistema è disabilitata. Abilitala da Pannello di Controllo → Sistema → Protezione del sistema.

📜 Licenza
MIT (vedi LICENSE).

🙏 Crediti
Fabry Toolbox
Tema Matrix
