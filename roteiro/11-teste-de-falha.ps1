#Requires -RunAsAdministrator
# Passo 11 · Teste de falha.
# Derruba a aplicação de cinco jeitos e mede quanto tempo ela leva para voltar sozinha:
#   1. processo Python da API morto      -> o HttpPlatformHandler sobe outro no próximo pedido
#   2. processo do pool (w3wp) morto     -> o WAS cria outro (pool AlwaysRunning)
#   3. serviço W3SVC derrubado           -> recuperação automática do serviço (5 s) + evento 7031
#   4. pool de aplicativos parado        -> o vigia percebe em até 1 minuto e religa (eventos 1001/1002)
#   5. PostgreSQL parado                 -> /health fica 503; o vigia inicia o serviço
# O resultado fica em C:\oasis\evidencias\teste-de-falha.txt.

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"
Import-Module WebAdministration

$url = 'http://localhost/health'
$linhas = New-Object System.Collections.Generic.List[string]
$inicioGeral = Get-Date

function Anotar([string]$texto) {
    $linha = '{0}  {1}' -f (Get-Date -Format 'HH:mm:ss'), $texto
    Write-Host $linha
    $linhas.Add($linha)
}

function Esperar-Volta([string]$teste, [datetime]$queda, [int]$limite = 150) {
    $ok = $false
    do {
        Start-Sleep -Seconds 1
        $ok = Testar-Saude $url 5
        $passou = ((Get-Date) - $queda).TotalSeconds
    } until ($ok -or $passou -ge $limite)
    if ($ok) {
        Anotar ('{0}: voltou sozinho em {1:N0} s' -f $teste, $passou)
    } else {
        Anotar ('{0}: NÃO voltou em {1} s' -f $teste, $limite)
    }
}

function Proximo([string]$titulo) {
    Write-Host ''
    Read-Host "Enter para: $titulo" | Out-Null
}

if (-not (Testar-Saude $url)) { throw 'A API precisa estar no ar antes do teste (rode o 06).' }
Anotar 'Início: API no ar'
Invoke-RestMethod -Uri $url | Format-List

# 1 ---------------------------------------------------------------
Proximo 'Teste 1 - matar o processo Python da API'
Get-Process -Name python -ErrorAction SilentlyContinue | Stop-Process -Force
$queda = Get-Date
Anotar 'Teste 1: processo python.exe encerrado à força'
Esperar-Volta 'Teste 1 (processo Python)' $queda

# 2 ---------------------------------------------------------------
Proximo 'Teste 2 - matar o processo do pool (w3wp.exe)'
Get-CimInstance Win32_Process -Filter "Name='w3wp.exe'" |
    Where-Object { $_.CommandLine -match [regex]::Escape($Oasis.Pool) } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
$queda = Get-Date
Anotar "Teste 2: w3wp.exe do $($Oasis.Pool) encerrado à força"
Esperar-Volta 'Teste 2 (processo do pool)' $queda

# 3 ---------------------------------------------------------------
Proximo 'Teste 3 - derrubar o serviço W3SVC'
$idProcesso = (Get-CimInstance Win32_Service -Filter "Name='W3SVC'").ProcessId
Stop-Process -Id $idProcesso -Force
$queda = Get-Date
Anotar "Teste 3: processo do serviço W3SVC (PID $idProcesso) encerrado à força"
Esperar-Volta 'Teste 3 (serviço W3SVC)' $queda
Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 7031, 7034; StartTime = $queda.AddSeconds(-5) } -ErrorAction SilentlyContinue |
    Select-Object -First 4 | Format-Table TimeCreated, Id, Message -Wrap

# 4 ---------------------------------------------------------------
Proximo 'Teste 4 - parar o pool de aplicativos (o vigia confere a cada minuto)'
Stop-WebAppPool -Name $Oasis.Pool
$queda = Get-Date
Anotar "Teste 4: pool $($Oasis.Pool) parado"
Esperar-Volta 'Teste 4 (pool parado, religado pelo vigia)' $queda 150

# 5 ---------------------------------------------------------------
Proximo 'Teste 5 - parar o PostgreSQL'
Stop-Service -Name $Oasis.ServicoBanco -Force
$queda = Get-Date
Anotar "Teste 5: serviço $($Oasis.ServicoBanco) parado (a API responde 503: banco sem resposta)"
try { Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 | Out-Null } catch { Anotar "  /health agora: $($_.Exception.Message)" }
Esperar-Volta 'Teste 5 (banco parado, iniciado pelo vigia)' $queda 150

# resumo ----------------------------------------------------------
Write-Host ''
Escrever-Passo 'Eventos do vigia (fonte Oasis) durante o teste'
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'Oasis'; StartTime = $inicioGeral } -ErrorAction SilentlyContinue |
    Sort-Object TimeCreated | Format-Table TimeCreated, Id, LevelDisplayName, Message -Wrap

$destino = Join-Path $Oasis.Raiz 'evidencias\teste-de-falha.txt'
New-Item -ItemType Directory -Force -Path (Split-Path $destino) | Out-Null
Set-Content -Path $destino -Value $linhas -Encoding UTF8
Escrever-Ok "linha do tempo salva em $destino"
