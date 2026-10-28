# Changelog

## [2.3.0] - 2025-01-28

### Added
- GUI Matrix con DataGrid per la lista delle app
- **Ghost Hunter**: rilevamento di app "fantasma" (file mancanti)
- **Deep Scan**: ricerca euristica delle cartelle di installazione
- **Codifica colori**: Verde (OK), Rosso (Fantasma), Grigio (Sistema)
- Pulsante "Pulisci Fantasmi" per rimuovere voci di registro orfane
- Backup del registro (HKLM\SOFTWARE, HKCU, HKCR)
- Creazione punto di ripristino
- Log su file (Uninstaller_*.log)
- **CLI interattiva** (App-Uninstaller-CLI.ps1) con menu testuale
- Launcher avvia.bat con scelta GUI/CLI

### Fixed
- **Bug critico**: disinstallazione di app con spazi nel path (es. `C:\Program Files\...`)
- **Bug critico**: errore Execution Policy durante l'avvio di UninstallString
- **Bug logico**: falsi positivi nel rilevamento fantasmi (aggiunto controllo cartella padre)
- **Bug logico**: funzioni mancanti (Create-RestorePoint, Write-Step)
