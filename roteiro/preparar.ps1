# Passo 00 · Prepara a VM: baixa os dois repositórios para C:\instaladores e preenche o 00-config.ps1
# com a placa, o IP e o gateway que a VM recebeu da rede (o IP do DHCP vira o IP fixo).
# Uso, no PowerShell como Administrador dentro da VM:
#   irm https://raw.githubusercontent.com/BeltonLeeMeira/oasis-operating-systems/main/roteiro/preparar.ps1 | iex

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
$destino = 'C:\instaladores'
New-Item -ItemType Directory -Force $destino | Out-Null

foreach ($repo in 'oasis-soa', 'oasis-operating-systems') {
    Write-Host "Baixando $repo..." -ForegroundColor Cyan
    $zip = Join-Path $destino "$repo.zip"
    Invoke-WebRequest "https://github.com/BeltonLeeMeira/$repo/archive/refs/heads/main.zip" -OutFile $zip -UseBasicParsing
    $pasta = Join-Path $destino $repo
    if (Test-Path $pasta) { Remove-Item $pasta -Recurse -Force }
    Expand-Archive $zip $destino -Force
    Rename-Item (Join-Path $destino "$repo-main") $repo
    Remove-Item $zip
}
Get-ChildItem $destino -Recurse | Unblock-File

$config = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
if (-not $config) { throw 'A VM não recebeu IP com gateway. Confira se ela está no comutador Externo.' }
$ip = $config.IPv4Address[0].IPAddress
$gateway = $config.IPv4DefaultGateway[0].NextHop
$rede = ($ip -replace '\.\d+$', '.0') + '/24'

$arquivo = Join-Path $destino 'oasis-operating-systems\roteiro\00-config.ps1'
$texto = Get-Content $arquivo -Raw -Encoding UTF8
$texto = $texto -replace "Interface\s*=\s*'[^']*'", "Interface     = '$($config.InterfaceAlias)'"
$texto = $texto -replace "IP\s*=\s*'[^']*'", "IP            = '$ip'"
$texto = $texto -replace "Gateway\s*=\s*'[^']*'", "Gateway       = '$gateway'"
$texto = $texto -replace "RedeAdmin\s*=\s*'[^']*'", "RedeAdmin     = '$rede'"
[IO.File]::WriteAllText($arquivo, $texto, (New-Object Text.UTF8Encoding $true))

Write-Host ''
Write-Host "Pronto. Placa '$($config.InterfaceAlias)', IP fixo $ip, gateway $gateway, rede de administração $rede." -ForegroundColor Green
Write-Host 'Próximo passo:  cd C:\instaladores\oasis-operating-systems\roteiro ; .\01-rede-e-nome.ps1' -ForegroundColor Yellow
