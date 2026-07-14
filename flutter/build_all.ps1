param(
    [ValidateSet('all', 'android', 'windows')]
    [string]$Target = 'all'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

$expectedFlutterVersion = '3.27.0'
$preferredFlutter = Join-Path $projectRoot ".fvm\versions\$expectedFlutterVersion\bin\flutter.bat"
$linkedFlutter = Join-Path $projectRoot '.fvm\flutter_sdk\bin\flutter.bat'
$userFvmFlutter = Join-Path $env:USERPROFILE "fvm\versions\$expectedFlutterVersion\bin\flutter.bat"
$installerScript = Join-Path $projectRoot 'windows_installer.iss'
$appPublisher = '9.9 Company, Inc.'
$appUrl = 'https://jsq.wangwei.tech/'

function Get-FlutterCommand {
    if (Test-Path $preferredFlutter) {
        return $preferredFlutter
    }

    if (Test-Path $linkedFlutter) {
        return $linkedFlutter
    }

    if (Test-Path $userFvmFlutter) {
        return $userFvmFlutter
    }

    $globalFlutter = Get-Command flutter -ErrorAction SilentlyContinue
    if ($null -ne $globalFlutter) {
        return $globalFlutter.Source
    }

    throw 'Flutter was not found. FVM SDK is also missing.'
}

function Get-InnoCompiler {
    function Resolve-InnoPath {
        param(
            [Parameter(Mandatory = $false)]
            [AllowNull()]
            [AllowEmptyString()]
            [string]$Path
        )

        if ([string]::IsNullOrWhiteSpace($Path)) {
            return $null
        }

        $candidate = $Path.Trim('"', ' ', "`t")
        if (-not [System.IO.Path]::IsPathRooted($candidate)) {
            $candidate = Join-Path $projectRoot $candidate
        }

        $resolved = Resolve-Path $candidate -ErrorAction SilentlyContinue
        if ($null -ne $resolved -and (Test-Path $resolved.Path -PathType Leaf)) {
            return $resolved.Path
        }
        return $null
    }

    $envCompiler = [Environment]::GetEnvironmentVariable('INNO_SETUP_PATH')
    if ([string]::IsNullOrWhiteSpace($envCompiler)) {
        $envCompiler = [Environment]::GetEnvironmentVariable('ISCC_PATH')
    }
    if (-not [string]::IsNullOrWhiteSpace($envCompiler)) {
        $resolved = Resolve-InnoPath -Path $envCompiler
        if ($null -ne $resolved) {
            return $resolved
        }
    }

    $globalCompiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($null -ne $globalCompiler) {
        return $globalCompiler.Source
    }

    $registryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 5_is1',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 5_is1'
    )

    foreach ($reg in $registryPaths) {
        if (Test-Path $reg) {
            $installDir = (Get-ItemProperty -Path $reg -ErrorAction SilentlyContinue).InstallLocation
            if (-not [string]::IsNullOrWhiteSpace($installDir)) {
                $resolved = Resolve-InnoPath -Path (Join-Path $installDir 'ISCC.exe')
                if ($null -ne $resolved) {
                    return $resolved
                }
            }
        }
    }

    $candidateRoots = @(
        ${env:ProgramFiles},
        ${env:ProgramFiles(x86)}
    )

    $candidates = @()
    foreach ($root in $candidateRoots) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            continue
        }

        if (Test-Path $root) {
            Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like 'Inno Setup*' } |
                ForEach-Object { $candidates += Join-Path $_.FullName 'ISCC.exe' }
        }
    }

    $candidates += @(
        'C:\Program Files\Inno Setup 6\ISCC.exe',
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 5\ISCC.exe',
        'C:\Program Files (x86)\Inno Setup 5\ISCC.exe'
    )

    foreach ($candidate in $candidates) {
        $resolved = Resolve-InnoPath -Path $candidate
        if ($null -ne $resolved) {
            return $resolved
        }
    }

    throw 'ISCC.exe was not found. Install Inno Setup or set ISCC_PATH/INNO_SETUP_PATH.'
}

function Invoke-Flutter {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    Write-Host ">> flutter $($Arguments -join ' ')" -ForegroundColor Cyan
    & $script:flutterCommand @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter command failed: flutter $($Arguments -join ' ')"
    }
}

