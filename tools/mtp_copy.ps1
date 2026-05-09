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

. (Join-Path $PSScriptRoot "mtp_shell_common.ps1")

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

if ($UseRepoConfig) {
    $mergedObj = Read-RepoMergedConfigObject -RepoRoot $repoRoot
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

$ctx = Get-ThisPcShellFolder
$shell = $ctx.Shell
$root = $ctx.Folder

Write-Host "Resolving device under This PC..."
$deviceItem = Find-DeviceItem -RootFolder $root -NameSubstring $DeviceName
Write-Host "  Device: $($deviceItem.Name)"

$cameraItem = Resolve-MtpCameraShellFolder `
    -DeviceRootItem $deviceItem `
    -RelativePath $RelativePath `
    -MaxSearchDepth $MaxSearchDepth `
    -NoDcimBfsPrune:$NoDcimBfsPrune `
    -DcimBfsExtraPruneSegments $script:DcimBfsExtraPruneFromConfig `
    -DcimBfsPrioritySegmentsFromConfig $script:DcimBfsPrioritySegmentsFromConfig

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
