param(
    [string]$EmbeddingModel = 'embeddinggemma:300m',
    [string]$ChatModel = 'qwen3:4b'
)
$ErrorActionPreference = 'Stop'
$ollamaCommand = Get-Command ollama -ErrorAction SilentlyContinue
$ollamaPath = if ($ollamaCommand) { $ollamaCommand.Source } else { Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe' }
if (-not (Test-Path -LiteralPath $ollamaPath)) {
    throw 'Install Ollama from https://ollama.com/download/windows, then rerun this script.'
}
try {
    Invoke-RestMethod 'http://127.0.0.1:11434/api/version' -TimeoutSec 5 | Out-Null
} catch {
    $env:OLLAMA_HOST = '127.0.0.1:11434'
    Start-Process -FilePath $ollamaPath -ArgumentList 'serve' -WindowStyle Hidden | Out-Null
    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        Start-Sleep -Seconds 1
        try {
            Invoke-RestMethod 'http://127.0.0.1:11434/api/version' -TimeoutSec 2 | Out-Null
            $ready = $true
            break
        } catch { }
    }
    if (-not $ready) { throw 'Ollama did not start on 127.0.0.1:11434.' }
}
$env:OLLAMA_HOST = '127.0.0.1:11434'
foreach ($model in @($EmbeddingModel, $ChatModel)) {
    Write-Host "Downloading local model: $model"
    & $ollamaPath pull $model
    if ($LASTEXITCODE -ne 0) { throw "Model download failed: $model" }
}
Write-Host 'Local AI models are ready. Start the StudyMate backend with start-dev.ps1.'