function Invoke-InnoCompiler {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    Write-Host ">> iscc $($Arguments -join ' ')" -ForegroundColor Cyan
    & $script:innoCompiler @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup compile failed: ISCC.exe $($Arguments -join ' ')"
    }
}

function Get-AppVersion {
    $versionLine = Select-String -Path (Join-Path $projectRoot 'pubspec.yaml') -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(\+\d+)?\s*$' | Select-Object -First 1
    if ($null -eq $versionLine) {
        throw 'Failed to parse app version from pubspec.yaml.'
    }

    return $versionLine.Matches[0].Groups[1].Value
}

function Find-CoreBinary {
    $candidatePaths = @(
        (Join-Path $projectRoot 'windows\bin\windows\xray.exe'),
        (Join-Path $projectRoot 'windows\bin\windows\v2ray.exe'),
        (Join-Path $projectRoot '..\bin\windows\xray.exe'),
        (Join-Path $projectRoot '..\bin\windows\v2ray.exe')
    )

    foreach ($envName in @('9.9_CORE_PATH', 'XRAY_EXE_PATH', 'V2RAY_EXE_PATH')) {
        $envValue = [Environment]::GetEnvironmentVariable($envName)
        if (-not [string]::IsNullOrWhiteSpace($envValue)) {
            $candidatePaths += $envValue
        }
    }

    foreach ($candidate in $candidatePaths) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        if (Test-Path $candidate -PathType Leaf) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

function Get-WindowsPackagingConfig {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('vpn', 'acc')]
        [string]$Flavor
    )

    switch ($Flavor) {
        'vpn' {
            return @{
                AppName = '9.9 VPN'
                AppGuid = '9F69C65B-6DF2-4895-88B7-46A1E9B8E4B1'
            }
        }
        'acc' {
            return @{
                AppName = '9.9 Accelerator'
                AppGuid = '0D5EE5D0-C8BE-4738-BE16-9A2B05F7547A'
            }
        }
    }
}

function Build-AndroidArtifact {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('vpn', 'acc')]
        [string]$Flavor,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$DistDir
    )

    Invoke-Flutter -Arguments @('build', 'apk', '--release', '--flavor', $Flavor, "--dart-define=FLAVOR=$Flavor")

    $sourceApk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-$Flavor-release.apk"
    if (-not (Test-Path $sourceApk -PathType Leaf)) {
        throw "APK artifact not found: $sourceApk"
    }

    $targetApk = Join-Path $DistDir "9.9$Flavor`_$Version.apk"
    Copy-Item -Path $sourceApk -Destination $targetApk -Force
}

function Test-ValidZipFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path -PathType Leaf)) {
        return $false
    }

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        $valid = $zip.Entries.Count -gt 0
        $zip.Dispose()
        return $valid
    } catch {
        return $false
    }
}

function Get-RemoteContentLength {
    param([Parameter(Mandatory = $true)][string]$Url)

    $output = curl.exe -sI $Url | Out-String
    if ($output -match 'Content-Length:\s*(\d+)') {
        return [long]$Matches[1]
    }
    throw "Failed to read Content-Length for $Url"
}

function Download-EngineZip {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $expectedLength = Get-RemoteContentLength -Url $Url

    $dir = Split-Path $Destination -Parent
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    for ($attempt = 1; $attempt -le 30; $attempt++) {
        $resume = $false
        if (Test-Path $Destination -PathType Leaf) {
            $currentLength = (Get-Item $Destination).Length
            if ($currentLength -ge $ExpectedLength -and (Test-ValidZipFile -Path $Destination)) {
                return
            }
            if ($currentLength -gt 0 -and $currentLength -lt $ExpectedLength) {
                $resume = $true
            } else {
                Remove-Item $Destination -Force -ErrorAction SilentlyContinue
            }
        }

        Write-Host "  downloading $([IO.Path]::GetFileName($Destination)) attempt $attempt/30 ($ExpectedLength bytes)" -ForegroundColor DarkCyan
        $curlArgs = @(
            '-L', '--ssl-no-revoke', '--retry', '3', '--retry-delay', '2', '--connect-timeout', '30',
            '-o', $Destination
        )
        if ($resume) {
            $curlArgs += @('-C', '-')
        }
        $curlArgs += $Url
        & curl.exe @curlArgs | Out-Null
        Start-Sleep -Milliseconds 500

        if ((Test-Path $Destination -PathType Leaf) -and (Test-ValidZipFile -Path $Destination)) {
            $actualLength = (Get-Item $Destination).Length
            if ($actualLength -ge $ExpectedLength) {
                return
            }
        }
        Start-Sleep -Seconds 2
    }

    throw "Failed to download engine zip: $Url"
}

