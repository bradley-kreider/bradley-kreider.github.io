# Converts a .docx file dropped into content/blog/inbox/ into a Hugo blog post.
# Usage: .\scripts\docx-to-post.ps1 [-File "path\to\file.docx"]
# If -File is omitted, processes all .docx files in content/blog/inbox/.

param(
    [string]$File = ""
)

$ErrorActionPreference = "Stop"
$pandoc   = "$env:LOCALAPPDATA\Pandoc\pandoc.exe"
$repoRoot = Split-Path -Parent $PSScriptRoot
$inbox    = Join-Path $repoRoot "content\blog\inbox"

if (-not (Test-Path $pandoc)) {
    Write-Host "  ERROR: Pandoc not found at $pandoc" -ForegroundColor Red
    exit 1
}

# Resolve which files to process
if ($File -ne "") {
    $docxFiles = @(Get-Item $File)
} else {
    $docxFiles = @(Get-ChildItem -Path $inbox -Filter "*.docx")
}

if ($docxFiles.Count -eq 0) {
    Write-Host "  No .docx files found to process." -ForegroundColor Yellow
    exit 0
}

foreach ($docx in $docxFiles) {
    Write-Host ""
    Write-Host "  Processing: $($docx.Name)" -ForegroundColor Cyan

    # Derive slug and post folder from filename
    $slug     = $docx.BaseName -replace '\s+', '-' -replace '[^a-zA-Z0-9\-]', '' -replace '-+', '-'
    $slug     = $slug.ToLower().Trim('-')
    $postDir  = Join-Path $repoRoot "content\blog\$slug"
    $mediaDir = Join-Path $postDir "images-tmp"

    if (Test-Path $postDir) {
        Write-Host "  WARNING: $postDir already exists — skipping to avoid overwrite." -ForegroundColor Yellow
        continue
    }

    New-Item -ItemType Directory -Path $postDir | Out-Null
    New-Item -ItemType Directory -Path $mediaDir | Out-Null

    # Run Pandoc: docx -> markdown, extract media into images-tmp/
    $mdRaw = Join-Path $postDir "_raw.md"
    & $pandoc $docx.FullName `
        --from docx `
        --to markdown+smart `
        --wrap=none `
        --extract-media=$mediaDir `
        --output $mdRaw

    # Read converted markdown
    $body = Get-Content $mdRaw -Raw -Encoding UTF8

    # Move extracted images up to post root and rewrite paths
    $mediaFiles = Get-ChildItem -Path $mediaDir -Recurse -File -ErrorAction SilentlyContinue
    foreach ($img in $mediaFiles) {
        $dest = Join-Path $postDir $img.Name
        Move-Item $img.FullName $dest -Force
        # Rewrite markdown image paths to just the filename
        $body = $body -replace [regex]::Escape("images-tmp/$($img.Name)"), $img.Name
        $body = $body -replace [regex]::Escape("images-tmp\$($img.Name)"), $img.Name
        # Handle nested media paths pandoc sometimes generates
        $body = $body -replace "images-tmp/[^/]+/$([regex]::Escape($img.Name))", $img.Name
    }

    # Clean up temp media folder
    Remove-Item $mediaDir -Recurse -Force -ErrorAction SilentlyContinue

    # Remove raw file
    Remove-Item $mdRaw -Force

    # Build Hugo frontmatter
    $today = Get-Date -Format "yyyy-MM-dd"
    $title  = ($docx.BaseName -replace '-', ' ' -replace '_', ' ')
    # Title case the title
    $title = (Get-Culture).TextInfo.ToTitleCase($title.ToLower())

    $frontmatter = @"
---
title: "$title"
date: $today
description: ""
summary: ""
tags: []
showHero: false
showReadingTime: true
showTableOfContents: false
draft: true
---

"@

    # Write final index.md
    $indexMd = Join-Path $postDir "index.md"
    Set-Content -Path $indexMd -Value ($frontmatter + $body) -Encoding UTF8

    # Delete the source docx from inbox
    Remove-Item $docx.FullName -Force

    Write-Host "  Created: content/blog/$slug/index.md" -ForegroundColor Green
    Write-Host "  Post is set to draft:true — review it, then set draft:false to publish." -ForegroundColor DarkGray
}

Write-Host ""
