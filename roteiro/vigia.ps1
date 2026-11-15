# Vigia do Oásis: roda a cada minuto pela tarefa agendada "Oasis-Vigia" (criada no passo 10).
# Se http://localhost/health não responde 200, religa o que estiver parado (serviços do IIS,
# PostgreSQL, pool de aplicativos), espera e confere de novo. Tudo fica no log Aplicativo:
#   1001 = falha detectada (aviso) · 1002 = recuperado (informação) · 1003 = não recuperou (erro)

param(
    [string]$Url = 'http://localhost/health',
    [string]$Pool = 'OasisPool',
    [string]$ServicoBanco = 'postgresql-x64-17'
)

$fonte = 'Oasis'

function Saude-Ok {
    try {
        $resposta = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 15
        return ($resposta.StatusCode -eq 200)
    } catch {
        return $false
    }
}

function Registrar([int]$id, [string]$tipo, [string]$mensagem) {
    Write-EventLog -LogName Application -Source $fonte -EventId $id -EntryType $tipo -Message $mensagem
}

if (Saude-Ok) { exit 0 }

$acoes = New-Object System.Collections.Generic.List[string]
foreach ($nome in @('WAS', 'W3SVC', $ServicoBanco)) {
    $servico = Get-Service -Name $nome -ErrorAction SilentlyContinue
    if ($servico -and $servico.Status -ne 'Running') {
        Start-Service -Name $nome -ErrorAction SilentlyContinue
        $acoes.Add("serviço $nome iniciado")
    }
}

Import-Module WebAdministration
$estado = (Get-WebAppPoolState -Name $Pool).Value
if ($estado -ne 'Started') {
    Start-WebAppPool -Name $Pool
    $acoes.Add("pool $Pool iniciado (estava $estado)")
} elseif ($acoes.Count -eq 0) {
    Restart-WebAppPool -Name $Pool
    $acoes.Add("pool $Pool reiniciado")
}

Registrar 1001 'Warning' ("A API não respondeu em $Url. Ações: " + ($acoes -join '; ') + '.')

$recuperado = $false
for ($i = 0; $i -lt 6; $i++) {
    Start-Sleep -Seconds 10
    if (Saude-Ok) { $recuperado = $true; break }
}

if ($recuperado) {
    Registrar 1002 'Information' "A API voltou a responder em $Url."
} else {
    Registrar 1003 'Error' "A API continua fora do ar em $Url. Veja C:\oasis\logs e o log Sistema."
}
