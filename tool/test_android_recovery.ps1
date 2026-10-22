param(
  [string]$Adb = 'C:\Users\felip\AppData\Local\Android\Sdk\platform-tools\adb.exe',
  [string]$Device = 'emulator-5554'
)
$ErrorActionPreference = 'Stop'
$packageName = 'br.com.conectepalavras.caca_palavra'
$projectRoot = Split-Path -Parent $PSScriptRoot
$apkPath = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-debug.apk'
& $Adb -s $Device install -r $apkPath
if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar a fixture. Compile integration_test/recovery_app.dart primeiro.' }
$phases = @('seed', 'verify_partial', 'complete', 'verify_completed', 'advance', 'verify_advance', 'finish', 'verify_final')
foreach ($phase in $phases) {
  & $Adb -s $Device shell am force-stop $packageName
  & $Adb -s $Device shell "run-as $packageName sh -c 'mkdir -p databases; printf $phase > databases/stage3_phase.txt; : > databases/stage3_event.txt'"
  if ($LASTEXITCODE -ne 0) { throw "Falha ao preparar $phase" }
  & $Adb -s $Device shell am start -n "$packageName/.MainActivity" | Out-Null
  $deadline = (Get-Date).AddSeconds(40)
  $result = ''
  do {
    Start-Sleep -Milliseconds 300
    $result = (& $Adb -s $Device shell run-as $packageName cat databases/stage3_event.txt 2>$null) -join "`n"
  } while ([string]::IsNullOrWhiteSpace($result) -and (Get-Date) -lt $deadline)
  if (-not $result.StartsWith("$phase OK")) { throw "Falha em $phase : $result" }
  $processId = (& $Adb -s $Device shell pidof $packageName) -join ''
  Write-Output "$result pid=$processId"
}
Write-Output 'Recuperação Android aprovada. Recompile lib/main.dart e reinstale com adb install -r para retornar ao aplicativo normal.'
