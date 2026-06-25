<#
.SYNOPSIS
    Bulk rename ABAP object files and replace matching text inside file contents.

.DESCRIPTION
    Renames files (and optionally folders) whose names contain the old pattern,
    and replaces matching text inside text files — recursively.
    Runs interactively: prompts for inputs, shows a preview, asks to apply.
    At the end offers to run again without restarting the terminal.

.PARAMETER Folder
    Root folder to process. Defaults to the current directory.

.PARAMETER OldText
    Text to find (in file names and content). Prompted if omitted.

.PARAMETER NewText
    Replacement text. Prompted if omitted.

.PARAMETER Apply
    Skip the apply prompt and go straight to applying changes.

.PARAMETER CaseSensitive
    Match case exactly. Default is case-insensitive.

.PARAMETER RenameDirs
    Also rename matching folder names.

.PARAMETER NoContent
    Skip content replacement, rename files only.

.PARAMETER NoRename
    Skip file renaming, replace content only.

.EXAMPLE
    # Fully interactive (run from target folder):
    .\Rename-AbapObjects.ps1

.EXAMPLE
    # Pre-fill values:
    .\Rename-AbapObjects.ps1 -OldText zmm_c_ -NewText zc_mm_ -Apply
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Folder = (Get-Location).Path,
    [string] $OldText,
    [string] $NewText,
    [switch] $Apply,
    [switch] $CaseSensitive,
    [switch] $RenameDirs,
    [switch] $NoContent,
    [switch] $NoRename
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── helpers ──────────────────────────────────────────────────────────────────

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

function Replace-Text([string]$Text, [string]$Old, [string]$New, [System.StringComparison]$Cmp) {
    $idx = $Text.IndexOf($Old, $Cmp)
    while ($idx -ge 0) {
        $Text = $Text.Remove($idx, $Old.Length).Insert($idx, $New)
        $idx  = $Text.IndexOf($Old, $idx + $New.Length, $Cmp)
    }
    return $Text
}

# ── main loop ────────────────────────────────────────────────────────────────

$root = (Resolve-Path $Folder).Path

do {
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host "Root: $root" -ForegroundColor DarkGray
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    # Prompt for inputs (use passed values on first run if provided)
    $oldText = if ($OldText) { $OldText } else { Read-Host "Find text" }
    $newText = if ($NewText) { $NewText } else { Read-Host "Replace with" }

    $csAnswer = Read-Host "Case sensitive? (y/n, default n)"
    $comparison = if ($csAnswer -match '^y') { [System.StringComparison]::Ordinal }
                  else                        { [System.StringComparison]::OrdinalIgnoreCase }
    $caseSensitive = $csAnswer -match '^y'

    # Clear one-shot params so subsequent loops prompt fresh
    $OldText = $null
    $NewText = $null

    Write-Host ""
    Write-Host "Find   : $oldText"
    Write-Host "Replace: $newText"
    Write-Host "Case   : $(if ($caseSensitive) { 'sensitive' } else { 'insensitive' })"
    Write-Host ""

    # ── collect content changes ───────────────────────────────────────────────

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
            $replaced = Replace-Text $original $oldText $newText $comparison
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

    # ── collect renames ───────────────────────────────────────────────────────

    $renameItems = @()

    if (-not $NoRename) {
        Write-Host ""
        Write-Host "Scanning names..."

        Get-ChildItem -Path $root -Recurse -File | ForEach-Object {
            $newName = Replace-Text $_.Name $oldText $newText $comparison
            if ($newName -ne $_.Name) {
                $renameItems += [PSCustomObject]@{
                    OldPath = $_.FullName
                    NewPath = Join-Path $_.DirectoryName $newName
                    Label   = "$($_.Name)  ->  $newName"
                }
            }
        }

        if ($RenameDirs) {
            Get-ChildItem -Path $root -Recurse -Directory |
                Sort-Object { $_.FullName.Length } -Descending |
                ForEach-Object {
                    if ($_.FullName -eq $root) { return }
                    $newName = Replace-Text $_.Name $oldText $newText $comparison
                    if ($newName -ne $_.Name) {
                        $renameItems += [PSCustomObject]@{
                            OldPath = $_.FullName
                            NewPath = Join-Path $_.Parent.FullName $newName
                            Label   = "[DIR] $($_.Name)  ->  $newName"
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

    # ── apply ─────────────────────────────────────────────────────────────────

    Write-Host ""
    $doApply = $Apply
    if (-not $doApply) {
        $answer = Read-Host "Apply changes? (y/n)"
        $doApply = $answer -match '^y'
    }
    $Apply = $false  # reset for next iteration

    if (-not $doApply) {
        Write-Host "Aborted. No changes written." -ForegroundColor Yellow
    } else {
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
    }

    # ── run again? ────────────────────────────────────────────────────────────

    Write-Host ""
    $again = Read-Host "Run again? (y/n)"

} while ($again -match '^y')

Write-Host ""
Write-Host "Bye." -ForegroundColor DarkGray