function Expand-EngineZip {
    param(
        [Parameter(Mandatory = $true)][string]$ZipPath,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (Test-Path $Destination) {
        Remove-Item $Destination -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Expand-Archive -Path $ZipPath -DestinationPath $Destination -Force

    $nested = Join-Path $Destination 'windows-x64-flutter'
    if (Test-Path $nested -PathType Container) {
        Get-ChildItem $nested | Move-Item -Destination $Destination -Force
        Remove-Item $nested -Recurse -Force
    }

    if (-not (Test-Path (Join-Path $Destination 'flutter_windows.dll') -PathType Leaf)) {
        throw "Invalid engine artifact extracted to $Destination"
    }
}

function Repair-WindowsEngineCache {
    $flutterRoot = Split-Path (Split-Path $script:flutterCommand -Parent) -Parent
    $cacheRoot = Join-Path $flutterRoot 'bin\cache'
    $engineDir = Join-Path $cacheRoot 'artifacts\engine'
    $engineVersion = (& $script:flutterCommand --version --machine | ConvertFrom-Json).engineRevision
    $baseUrl = "https://storage.googleapis.com/flutter_infra_release/flutter/$engineVersion"
    $workDir = Join-Path $cacheRoot '_engine_repair'
    $artifacts = @(
        @{ Name = 'windows-x64-debug'; Path = 'windows-x64-debug/windows-x64-flutter.zip' },
        @{ Name = 'windows-x64-profile'; Path = 'windows-x64-profile/windows-x64-flutter.zip' },
        @{ Name = 'windows-x64-release'; Path = 'windows-x64-release/windows-x64-flutter.zip' }
    )

    $missing = @()
    foreach ($artifact in $artifacts) {
        $dll = Join-Path $engineDir "$($artifact.Name)\flutter_windows.dll"
        if (-not (Test-Path $dll -PathType Leaf)) {
            $missing += $artifact.Name
        }
    }
    if ($missing.Count -eq 0) {
        Write-Host 'Windows engine cache is ready.' -ForegroundColor Green
        return
    }

    Write-Host "Repairing Windows engine cache: $($missing -join ', ')" -ForegroundColor Yellow
    Get-Process -Name 'dart','flutter' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $cacheRoot 'flutter.bat.lock') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $cacheRoot 'lockfile') -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $workDir | Out-Null

    foreach ($artifact in $artifacts) {
        $dll = Join-Path $engineDir "$($artifact.Name)\flutter_windows.dll"
        if (Test-Path $dll -PathType Leaf) {
            continue
        }

        $zipPath = Join-Path $workDir ($artifact.Name + '.zip')
        $destDir = Join-Path $engineDir $artifact.Name
        Download-EngineZip -Url "$baseUrl/$($artifact.Path)" -Destination $zipPath
        Expand-EngineZip -ZipPath $zipPath -Destination $destDir
        Write-Host "  ready: $($artifact.Name)" -ForegroundColor Green
    }

    Set-Content -Path (Join-Path $cacheRoot 'windows-sdk.stamp') -Value $engineVersion -NoNewline
    $downloadRoot = Join-Path $cacheRoot "downloads\storage.googleapis.com\flutter_infra_release\flutter\$engineVersion"
    Remove-Item $downloadRoot -Recurse -Force -ErrorAction SilentlyContinue
}

