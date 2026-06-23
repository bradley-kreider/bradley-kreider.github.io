# Hook shim — called by Claude Code PostToolUse on Write|Edit.
# Reads JSON from stdin, fires docx-to-post.ps1 only for inbox .docx files.
$json = $input | Out-String | ConvertFrom-Json
$fp   = $json.tool_input.file_path

if ($fp -match 'content\\blog\\inbox' -and $fp -match '\.docx$') {
    & "$PSScriptRoot\docx-to-post.ps1" -File $fp
}
