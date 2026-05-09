<#
.SYNOPSIS
  Per-file MTP camera roll archive: copy to NAS (User/Image|Video), verify, move into phone quarantine folder.

.DESCRIPTION
  Processes eligible files one at a time (oldest first). Eligibility: calendar year of best-known
  date is at most (reference year - 2) — i.e. excludes the last two calendar years including reference.
  Logs append-only JSONL under logs/. Use -CleanupHidden to delete only the quarantine folder tree
  on the phone after manual NAS verification.

.PARAMETER UseRepoConfig
  Load merged JSON from repo root (same merge as mtp_copy.ps1).

.PARAMETER ListOnly
  List files that would be archived (after year filter and resume skip); no copy.

.PARAMETER CleanupHidden
  Delete contents of mtp.archiveHiddenRelativePath on the phone (default DCIM\.hidden.phone.manager).
  Does not touch Camera loose files.

.PARAMETER MaxFiles
  Max files to process this run (default 1). Use 0 for no limit.

.PARAMETER AsOfYear
  Reference calendar year for the two-year exclusion (default: current year).

.PARAMETER LogFile
  JSONL log path relative to repo root or absolute (default logs/mtp-archive.jsonl).
#>
[CmdletBinding()]
param(
    [switch] $UseRepoConfig,
    [switch] $ListOnly,
    [switch] $CleanupHidden,
    [string] $DeviceName = "",
    [string] $RelativePath = "",
    [int] $MaxSearchDepth = 20,
    [switch] $NoDcimBfsPrune,
    [int] $MaxFiles = 1,
    [int] $AsOfYear = 0,
    [string] $LogFile = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$script:DcimBfsExtraPruneFromConfig = @()
$script:DcimBfsPrioritySegmentsFromConfig = @()

. (Join-Path $PSScriptRoot "mtp_shell_common.ps1")

$script:ArchiveImageExtRegex = '\.(jpe?g|png|heic|webp|gif|bmp|tif|tiff)$'
$script:ArchiveVideoExtRegex = '\.(mp4|m4v|mov|mkv|3gp|webm|avi)$'

# FOF_SILENT | FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_NOCONFIRMMKDIR
$script:ShellFileOpFlags = 4 + 16 + 1024 + 512

function Resolve-NasMediaRootPath {
    param([string] $Raw)
    $t = $Raw.Trim()
    if ([string]::IsNullOrWhiteSpace($t)) {
        return $null
    }
    if ($t.StartsWith("\\", [System.StringComparison]::Ordinal)) {
        return $t
    }
    if ($t.Length -ge 2 -and $t[1] -eq ':') {
        return $t
    }
    $m = [regex]::Match($t, '^([^\\/]+)[\\/](.+)$')
    if ($m.Success) {
        $hostPart = $m.Groups[1].Value
        $shareTail = ($m.Groups[2].Value -replace '/', '\')
        return "\\$hostPart\$shareTail"
    }
    return $t
}

function Get-NasBucketFromLeafName {
    param([string] $LeafName)
    $n = $LeafName.Trim()
    if ($n -match $script:ArchiveVideoExtRegex) {
        return "Video"
    }
    if ($n -match $script:ArchiveImageExtRegex) {
        return "Image"
    }
    return $null
}

function Write-ArchiveJsonl {
    param(
        [Parameter(Mandatory)][string] $LogPath,
        [Parameter(Mandatory)][hashtable] $Entry
    )
    $dir = Split-Path -Parent $LogPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        $null = New-Item -ItemType Directory -Force -Path $dir
    }
    $Entry["ts"] = (Get-Date).ToUniversalTime().ToString("o")
    ($Entry | ConvertTo-Json -Compress -Depth 8) | Add-Content -LiteralPath $LogPath -Encoding UTF8
}

function Get-CompletedResumeKeysFromLog {
    param([string] $LogPath)
    $set = @{}
    if (-not (Test-Path -LiteralPath $LogPath)) {
        return $set
    }
    Get-Content -LiteralPath $LogPath -Encoding UTF8 -ErrorAction Stop | ForEach-Object {
        $line = $_.Trim()
        if (-not $line) {
            return
        }
        try {
            $o = $line | ConvertFrom-Json
        }
        catch {
            return
        }
        if ($o.phase -eq "phone_move" -and $o.outcome -eq "ok" -and $o.resumeKey) {
            $set[[string]$o.resumeKey] = $true
        }
    }
    return $set
}

function Get-ShellDetailColumnIndex {
    param(
        [Parameter(Mandatory)]$ParentFolderItem,
        [Parameter(Mandatory)][string[]] $HeaderSubstrings
    )
    $fd = $ParentFolderItem.GetFolder()
    $i = 0
    while ($true) {
        $h = $fd.GetDetailsOf($null, $i)
        if ([string]::IsNullOrWhiteSpace($h)) {
            break
        }
        foreach ($sub in $HeaderSubstrings) {
            if ($h -like "*$sub*") {
                return @{ Index = $i; Header = $h }
            }
        }
        $i++
    }
    return $null
}

function Get-MtpItemSizeBytes {
    param(
        [Parameter(Mandatory)]$ParentFolderItem,
        [Parameter(Mandatory)]$ChildItem
    )
    foreach ($pk in @("System.Size", "{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 12")) {
        try {
            $v = $ChildItem.ExtendedProperty($pk)
            if ($null -ne $v -and "$v" -ne "") {
                return [int64]$v
            }
        }
        catch {
        }
    }
    $col = Get-ShellDetailColumnIndex -ParentFolderItem $ParentFolderItem -HeaderSubstrings @("Size", "大小", "Größe")
    if ($null -eq $col) {
        return -1
    }
    $raw = $ParentFolderItem.GetFolder().GetDetailsOf($ChildItem, $col.Index)
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return -1
    }
    $digits = ($raw -replace '[^\d]', '')
    if ($digits.Length -gt 0) {
        try {
            return [int64]$digits
        }
        catch {
        }
    }
    return -1
}

