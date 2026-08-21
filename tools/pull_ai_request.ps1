$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$debugDir = Join-Path $projectRoot 'debug'
$target = Join-Path $debugDir 'ocr_ai_payload.json'

New-Item -ItemType Directory -Force -Path $debugDir | Out-Null

Write-Host 'Reading exact AI request JSON from the connected debug device...'

$b64Lines = & adb shell "run-as com.example.munib base64 app_flutter/last_ai_request.json"
if ($LASTEXITCODE -ne 0) {
    throw 'Could not read last_ai_request.json. Run the app in debug mode, upload an Imsakia, then try again.'
}

$b64 = ($b64Lines -join '').Trim()
if ([string]::IsNullOrWhiteSpace($b64)) {
    throw 'The debug payload was empty. Upload an Imsakia first so the app sends an AI request.'
}

[System.IO.File]::WriteAllBytes(
    $target,
    [System.Convert]::FromBase64String($b64)
)

Write-Host "Saved exact AI request to: $target"
