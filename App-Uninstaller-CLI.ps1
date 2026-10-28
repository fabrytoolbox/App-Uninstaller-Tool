# App-Uninstaller-CLI.ps1 - v1.0
# Disinstallatore CLI con Ghost Hunter, Deep Scan, Backup e Punto di Ripristino
# Richiede privilegi di amministratore

function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor $Color
    Write-Host "  $Message" -ForegroundColor $Color
    Write-Host ("=" * 60) -ForegroundColor $Color
}

# ============================================
# ADMIN CHECK
# ============================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Richiesta privilegi di amministratore..." -ForegroundColor Yellow
    $pwshPath = Join-Path $PSHOME "pwsh.exe"
    if (-not (Test-Path $pwshPath)) { $pwshPath = "pwsh.exe" }
    Start-Process $pwshPath -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$script:workDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:logFile = $null
$script:foundApps = @()

# ============================================
# LOGGING
# ============================================
function Start-Log {
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:logFile = Join-Path $script:workDir "Uninstaller_CLI_$ts.log"
    "--- APP UNINSTALLER CLI LOG ---" | Set-Content -Path $script:logFile -Encoding UTF8
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    switch ($Level) {
        "OK" { Write-Host "  [OK] $Message" -ForegroundColor Green }
        "ERROR" { Write-Host "  [X] $Message" -ForegroundColor Red }
        "WARNING" { Write-Host "  [!] $Message" -ForegroundColor Magenta }
        default { Write-Host "  [i] $Message" -ForegroundColor Cyan }
    }
    if ($script:logFile) {
        Add-Content -Path $script:logFile -Value $line -Encoding UTF8
    }
}

# ============================================
# FUNZIONI DI ANALISI (identiche alla GUI)
# ============================================
function Test-AppStatus ($app) {
    if ($app.SystemComponent -eq 1) { return "Sistema" }
    
    $uninstString = $app.UninstallString
    if ($uninstString -and $uninstString -match "msiexec") { return "OK" }
    
    $installLoc = $app.InstallLocation
    if ($installLoc -and (Test-Path $installLoc)) {
        $hasFiles = (Get-ChildItem -Path $installLoc -Force -ErrorAction SilentlyContinue | Select-Object -First 1) -ne $null
        if ($hasFiles) { return "OK" }
    }
    
    if ($uninstString) {
        $exePath = ""
        if ($uninstString -like '"*"*') { $exePath = $uninstString.Split('"')[1] }
        else { $exePath = $uninstString.Split(" ")[0] }
        
        if ($exePath -and (Test-Path $exePath)) { return "OK" }
        
        if ($exePath) {
            $parentDir = Split-Path $exePath -Parent
            if ($parentDir -and (Test-Path $parentDir)) {
                $uninstFile = Get-ChildItem -Path $parentDir -Filter "*uninstall*" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($uninstFile) { return "OK" }
                $exeFile = Get-ChildItem -Path $parentDir -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($exeFile) { return "OK" }
            }
        }
    }

    if ($app.DisplayIcon) {
        $iconPath = $app.DisplayIcon.Split(',')[0].Trim('"')
        if (Test-Path $iconPath) { return "OK" }
    }

    $cleanName = $app.DisplayName -replace '\s+', '' -replace '[^\w\-]', ''
    if ($cleanName.Length -gt 10) { $cleanName = $cleanName.Substring(0, 10) }
    $searchPaths = @("$env:ProgramFiles", "${env:ProgramFiles(x86)}", "$env:LOCALAPPDATA", "$env:USERPROFILE")
    
    foreach ($basePath in $searchPaths) {
        if (Test-Path $basePath) {
            $found = Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue | 
                     Where-Object { $_.Name -like "*$cleanName*" } | 
                     Select-Object -First 1
            if ($found) {
                $hasExe = (Get-ChildItem -Path $found.FullName -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1) -ne $null
                if ($hasExe) { return "OK" }
            }
        }
    }
    return "Fantasma"
}

function Get-InstalledApps {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $apps = @()
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $rawApps = Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName }
            foreach ($rawApp in $rawApps) {
                $status = Test-AppStatus $rawApp
                $rawApp | Add-Member -MemberType NoteProperty -Name "Status" -Value $status -Force
                $apps += $rawApp
            }
        }
    }
    return $apps | Sort-Object DisplayName
}

