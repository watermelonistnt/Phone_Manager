<#
.SYNOPSIS
  Copy photo(s) from an Android phone over USB (MTP) without adb.

.DESCRIPTION
  Uses the Windows Shell (same layer as File Explorer) because MTP devices do not
  always get a drive letter. Requires USB + File transfer/MTP and the phone visible
  under "This PC".

.PARAMETER DeviceName
  Substring of the phone name as shown under This PC (e.g. "Galaxy"). If omitted and
  exactly one portable-style child exists, that child is used; if multiple match, you must pass this.

.PARAMETER RelativePath
  Path under the phone, backslash-separated.
  Leave empty or pass AUTO to search for **/DCIM/Camera under internal storage (any locale
  name for the internal volume, e.g. 內部儲存裝置/DCIM/Camera).
  Otherwise set an explicit path; if it starts with English "Internal storage", localized
  internal volume names are still tried for that first segment. You may pass DCIM\Camera
  only (resolved under internal storage).
.PARAMETER MaxSearchDepth
  When using AUTO discovery, max folder depth to search below internal storage (default 20).

.PARAMETER Destination
  Folder on this PC to receive files (created if missing). Default: repo tmp/mtp-incoming.

.PARAMETER MaxFiles
  Maximum image files to copy (default 1 for a quick test).

.PARAMETER ListOnly
  If set, only print what would be used; no copy.

.PARAMETER UseRepoConfig
  Load merged config.json + config.local.json from the repo root (via tools/read_merged_config.py)
  and apply the active user/phone MTP fields when DeviceName / RelativePath / MaxSearchDepth are
  not passed on the command line. Explicit CLI parameters always win.

.EXAMPLE
  .\tools\mtp_copy.ps1 -ListOnly
.EXAMPLE
  .\tools\mtp_copy.ps1 -DeviceName "Pixel" -MaxFiles 3
.EXAMPLE
  .\tools\mtp_copy.ps1 -UseRepoConfig -ListOnly
#>
[CmdletBinding()]
param(
    [string] $DeviceName = "",
    [string] $RelativePath = "",
    [string] $Destination = "",
    [int] $MaxFiles = 1,
    [int] $MaxSearchDepth = 20,
    [switch] $ListOnly,
    [switch] $UseRepoConfig
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Destination) {
    $Destination = Join-Path $repoRoot "tmp\mtp-incoming"
}

function Get-ActivePhoneProfileFromMerged {
    param($Merged)
    $uid = $Merged.activeUserId
    $pid = $Merged.activePhoneId
    if (-not $uid -or -not $pid) {
        return $null
    }
    try {
        $user = $Merged.users.$uid
        $phone = $user.phones.$pid
    }
    catch {
        return $null
    }
    if (-not $phone) {
        return $null
    }
    $mtp = $phone.mtp
    $depth = 20
    if ($mtp -and ($null -ne $mtp.maxSearchDepth)) {
        try {
            $depth = [int]$mtp.maxSearchDepth
        }
        catch {
            $depth = 20
        }
    }
    if ($depth -lt 1) {
        $depth = 20
    }
    $rel = ""
    if ($mtp) {
        if ($null -ne $mtp.cameraRelativePath -and [string]$mtp.cameraRelativePath.Trim()) {
            $rel = [string]$mtp.cameraRelativePath
        }
        elseif ($null -ne $mtp.relativePath) {
            $rel = [string]$mtp.relativePath
        }
    }
    $wa = ""
    if ($mtp -and ($null -ne $mtp.whatsappMediaRelativePath)) {
        $wa = [string]$mtp.whatsappMediaRelativePath
    }
    $dn = ""
    if ($null -ne $phone.thisPcDeviceNameSubstring) {
        $dn = [string]$phone.thisPcDeviceNameSubstring
    }
    return @{
        DeviceNameSubstring       = $dn.Trim()
        RelativePath              = $rel.Trim()
        MaxSearchDepth            = $depth
        WhatsappMediaRelativePath = $wa.Trim()
    }
}

