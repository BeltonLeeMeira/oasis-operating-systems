# Baixa para C:\instaladores os três instaladores do passo 04: Python 3.13 (a versão 3.13 mais nova
# com instalador para Windows), HttpPlatformHandler v1.2 (x64) e PostgreSQL 17 (instalador da EDB).

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
$destino = $Oasis.Instaladores
New-Item -ItemType Directory -Force $destino | Out-Null

function Existe([string]$url) {
    try { return (Invoke-WebRequest $url -Method Head -UseBasicParsing -TimeoutSec 30).StatusCode -eq 200 } catch { return $false }
}
function Baixar([string]$url, [string]$nome) {
    Write-Host "    baixando $nome..."
    Invoke-WebRequest $url -OutFile (Join-Path $destino $nome) -UseBasicParsing
    Escrever-Ok $nome
}

Escrever-Passo 'Python 3.13'
if (-not (Get-ChildItem $destino -Filter 'python-3.13*-amd64.exe' -ErrorAction SilentlyContinue)) {
    $achou = $false
    for ($n = 25; $n -ge 0 -and -not $achou; $n--) {
        $url = "https://www.python.org/ftp/python/3.13.$n/python-3.13.$n-amd64.exe"
        if (Existe $url) { Baixar $url "python-3.13.$n-amd64.exe"; $achou = $true }
    }
    if (-not $achou) { Escrever-Aviso 'Não achei o instalador; baixe em https://www.python.org/downloads/windows/' }
}

Escrever-Passo 'HttpPlatformHandler v1.2 (x64)'
if (-not (Get-ChildItem $destino -Filter '*httpPlatformHandler*amd64*.msi' -ErrorAction SilentlyContinue)) {
    Baixar 'https://go.microsoft.com/fwlink/?LinkId=690721' 'httpPlatformHandler_amd64.msi'
}

Escrever-Passo 'PostgreSQL 17'
if (-not (Get-ChildItem $destino -Filter 'postgresql-17*-windows-x64.exe' -ErrorAction SilentlyContinue)) {
    $achou = $false
    for ($n = 25; $n -ge 0 -and -not $achou; $n--) {
        foreach ($rev in 2, 1) {
            $nome = "postgresql-17.$n-$rev-windows-x64.exe"
            if (-not $achou -and (Existe "https://get.enterprisedb.com/postgresql/$nome")) {
                Baixar "https://get.enterprisedb.com/postgresql/$nome" $nome
                $achou = $true
            }
        }
    }
    if (-not $achou) { Escrever-Aviso 'Não achei o instalador; baixe em https://www.postgresql.org/download/windows/' }
}

Get-ChildItem $destino -File | Format-Table Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } } -AutoSize
