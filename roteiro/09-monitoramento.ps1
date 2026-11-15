#Requires -RunAsAdministrator
# Passo 09 · Monitoramento no Monitor de Desempenho.
#  - Conjunto "Oasis-Alertas": CPU > 85%, disco C: livre < 15%, memória disponível < 500 MB,
#    conferidos a cada 15 s; cada alerta vira o evento 2031 no Visualizador de Eventos
#  - Conjunto "Oasis-Desempenho": grava CPU, memória, disco, conexões do IIS e o processo da API
#  - Os dois voltam a rodar quando o servidor reinicia
#  - Modo de exibição "Oásis" no Visualizador de Eventos
#
# Para demonstrar no vídeo:  .\09-monitoramento.ps1 -Testar
#   cria um conjunto temporário com limites que disparam na hora e gera 60 s de CPU alta.

param([switch]$Testar)

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"

$cpu = Traduzir-Contador '\Processor(_Total)\% Processor Time'
$disco = Traduzir-Contador '\LogicalDisk(C:)\% Free Space'
$memoria = Traduzir-Contador '\Memory\Available MBytes'

function Remover-Conjunto([string]$nome) {
    $conjunto = New-Object -ComObject Pla.DataCollectorSet
    try {
        $conjunto.Query($nome, $null)
        if ($conjunto.Status -eq 1) { $conjunto.Stop($true) }
        $conjunto.Delete()
    } catch {
        # ainda não existia
    }
}

function Criar-ConjuntoDeAlertas([string]$nome, [string[]]$limites, [int]$intervalo) {
    Remover-Conjunto $nome
    $conjunto = New-Object -ComObject Pla.DataCollectorSet
    $conjunto.DisplayName = $nome
    $conjunto.Description = 'Oásis: alertas de CPU, disco e memória'
    $alerta = $conjunto.DataCollectors.CreateDataCollector(3)   # 3 = alerta de contador
    $alerta.Name = 'Limites'
    $alerta.SampleInterval = $intervalo
    $alerta.AlertThresholds = $limites
    $alerta.EventLog = $true                                       # grava cada alerta no log
    $conjunto.DataCollectors.Add($alerta)
    $conjunto.Commit($nome, $null, 0x0003) | Out-Null              # criar ou alterar
    $conjunto.Start($false)
}

if ($Testar) {
    Escrever-Passo 'Teste: limites que disparam na hora (conjunto temporário Oasis-Alertas-Teste)'
    Criar-ConjuntoDeAlertas 'Oasis-Alertas-Teste' @("$cpu>0", "$disco<100", "$memoria<1000000") 5
    $inicio = Get-Date
    Escrever-Passo 'Gerando 60 s de CPU alta (o alerta real de CPU > 85% também dispara)'
    $nucleos = [Environment]::ProcessorCount
    $trabalhos = 1..$nucleos | ForEach-Object {
        Start-Job -ScriptBlock {
            $fim = (Get-Date).AddSeconds(60)
            while ((Get-Date) -lt $fim) { [Math]::Sqrt(123456789) | Out-Null }
        }
    }
    $trabalhos | Wait-Job | Remove-Job
    Remover-Conjunto 'Oasis-Alertas-Teste'
    Escrever-Passo 'Alertas registrados (evento 2031) desde o início do teste'
    Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Diagnosis-PLA/Operational'; Id = 2031; StartTime = $inicio } -ErrorAction SilentlyContinue |
        Select-Object -First 12 | Format-Table TimeCreated, Message -Wrap
    return
}

Escrever-Passo 'Conjunto de alertas Oasis-Alertas'
Criar-ConjuntoDeAlertas 'Oasis-Alertas' @("$cpu>85", "$disco<15", "$memoria<500") 15
Escrever-Ok "$cpu > 85"
Escrever-Ok "$disco < 15"
Escrever-Ok "$memoria < 500"

Escrever-Passo 'Registro de desempenho Oasis-Desempenho (para os gráficos do vídeo)'
$nomeLog = 'Oasis-Desempenho'
logman stop $nomeLog 2>&1 | Out-Null
logman delete $nomeLog 2>&1 | Out-Null
$contadores = @(
    $cpu, $memoria, $disco,
    (Traduzir-Contador '\Web Service(_Total)\Current Connections'),
    (Traduzir-Contador '\Process(python)\% Processor Time'),
    (Traduzir-Contador '\Process(python)\Working Set')
)
logman create counter $nomeLog -c $contadores -si 00:00:15 -f bincirc -max 256 -o (Join-Path $Oasis.Raiz 'logs\perfmon\desempenho') | Out-Null
logman start $nomeLog | Out-Null
Escrever-Ok "grava em $($Oasis.Raiz)\logs\perfmon"

Escrever-Passo 'Os dois conjuntos voltam a rodar quando o servidor reinicia'
$acao = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument '/c logman start Oasis-Alertas & logman start Oasis-Desempenho'
$gatilho = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'Oasis-Monitoramento' -Action $acao -Trigger $gatilho -Principal $principal -Force | Out-Null
Escrever-Ok 'tarefa agendada Oasis-Monitoramento'

Escrever-Passo 'Visualizador de Eventos: fonte "Oasis" e modo de exibição "Oásis"'
Garantir-FonteDeEventos 'Oasis'
$pastaVisoes = Join-Path $env:ProgramData 'Microsoft\Event Viewer\Views'
New-Item -ItemType Directory -Force -Path $pastaVisoes | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'visao-oasis.xml') -Destination (Join-Path $pastaVisoes 'Oasis.xml') -Force
Escrever-Ok 'Modos de Exibição Personalizados > Oásis (se não aparecer: Ação > Importar Modo de Exibição Personalizado)'

logman query
Write-Host 'Próximo: 10-tolerancia-a-falhas.ps1  (para testar os alertas: .\09-monitoramento.ps1 -Testar)' -ForegroundColor Yellow