function Get-MtpItemDateTimeBestEffort {
    param(
        [Parameter(Mandatory)]$ParentFolderItem,
        [Parameter(Mandatory)]$ChildItem,
        [Parameter(Mandatory)][string] $LeafName
    )
    foreach ($pk in @(
            "System.Photo.DateTaken",
            "System.Media.DateEncoded",
            "System.DateModified",
            "{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 4"
        )) {
        try {
            $v = $ChildItem.ExtendedProperty($pk)
            if ($null -ne $v -and "$v" -ne "") {
                $dt = [datetime]$v
                return $dt
            }
        }
        catch {
        }
    }
    foreach ($sub in @("Date taken", "Date modified", "修改日期", "建立日期")) {
        $col = Get-ShellDetailColumnIndex -ParentFolderItem $ParentFolderItem -HeaderSubstrings @($sub)
        if ($null -eq $col) {
            continue
        }
        $raw = $ParentFolderItem.GetFolder().GetDetailsOf($ChildItem, $col.Index)
        if ([string]::IsNullOrWhiteSpace($raw)) {
            continue
        }
        try {
            return [datetime]::Parse($raw, [System.Globalization.CultureInfo]::CurrentCulture,
                [System.Globalization.DateTimeStyles]::AssumeLocal)
        }
        catch {
        }
        try {
            return [datetime]::Parse($raw, [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AssumeLocal)
        }
        catch {
        }
    }
    $m = [regex]::Match($LeafName, '(?:IMG|PXL|VID)_(\d{4})(\d{2})(\d{2})', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) {
        try {
            return New-Object datetime @([int]$m.Groups[1].Value, [int]$m.Groups[2].Value, [int]$m.Groups[3].Value)
        }
        catch {
        }
    }
    return $null
}

function Get-CameraMediaShellItemsForArchive {
    param([Parameter(Mandatory)]$FolderItem)
    $folder = $FolderItem.GetFolder()
    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($it in $folder.Items()) {
        if (Test-ShellItemIsFolder -Item $it) {
            continue
        }
        $name = [string]$it.Name
        if ($name -match ($script:ArchiveImageExtRegex + "|" + $script:ArchiveVideoExtRegex)) {
            $null = $out.Add($it)
        }
    }
    return @($out)
}

function Resolve-PathUnderInternalStorage {
    param(
        [Parameter(Mandatory)]$DeviceRootItem,
        [Parameter(Mandatory)][string] $RelativeUnderInternal
    )
    $internal = Find-InternalStorageRoot -DeviceRootItem $DeviceRootItem
    $current = $internal
    $segments = @($RelativeUnderInternal -split "\\" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    foreach ($seg in $segments) {
        $current = Resolve-ShellChildFolder -FolderItem $current -SegmentName $seg
    }
    return $current
}

function Ensure-ChildFolderByName {
    param(
        [Parameter(Mandatory)]$ParentFolderItem,
        [Parameter(Mandatory)][string] $ChildName
    )
    $existing = Try-ResolveShellChildFolder -FolderItem $ParentFolderItem -SegmentName $ChildName
    if ($existing) {
        return $existing
    }
    $parentFolder = $ParentFolderItem.GetFolder()
    try {
        $null = $parentFolder.NewFolder($ChildName, 0)
    }
    catch {
        $again = Try-ResolveShellChildFolder -FolderItem $ParentFolderItem -SegmentName $ChildName
        if ($again) {
            return $again
        }
        throw
    }
    $resolved = Try-ResolveShellChildFolder -FolderItem $ParentFolderItem -SegmentName $ChildName
    if (-not $resolved) {
        throw "NewFolder did not create '$ChildName' under '$($ParentFolderItem.Name)'."
    }
    return $resolved
}

function Resolve-QuarantineFolderOnDevice {
    param(
        [Parameter(Mandatory)]$DeviceRootItem,
        [Parameter(Mandatory)][string] $ArchiveHiddenRelativePath
    )
    $rp = $ArchiveHiddenRelativePath.Trim()
    if (-not $rp) {
        throw "archiveHiddenRelativePath is empty."
    }
    $segments = @($rp -split "\\" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($segments.Count -lt 1) {
        throw "Invalid archiveHiddenRelativePath: $ArchiveHiddenRelativePath"
    }
    $internal = Find-InternalStorageRoot -DeviceRootItem $DeviceRootItem
    $current = $internal
    foreach ($seg in $segments) {
        $current = Ensure-ChildFolderByName -ParentFolderItem $current -ChildName $seg
    }
    return $current
}

function Wait-FileStableSize {
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [int] $StableMs = 900,
        [int] $TimeoutSec = 300
    )
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSec)
    [long]$last = -1
    $stableSince = [datetime]::UtcNow
    while ([datetime]::UtcNow -lt $deadline) {
        if (-not (Test-Path -LiteralPath $LiteralPath)) {
            Start-Sleep -Milliseconds 200
            continue
        }
        $fi = Get-Item -LiteralPath $LiteralPath -ErrorAction Stop
        $sz = $fi.Length
        if ($sz -le 0) {
            Start-Sleep -Milliseconds 200
            continue
        }
        if ($sz -eq $last) {
            if (([datetime]::UtcNow - $stableSince).TotalMilliseconds -ge $StableMs) {
                return $sz
            }
        }
        else {
            $last = $sz
            $stableSince = [datetime]::UtcNow
        }
        Start-Sleep -Milliseconds 250
    }
    throw "Timeout waiting for stable file size: $LiteralPath"
}

function Get-SanitizedUserFolderName {
    param([string] $Preferred, [string] $FallbackActiveUserId)
    $raw = $Preferred.Trim()
    if (-not $raw) {
        $raw = $FallbackActiveUserId.Trim()
    }
    if (-not $raw) {
        throw "Set storage.nasMediaUserFolder or activeUserId for NAS user folder segment."
    }
    $invEscaped = [regex]::Escape(-join [char[]][System.IO.Path]::GetInvalidFileNameChars())
    $clean = $raw -replace "[$invEscaped]", "_"
    $clean = $clean.TrimEnd('.', ' ')
    if (-not $clean) {
        throw "NAS user folder segment empty after sanitization."
    }
    return $clean
}

function Remove-MtpFolderTreeBestEffort {
    param(
        [Parameter(Mandatory)]$FolderItemToRemove,
        [Parameter(Mandatory)]$ShellApp
    )
    function Remove-ChildrenRecursive {
        param($Fi)
        $fd = $Fi.GetFolder()
        foreach ($it in @($fd.Items())) {
            if (Test-ShellItemIsFolder -Item $it) {
                Remove-ChildrenRecursive -Fi $it
                try {
                    $it.InvokeVerb("delete")
                }
                catch {
                    Write-Warning "Delete folder failed: $($it.Name) — $($_.Exception.Message)"
                }
            }
            else {
                try {
                    $it.InvokeVerb("delete")
                }
                catch {
                    Write-Warning "Delete file failed: $($it.Name) — $($_.Exception.Message)"
                }
            }
            Start-Sleep -Milliseconds 400
        }
    }
    Remove-ChildrenRecursive -Fi $FolderItemToRemove
    Start-Sleep -Milliseconds 600
    try {
        $FolderItemToRemove.InvokeVerb("delete")
    }
    catch {
        Write-Warning "Delete quarantine root folder failed: $($FolderItemToRemove.Name) — $($_.Exception.Message)"
    }
}

# --- Load config ---
$merged = $null
$archiveHiddenRel = "DCIM\.hidden.phone.manager"
$nasUserOverride = ""

if ($UseRepoConfig -or $CleanupHidden) {
    $merged = Read-RepoMergedConfigObject -RepoRoot $repoRoot
}

if ($UseRepoConfig -and $merged) {
    $prof = Get-ActivePhoneProfileFromMerged -Merged $merged
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
        $ahRel = $prof['ArchiveHiddenRelativePath']
        if ($ahRel -and [string]$ahRel.Trim()) {
            $archiveHiddenRel = [string]$ahRel
        }
    }
}

