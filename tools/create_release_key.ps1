# Creates the permanent Android release key for Easy Draw (run ONCE).
#
#   powershell -ExecutionPolicy Bypass -File tools\create_release_key.ps1
#
# Every release must be signed with this same key, or phones refuse to
# install the update over the old version. Back up the .jks file AND its
# password somewhere safe (password manager + a second drive): if either is
# lost, existing users can never update again.
#
# What it does:
#   1. keytool asks you for a password and your name/organisation and creates
#      the key (outside the repo, by default in %USERPROFILE%\.easydraw).
#   2. Writes android\key.properties (git-ignored) so local release builds use it.
#   3. Optionally stores the key in this GitHub repo's Actions secrets, so the
#      release workflow can sign APKs.
# Nothing here is committed; passwords are typed by you and never printed.
param(
    [string]$KeystorePath = (Join-Path $env:USERPROFILE '.easydraw\easy-draw-release.jks'),
    [string]$Alias = 'easydraw'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

function Find-Keytool {
    $candidates = @()
    if ($env:JAVA_HOME) { $candidates += (Join-Path $env:JAVA_HOME 'bin\keytool.exe') }
    $candidates += 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { return $cmd.Source }
    throw 'keytool not found. Install Android Studio or a JDK, or set JAVA_HOME.'
}

if (Test-Path $KeystorePath) {
    throw "A key already exists at $KeystorePath. It is never overwritten: losing it would block updates."
}
$keytool = Find-Keytool
New-Item -ItemType Directory -Force (Split-Path -Parent $KeystorePath) | Out-Null

Write-Host ''
Write-Host 'Creating the release key. Choose a strong password (at least 6 characters) and remember it.' -ForegroundColor Cyan
& $keytool -genkeypair -v -keystore $KeystorePath -storetype PKCS12 -alias $Alias -keyalg RSA -keysize 4096 -validity 10000
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $KeystorePath)) { throw 'keytool did not create the key.' }

$secure = Read-Host 'Type the key password once more (it is saved only in android\key.properties, which git ignores)' -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $pw = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }

# Check the password really opens the key before saving it anywhere.
& $keytool -list -keystore $KeystorePath -storepass $pw -alias $Alias *> $null
if ($LASTEXITCODE -ne 0) { throw 'That password does not open the new key. Nothing was saved; run "keytool -list" to check, or delete the .jks and start again.' }

$props = Join-Path $repo 'android\key.properties'
$storePath = $KeystorePath -replace '\\', '/'
@(
    "storeFile=$storePath",
    "storePassword=$pw",
    "keyAlias=$Alias",
    "keyPassword=$pw"
) | Set-Content -Path $props -Encoding ascii
Write-Host "Saved $props (git-ignored)." -ForegroundColor Green

$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($null -ne $gh) {
    $answer = Read-Host 'Store the key in this GitHub repo''s Actions secrets for the release workflow? (y/n)'
    if ($answer -eq 'y') {
        Push-Location $repo
        try {
            $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($KeystorePath))
            & gh secret set EASYDRAW_KEYSTORE_BASE64 --body $b64
            if ($LASTEXITCODE -ne 0) { throw 'gh secret set failed (EASYDRAW_KEYSTORE_BASE64).' }
            & gh secret set EASYDRAW_KEY_PASSWORD --body $pw
            if ($LASTEXITCODE -ne 0) { throw 'gh secret set failed (EASYDRAW_KEY_PASSWORD).' }
            Write-Host 'GitHub secrets EASYDRAW_KEYSTORE_BASE64 and EASYDRAW_KEY_PASSWORD are set.' -ForegroundColor Green
        } finally { Pop-Location }
    }
}
$pw = $null

Write-Host ''
Write-Host 'IMPORTANT: back up these two things now (password manager + another drive):' -ForegroundColor Yellow
Write-Host "  1. $KeystorePath" -ForegroundColor Yellow
Write-Host '  2. its password' -ForegroundColor Yellow
Write-Host 'Without them, nobody who installed Easy Draw can ever receive an update.' -ForegroundColor Yellow