if ($UseRepoConfig) {
    $reader = Join-Path $PSScriptRoot "read_merged_config.py"
    if (-not (Test-Path -LiteralPath $reader)) {
        throw "Missing read_merged_config.py next to mtp_copy.ps1: $reader"
    }
    $py = $null
    foreach ($name in @("py", "python")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) {
            $py = $cmd.Path
            break
        }
    }
    if (-not $py) {
        throw "Python (py or python) on PATH is required for -UseRepoConfig."
    }
    Push-Location $RepoRoot
    try {
        $mergedText = & $py @("-3.12", $reader, $RepoRoot)
        if ($LASTEXITCODE -ne 0) {
            $mergedText = & $py @($reader, $RepoRoot)
        }
    }
    finally {
        Pop-Location
    }
    if (-not $mergedText) {
        throw "read_merged_config.py returned no output."
    }
    $mergedObj = $mergedText | ConvertFrom-Json
    $prof = Get-ActivePhoneProfileFromMerged -Merged $mergedObj
    if ($prof) {
        if (-not $PSBoundParameters.ContainsKey("DeviceName")) {
            $DeviceName = $prof.DeviceNameSubstring
        }
        if (-not $PSBoundParameters.ContainsKey("RelativePath")) {
            $RelativePath = $prof.RelativePath
        }
        if (-not $PSBoundParameters.ContainsKey("MaxSearchDepth")) {
            $MaxSearchDepth = $prof.MaxSearchDepth
        }
        Write-Host "Applied repo config profile (active user/phone MTP defaults where CLI omitted)."
        if ($prof.WhatsappMediaRelativePath) {
            Write-Host ("Configured WhatsApp media (relative to internal storage): {0}" -f $prof.WhatsappMediaRelativePath)
        }
    }
    else {
        Write-Host "UseRepoConfig: no active user/phone profile found; CLI defaults unchanged."
    }
}

# OEM / locale labels for the built-in flash volume (first folder under the phone in MTP).
$script:InternalStorageAliases = @(
    "Internal storage",
    "Internal shared storage",
    "Phone storage",
    "內部儲存裝置",
    "内部存储空间"
)

function Get-ThisPcShellFolder {
    $shell = New-Object -ComObject Shell.Application
    # 0x11 = ssfDRIVES ("My Computer" / This PC)
    $folder = $shell.NameSpace(0x11)
    if (-not $folder) {
        throw "Shell.Application could not open namespace 0x11 (This PC)."
    }
    return @{ Shell = $shell; Folder = $folder }
}

function Find-DeviceItem {
    param(
        $RootFolder,
        [string] $NameSubstring
    )
    $items = @()
    foreach ($it in $RootFolder.Items()) {
        $items += , $it
    }
    if ($items.Count -eq 0) {
        throw "No items under This PC. Is the phone connected with File transfer / MTP?"
    }

    $matches = @()
    foreach ($it in $items) {
        if (-not $NameSubstring) {
            $matches += , $it
        }
        elseif ($it.Name -like "*$NameSubstring*") {
            $matches += , $it
        }
    }

    if ($NameSubstring) {
        if ($matches.Count -eq 0) {
            $names = ($items | ForEach-Object { $_.Name }) -join "`n  - "
            throw "No device name matches '$NameSubstring'. Under This PC:`n  - $names"
        }
        if ($matches.Count -gt 1) {
            $m = ($matches | ForEach-Object { $_.Name }) -join "; "
            throw "Multiple devices match '$NameSubstring': $m. Use a longer -DeviceName string."
        }
        return $matches[0]
    }

    # No substring: prefer items that do not look like "Local Disk (C:)" / DVD drives
    $nonDrives = @($items | Where-Object { $_.Name -notmatch '\([A-Z]:\)\s*$' })
    if ($nonDrives.Count -eq 1) {
        return $nonDrives[0]
    }
    if ($nonDrives.Count -eq 0) {
        $names = ($items | ForEach-Object { $_.Name }) -join "`n  - "
        throw "Could not guess phone under This PC. Pass -DeviceName.`n  - $names"
    }
    $names = ($nonDrives | ForEach-Object { $_.Name }) -join "`n  - "
    throw "Multiple possible phones. Pass -DeviceName.`n  - $names"
}