if ($merged) {
    $st = $merged.storage
    if ($null -ne $st) {
        $pU = $st.PSObject.Properties["nasMediaUserFolder"]
        if ($null -ne $pU -and $null -ne $pU.Value) {
            $nasUserOverride = [string]$pU.Value
        }
    }
}

$logPath = if ($LogFile.Trim()) {
    if ([System.IO.Path]::IsPathRooted($LogFile)) {
        $LogFile.Trim()
    }
    else {
        Join-Path $repoRoot $LogFile.Trim()
    }
}
else {
    Join-Path $repoRoot "logs\mtp-archive.jsonl"
}

$refYear = if ($AsOfYear -gt 0) { $AsOfYear } else { (Get-Date).Year }
$maxEligibleYear = $refYear - 2

$ctx = Get-ThisPcShellFolder
$shell = $ctx.Shell
$root = $ctx.Folder

Write-Host "Resolving device under This PC..."
$deviceItem = Find-DeviceItem -RootFolder $root -NameSubstring $DeviceName
Write-Host "  Device: $($deviceItem.Name)"

if ($CleanupHidden) {
    if (-not $merged) {
        $merged = Read-RepoMergedConfigObject -RepoRoot $repoRoot
    }
    $prof2 = Get-ActivePhoneProfileFromMerged -Merged $merged
    $ah2 = if ($prof2) { $prof2['ArchiveHiddenRelativePath'] } else { $null }
    if ($ah2 -and [string]$ah2.Trim()) {
        $archiveHiddenRel = [string]$ah2
    }
    Write-Host "CleanupHidden: removing tree at internal storage\$archiveHiddenRel"
    try {
        $hiddenRoot = Resolve-PathUnderInternalStorage -DeviceRootItem $deviceItem -RelativeUnderInternal $archiveHiddenRel
    }
    catch {
        Write-Host "Quarantine path not found or already removed: $($_.Exception.Message)"
        Write-ArchiveJsonl -LogPath $logPath -Entry @{
            phase   = "cleanup_hidden"
            outcome = "skip"
            message = [string]$_.Exception.Message
            path    = $archiveHiddenRel
        }
        exit 0
    }
    Remove-MtpFolderTreeBestEffort -FolderItemToRemove $hiddenRoot -ShellApp $shell
    Write-ArchiveJsonl -LogPath $logPath -Entry @{
        phase   = "cleanup_hidden"
        outcome = "ok"
        path    = $archiveHiddenRel
    }
    Write-Host "CleanupHidden finished (see log). Verify phone gallery if needed."
    exit 0
}

