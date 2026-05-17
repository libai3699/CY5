param(
    [string]$FlutterCommand = ''
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Get-FlutterVersionName {
    $propertiesPath = Join-Path $root 'android/local.properties'
    if (-not (Test-Path -LiteralPath $propertiesPath)) {
        return '1.0.0'
    }

    $versionLine = Get-Content -LiteralPath $propertiesPath |
        Where-Object { $_ -match '^flutter\.versionName=' } |
        Select-Object -First 1

    if (-not $versionLine) {
        return '1.0.0'
    }

    $versionName = ($versionLine -split '=', 2)[1].Trim()
    if ([string]::IsNullOrWhiteSpace($versionName)) {
        return '1.0.0'
    }

    return $versionName
}

function Invoke-Flutter {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )

    if ($script:UseFvm) {
        & fvm flutter @Args
    } else {
        & flutter @Args
    }

    if ($LASTEXITCODE -ne 0) {
        throw ("Flutter command failed: " + ($Args -join ' '))
    }
}

function Get-FirstExistingFile {
    param([string[]]$Paths)

    foreach ($path in $Paths) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return (Get-Item -LiteralPath $path).FullName
        }
    }

    return $null
}

function Get-AndroidApkPath {
    param([string]$Flavor)

    $apkDir = Join-Path $root 'build/app/outputs/flutter-apk'
    $apk = Get-ChildItem -Path $apkDir -Filter "app*$Flavor*release.apk" -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $apk) {
        $apk = Get-ChildItem -Path $apkDir -Filter 'app-release.apk' -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }
    if (-not $apk) {
        throw "APK not found for flavor '$Flavor' in $apkDir"
    }

    return $apk.FullName
}

function Get-WindowsReleaseDir {
    $default = Join-Path $root 'build/windows/x64/runner/Release'
    if (Test-Path -LiteralPath $default) {
        return (Get-Item -LiteralPath $default).FullName
    }

    $candidate = Get-ChildItem -Path (Join-Path $root 'build/windows') -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match 'runner[\\/]+Release$' } |
        Select-Object -First 1

    if (-not $candidate) {
        throw 'Windows release directory not found.'
    }

    return $candidate.FullName
}

function Get-CoreBinaryPath {
    $envKeys = @('9.9_CORE_PATH', 'XRAY_EXE_PATH', 'V2RAY_EXE_PATH')
    $searchNames = @('xray.exe', 'v2ray.exe')
    $searchRoots = @(
        (Join-Path $root 'windows/bin/windows'),
        (Join-Path $root 'bin/windows'),
        (Join-Path $root 'windows'),
        $root
    )

    foreach ($key in $envKeys) {
        $value = [Environment]::GetEnvironmentVariable($key)
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        if (Test-Path -LiteralPath $value -PathType Leaf) {
            return (Get-Item -LiteralPath $value).FullName
        }

        if (Test-Path -LiteralPath $value -PathType Container) {
            foreach ($name in $searchNames) {
                $candidate = Join-Path $value $name
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    return (Get-Item -LiteralPath $candidate).FullName
                }
            }
        }
    }

    foreach ($rootDir in $searchRoots) {
        foreach ($name in $searchNames) {
            $candidate = Join-Path $rootDir $name
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return (Get-Item -LiteralPath $candidate).FullName
            }
        }
    }

    throw 'Windows core not found. Set 9.9_CORE_PATH, XRAY_EXE_PATH, or V2RAY_EXE_PATH.'
}

function Copy-CoreBinaryToRelease {
    param(
        [string]$SourcePath,
        [string]$ReleaseDir
    )

    $destPath = Join-Path $ReleaseDir 'xray.exe'
    Copy-Item -LiteralPath $SourcePath -Destination $destPath -Force
    return $destPath
}

