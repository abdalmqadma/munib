$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$debugDir = Join-Path $projectRoot 'debug'
$jsonTarget = Join-Path $debugDir 'ocr_ai_payload.json'
$textTarget = Join-Path $debugDir 'ocr_sent_to_ai.txt'

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

$bytes = [System.Convert]::FromBase64String($b64)
[System.IO.File]::WriteAllBytes($jsonTarget, $bytes)

$jsonText = [System.Text.Encoding]::UTF8.GetString($bytes)
$request = $jsonText | ConvertFrom-Json
$userMessage = $request.payload.messages | Where-Object { $_.role -eq 'user' } | Select-Object -First 1

if ($null -ne $userMessage -and -not [string]::IsNullOrWhiteSpace($userMessage.content)) {
    [System.IO.File]::WriteAllText(
        $textTarget,
        [string]$userMessage.content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

Write-Host "Saved exact AI request to: $jsonTarget"
Write-Host "Saved OCR text sent to AI to: $textTarget"