$cameraItem = Resolve-MtpCameraShellFolder `
    -DeviceRootItem $deviceItem `
    -RelativePath $RelativePath `
    -MaxSearchDepth $MaxSearchDepth `
    -NoDcimBfsPrune:$NoDcimBfsPrune `
    -DcimBfsExtraPruneSegments $script:DcimBfsExtraPruneFromConfig `
    -DcimBfsPrioritySegmentsFromConfig $script:DcimBfsPrioritySegmentsFromConfig

$rawItems = @(Get-CameraMediaShellItemsForArchive -FolderItem $cameraItem)
$candidates = [System.Collections.Generic.List[hashtable]]::new()
foreach ($it in $rawItems) {
    $leaf = [string]$it.Name
    $bucket = Get-NasBucketFromLeafName -LeafName $leaf
    if (-not $bucket) {
        continue
    }
    $sz = Get-MtpItemSizeBytes -ParentFolderItem $cameraItem -ChildItem $it
    $dt = Get-MtpItemDateTimeBestEffort -ParentFolderItem $cameraItem -ChildItem $it -LeafName $leaf
    if ($null -eq $dt) {
        Write-ArchiveJsonl -LogPath $logPath -Entry @{
            phase    = "selected"
            outcome  = "skip"
            fileName = $leaf
            message  = "No date from MTP or filename; skipped."
        }
        continue
    }
    $y = $dt.Year
    if ($y -gt $maxEligibleYear) {
        continue
    }
    $resumeKey = "$leaf|$sz"
    $null = $candidates.Add(@{
        Item      = $it
        Leaf      = $leaf
        Size      = $sz
        SortTime  = $dt
        Bucket    = $bucket
        ResumeKey = $resumeKey
    })
}