function New-SfxPackage {
    param(
        [string]$SourceDir,
        [string]$OutputExe,
        [string]$RunProgram
    )

    $sevenZip = Get-FirstExistingFile @(
        (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
        (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe'),
        ((Get-Command 7z.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1))
    )
    $sfx = Get-FirstExistingFile @(
        (Join-Path $env:ProgramFiles '7-Zip\7z.sfx'),
        (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.sfx')
    )

    if (-not $sevenZip -or -not $sfx) {
        throw '7-Zip not found.'
    }

    $tempDir = Join-Path $root 'build/package-tmp'
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    $archive = Join-Path $tempDir 'payload.7z'
    $config = Join-Path $tempDir 'config.txt'
    Remove-Item -LiteralPath $archive, $config -Force -ErrorAction SilentlyContinue

    Push-Location $SourceDir
    try {
        & $sevenZip a -t7z $archive '*' | Out-Null
    } finally {
        Pop-Location
    }

    @"
;!@Install@!UTF-8!
RunProgram="$RunProgram"
GUIMode="2"
;!@InstallEnd@!
"@ | Set-Content -LiteralPath $config -Encoding UTF8

    $outDir = Split-Path -Parent $OutputExe
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    $outStream = [System.IO.File]::Create($OutputExe)
    try {
        foreach ($path in @($sfx, $config, $archive)) {
            $bytes = [System.IO.File]::ReadAllBytes($path)
            $outStream.Write($bytes, 0, $bytes.Length)
        }
    } finally {
        $outStream.Dispose()
    }
}

$script:UseFvm = [bool](Get-Command fvm -ErrorAction SilentlyContinue)

Write-Host 'Building APKs...'
Invoke-Flutter build apk --release --flavor vpn --dart-define=FLAVOR=vpn
$vpnApk = Get-AndroidApkPath -Flavor 'vpn'

Invoke-Flutter build apk --release --flavor acc --dart-define=FLAVOR=acc
$accApk = Get-AndroidApkPath -Flavor 'acc'

$distRoot = Join-Path $root 'dist'
$androidOut = Join-Path $distRoot 'android'
$versionName = Get-FlutterVersionName
$vpnArtifactName = "9.9vpn_$versionName"
$accArtifactName = "9.9acc_$versionName"
New-Item -ItemType Directory -Path $androidOut -Force | Out-Null
Copy-Item -LiteralPath $vpnApk -Destination (Join-Path $androidOut "$vpnArtifactName.apk") -Force
Copy-Item -LiteralPath $accApk -Destination (Join-Path $androidOut "$accArtifactName.apk") -Force

Write-Host 'Building Windows VPN package...'
$corePath = Get-CoreBinaryPath
$windowsOut = Join-Path $distRoot 'windows'
New-Item -ItemType Directory -Path $windowsOut -Force | Out-Null
$windowsRunnerName = '9.9.exe'

$releaseName = '9.9'
${env:9.9_WINDOWS_EXE_NAME} = $releaseName
Invoke-Flutter build windows --release --dart-define=FLAVOR=vpn
$releaseDir = Get-WindowsReleaseDir
$stagingVpn = Join-Path $root 'build/package/windows-vpn'
Remove-Item -LiteralPath $stagingVpn -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagingVpn -Force | Out-Null
Copy-Item -Path (Join-Path $releaseDir '*') -Destination $stagingVpn -Recurse -Force
Copy-CoreBinaryToRelease -SourcePath $corePath -ReleaseDir $stagingVpn | Out-Null
New-SfxPackage -SourceDir $stagingVpn -OutputExe (Join-Path $windowsOut "$vpnArtifactName.exe") -RunProgram $windowsRunnerName

$releaseName = '9.9'
${env:9.9_WINDOWS_EXE_NAME} = $releaseName
Invoke-Flutter build windows --release --dart-define=FLAVOR=acc
$releaseDir = Get-WindowsReleaseDir
$stagingAcc = Join-Path $root 'build/package/windows-acc'
Remove-Item -LiteralPath $stagingAcc -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagingAcc -Force | Out-Null
Copy-Item -Path (Join-Path $releaseDir '*') -Destination $stagingAcc -Recurse -Force
Copy-CoreBinaryToRelease -SourcePath $corePath -ReleaseDir $stagingAcc | Out-Null
New-SfxPackage -SourceDir $stagingAcc -OutputExe (Join-Path $windowsOut "$accArtifactName.exe") -RunProgram $windowsRunnerName

Write-Host 'Done.'
Write-Host "Android: $androidOut"
Write-Host "Windows: $windowsOut"
