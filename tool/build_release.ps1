<#
  tool/build_release.ps1
  Build APK/AAB rápido con split por ABI y (opcional) SKSL.
  Uso:
    .\tool\build_release.ps1                 # APK arm64 + arm
    .\tool\build_release.ps1 -SkslPath assets\sksl.json
    .\tool\build_release.ps1 -Abi arm64
    .\tool\build_release.ps1 -NoSplitPerAbi
    .\tool\build_release.ps1 -NoTreeShakeIcons
    .\tool\build_release.ps1 -Bundle         # también genera AAB
#>

param(
  [string]$SkslPath = "",
  [ValidateSet("all","arm64","arm")] [string]$Abi = "all",
  [switch]$NoClean,
  [switch]$NoSplitPerAbi,
  [switch]$NoTreeShakeIcons,
  [switch]$Bundle
)

# ---------- Config base ----------
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Exec {
  param([Parameter(Mandatory=$true)][string]$Cmd, [string[]]$Args)
  Write-Host ("» {0} {1}" -f $Cmd, ($Args -join ' '))
  & $Cmd @Args
  if ($LASTEXITCODE -ne 0) {
    throw ("Fallo: {0} {1} (exit {2})" -f $Cmd, ($Args -join ' '), $LASTEXITCODE)
  }
}

# ---------- Validaciones ----------
if (-not (Test-Path "pubspec.yaml")) {
  throw "Ejecutá este script desde la raíz del proyecto (no se encontró pubspec.yaml)."
}
try { Exec -Cmd "flutter" -Args @("--version") } catch { throw "Flutter no encontrado en PATH." }

# ---------- Build ----------
$sw = [System.Diagnostics.Stopwatch]::StartNew()

if (-not $NoClean) {
  Exec -Cmd "flutter" -Args @("clean")
}
Exec -Cmd "flutter" -Args @("pub","get")

# Args para APK
$apkArgs = @("build","apk","--release")

if (-not $NoSplitPerAbi) {
  $apkArgs += "--split-per-abi"
}

$targetPlatforms = switch ($Abi) {
  "arm64" { "android-arm64" }
  "arm"   { "android-arm" }
  default { "android-arm64,android-arm" }
}
$apkArgs += "--target-platform=$targetPlatforms"

if (-not [string]::IsNullOrWhiteSpace($SkslPath) -and (Test-Path $SkslPath)) {
  $apkArgs += "--bundle-sksl-path=$SkslPath"
}

if ($NoTreeShakeIcons) {
  $apkArgs += "--no-tree-shake-icons"
}

# Build APK
Exec -Cmd "flutter" -Args $apkArgs

# (Opcional) Build AAB para Play Store
if ($Bundle) {
  $aabArgs = @("build","appbundle","--release")
  if (-not [string]::IsNullOrWhiteSpace($SkslPath) -and (Test-Path $SkslPath)) {
    $aabArgs += "--bundle-sksl-path=$SkslPath"
  }
  if ($NoTreeShakeIcons) {
    $aabArgs += "--no-tree-shake-icons"
  }
  Exec -Cmd "flutter" -Args $aabArgs
}

$sw.Stop()

# ---------- Resultados ----------
$apkOutDir = "build\app\outputs\flutter-apk"
$aabOutDir = "build\app\outputs\bundle\release"

Write-Host ("Build OK en {0}s" -f [int]$sw.Elapsed.TotalSeconds)

if (Test-Path $apkOutDir) {
  Write-Host "APKs generados:"
  Get-ChildItem $apkOutDir -Filter "*.apk" | ForEach-Object {
    Write-Host (" - {0}" -f $_.FullName)
  }
  $arm64Apk = Join-Path $apkOutDir "app-arm64-v8a-release.apk"
  $armApk   = Join-Path $apkOutDir "app-armeabi-v7a-release.apk"
  $universalApk = Join-Path $apkOutDir "app-release.apk"
  if (Test-Path $arm64Apk)   { Write-Host ('  adb install -r "{0}"' -f $arm64Apk) }
  if (Test-Path $armApk)     { Write-Host ('  adb install -r "{0}"' -f $armApk) }
  if (Test-Path $universalApk){ Write-Host ('  adb install -r "{0}"' -f $universalApk) }
}
if ($Bundle -and (Test-Path $aabOutDir)) {
  Write-Host "AAB generado:"
  Get-ChildItem $aabOutDir -Filter "*.aab" | ForEach-Object {
    Write-Host (" - {0}" -f $_.FullName)
  }
}
