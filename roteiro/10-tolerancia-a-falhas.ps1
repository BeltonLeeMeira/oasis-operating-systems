#Requires -RunAsAdministrator
# Passo 10 · Serviços tolerantes a falhas.
#  1. Recuperação automática dos serviços W3SVC, WAS e PostgreSQL (reinicia em 5 s, 10 s e 30 s)
#  2. Pool do IIS: AlwaysRunning e proteção contra falhas rápidas (configurados no passo 06);
#     o HttpPlatformHandler reinicia o processo Python sozinho se ele cair
#  3. Vigia: tarefa agendada que confere http://localhost/health a cada minuto e religa
#     o que estiver parado, registrando no Visualizador de Eventos (fonte Oasis, eventos 1001-1003)

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"
Import-Module WebAdministration

Escrever-Passo 'Recuperação automática dos serviços'
foreach ($servico in @('WAS', 'W3SVC', $Oasis.ServicoBanco)) {
    sc.exe failure $servico reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
    sc.exe failureflag $servico 1 | Out-Null
    Escrever-Ok "$($servico): reinicia em 5 s, 10 s e 30 s se cair"
}

Escrever-Passo "Pool $($Oasis.Pool)"
Get-ItemProperty "IIS:\AppPools\$($Oasis.Pool)" |
    Select-Object name, startMode, autoStart, @{ n = 'idleTimeout'; e = { $_.processModel.idleTimeout } },
        @{ n = 'rapidFailProtection'; e = { $_.failure.rapidFailProtection } },
        @{ n = 'maxCrashes'; e = { $_.failure.rapidFailProtectionMaxCrashes } } | Format-List

Escrever-Passo 'Vigia da aplicação (tarefa agendada a cada minuto)'
Garantir-FonteDeEventos 'Oasis'
$pastaScripts = Join-Path $Oasis.Raiz 'scripts'
New-Item -ItemType Directory -Force -Path $pastaScripts | Out-Null
$vigia = Join-Path $pastaScripts 'vigia.ps1'
Copy-Item -Path (Join-Path $PSScriptRoot 'vigia.ps1') -Destination $vigia -Force
icacls $pastaScripts /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' /Q | Out-Null

$argumentos = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Pool "{1}" -ServicoBanco "{2}"' -f $vigia, $Oasis.Pool, $Oasis.ServicoBanco
$acao = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argumentos
$gatilho = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest
$ajustes = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 3) -MultipleInstances IgnoreNew -StartWhenAvailable
Register-ScheduledTask -TaskName 'Oasis-Vigia' -Action $acao -Trigger $gatilho -Principal $principal -Settings $ajustes -Force | Out-Null
Escrever-Ok 'tarefa Oasis-Vigia (roda como SISTEMA)'

Escrever-Passo 'Conferência'
foreach ($servico in @('WAS', 'W3SVC', $Oasis.ServicoBanco)) { sc.exe qfailure $servico }
Get-ScheduledTask -TaskName 'Oasis-Vigia' | Format-Table TaskName, State -AutoSize
Write-Host 'Próximo: 11-teste-de-falha.ps1' -ForegroundColor Yellow
