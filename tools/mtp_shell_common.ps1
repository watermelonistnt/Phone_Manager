# Shared MTP Shell helpers — dot-source from tools/mtp_copy.ps1, tools/mtp_nas_archive.ps1, etc.
# Caller must set Set-StrictMode and $ErrorActionPreference as desired.

$script:MtpShellToolsDir = $PSScriptRoot

$script:InternalStorageAliases = @(
    "Internal storage",
    "Internal shared storage",
    "Phone storage",
    "內部儲存裝置",
    "内部存储空间"
)

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
    $archiveHidden = ""
    if ($mtp) {
        $ah = $mtp.PSObject.Properties["archiveHiddenRelativePath"]
        if ($null -ne $ah -and $null -ne $ah.Value) {
            $archiveHidden = [string]$ah.Value
        }
    }
    return @{
        DeviceNameSubstring          = $dn.Trim()
        RelativePath                 = $rel.Trim()
        MaxSearchDepth               = $depth
        WhatsappMediaRelativePath    = $wa.Trim()
        DcimBfsNoPrune               = $dcimNoPrune
        DcimBfsExtraPruneFolderNames = @($dcimExtra)
        DcimBfsPrioritySegments      = $dcimPriHints
        ArchiveHiddenRelativePath    = $archiveHidden.Trim()
    }
}

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

function Resolve-MtpCameraShellFolder {
    <#
    .SYNOPSIS
      Resolve the DCIM/Camera (or explicit) folder as a Shell FolderItem.
    #>
    param(
        [Parameter(Mandatory)]$DeviceRootItem,
        [string] $RelativePath,
        [int] $MaxSearchDepth = 20,
        [switch] $NoDcimBfsPrune,
        [string[]] $DcimBfsExtraPruneSegments = @(),
        [string[]] $DcimBfsPrioritySegmentsFromConfig = @()
    )
    $useAuto = [string]::IsNullOrWhiteSpace($RelativePath) -or ($RelativePath.Trim() -ieq "AUTO")
    if ($useAuto) {
        if ($NoDcimBfsPrune) {
            Write-Host "Searching for **/DCIM/Camera under internal storage (max depth $MaxSearchDepth; full tree, no segment prune)..."
        }
        else {
            Write-Host "Searching for **/DCIM/Camera under internal storage (max depth $MaxSearchDepth; skipping unlikely folder names — -NoDcimBfsPrune for exhaustive search)..."
        }
        $internalRoot = Find-InternalStorageRoot -DeviceRootItem $DeviceRootItem
        Write-Host "  Internal volume: $($internalRoot.Name)"
        $priHints = @()
        if ($DcimBfsPrioritySegmentsFromConfig -and @($DcimBfsPrioritySegmentsFromConfig).Count -gt 0) {
            $priHints = @($DcimBfsPrioritySegmentsFromConfig | ForEach-Object { [string]$_ })
        }
        else {
            $priHints = @("DCIM", "Camera")
        }
        Write-Host ("  DCIM AUTO: priority folder names (expanded before others): {0}" -f ($priHints -join ", "))
        $cameraItem = Find-DcimCameraFolder `
            -StartFolderItem $internalRoot `
            -MaxDepth $MaxSearchDepth `
            -NoPrune:$NoDcimBfsPrune `
            -ExtraPruneSegments $DcimBfsExtraPruneSegments `
            -PrioritySegmentHints $priHints
        if (-not $cameraItem) {
            throw (
                "Could not find a DCIM/Camera folder under internal storage. " +
                "Try increasing -MaxSearchDepth, pass an explicit -RelativePath, or use -NoDcimBfsPrune " +
                "(or mtp.dcimBfsPrune false in config) if DCIM lives under a pruned folder name."
            )
        }
        Write-Host "  Found folder: $($cameraItem.Name) (under .../DCIM/Camera)"
        return $cameraItem
    }
    Write-Host "Opening explicit path: $RelativePath"
    return Resolve-DeviceSubfolder -DeviceRootItem $DeviceRootItem -RelativePath $RelativePath
}

function Read-RepoMergedConfigObject {
    param([Parameter(Mandatory)][string] $RepoRoot)
    $reader = Join-Path $script:MtpShellToolsDir "read_merged_config.py"
    if (-not (Test-Path -LiteralPath $reader)) {
        throw "Missing read_merged_config.py: $reader"
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
        throw "Python (py or python) on PATH is required to read merged config."
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
    return ($mergedText | ConvertFrom-Json)
}