$sorted = $candidates | Sort-Object { $_.SortTime }, { $_.Leaf }
$doneKeys = Get-CompletedResumeKeysFromLog -LogPath $logPath
$queue = @($sorted | Where-Object { -not $doneKeys.ContainsKey($_.ResumeKey) })

Write-Host "Reference year: $refYear - archiving files with year <= $maxEligibleYear (calendar rule)."
Write-Host "Camera items (media-like): $($rawItems.Count); eligible in queue after resume filter: $($queue.Count)."

if ($ListOnly) {
    $queue | Select-Object -First ($(if ($MaxFiles -le 0) { $queue.Count } else { $MaxFiles })) | ForEach-Object {
        Write-Host ("  {0}  ({1})  {2} bytes" -f $_.Leaf, $_.SortTime, $_.Size)
    }
    exit 0
}

if (-not $merged) {
    $merged = Read-RepoMergedConfigObject -RepoRoot $repoRoot
}

$nasRaw = ""
$st2 = $merged.storage
if ($null -ne $st2) {
    $pN = $st2.PSObject.Properties["nasMediaRoot"]
    if ($null -ne $pN -and $null -ne $pN.Value) {
        $nasRaw = [string]$pN.Value
    }
}
$nasResolved = Resolve-NasMediaRootPath -Raw $nasRaw
if ([string]::IsNullOrWhiteSpace($nasResolved)) {
    throw "storage.nasMediaRoot missing in merged config."
}

$activeUid = ""
$propUid = $merged.PSObject.Properties["activeUserId"]
if ($null -ne $propUid -and $null -ne $propUid.Value) {
    $activeUid = [string]$propUid.Value
}
$userSeg = Get-SanitizedUserFolderName -Preferred $nasUserOverride -FallbackActiveUserId $activeUid
$imageDir = Join-Path $nasResolved (Join-Path $userSeg "Image")
$videoDir = Join-Path $nasResolved (Join-Path $userSeg "Video")

if (-not (Test-Path -LiteralPath $nasResolved)) {
    throw "NAS not reachable: $nasResolved"
}
$null = New-Item -ItemType Directory -Force -Path $imageDir
$null = New-Item -ItemType Directory -Force -Path $videoDir

$stagingDir = Join-Path $repoRoot "tmp\mtp-archive-staging"
$null = New-Item -ItemType Directory -Force -Path $stagingDir

$destShellTmp = $shell.NameSpace((Resolve-Path -LiteralPath $stagingDir).Path)
if (-not $destShellTmp) {
    throw "Shell could not open staging: $stagingDir"
}

$prof3 = Get-ActivePhoneProfileFromMerged -Merged $merged
$ah3 = if ($prof3) { $prof3['ArchiveHiddenRelativePath'] } else { $null }
if ($ah3 -and [string]$ah3.Trim()) {
    $archiveHiddenRel = [string]$ah3
}
$quarantineFolderItem = Resolve-QuarantineFolderOnDevice -DeviceRootItem $deviceItem -ArchiveHiddenRelativePath $archiveHiddenRel
$destShellQuarantine = $quarantineFolderItem.GetFolder()

$processed = 0
$limit = if ($MaxFiles -le 0) { [int]::MaxValue } else { $MaxFiles }

