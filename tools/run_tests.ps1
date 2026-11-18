param(
    [string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Resolve-GodotBinary {
    param([string]$Requested)

    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        if (Test-Path $Requested) {
            return (Resolve-Path $Requested).Path
        }
        throw "GODOT_BIN definido, mas nao encontrado: $Requested"
    }

    foreach ($candidate in @("godot", "godot4")) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    }

    $localDefault = "C:\Users\gabri\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
    if (Test-Path $localDefault) {
        return $localDefault
    }

    throw "Binario do Godot 4.7 nao encontrado. Defina GODOT_BIN ou adicione 'godot' ao PATH."
}

function Invoke-GodotStep {
    param(
        [string]$Bin,
        [string]$Label,
        [string[]]$GodotArgs
    )

    Write-Host ""
    Write-Host "=== $Label ===" -ForegroundColor Cyan

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $Bin
    $psi.WorkingDirectory = $RepoRoot
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $quotedArgs = $GodotArgs | ForEach-Object {
        if ($_ -match '\s|"' ) {
            '"' + ($_ -replace '"', '\"') + '"'
        } else {
            $_
        }
    }
    $psi.Arguments = ($quotedArgs -join " ")

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit()

    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $combined = ($stdout + "`n" + $stderr).TrimEnd()
    if (-not [string]::IsNullOrWhiteSpace($combined)) {
        Write-Host $combined
    }

    $exitCode = $proc.ExitCode
    if ($exitCode -ne 0) {
        throw "$Label falhou com codigo de saida $exitCode."
    }
    if ($combined -match "SCRIPT ERROR:|Parse Error:|ObjectDB instance was leaked") {
        throw "$Label apresentou erro de script ou vazamento de memoria (ObjectDB)."
    }
}

$ResolvedGodot = Resolve-GodotBinary -Requested $GodotBin
Write-Host "Godot: $ResolvedGodot"
Write-Host "Projeto: $RepoRoot"

$ClassCache = Join-Path $RepoRoot ".godot\global_script_class_cache.cfg"
if (-not (Test-Path $ClassCache)) {
    Invoke-GodotStep -Bin $ResolvedGodot -Label "0. Importacao inicial de classes/UIDs" -GodotArgs @("--headless", "--import", "--path", $RepoRoot)
}

Invoke-GodotStep -Bin $ResolvedGodot -Label "1/3 Suite GUT (tests/)" -GodotArgs @(
    "--headless", "--path", $RepoRoot,
    "-s", "res://addons/gut/gut_cmdln.gd",
    "-gdir=res://tests", "-ginclude_subdirs", "-gexit"
)

Invoke-GodotStep -Bin $ResolvedGodot -Label "2/3 Validacao de layout UI (test_ui_layout.gd)" -GodotArgs @(
    "--headless", "--path", $RepoRoot,
    "-s", "res://scenes/ui/test_ui_layout.gd"
)

Invoke-GodotStep -Bin $ResolvedGodot -Label "3/3 Smoke test Main.tscn (600 frames)" -GodotArgs @(
    "--headless", "--path", $RepoRoot,
    "--quit-after", "600"
)

Write-Host ""
Write-Host "ALL CHECKS PASSED" -ForegroundColor Green
exit 0
