# App-Uninstaller-GUI.ps1 - v2.3 (Deep Scan Edition)
# Disinstallatore robusto con Ghost Hunter e Deep Scan
# Richiede privilegi di amministratore

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:workDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:logFile = $null
$script:foundApps = @()

# ============================================
# LOGGING
# ============================================
function Start-Log {
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:logFile = Join-Path $script:workDir "Uninstaller_$ts.log"
    "--- APP UNINSTALLER LOG ---" | Set-Content -Path $script:logFile -Encoding UTF8
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    if ($txtLog) { 
        $txtLog.AppendText("$line`r`n")
        $txtLog.SelectionStart = $txtLog.TextLength
        $txtLog.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
    if ($script:logFile) {
        Add-Content -Path $script:logFile -Value $line -Encoding UTF8
    }
}

# ============================================
# ADMIN CHECK
# ============================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show("Questo tool richiede privilegi di amministratore. Rilancio con UAC...", "Privilegi", "OK", "Information")
    $pwshPath = Join-Path $PSHOME "pwsh.exe"
    if (-not (Test-Path $pwshPath)) { $pwshPath = "pwsh.exe" }
    Start-Process $pwshPath -ArgumentList "-NoProfile -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ============================================
# GUI MATRIX v2.3
# ============================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "APP UNINSTALLER - GHOST HUNTER v2.3"
$form.Size = New-Object System.Drawing.Size(950, 750)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::Black
$form.ForeColor = [System.Drawing.Color]::Lime
$form.Font = New-Object System.Drawing.Font("Consolas", 9)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "APP UNINSTALLER & GHOST HUNTER"
$lblTitle.Font = New-Object System.Drawing.Font("Consolas", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::Lime
$lblTitle.TextAlign = "MiddleCenter"
$lblTitle.Location = New-Object System.Drawing.Point(20, 10)
$lblTitle.Size = New-Object System.Drawing.Size(890, 30)
$form.Controls.Add($lblTitle)

# --- DataGrid (Lista App) ---
$dataGrid = New-Object System.Windows.Forms.DataGridView
$dataGrid.Location = New-Object System.Drawing.Point(20, 50)
$dataGrid.Size = New-Object System.Drawing.Size(890, 400)
$dataGrid.BackgroundColor = [System.Drawing.Color]::FromArgb(10, 10, 10)
$dataGrid.ForeColor = [System.Drawing.Color]::Lime
$dataGrid.GridColor = [System.Drawing.Color]::DarkGreen
$dataGrid.BorderStyle = "None"
$dataGrid.EnableHeadersVisualStyles = $false
$dataGrid.SelectionMode = "FullRowSelect"
$dataGrid.MultiSelect = $false
$dataGrid.RowHeadersVisible = $false
$dataGrid.ReadOnly = $true
$dataGrid.AutoSizeColumnsMode = "Fill"
$dataGrid.ColumnHeadersDefaultCellStyle.BackColor = "Black"
$dataGrid.ColumnHeadersDefaultCellStyle.ForeColor = "Lime"
$dataGrid.DefaultCellStyle.BackColor = "Black"
$dataGrid.DefaultCellStyle.ForeColor = "Lime"
$dataGrid.DefaultCellStyle.SelectionBackColor = "DarkGreen"
$dataGrid.DefaultCellStyle.SelectionForeColor = "White"
$form.Controls.Add($dataGrid)

# --- Pulsanti ---
function New-MatrixButton { param($text, $x, $y, $w, $h, $color = "Black") 
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($w, $h)
    $b.FlatStyle = "Flat"
    $b.FlatAppearance.BorderColor = [System.Drawing.Color]::Lime
    $b.ForeColor = [System.Drawing.Color]::Lime
    $b.BackColor = $color
    $form.Controls.Add($b)
    return $b
}

$btnRefresh = New-MatrixButton "REFRESH" 20 470 110 35
$btnRestorePoint = New-MatrixButton "PUNTO RIPRISTINO" 140 470 140 35
$btnBackupReg = New-MatrixButton "BACKUP REGISTRO" 290 470 140 35
$btnDeepScan = New-MatrixButton "DEEP SCAN" 440 470 100 35
$btnCleanGhost = New-MatrixButton "PULISCI" 550 470 100 35
$btnUninstall = New-MatrixButton "UNINSTALL" 660 470 120 35 "DarkRed"
$btnOpenLog = New-MatrixButton "LOG" 790 470 60 35
$btnExit = New-MatrixButton "EXIT" 860 470 50 35

# --- Log ---
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.Location = New-Object System.Drawing.Point(20, 520)
$txtLog.Size = New-Object System.Drawing.Size(890, 170)
$txtLog.ReadOnly = $true
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 10)
$txtLog.ForeColor = [System.Drawing.Color]::Lime
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8)
$txtLog.BorderStyle = "FixedSingle"
$form.Controls.Add($txtLog)