foreach ($row in $queue) {
    if ($processed -ge $limit) {
        break
    }
    $it = $row.Item
    $leaf = $row.Leaf
    $bucket = $row.Bucket
    $resumeKey = $row.ResumeKey
    $expectedSize = [int64]$row.Size

    $nasBucketDir = if ($bucket -eq "Video") { $videoDir } else { $imageDir }
    $nasDestPath = Join-Path $nasBucketDir $leaf

    Write-ArchiveJsonl -LogPath $logPath -Entry @{
        phase     = "selected"
        outcome   = "ok"
        fileName  = $leaf
        resumeKey = $resumeKey
        bucket    = $bucket
        sortTime  = $row.SortTime.ToString("o")
    }

    if (Test-Path -LiteralPath $nasDestPath) {
        Write-ArchiveJsonl -LogPath $logPath -Entry @{
            phase     = "nas_push"
            outcome   = "skip"
            fileName  = $leaf
            resumeKey = $resumeKey
            nasPath   = $nasDestPath
            message   = "Destination exists on NAS; skip."
        }
        continue
    }

    $tmpLeafPath = Join-Path $stagingDir $leaf
    if (Test-Path -LiteralPath $tmpLeafPath) {
        Remove-Item -LiteralPath $tmpLeafPath -Force -ErrorAction SilentlyContinue
    }

    try {
        Write-Host "Pull MTP -> tmp: $leaf"
        $destShellTmp.CopyHere($it, $script:ShellFileOpFlags)
        $actualSize = Wait-FileStableSize -LiteralPath $tmpLeafPath
        $hashTmp = (Get-FileHash -LiteralPath $tmpLeafPath -Algorithm SHA256).Hash

        if ($expectedSize -ge 0 -and $actualSize -ne $expectedSize) {
            throw "Local size $actualSize != MTP reported $expectedSize"
        }

        Write-ArchiveJsonl -LogPath $logPath -Entry @{
            phase     = "verify_tmp"
            outcome   = "ok"
            fileName  = $leaf
            resumeKey = $resumeKey
            bytes     = $actualSize
            sha256    = $hashTmp
        }

        Copy-Item -LiteralPath $tmpLeafPath -Destination $nasDestPath -Force
        Write-ArchiveJsonl -LogPath $logPath -Entry @{
            phase     = "nas_push"
            outcome   = "ok"
            fileName  = $leaf
            resumeKey = $resumeKey
            nasPath   = $nasDestPath
            nasBucket = $bucket
        }
        $nasSize = (Get-Item -LiteralPath $nasDestPath).Length
        if ($nasSize -ne $actualSize) {
            throw "NAS size $nasSize != tmp $actualSize"
        }
        $hashNas = (Get-FileHash -LiteralPath $nasDestPath -Algorithm SHA256).Hash
        if ($hashNas -ne $hashTmp) {
            throw "NAS hash mismatch"
        }

        Write-ArchiveJsonl -LogPath $logPath -Entry @{
            phase     = "verify_nas"
            outcome   = "ok"
            fileName  = $leaf
            resumeKey = $resumeKey
            nasPath   = $nasDestPath
            nasBucket = $bucket
            bytes     = $nasSize
            sha256    = $hashNas
        }

        $destShellQuarantine.MoveHere($it, $script:ShellFileOpFlags)
        Start-Sleep -Milliseconds 800

        Write-ArchiveJsonl -LogPath $logPath -Entry @{
            phase     = "phone_move"
            outcome   = "ok"
            fileName  = $leaf
            resumeKey = $resumeKey
            nasPath   = $nasDestPath
            nasBucket = $bucket
        }

        Remove-Item -LiteralPath $tmpLeafPath -Force -ErrorAction SilentlyContinue
        Write-ArchiveJsonl -LogPath $logPath -Entry @{
            phase     = "tmp_cleanup"
            outcome   = "ok"
            fileName  = $leaf
            resumeKey = $resumeKey
        }

        $processed++
    }
    catch {
        Write-ArchiveJsonl -LogPath $logPath -Entry @{
            phase     = "error"
            outcome   = "fail"
            fileName  = $leaf
            resumeKey = $resumeKey
            message   = $_.Exception.Message
        }
        throw
    }
}

Write-Host "Archived $processed file(s) this run. Log: $logPath"
