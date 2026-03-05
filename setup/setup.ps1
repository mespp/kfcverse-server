# configure TLS for downloads (GitHub, Oracle, etc.)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Download-File {
    param (
        [string]$Url,
        [string]$OutFile
    )
    Write-Host "Downloading $Url ..."
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
        return $true
    } catch {
        Write-Warning "Failed to download $Url - $_"
        return $false
    }
}

# Install Java 21
$javaUrl = "https://download.oracle.com/java/21/latest/jdk-21_windows-x64_bin.msi"
$javaInstaller = "$env:TEMP\jdk-21_windows-x64_bin.msi"
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    if (Download-File $javaUrl $javaInstaller) {
        Start-Process msiexec.exe -ArgumentList "/i `"$javaInstaller`" /qn" -Wait
    } else {
        Write-Error "Java installer could not be downloaded; aborting."
        exit 1
    }
} else {
    Write-Host "Java already installed."
}

# Install Git (track if installed this run)
$gitInstalled = $false
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git not detected. Downloading and installing Git for Windows..."
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.53.0.windows.1/Git-2.53.0-64-bit.exe"
    $gitInstaller = "$env:TEMP\git-installer.exe"
    if (Download-File $gitUrl $gitInstaller) {
        Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT","/NORESTART" -Wait
        $gitInstalled = $true
    } else {
        Write-Warning "Could not download Git installer; please install Git manually."
    }
} else {
    Write-Host "Git already installed."
}

if ($gitInstalled) {
    Write-Host "Git has just been installed. You need to close and reopen this shell (or log out/in) before continuing."
    Write-Host "Please restart PowerShell and run this script again." -ForegroundColor Yellow
    exit 0
}

# Ask user where to clone the server
$cloneDir = Read-Host "Enter folder to clone the server into"
if (-not [string]::IsNullOrEmpty($cloneDir)) {
    if (-not (Test-Path $cloneDir)) {
        New-Item -ItemType Directory -Path $cloneDir | Out-Null
    }
} else {
    Write-Host "No directory provided."
    exit 1
}

# attempt GitHub login via credential manager (opens browser popup)
if (Get-Command "git" -ErrorAction SilentlyContinue) {
    Write-Host "Attempting to authenticate via Git credential manager (if installed)..."
    try {
        git credential-manager-core login --scopes repo
    } catch {
        Write-Host "credential-manager-core command not available or failed." -ForegroundColor Yellow
        Write-Host "Opening browser to GitHub login page so you can authenticate manually..."
        Start-Process "https://github.com/login"  # opens default browser
    }
}

# Configure Git user identity only if not already set
if (-not (git config --global --get user.name)) {
    $ghName = Read-Host "Enter your GitHub user name (for git config)"
    if ($ghName) { git config --global user.name $ghName }
}
if (-not (git config --global --get user.email)) {
    $ghEmail = Read-Host "Enter your GitHub email address (for git config)"
    if ($ghEmail) { git config --global user.email $ghEmail }
}
# capture the configured values (global or just set)
$ghName = git config --global user.name
$ghEmail = git config --global user.email
Write-Host "If you need to authenticate with GitHub, run 'git credential-manager-core configure' or use SSH keys."

# after cloning we'll apply these same values to the local repo so auto‑commits
# use the `--add` flag to avoid overwriting if repo already has them
function Configure-RepoIdentity {
    param([string]$repoPath)
    if ($ghName) { git -C $repoPath config user.name "$ghName" }
    if ($ghEmail) { git -C $repoPath config user.email "$ghEmail" }
}

# Clone repository
Write-Host "Cloning repository into $cloneDir..."
Set-Location $cloneDir
git clone https://github.com/mespp/kfcverse-server

Write-Host "Done!"