# ============================================
# AZIONI
# ============================================
function Show-AppList {
    Write-Step "LISTA APPLICAZIONI INSTALLATE" "Cyan"
    $script:foundApps = Get-InstalledApps
    
    $ghosts = ($script:foundApps | Where-Object { $_.Status -eq "Fantasma" }).Count
    $system = ($script:foundApps | Where-Object { $_.Status -eq "Sistema" }).Count
    $okApps = ($script:foundApps | Where-Object { $_.Status -eq "OK" }).Count
    
    Write-Host ""
    Write-Host "Totale: $($script:foundApps.Count) | OK: $okApps | Sistema: $system | Fantasmi: $ghosts" -ForegroundColor Yellow
    Write-Host ""
    
    $i = 1
    foreach ($app in $script:foundApps) {
        $color = switch ($app.Status) {
            "OK" { "Green" }
            "Fantasma" { "Red" }
            "Sistema" { "DarkGray" }
            default { "Yellow" }
        }
        Write-Host ("[{0:D3}] {1,-50} {2,-20} [{3}]" -f $i, $app.DisplayName, $app.Publisher, $app.Status) -ForegroundColor $color
        $i++
    }
    Write-Host ""
}

function Uninstall-App {
    param([int]$Index)
    $app = $script:foundApps[$Index - 1]
    if (-not $app) { Write-Log "Indice non valido." "ERROR"; return }

    if ($app.Status -eq "Sistema") {
        Write-Log "Impossibile disinstallare app di sistema." "ERROR"
        return
    }

    if ($app.Status -eq "Fantasma") {
        $resp = Read-Host "L'app e un fantasma. Vuoi rimuovere SOLO la voce di registro? (S/N)"
        if ($resp -eq 'S' -or $resp -eq 's') {
            try {
                Remove-Item -LiteralPath $app.PSPath -Recurse -Force -ErrorAction Stop
                Write-Log "Voce fantasma rimossa: $($app.DisplayName)" "OK"
            } catch {
                Write-Log "Errore: $($_.Exception.Message)" "ERROR"
            }
        }
        return
    }

    $resp = Read-Host "Confermi la disinstallazione di '$($app.DisplayName)'? (S/N)"
    if ($resp -ne 'S' -and $resp -ne 's') { return }

    $uninstString = $app.UninstallString
    $quietString = $app.QuietUninstallString

    try {
        if ($quietString) {
            $exe = ""; $args = ""
            if ($quietString -like '"*"*') {
                $exe = $quietString.Split('"')[1]
                $args = $quietString.Substring($quietString.IndexOf('"', 1) + 1).Trim()
            } else {
                $parts = $quietString.Split(" ", 2)
                $exe = $parts[0]; if ($parts.Count -gt 1) { $args = $parts[1] }
            }
            $proc = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru -ErrorAction Stop
            if ($proc.ExitCode -eq 0) { Write-Log "Disinstallazione completata." "OK"; return }
        }

        if ($uninstString) {
            $exe = ""; $args = ""
            if ($uninstString -like '"*"*') {
                $exe = $uninstString.Split('"')[1]
                $args = $uninstString.Substring($uninstString.IndexOf('"', 1) + 1).Trim()
            } else {
                $parts = $uninstString.Split(" ", 2)
                $exe = $parts[0]; if ($parts.Count -gt 1) { $args = $parts[1] }
            }
            $proc = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru -ErrorAction Stop
            Write-Log "Processo terminato (codice: $($proc.ExitCode))"
        }
    } catch {
        Write-Log "Errore: $($_.Exception.Message)" "ERROR"
    }
}

function Clean-Ghosts {
    $ghosts = @($script:foundApps | Where-Object { $_.Status -eq "Fantasma" })
    if ($ghosts.Count -eq 0) { Write-Log "Nessun fantasma trovato." "OK"; return }

    Write-Log "Trovati $($ghosts.Count) fantasmi." "WARNING"
    $resp = Read-Host "Vuoi rimuovere tutte le voci orfane? (S/N)"
    if ($resp -ne 'S' -and $resp -ne 's') { return }

    $deleted = 0
    foreach ($ghost in $ghosts) {
        try {
            Remove-Item -LiteralPath $ghost.PSPath -Recurse -Force -ErrorAction Stop
            Write-Log "Rimosso: $($ghost.DisplayName)" "OK"
            $deleted++
        } catch {
            Write-Log "Errore $($ghost.DisplayName): $($_.Exception.Message)" "ERROR"
        }
    }
    Write-Log "Rimossi $deleted fantasmi." "OK"
}

