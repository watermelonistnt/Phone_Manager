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

.PARAMETER NoDcimBfsPrune
  When set with AUTO discovery, do not skip expanding folder branches that are unlikely to
  contain DCIM/Camera (default: pruning is on — fewer MTP folder opens into e.g. Android/, Music/).
  AUTO also uses a two-queue BFS: folder names listed in merged mtp.dcimBfsPrioritySegments plus
  segments from confirmed camera/relative paths (not AUTO) are expanded before other branches.

.PARAMETER Destination
  Folder on this PC to receive files (created if missing). Default: repo tmp/mtp-incoming.

.PARAMETER MaxFiles
  Maximum image files to copy (default 1 for a quick test).

.PARAMETER ListOnly
  If set, only print what would be used; no copy.

.PARAMETER UseRepoConfig
  Load merged config from the repo root (via tools/read_merged_config.py) and apply the active
  user/phone MTP fields when DeviceName / RelativePath / MaxSearchDepth are not passed on the
  command line. Explicit CLI parameters always win. When the profile sets whatsappMediaRelativePath,
  the script resolves that folder after the camera step (same Resolve-DeviceSubfolder rules) and
  prints a short probe (top-level files; not recursive).

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
    [switch] $NoDcimBfsPrune,
    [switch] $ListOnly,
    [switch] $UseRepoConfig
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Destination) {
    $Destination = Join-Path $repoRoot "tmp\mtp-incoming"
}
$script:DcimBfsExtraPruneFromConfig = @()
$script:DcimBfsPrioritySegmentsFromConfig = @()
$script:WhatsappMediaRelativePathFromConfig = ""