function Resolve-ShellChildFolder {
    param(
        $FolderItem,
        [string] $SegmentName
    )
    $want = $SegmentName.Trim()
    $folder = $FolderItem.GetFolder()
    foreach ($child in $folder.Items()) {
        $cn = [string]$child.Name
        if ([string]::Equals($cn.Trim(), $want, [StringComparison]::OrdinalIgnoreCase)) {
            return $child
        }
    }
    $avail = @()
    foreach ($child in $folder.Items()) {
        $avail += $child.Name
    }
    throw "Missing folder '$SegmentName' under '$($FolderItem.Name)'. Children: $($avail -join ', ')"
}

function Try-ResolveShellChildFolder {
    param(
        $FolderItem,
        [string] $SegmentName
    )
    try {
        return Resolve-ShellChildFolder -FolderItem $FolderItem -SegmentName $SegmentName
    }
    catch {
        return $null
    }
}

function Test-ShellItemIsFolder {
    param($Item)
    if ($null -eq $Item) {
        return $false
    }
    # MTP: IsFolder is often wrong; opening as folder is reliable.
    try {
        $null = $Item.GetFolder()
        return $true
    }
    catch {
        return $false
    }
}

function Find-DcimCameraFolder {
    param(
        [Parameter(Mandatory)]$StartFolderItem,
        [int] $MaxDepth = 20
    )
    $queue = New-Object System.Collections.Queue
    $null = $queue.Enqueue(@($StartFolderItem, 0))
    while ($queue.Count -gt 0) {
        $state = @($queue.Dequeue())
        $node = $state[0]
        $depth = [int]$state[1]
        if ($depth -gt $MaxDepth) {
            continue
        }
        $folder = $node.GetFolder()
        foreach ($child in $folder.Items()) {
            if (-not (Test-ShellItemIsFolder -Item $child)) {
                continue
            }
            if ($child.Name -ieq "DCIM") {
                $dcimFolder = $child.GetFolder()
                foreach ($inner in $dcimFolder.Items()) {
                    if ((Test-ShellItemIsFolder -Item $inner) -and ($inner.Name -ieq "Camera")) {
                        return $inner
                    }
                }
            }
            $null = $queue.Enqueue(@($child, $depth + 1))
        }
    }
    return $null
}

function Find-InternalStorageRoot {
    param($DeviceRootItem)
    foreach ($alias in $script:InternalStorageAliases) {
        $child = Try-ResolveShellChildFolder -FolderItem $DeviceRootItem -SegmentName $alias
        if ($child) {
            return $child
        }
    }

    # Many phones expose exactly one navigable root (e.g. 內部儲存裝置) — use it even if the
    # label differs from our alias table (Unicode / OEM spelling).
    $deviceFolder = $DeviceRootItem.GetFolder()
    $navigable = [System.Collections.Generic.List[object]]::new()
    foreach ($c in $deviceFolder.Items()) {
        if (Test-ShellItemIsFolder -Item $c) {
            $null = $navigable.Add($c)
        }
    }
    if ($navigable.Count -eq 1) {
        $only = $navigable[0]
        Write-Host "  Using sole navigable folder under device as internal storage: $($only.Name)"
        return $only
    }

    $avail = @()
    foreach ($child in $deviceFolder.Items()) {
        $avail += $child.Name
    }
    throw (
        "Could not find internal storage root (tried aliases + single-folder heuristic). " +
        "Children under device: $($avail -join ', '). Pass -RelativePath with your exact first folder name."
    )
}