function Build-WindowsArtifact {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('vpn', 'acc')]
        [string]$Flavor,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$DistDir,

        [string]$CoreBinary
    )

    Invoke-Flutter -Arguments @('build', 'windows', '--release', "--dart-define=FLAVOR=$Flavor")

    $releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
    if (-not (Test-Path $releaseDir -PathType Container)) {
        throw "Windows release directory not found: $releaseDir"
    }

    $stageDir = Join-Path $projectRoot "build\windows\package-$Flavor"
    if (Test-Path $stageDir) {
        Remove-Item -Path $stageDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $stageDir | Out-Null
    Copy-Item -Path (Join-Path $releaseDir '*') -Destination $stageDir -Recurse -Force

    $renamedExeName = "9.9$Flavor`_$Version.exe"
    $sourceExe = Join-Path $stageDir '9.9.exe'
    if (-not (Test-Path $sourceExe -PathType Leaf)) {
        throw "Windows executable not found: $sourceExe"
    }
    Rename-Item -Path $sourceExe -NewName $renamedExeName

    if (-not [string]::IsNullOrWhiteSpace($CoreBinary) -and (Test-Path $CoreBinary -PathType Leaf)) {
        Copy-Item -Path $CoreBinary -Destination (Join-Path $stageDir (Split-Path $CoreBinary -Leaf)) -Force
    } else {
        throw 'xray.exe or v2ray.exe was not found. Refusing to create a Windows installer that cannot connect.'
    }

    if (-not (Test-Path $installerScript -PathType Leaf)) {
        throw "Installer script not found: $installerScript"
    }

    $packaging = Get-WindowsPackagingConfig -Flavor $Flavor
    $iconFile = Join-Path $projectRoot 'windows\runner\resources\app_icon.ico'
    $installerName = "9.9$Flavor`_$Version`_windows"

    Invoke-InnoCompiler -Arguments @(
        "/DAppGuid=$($packaging.AppGuid)",
        "/DMyAppName=$($packaging.AppName)",
        "/DMyAppVersion=$Version",
        "/DMyAppPublisher=$appPublisher",
        "/DMyAppURL=$appUrl",
        "/DMyAppExeName=$renamedExeName",
        "/DMyOutputDir=$DistDir",
        "/DMyOutputBaseFilename=$installerName",
        "/DMySourceDir=$stageDir",
        "/DMyIconFile=$iconFile",
        $installerScript
    )
}

$script:flutterCommand = Get-FlutterCommand
$script:flutterSdkRoot = Split-Path -Parent (Split-Path -Parent $script:flutterCommand)
$env:FLUTTER_ROOT = $script:flutterSdkRoot
$env:PATH = @(
    (Join-Path $script:flutterSdkRoot 'bin'),
    (Join-Path $script:flutterSdkRoot 'bin\cache\dart-sdk\bin'),
    $env:PATH
) -join ';'
$script:innoCompiler = Get-InnoCompiler
$flutterVersionInfo = & $script:flutterCommand --version --machine | ConvertFrom-Json
if ($flutterVersionInfo.frameworkVersion -ne $expectedFlutterVersion) {
    throw "Expected Flutter $expectedFlutterVersion but found $($flutterVersionInfo.frameworkVersion)."
}

$appVersion = Get-AppVersion
$distDir = Join-Path $projectRoot 'dist'
$coreBinary = Find-CoreBinary

New-Item -ItemType Directory -Path $distDir -Force | Out-Null
switch ($Target) {
    'all' {
        Get-ChildItem -Path $distDir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    }
    'android' {
        Get-ChildItem -Path $distDir -Filter '*.apk' -Force -ErrorAction SilentlyContinue | Remove-Item -Force
    }
    'windows' {
        Get-ChildItem -Path $distDir -Filter '*_windows.exe' -Force -ErrorAction SilentlyContinue | Remove-Item -Force
    }
}

Invoke-Flutter -Arguments @('clean')
Invoke-Flutter -Arguments @('pub', 'get')

if ($Target -in @('all', 'android')) {
    Build-AndroidArtifact -Flavor 'vpn' -Version $appVersion -DistDir $distDir
    Build-AndroidArtifact -Flavor 'acc' -Version $appVersion -DistDir $distDir
}

if ($Target -in @('all', 'windows')) {
    Repair-WindowsEngineCache
    Build-WindowsArtifact -Flavor 'vpn' -Version $appVersion -DistDir $distDir -CoreBinary $coreBinary
    Build-WindowsArtifact -Flavor 'acc' -Version $appVersion -DistDir $distDir -CoreBinary $coreBinary
}

Write-Host ''
Write-Host 'Build completed. Artifacts:' -ForegroundColor Green
Get-ChildItem -Path $distDir | Select-Object Name, Length | Format-Table -AutoSize
