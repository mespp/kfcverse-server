# get into the folder
Set-Location -Path $PSScriptRoot
$RepoRoot = $PSScriptRoot
while ($RepoRoot -and -not (Test-Path (Join-Path $RepoRoot ".git"))) {
    $RepoRoot = Split-Path $RepoRoot -Parent
}
if (-not $RepoRoot) {
    Write-Host "ERROR: folder not found." -ForegroundColor Red
    exit
}
$ReadmePath = Join-Path -Path $RepoRoot -ChildPath "README.md"

# sync github
Write-Host "Syncing server" -ForegroundColor Yellow
try {
    Push-Location $RepoRoot
    git pull origin main --rebase 
    Pop-Location
} catch {
    Write-Host "Error. GitHub not synced." -ForegroundColor Red
}

# update github status
function Update-GitHubStatus($status) {
    $Fecha = Get-Date -Format "dd/MM/yyyy HH:mm"
    
    if ($status -eq "Online") {
        $msg = "# SERVER ONLINE"
        $gitTarget = "README.md" 
    } else {
        $status = "Offline" 
        $msg = "# SERVER OFFLINE"
        $gitTarget = "."
    }
    
    Set-Content -Path $ReadmePath -Value $msg -Encoding utf8
    
    try {
        Push-Location $RepoRoot
        git add $gitTarget
        git commit -m "Status: Server $status ($Fecha)" --allow-empty
        git push origin main
        Pop-Location
        Write-Host "GitHub updated ($status)" -ForegroundColor Green
    } catch {
        Write-Host "Error $status" -ForegroundColor Yellow
    }
}

# la chicha
try {
    Update-GitHubStatus "Online"
    $URL = "https://github.com/mespp/kfcverse-server/releases/download/mods/Cobblemon-fabric-1.7.1+1.21.1.jar"
    $ModsFolder = Join-Path -Path $RepoRoot -ChildPath "server/mods"

    if (-not (Test-Path $ModsFolder)) { New-Item -ItemType Directory -Path $ModsFolder | Out-Null }

    $fileName = Split-Path -Leaf $URL
    $destination = Join-Path $ModsFolder $fileName

    if (Test-Path $destination) {
        Write-Host "All mods are downloaded."
    } else {
        try {
            Write-Host "Downloading $fileName..."
            Start-Process -FilePath "curl.exe" -ArgumentList "-L -O $URL" -WorkingDirectory $ModsFolder -Wait
            Write-Host "Download completed: $destination"
        } catch {
            Write-Host "Error downloading: $_"
        }
    }

    # run playit
    Start-Process -FilePath "$RepoRoot/misc/playit.exe"

    Write-Host "Server online. Close typing 'stop' or just closing the window." -ForegroundColor Cyan
    Set-Location -Path "$RepoRoot/server"
    $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c start.bat" -Wait -PassThru
}
finally {
    # backup to github
    Write-Host "Cierre detectado. Realizando backup final en GitHub..." -ForegroundColor Magenta
    Update-GitHubStatus "Offline"
    Write-Host "Backup completado." -ForegroundColor Green
    Start-Sleep -Seconds 2
}