function Get-MtpPathSegmentsExcludingAuto {
    param([string] $PathRaw)
    if ([string]::IsNullOrWhiteSpace($PathRaw)) {
        return @()
    }
    $t = $PathRaw.Trim()
    if ($t -ieq "AUTO") {
        return @()
    }
    return @($t -split "\\" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Build-DcimBfsPrioritySegmentHintsList {
    param(
        $MtpObject,
        [string[]] $ExplicitFromJson = @()
    )
    $seen = @{}
    $list = [System.Collections.Generic.List[string]]::new()
    function Add-One([string] $s) {
        if ([string]::IsNullOrWhiteSpace($s)) {
            return
        }
        $x = $s.Trim()
        if ($x -ieq "AUTO") {
            return
        }
        $k = $x.ToLowerInvariant()
        if ($seen.ContainsKey($k)) {
            return
        }
        $seen[$k] = $true
        $null = $list.Add($x)
    }
    foreach ($e in $ExplicitFromJson) {
        Add-One $e
    }
    $camSegs = @()
    $relSegs = @()
    if ($null -ne $MtpObject) {
        $pCam = $MtpObject.PSObject.Properties["cameraRelativePath"]
        if ($null -ne $pCam -and $null -ne $pCam.Value) {
            $camSegs = @(Get-MtpPathSegmentsExcludingAuto -PathRaw ([string]$pCam.Value))
        }
        $pRel = $MtpObject.PSObject.Properties["relativePath"]
        if ($null -ne $pRel -and $null -ne $pRel.Value) {
            $relSegs = @(Get-MtpPathSegmentsExcludingAuto -PathRaw ([string]$pRel.Value))
        }
    }
    foreach ($x in $camSegs) {
        Add-One $x
    }
    foreach ($x in $relSegs) {
        Add-One $x
    }
    foreach ($d in @("DCIM", "Camera")) {
        Add-One $d
    }
    return @($list)
}

function Get-ActivePhoneProfileFromMerged {
    param($Merged)
    $uid = $Merged.activeUserId
    # Do not use $pid — it aliases the read-only automatic $PID (process id).
    $phoneKey = $Merged.activePhoneId
    if (-not $uid -or -not $phoneKey) {
        return $null
    }
    try {
        $user = $Merged.users.$uid
        $phone = $user.phones.$phoneKey
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
    $dcimNoPrune = $false
    $dcimExtra = [System.Collections.Generic.List[string]]::new()
    if ($mtp) {
        $pruneProp = $mtp.PSObject.Properties["dcimBfsPrune"]
        if ($pruneProp -and ($pruneProp.Value -eq $false)) {
            $dcimNoPrune = $true
        }
        $extraProp = $mtp.PSObject.Properties["dcimBfsExtraPruneFolderNames"]
        if ($null -ne $extraProp -and $null -ne $extraProp.Value) {
            foreach ($x in @($extraProp.Value)) {
                $s = [string]$x
                if ($s.Trim()) {
                    $null = $dcimExtra.Add($s.Trim())
                }
            }
        }
    }
    $explicitPri = @()
    if ($mtp) {
        $priProp = $mtp.PSObject.Properties["dcimBfsPrioritySegments"]
        if ($null -ne $priProp -and $null -ne $priProp.Value) {
            foreach ($x in @($priProp.Value)) {
                $s = [string]$x
                if ($s.Trim()) {
                    $explicitPri += $s.Trim()
                }
            }
        }
    }
    $dcimPriHints = @(Build-DcimBfsPrioritySegmentHintsList -MtpObject $mtp -ExplicitFromJson $explicitPri)
    return @{
        DeviceNameSubstring            = $dn.Trim()
        RelativePath                   = $rel.Trim()
        MaxSearchDepth                 = $depth
        WhatsappMediaRelativePath      = $wa.Trim()
        DcimBfsNoPrune                 = $dcimNoPrune
        DcimBfsExtraPruneFolderNames   = @($dcimExtra)
        DcimBfsPrioritySegments        = $dcimPriHints
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
        if (-not $PSBoundParameters.ContainsKey("NoDcimBfsPrune") -and $prof.DcimBfsNoPrune) {
            $NoDcimBfsPrune = $true
        }
        if ($prof.DcimBfsExtraPruneFolderNames -and @($prof.DcimBfsExtraPruneFolderNames).Count -gt 0) {
            $script:DcimBfsExtraPruneFromConfig = @($prof.DcimBfsExtraPruneFolderNames | ForEach-Object { [string]$_ })
        }
        if ($prof.DcimBfsPrioritySegments -and @($prof.DcimBfsPrioritySegments).Count -gt 0) {
            $script:DcimBfsPrioritySegmentsFromConfig = @($prof.DcimBfsPrioritySegments | ForEach-Object { [string]$_ })
        }
        $waRel = [string]$prof.WhatsappMediaRelativePath
        if ($waRel.Trim()) {
            $script:WhatsappMediaRelativePathFromConfig = $waRel.Trim()
        }
        Write-Host "Applied repo config profile (active user/phone MTP defaults where CLI omitted)."
        if ($script:WhatsappMediaRelativePathFromConfig) {
            Write-Host ("Configured WhatsApp media (relative to internal storage): {0}" -f $script:WhatsappMediaRelativePathFromConfig)
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

# AUTO BFS: skip expanding these single-folder *segment names* (case-insensitive). Camera roll
# is almost always .../DCIM/Camera under internal storage; these names are usually huge or
# unrelated trees (apps, caches, standard media buckets). The segment "DCIM" is never pruned.
$script:DcimBfsDefaultPruneSegments = @(
    "Android",
    "LOST.DIR",
    "System",
    ".thumbnails",
    "Thumbnails",
    "Music",
    "Ringtones",
    "Alarms",
    "Notifications",
    "Podcasts",
    "Audiobooks",
    "Movies",
    "obb",
    "Pictures",
    "Download",
    "MIUI",
    "`$RECYCLE.BIN",
    "RECYCLER"
)

function Test-DcimBfsFolderNameIsPriorityHint {
    param(
        [string] $SegmentName,
        [string[]] $PriorityHints
    )
    if (-not $PriorityHints -or $PriorityHints.Count -eq 0) {
        return $false
    }
    $n = $SegmentName.Trim()
    foreach ($h in $PriorityHints) {
        if ([string]::Equals($n, $h.Trim(), [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Test-DcimBfsFolderSegmentShouldPrune {
    param(
        [string] $SegmentName,
        [switch] $NoPrune,
        [string[]] $ExtraPruneSegments = @()
    )
    if ($NoPrune) {
        return $false
    }
    $n = $SegmentName.Trim()
    if (-not $n) {
        return $false
    }
    if ($n -ieq "DCIM") {
        return $false
    }
    foreach ($p in ($script:DcimBfsDefaultPruneSegments + $ExtraPruneSegments)) {
        if ($n -ieq $p.Trim()) {
            return $true
        }
    }
    return $false
}

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
        [int] $MaxDepth = 20,
        [switch] $NoPrune,
        [string[]] $ExtraPruneSegments = @(),
        [string[]] $PrioritySegmentHints = @("DCIM", "Camera")
    )
    $hints = @()
    if ($PrioritySegmentHints -and @($PrioritySegmentHints).Count -gt 0) {
        $hints = @($PrioritySegmentHints | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() })
    }
    if ($hints.Count -eq 0) {
        $hints = @("DCIM", "Camera")
    }
    $priQ = New-Object System.Collections.Queue
    $normQ = New-Object System.Collections.Queue
    $null = $normQ.Enqueue(@($StartFolderItem, 0))
    while ($priQ.Count -gt 0 -or $normQ.Count -gt 0) {
        if ($priQ.Count -gt 0) {
            $state = @($priQ.Dequeue())
        }
        else {
            $state = @($normQ.Dequeue())
        }
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
            if (Test-DcimBfsFolderSegmentShouldPrune -SegmentName $child.Name -NoPrune:$NoPrune -ExtraPruneSegments $ExtraPruneSegments) {
                continue
            }
            $nextDepth = $depth + 1
            $pack = @($child, $nextDepth)
            if (Test-DcimBfsFolderNameIsPriorityHint -SegmentName $child.Name -PriorityHints $hints) {
                $null = $priQ.Enqueue($pack)
            }
            else {
                $null = $normQ.Enqueue($pack)
            }
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

function Get-ShellFolderDirectNonFolderItems {
    param($FolderItem)
    $folder = $FolderItem.GetFolder()
    $out = @()
    foreach ($it in $folder.Items()) {
        if (-not (Test-ShellItemIsFolder -Item $it)) {
            $out += , $it
        }
    }
    return $out | Sort-Object { $_.Name }
}

function Show-WhatsAppMediaFolderProbe {
    param(
        $DeviceRootItem,
        [Parameter(Mandatory)][string] $RelativePath,
        [int] $MaxPreviewNames = 8
    )
    $rp = $RelativePath.Trim()
    if (-not $rp) {
        return
    }
    Write-Host "Resolving WhatsApp media path (same rules as explicit camera path): $rp"
    $waFolder = Resolve-DeviceSubfolder -DeviceRootItem $DeviceRootItem -RelativePath $rp
    Write-Host "  Opened WhatsApp media folder: $($waFolder.Name)"
    $all = @(Get-ShellFolderDirectNonFolderItems -FolderItem $waFolder)
    Write-Host "  Top-level files here: $($all.Count) (not recursive; WhatsApp often uses subfolders like Private, Sent)."
    $mediaLike = @(
        $all | Where-Object {
            $_.Name -match '\.(jpe?g|png|gif|mp4|m4v|mkv|opus|ogg|m4a|pdf|webp|aac|3gp|wav)$'
        }
    )
    if ($mediaLike.Count -gt 0) {
        Write-Host "  Sample media-like files (first $MaxPreviewNames):"
        $mediaLike | Select-Object -First $MaxPreviewNames | ForEach-Object { Write-Host "    $($_.Name)" }
    }
    elseif ($all.Count -eq 0) {
        Write-Host "  (No files at this level — path is still valid if subfolders exist.)"
    }
    else {
        Write-Host "  Sample top-level files (first $MaxPreviewNames):"
        $all | Select-Object -First $MaxPreviewNames | ForEach-Object { Write-Host "    $($_.Name)" }
    }
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
    if ($NoDcimBfsPrune) {
        Write-Host "Searching for **/DCIM/Camera under internal storage (max depth $MaxSearchDepth; full tree, no segment prune)..."
    }
    else {
        Write-Host "Searching for **/DCIM/Camera under internal storage (max depth $MaxSearchDepth; skipping unlikely folder names — -NoDcimBfsPrune for exhaustive search)..."
    }
    $internalRoot = Find-InternalStorageRoot -DeviceRootItem $deviceItem
    Write-Host "  Internal volume: $($internalRoot.Name)"
    $priHints = @()
    if ($script:DcimBfsPrioritySegmentsFromConfig -and @($script:DcimBfsPrioritySegmentsFromConfig).Count -gt 0) {
        $priHints = @($script:DcimBfsPrioritySegmentsFromConfig | ForEach-Object { [string]$_ })
    }
    else {
        $priHints = @("DCIM", "Camera")
    }
    Write-Host ("  DCIM AUTO: priority folder names (expanded before others): {0}" -f ($priHints -join ", "))
    $cameraItem = Find-DcimCameraFolder `
        -StartFolderItem $internalRoot `
        -MaxDepth $MaxSearchDepth `
        -NoPrune:$NoDcimBfsPrune `
        -ExtraPruneSegments $script:DcimBfsExtraPruneFromConfig `
        -PrioritySegmentHints $priHints
    if (-not $cameraItem) {
        throw (
            "Could not find a DCIM/Camera folder under internal storage. " +
            "Try increasing -MaxSearchDepth, pass an explicit -RelativePath, or use -NoDcimBfsPrune " +
            "(or mtp.dcimBfsPrune false in config) if DCIM lives under a pruned folder name."
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

if ($script:WhatsappMediaRelativePathFromConfig) {
    Show-WhatsAppMediaFolderProbe `
        -DeviceRootItem $deviceItem `
        -RelativePath $script:WhatsappMediaRelativePathFromConfig `
        -MaxPreviewNames ([Math]::Max($MaxFiles, 8))
}

if ($ListOnly) {
    $preview = $images | Select-Object -First $MaxFiles | ForEach-Object { $_.Name }
    Write-Host "ListOnly - would copy from camera folder:"
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
