<#
.SYNOPSIS
    Bulk rename ABAP object files and replace matching text inside file contents.

.DESCRIPTION
    Renames files (and optionally folders) whose names contain the old pattern,
    and replaces matching text inside text files — recursively.
    Runs in dry-run mode by default. Pass -Apply to commit changes.

.PARAMETER Folder
    Root folder to process. Defaults to the current directory.

.PARAMETER OldText
    Text to find (in file names and content).

.PARAMETER NewText
    Replacement text.

.PARAMETER Apply
    Actually apply changes. Omit for dry-run (default).

.PARAMETER CaseSensitive
    Match case exactly. Default is case-insensitive.

.PARAMETER RenameDirs
    Also rename matching folder names.

.PARAMETER NoContent
    Skip content replacement, rename files only.

.PARAMETER NoRename
    Skip file renaming, replace content only.

.EXAMPLE
    # Preview current folder (dry-run):
    .\Rename-AbapObjects.ps1 -OldText zmm_c_ -NewText zc_mm_

.EXAMPLE
    # Preview a specific folder:
    .\Rename-AbapObjects.ps1 -Folder .\my_download -OldText zmm_c_ -NewText zc_mm_

.EXAMPLE
    # Apply in current folder:
    .\Rename-AbapObjects.ps1 -OldText zmm_c_ -NewText zc_mm_ -Apply

.EXAMPLE
    # Also rename folder names:
    .\Rename-AbapObjects.ps1 -OldText zmm_c_ -NewText zc_mm_ -Apply -RenameDirs
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Folder = (Get-Location).Path,
    [Parameter(Mandatory)][string] $OldText,
    [Parameter(Mandatory)][string] $NewText,
    [switch] $Apply,
    [switch] $CaseSensitive,
    [switch] $RenameDirs,
    [switch] $NoContent,
    [switch] $NoRename
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── helpers ──────────────────────────────────────────────────────────────────

$comparison = if ($CaseSensitive) { [System.StringComparison]::Ordinal }
              else                 { [System.StringComparison]::OrdinalIgnoreCase }

function Replace-Text([string]$Text) {
    $idx = $Text.IndexOf($OldText, $comparison)
    while ($idx -ge 0) {
        $Text = $Text.Remove($idx, $OldText.Length).Insert($idx, $NewText)
        $idx  = $Text.IndexOf($OldText, $idx + $NewText.Length, $comparison)
    }
    return $Text
}

$binaryExtensions = @(
    '.png','.jpg','.jpeg','.gif','.bmp','.ico',
    '.pdf','.zip','.tar','.gz','.jar','.class',
    '.exe','.dll','.so','.bin','.svg'
)

function Test-BinaryFile([string]$Path) {
    if ([System.IO.Path]::GetExtension($Path).ToLower() -in $binaryExtensions) { return $true }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path) | Select-Object -First 8192
        return $bytes -contains 0
    } catch { return $true }
}

# ── banner ───────────────────────────────────────────────────────────────────

$root = (Resolve-Path $Folder).Path
$mode = if ($Apply) { 'APPLY' } else { 'DRY-RUN  (pass -Apply to commit)' }

Write-Host ""
Write-Host "Root  : $root"
Write-Host "Find  : $OldText"
Write-Host "Replace: $NewText"
Write-Host "Mode  : $mode"
Write-Host "Case  : $(if ($CaseSensitive) { 'sensitive' } else { 'insensitive' })"
Write-Host ""

# ── collect content changes ───────────────────────────────────────────────────

$contentChanges = @()

if (-not $NoContent) {
    Write-Host "Scanning file contents..."
    Get-ChildItem -Path $root -Recurse -File | ForEach-Object {
        $file = $_
        if (Test-BinaryFile $file.FullName) { return }

        try {
            $original = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        } catch {
            Write-Warning "Cannot read: $($file.FullName)"
            return
        }

        $replaced = Replace-Text $original
        if ($replaced -ne $original) {
            $contentChanges += [PSCustomObject]@{ File = $file.FullName; New = $replaced }
        }
    }

    if ($contentChanges.Count -gt 0) {
        Write-Host "  Content replacements in $($contentChanges.Count) file(s):" -ForegroundColor Cyan
        $contentChanges | ForEach-Object { Write-Host "    $($_.File)" }
    } else {
        Write-Host "  No content changes." -ForegroundColor DarkGray
    }
}

# ── collect renames ───────────────────────────────────────────────────────────

$renameItems = @()

if (-not $NoRename) {
    Write-Host ""
    Write-Host "Scanning names..."

    # Files
    Get-ChildItem -Path $root -Recurse -File | ForEach-Object {
        $newName = Replace-Text $_.Name
        if ($newName -ne $_.Name) {
            $renameItems += [PSCustomObject]@{
                OldPath = $_.FullName
                NewPath = Join-Path $_.DirectoryName $newName
                Label   = "$($_.Name)  →  $newName"
            }
        }
    }

    # Folders (bottom-up so children rename before parents)
    if ($RenameDirs) {
        Get-ChildItem -Path $root -Recurse -Directory |
            Sort-Object { $_.FullName.Length } -Descending |
            ForEach-Object {
                if ($_.FullName -eq $root) { return }
                $newName = Replace-Text $_.Name
                if ($newName -ne $_.Name) {
                    $renameItems += [PSCustomObject]@{
                        OldPath = $_.FullName
                        NewPath = Join-Path $_.Parent.FullName $newName
                        Label   = "[DIR] $($_.Name)  →  $newName"
                    }
                }
            }
    }

    if ($renameItems.Count -gt 0) {
        Write-Host "  Renames ($($renameItems.Count)):" -ForegroundColor Cyan
        $renameItems | ForEach-Object { Write-Host "    $($_.Label)" }
    } else {
        Write-Host "  No renames." -ForegroundColor DarkGray
    }
}

# ── apply ─────────────────────────────────────────────────────────────────────

if (-not $Apply) {
    Write-Host ""
    Write-Host "Dry-run complete. No changes written." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

if ($contentChanges.Count -gt 0) {
    Write-Host "Applying content changes..."
    $contentChanges | ForEach-Object {
        [System.IO.File]::WriteAllText($_.File, $_.New, [System.Text.Encoding]::UTF8)
    }
}

if ($renameItems.Count -gt 0) {
    Write-Host "Applying renames..."
    $renameItems | ForEach-Object {
        if (Test-Path $_.NewPath) {
            Write-Warning "Target already exists, skipping: $($_.NewPath)"
        } else {
            Rename-Item -Path $_.OldPath -NewName (Split-Path $_.NewPath -Leaf)
        }
    }
}

Write-Host ""
Write-Host "Done. $($contentChanges.Count) file(s) updated, $($renameItems.Count) item(s) renamed." -ForegroundColor Green