function Resolve-DeviceSubfolder {
    param(
        $DeviceRootItem,
        [string] $RelativePath
    )
    $segments = @($RelativePath -split "\\" | Where-Object { $_ })
    if ($segments.Count -eq 0) {
        throw "RelativePath is empty."
    }

    $firstIsEnglishInternal = ($segments[0] -ceq "Internal storage")
    $trialsFirst = [System.Collections.Generic.List[string]]::new()
    if ($firstIsEnglishInternal) {
        foreach ($n in @("Internal storage") + $script:InternalStorageAliases) {
            if (-not $trialsFirst.Contains($n)) {
                $null = $trialsFirst.Add($n)
            }
        }
    }
    else {
        $null = $trialsFirst.Add($segments[0])
    }

    foreach ($trial in $trialsFirst) {
        $rootChild = Try-ResolveShellChildFolder -FolderItem $DeviceRootItem -SegmentName $trial
        if (-not $rootChild) {
            continue
        }
        try {
            $current = $rootChild
            foreach ($seg in ($segments | Select-Object -Skip 1)) {
                $current = Resolve-ShellChildFolder -FolderItem $current -SegmentName $seg
            }
            return $current
        }
        catch {
            # Wrong internal root or missing subfolder under this candidate — try next alias.
            continue
        }
    }

    $internal = Find-InternalStorageRoot -DeviceRootItem $DeviceRootItem
    $current = $internal
    foreach ($seg in $segments) {
        $current = Resolve-ShellChildFolder -FolderItem $current -SegmentName $seg
    }
    return $current
}

function Get-ImageShellItems {
    param($FolderItem)
    $folder = $FolderItem.GetFolder()
    $out = @()
    foreach ($it in $folder.Items()) {
        if ($it.Name -match '\.(jpe?g|png|heic|webp)$') {
            $out += , $it
        }
    }
    if ($out.Count -eq 0) {
        throw "No image files (.jpg/.jpeg/.png/.heic/.webp) in folder '$($FolderItem.Name)'."
    }
    return $out | Sort-Object { $_.Name }
}

$ctx = Get-ThisPcShellFolder
$shell = $ctx.Shell
$root = $ctx.Folder

Write-Host "Resolving device under This PC..."
$deviceItem = Find-DeviceItem -RootFolder $root -NameSubstring $DeviceName
Write-Host "  Device: $($deviceItem.Name)"

$useAuto = [string]::IsNullOrWhiteSpace($RelativePath) -or ($RelativePath.Trim() -ieq "AUTO")
if ($useAuto) {
    Write-Host "Searching for **/DCIM/Camera under internal storage (max depth $MaxSearchDepth)..."
    $internalRoot = Find-InternalStorageRoot -DeviceRootItem $deviceItem
    Write-Host "  Internal volume: $($internalRoot.Name)"
    $cameraItem = Find-DcimCameraFolder -StartFolderItem $internalRoot -MaxDepth $MaxSearchDepth
    if (-not $cameraItem) {
        throw (
            "Could not find a DCIM/Camera folder under internal storage. " +
            "Try increasing -MaxSearchDepth or pass an explicit -RelativePath."
        )
    }
    Write-Host "  Found folder: $($cameraItem.Name) (under .../DCIM/Camera)"
}
else {
    Write-Host "Opening explicit path: $RelativePath"
    $cameraItem = Resolve-DeviceSubfolder -DeviceRootItem $deviceItem -RelativePath $RelativePath
}

$images = @(Get-ImageShellItems -FolderItem $cameraItem)
Write-Host "  Found $($images.Count) image file(s); will use first $([Math]::Min($MaxFiles, $images.Count))."

if ($ListOnly) {
    $preview = $images | Select-Object -First $MaxFiles | ForEach-Object { $_.Name }
    Write-Host "ListOnly - would copy:"
    $preview | ForEach-Object { Write-Host "    $_" }
    exit 0
}

$null = New-Item -ItemType Directory -Force -Path $Destination
$destFull = (Resolve-Path -LiteralPath $Destination).Path
Write-Host "Destination: $destFull"

$destFolder = $shell.NameSpace($destFull)
if (-not $destFolder) {
    throw "Shell could not open destination folder: $destFull"
}

# FOF_SILENT | FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_NOCONFIRMMKDIR (common MTP copy flags)
$copyFlags = 4 + 16 + 1024 + 512

$take = [Math]::Min($MaxFiles, $images.Count)
for ($i = 0; $i -lt $take; $i++) {
    $file = $images[$i]
    Write-Host "Copying: $($file.Name)"
    $destFolder.CopyHere($file, $copyFlags)
    Start-Sleep -Milliseconds 400
}

Write-Host "Done. If files are still copying, wait a few seconds and check:`n  $destFull"
