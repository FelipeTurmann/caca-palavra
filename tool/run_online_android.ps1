param([string]$DeviceId)

$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$adbCommand = Get-Command adb -ErrorAction SilentlyContinue
$adbExecutable = if ($adbCommand) { $adbCommand.Source } else {
    Join-Path $env:LOCALAPPDATA 'Android/sdk/platform-tools/adb.exe'
}
if (-not (Test-Path -LiteralPath $adbExecutable)) {
    throw 'ADB não encontrado. Adicione platform-tools ao PATH ou confira a instalação do Android SDK.'
}

$deviceOutput = & $adbExecutable devices
if ($LASTEXITCODE -ne 0) { throw 'Falha ao consultar dispositivos Android.' }
$deviceIds = @($deviceOutput | ForEach-Object {
    if ($_ -match '^(\S+)\s+device\s*$') { $Matches[1] }
})
if (-not $DeviceId) {
    if ($deviceIds.Count -ne 1) {
        throw 'Conecte um único dispositivo ou informe -DeviceId com o ID exibido por adb devices.'
    }
    $DeviceId = $deviceIds[0]
}
if ($DeviceId -notin $deviceIds) { throw "Dispositivo '$DeviceId' não está conectado/autorizado." }

foreach ($healthPort in @(9081, 9082)) {
    try { $health = Invoke-RestMethod -Uri "http://127.0.0.1:$healthPort/actuator/health/readiness" -TimeoutSec 5 }
    catch { throw "Inicie as APIs locais. Readiness indisponível na porta $healthPort." }
    if ($health.status -ne 'UP') { throw "API da porta $healthPort ainda não está pronta." }
}
foreach ($apiPort in @(8081, 8082)) {
    & $adbExecutable -s $DeviceId reverse "tcp:$apiPort" "tcp:$apiPort"
    if ($LASTEXITCODE -ne 0) { throw "Falha ao encaminhar a porta $apiPort." }
}

Push-Location $projectDirectory
try {
    Write-Host "Executando app online em $DeviceId, com as portas 8081 e 8082 encaminhadas."
    & flutter run --debug -d $DeviceId --target lib/main.dart
    $runExit = $LASTEXITCODE
} finally { Pop-Location }
if ($runExit -ne 0) { throw "Flutter terminou com código $runExit." }
