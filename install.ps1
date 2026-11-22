<#
  Install (or with -Uninstall remove) the SteamVR controller bindings for
  KORG Gadget VR on Windows.

    install.bat / uninstall.bat           (double-click)
    powershell -ExecutionPolicy Bypass -File install.ps1 [-GameDir <folder>] [-Uninstall]

  Copies bindings\*.json into the game's Config\SteamVRBindings folder and lists
  them as default bindings in steamvr_manifest.json. The unpatched manifest is
  kept as steamvr_manifest.json.orig. Steam's "Verify integrity" also undoes it.
#>
param([string]$GameDir, [switch]$Uninstall)
$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 otherwise writes some arrays as {"value":[...],"Count":n}
Remove-TypeData System.Array -ErrorAction SilentlyContinue

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$rel  = 'GadgetVRGame\Config\SteamVRBindings'

function Find-Game {
    $roots = @()
    $reg = Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue
    if ($reg -and $reg.SteamPath) { $roots += $reg.SteamPath }
    $roots += "${env:ProgramFiles(x86)}\Steam"
    foreach ($root in $roots) {
        $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path $vdf)) { continue }
        $libs = @($root)
        foreach ($match in [regex]::Matches((Get-Content -Raw $vdf), '"path"\s+"([^"]+)"')) {
            $libs += ($match.Groups[1].Value -replace '\\\\', '\')
        }
        foreach ($lib in $libs) {
            $game = Join-Path $lib 'steamapps\common\GadgetVRGame'
            if (Test-Path (Join-Path $game "$rel\steamvr_manifest.json")) { return $game }
        }
    }
    return $null
}

function Write-Manifest($obj, $path) {
    $text = $obj | ConvertTo-Json -Depth 32
    $tmp = "$path.tmp"
    [IO.File]::WriteAllText($tmp, $text + "`n", (New-Object Text.UTF8Encoding $false))  # no BOM
    Move-Item -Force $tmp $path
}

if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir) {
    throw "KORG Gadget VR not found. Run again with -GameDir 'D:\SteamLibrary\steamapps\common\GadgetVRGame'"
}
$dir      = Join-Path $GameDir $rel
$manifest = Join-Path $dir 'steamvr_manifest.json'
$backup   = "$manifest.orig"
if (-not (Test-Path $manifest)) { throw "No steamvr_manifest.json in $dir" }

$files = @(Get-ChildItem (Join-Path $here 'bindings') -Filter '*.json')
$ours = @()
foreach ($f in $files) {
    $ct = (Get-Content -Raw $f.FullName | ConvertFrom-Json).controller_type
    $ours += [pscustomobject]@{ controller_type = $ct; binding_url = $f.Name }
}
$names = @($ours | ForEach-Object { $_.binding_url })
$types = @($ours | ForEach-Object { $_.controller_type })

$m = Get-Content -Raw $manifest | ConvertFrom-Json
$current = @()
if ($m.PSObject.Properties['default_bindings']) { $current = @($m.default_bindings) }
$patched = @($current | Where-Object { $names -contains $_.binding_url }).Count -gt 0

if ($Uninstall) {
    if ($patched -and (Test-Path $backup)) {
        Move-Item -Force $backup $manifest
        Write-Host 'Restored the original steamvr_manifest.json'
    } elseif ($patched) {
        $keep = @($current | Where-Object { $names -notcontains $_.binding_url })
        $m.PSObject.Properties.Remove('default_bindings')
        if ($keep.Count -gt 0) { $m | Add-Member -NotePropertyName default_bindings -NotePropertyValue $keep }
        Write-Manifest $m $manifest
        Write-Host "Removed this fix's entries from steamvr_manifest.json"
    } else {
        if (Test-Path $backup) { Remove-Item -Force $backup }  # stale: Steam already restored it
        Write-Host 'steamvr_manifest.json was not patched'
    }
    foreach ($n in $names) {
        $p = Join-Path $dir $n
        if (Test-Path $p) { Remove-Item -Force $p }
    }
    Write-Host 'Removed the binding files. Restart SteamVR.'
    return
}

if (-not $patched) { Copy-Item -Force $manifest $backup }  # back up the current unpatched manifest
foreach ($f in $files) { Copy-Item -Force $f.FullName (Join-Path $dir $f.Name) }
$keep = @($current | Where-Object { $types -notcontains $_.controller_type })
$m.PSObject.Properties.Remove('default_bindings')
$m | Add-Member -NotePropertyName default_bindings -NotePropertyValue @($keep + $ours)
Write-Manifest $m $manifest
foreach ($o in $ours) { Write-Host ('  {0,-18} {1}' -f $o.controller_type, $o.binding_url) }
Write-Host "Installed into $dir"
Write-Host 'Restart SteamVR, then start the game.'