function Do-BackupRegistry {
    Write-Log "Backup registro in corso..." "INFO"
    $backupDir = Join-Path $script:workDir "RegistryBackups_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
    $hives = @("HKLM\SOFTWARE", "HKCU", "HKCR")
    foreach ($hive in $hives) {
        $safeName = $hive.Replace('\', '_')
        $file = Join-Path $backupDir "$safeName.reg"
        Write-Log "Esportazione $hive..."
        $proc = Start-Process "reg.exe" -ArgumentList "export `"$hive`" `"$file`" /y" -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -eq 0) { Write-Log "  -> OK" "OK" }
        else { Write-Log "  -> FALLITO" "ERROR" }
    }
    Write-Log "Backup completato in: $backupDir" "OK"
}

function Do-RestorePoint {
    Write-Log "Creazione punto di ripristino..." "INFO"
    
    # Controlla se il servizio VSS è attivo
    $vssService = Get-Service -Name "VSS" -ErrorAction SilentlyContinue
    if (-not $vssService -or $vssService.Status -ne "Running") {
        Write-Log "Il servizio 'Volume Shadow Copy' (VSS) non è in esecuzione. Impossibile creare punti di ripristino." "WARNING"
        Write-Log "Per abilitarlo: Pannello di Controllo -> Sistema -> Protezione del sistema." "INFO"
        return
    }
    
    # Controlla se la protezione del sistema è attiva (tramite WMI)
    try {
        $sr = Get-CimInstance -Namespace root/default -ClassName SystemRestore -ErrorAction SilentlyContinue
        if (-not $sr) {
            # Se non ci sono punti di ripristino, potrebbe essere disabilitato
            Write-Log "La Protezione del Sistema sembra disabilitata per l'unita C:." "WARNING"
            Write-Log "Abilitala da Pannello di Controllo -> Sistema -> Protezione del sistema." "INFO"
            return
        }
    } catch {}

    try {
        Checkpoint-Computer -Description "Prima della disinstallazione $(Get-Date -Format 'yyyyMMdd_HHmmss')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Punto di ripristino creato con successo." "OK"
    } catch {
        Write-Log "Errore creazione punto di ripristino: $($_.Exception.Message)" "ERROR"
        Write-Log "Suggerimento: verifica che la Protezione del Sistema sia attiva su C:." "INFO"
    }
}

# ============================================
# MENU PRINCIPALE
# ============================================
Clear-Host
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "      APP UNINSTALLER - CLI EDITION v1.0                    " -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

Start-Log
Write-Log "App Uninstaller CLI avviato." "INFO"

while ($true) {
    Write-Host ""
    Write-Host "MENU PRINCIPALE:" -ForegroundColor Cyan
    Write-Host "  1. Mostra lista applicazioni (con stato)"
    Write-Host "  2. Disinstalla applicazione per indice"
    Write-Host "  3. Pulisci fantasmi (voci registro orfane)"
    Write-Host "  4. Backup del Registro (HKLM\SOFTWARE, HKCU, HKCR)"
    Write-Host "  5. Crea punto di ripristino"
    Write-Host "  6. Apri log"
    Write-Host "  0. Esci"
    Write-Host ""

    $choice = Read-Host "Scegli un'opzione"

    switch ($choice) {
        "1" { Show-AppList }
        "2" {
            if ($script:foundApps.Count -eq 0) { 
                Write-Log "Devi prima mostrare la lista (opzione 1)." "WARNING"
                break 
            }
            $idx = Read-Host "Inserisci l'indice dell'app da disinstallare (0 per annullare)"
            if ($idx -eq "0") { continue }
            if ($idx -match '^\d+$') { 
                if ([int]$idx -gt 0 -and [int]$idx -le $script:foundApps.Count) {
                    Uninstall-App -Index ([int]$idx) 
                } else {
                    Write-Log "Indice fuori range (1-$($script:foundApps.Count))." "ERROR"
                }
            }
            else { Write-Log "Indice non valido." "ERROR" }
        }
        "3" { if ($script:foundApps.Count -eq 0) { $script:foundApps = Get-InstalledApps }; Clean-Ghosts }
        "4" { Do-BackupRegistry }
        "5" { Do-RestorePoint }
        "6" { if (Test-Path $script:logFile) { Invoke-Item $script:logFile } }
        "0" { Write-Log "Uscita." "INFO"; exit 0 }
        default { Write-Log "Opzione non valida." "WARNING" }
    }
}