# ============================================
# FUNZIONI CORE
# ============================================

function Search-AppFolder {
    param([string]$AppName)
    
    # Rimuove caratteri strani e prende la prima parola significativa
    $cleanName = $AppName -replace '\s+', '' -replace '[^\w\-]', ''
    if ($cleanName.Length -gt 15) { $cleanName = $cleanName.Substring(0, 15) }

    $searchPaths = @(
        "$env:ProgramFiles",
        "${env:ProgramFiles(x86)}",
        "$env:LOCALAPPDATA",
        "$env:APPDATA"
    )

    foreach ($basePath in $searchPaths) {
        if (Test-Path $basePath) {
            $found = Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue | 
                     Where-Object { $_.Name -like "*$cleanName*" } | 
                     Select-Object -First 1
            
            if ($found) {
                $hasFiles = (Get-ChildItem -Path $found.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1) -ne $null
                if ($hasFiles) { return $found.FullName }
            }
        }
    }
    return $null
}

function Test-AppStatus ($app) {
    # 1. È un'app di sistema?
    if ($app.SystemComponent -eq 1) { return "Sistema" }
    
    # 2. È un'app MSI?
    $uninstString = $app.UninstallString
    if ($uninstString -and $uninstString -match "msiexec") { return "OK" }
    
    # 3. InstallLocation?
    $installLoc = $app.InstallLocation
    if ($installLoc -and (Test-Path $installLoc)) {
        $hasFiles = (Get-ChildItem -Path $installLoc -Force -ErrorAction SilentlyContinue | Select-Object -First 1) -ne $null
        if ($hasFiles) { return "OK" }
    }
    
    # 4. UninstallString? (il percorso esatto)
    if ($uninstString) {
        $exePath = ""
        if ($uninstString -like '"*"*') { $exePath = $uninstString.Split('"')[1] }
        else { $exePath = $uninstString.Split(" ")[0] }
        
        # Se il file .exe esiste, è OK
        if ($exePath -and (Test-Path $exePath)) { return "OK" }
        
        # SE IL FILE NON ESISTE, CONTROLLIAMO LA CARTELLA CHE LO CONTIENE
        if ($exePath) {
            $parentDir = Split-Path $exePath -Parent
            if ($parentDir -and (Test-Path $parentDir)) {
                # Cerchiamo un file che inizia con "uninstall" o "unins" nella cartella
                $uninstFile = Get-ChildItem -Path $parentDir -Filter "*uninstall*" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($uninstFile) { return "OK" }
                
                # O se c'è un qualsiasi file .exe (escludendo i file di sistema)
                $exeFile = Get-ChildItem -Path $parentDir -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($exeFile) { return "OK" }
            }
        }
    }

    # 5. DisplayIcon?
    if ($app.DisplayIcon) {
        $iconPath = $app.DisplayIcon.Split(',')[0].Trim('"')
        if (Test-Path $iconPath) { return "OK" }
    }

    # 6. Deep Scan (ultima spiaggia, cerca in Program Files, AppData, ecc.)
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

    # 7. Vero fantasma
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

function Update-AppList {
    Write-Log "Scansione applicazioni (Ghost Hunter + Deep Scan attivo)..."
    $script:foundApps = Get-InstalledApps
    
    $dt = New-Object System.Data.DataTable
    "Nome", "Publisher", "Versione", "Stato", "RegPath" | ForEach-Object { [void]$dt.Columns.Add($_) }
    
    $ghosts = 0
    foreach ($app in $script:foundApps) {
        $row = $dt.NewRow()
        $row["Nome"] = $app.DisplayName
        $row["Publisher"] = if ($app.Publisher) { $app.Publisher } else { "N/D" }
        $row["Versione"] = if ($app.DisplayVersion) { $app.DisplayVersion } else { "N/D" }
        $row["Stato"] = $app.Status
        $row["RegPath"] = $app.PSPath
        $dt.Rows.Add($row)
        if ($app.Status -eq "Fantasma") { $ghosts++ }
    }
    
    $dataGrid.DataSource = $dt
    if ($dataGrid.Columns["RegPath"]) { $dataGrid.Columns["RegPath"].Visible = $false }
    
    foreach ($row in $dataGrid.Rows) {
        switch ($row.Cells["Stato"].Value) {
            "OK" { $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Lime }
            "Fantasma" { $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Red }
            "Sistema" { $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray }
            "Incompleta" { $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Orange }
        }
    }
    
    Write-Log "Trovate $($script:foundApps.Count) applicazioni. ($ghosts fantasmi residui dopo Deep Scan)" "INFO"
}

function Force-DeepScan {
    Write-Log "Avvio Deep Scan forzato su tutte le voci 'Fantasma'..."
    $ghosts = $script:foundApps | Where-Object { $_.Status -eq "Fantasma" }
    $recovered = 0

    foreach ($ghost in $ghosts) {
        Write-Log "Cerco '$($ghost.DisplayName)' sul disco..."
        $found = Search-AppFolder -AppName $ghost.DisplayName
        if ($found) {
            Write-Log "  -> TROVATO IN: $found. L'app è VIVA!" "OK"
            $ghost.Status = "OK"
            $recovered++
        } else {
            Write-Log "  -> Non trovato. È un vero fantasma." "WARNING"
        }
    }

    if ($recovered -gt 0) {
        Write-Log "Deep Scan completato. $recovered fantasmi sono stati 'salvati'." "OK"
        # Ricarica la lista per aggiornare i colori
        $dt = $dataGrid.DataSource
        foreach ($app in $script:foundApps) {
            $row = $dt.Rows | Where-Object { $_["RegPath"] -eq $app.PSPath }
            if ($row) {
                $row["Stato"] = $app.Status
                if ($app.Status -eq "OK") { $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Lime }
            }
        }
    } else {
        Write-Log "Nessun falso positivo trovato." "INFO"
    }
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

function Create-RestorePoint {
    Write-Log "Creazione punto di ripristino in corso..." "INFO"
    
    # Controlla se il servizio VSS è attivo
    $vssService = Get-Service -Name "VSS" -ErrorAction SilentlyContinue
    if (-not $vssService -or $vssService.Status -ne "Running") {
        Write-Log "Il servizio 'Volume Shadow Copy' (VSS) non è in esecuzione." "WARNING"
        Write-Log "Abilita la Protezione del Sistema da Pannello di Controllo -> Sistema." "INFO"
        return
    }

    try {
        Checkpoint-Computer -Description "Prima della disinstallazione $(Get-Date -Format 'yyyyMMdd_HHmmss')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Punto di ripristino creato con successo." "OK"
    } catch {
        Write-Log "Errore creazione punto di ripristino: $($_.Exception.Message)" "ERROR"
        Write-Log "Suggerimento: verifica che la Protezione del Sistema sia attiva su C:." "INFO"
    }
}

function Backup-Registry {
    Write-Log "Backup del registro in corso..."
    $backupDir = Join-Path $script:workDir "RegistryBackups_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
    $hives = @("HKLM\SOFTWARE", "HKCU", "HKCR")
    foreach ($hive in $hives) {
        $safeName = $hive.Replace('\', '_')
        $file = Join-Path $backupDir "$safeName.reg"
        Write-Log "Esportazione $hive..."
        $proc = Start-Process "reg.exe" -ArgumentList "export `"$hive`" `"$file`" /y" -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -eq 0) { Write-Log "  -> OK" "OK" }
        else { Write-Log "  -> FALLITO (codice $($proc.ExitCode))" "ERROR" }
    }
    Write-Log "Backup completato in: $backupDir" "OK"
}

function Uninstall-App {
    if ($dataGrid.SelectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Seleziona un'applicazione.", "Nessuna selezione", "OK", "Warning")
        return
    }

    $selectedName = $dataGrid.SelectedRows[0].Cells["Nome"].Value
    $selectedPath = $dataGrid.SelectedRows[0].Cells["RegPath"].Value
    $status = $dataGrid.SelectedRows[0].Cells["Stato"].Value
    
    if ($status -eq "Sistema") {
        [System.Windows.Forms.MessageBox]::Show("App di sistema non disinstallabile.", "Protetta", "OK", "Warning")
        return
    }

    $app = $script:foundApps | Where-Object { $_.PSPath -eq $selectedPath } | Select-Object -First 1
    if (-not $app) { return }

    if ($status -eq "Fantasma") {
        $msg = "Questa app è un fantasma (file non trovati).`n`nVuoi rimuovere SOLO la voce di registro?"
        $resp = [System.Windows.Forms.MessageBox]::Show($msg, "Fantasma", "YesNo", "Warning")
        if ($resp -eq "Yes") {
            try {
                Remove-Item -LiteralPath $app.PSPath -Recurse -Force -ErrorAction Stop
                Write-Log "Voce fantasma rimossa: $selectedName" "OK"
                Update-AppList
            } catch {
                Write-Log "Errore rimozione: $($_.Exception.Message)" "ERROR"
            }
        }
        return
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show("Disinstallare $selectedName?", "Conferma", "YesNo", "Warning")
    if ($confirm -ne "Yes") { return }

    Write-Log "Avvio disinstallazione: $selectedName"
    $uninstallString = $app.UninstallString
    $quietUninstallString = $app.QuietUninstallString

    try {
        if ($quietUninstallString) {
            Write-Log "Tentativo con QuietUninstallString..."
            $exe = ""; $args = ""
            if ($quietUninstallString -like '"*"*') {
                $exe = $quietUninstallString.Split('"')[1]
                $args = $quietUninstallString.Substring($quietUninstallString.IndexOf('"', 1) + 1).Trim()
            } else {
                $parts = $quietUninstallString.Split(" ", 2)
                $exe = $parts[0]
                if ($parts.Count -gt 1) { $args = $parts[1] }
            }
            
            $proc = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru -NoNewWindow -ErrorAction Stop
            if ($proc.ExitCode -eq 0) {
                Write-Log "Disinstallazione completata." "OK"
                Update-AppList
                return
            }
        }
        
        if ($uninstallString) {
            Write-Log "Tentativo con UninstallString..."
            $exe = ""; $args = ""
            if ($uninstallString -like '"*"*') {
                $exe = $uninstallString.Split('"')[1]
                $args = $uninstallString.Substring($uninstallString.IndexOf('"', 1) + 1).Trim()
            } else {
                $parts = $uninstallString.Split(" ", 2)
                $exe = $parts[0]
                if ($parts.Count -gt 1) { $args = $parts[1] }
            }
            
            $proc = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru -NoNewWindow -ErrorAction Stop
            Write-Log "Processo terminato (codice: $($proc.ExitCode))"
            Update-AppList
        }
    } catch {
        Write-Log "Errore: $($_.Exception.Message)" "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Errore durante la disinstallazione.", "Errore", "OK", "Error")
    }
}

function Clean-Ghosts {
    $ghosts = $script:foundApps | Where-Object { $_.Status -eq "Fantasma" }
    if ($ghosts.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Nessun fantasma rilevato. Sistema pulito!", "Pulizia", "OK", "Information")
        return
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Trovati $($ghosts.Count) fantasmi.`n`nVuoi rimuovere TUTTE le voci orfane? (Non elimina file dal disco)",
        "Pulisci Fantasmi", "YesNo", "Warning"
    )
    if ($confirm -ne "Yes") { return }

    Write-Log "Pulizia fantasmi in corso..."
    $deleted = 0
    foreach ($ghost in $ghosts) {
        try {
            Remove-Item -LiteralPath $ghost.PSPath -Recurse -Force -ErrorAction Stop
            Write-Log "Rimosso: $($ghost.DisplayName)" "OK"
            $deleted++
        } catch {
            Write-Log "Errore rimozione $($ghost.DisplayName): $($_.Exception.Message)" "ERROR"
        }
    }
    
    Write-Log "Pulizia completata. Rimossi $deleted fantasmi." "OK"
    Update-AppList
}

# ============================================
# EVENTI
# ============================================
$btnRefresh.Add_Click({ Update-AppList })
$btnRestorePoint.Add_Click({ Create-RestorePoint })
$btnBackupReg.Add_Click({ Backup-Registry })
$btnDeepScan.Add_Click({ Force-DeepScan })
$btnCleanGhost.Add_Click({ Clean-Ghosts })
$btnUninstall.Add_Click({ Uninstall-App })
$btnOpenLog.Add_Click({ if (Test-Path $script:logFile) { Invoke-Item $script:logFile } })
$btnExit.Add_Click({ $form.Close() })

# ============================================
# AVVIO
# ============================================
Start-Log
$form.Add_Shown({
    Write-Log "App Uninstaller v2.3 (Deep Scan) avviato."
    Update-AppList
})

$form.ShowDialog() | Out-Null