#Requires -RunAsAdministrator
# Passo 01 · IP fixo, DNS inicial, fuso horário e nome do servidor.
# Rode no console da VM (o IP muda no meio do script). No fim, reinicie.

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"

$adaptador = Get-NetAdapter -Name $Oasis.Interface -ErrorAction SilentlyContinue
if (-not $adaptador) {
    Get-NetAdapter | Format-Table Name, InterfaceDescription, Status -AutoSize
    throw "Não achei a placa '$($Oasis.Interface)'. Ajuste Interface no 00-config.ps1 com um dos nomes acima."
}

Escrever-Passo "IP fixo $($Oasis.IP)/$($Oasis.Prefixo), gateway $($Oasis.Gateway)"
Set-NetIPInterface -InterfaceIndex $adaptador.ifIndex -Dhcp Disabled
Get-NetIPAddress -InterfaceIndex $adaptador.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false
Get-NetRoute -InterfaceIndex $adaptador.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Remove-NetRoute -Confirm:$false
New-NetIPAddress -InterfaceIndex $adaptador.ifIndex -IPAddress $Oasis.IP -PrefixLength $Oasis.Prefixo `
    -DefaultGateway $Oasis.Gateway | Out-Null
# Antes do AD, o DNS ainda é o externo. Depois da promoção (passo 03), passa a ser o próprio servidor.
Set-DnsClientServerAddress -InterfaceIndex $adaptador.ifIndex -ServerAddresses $Oasis.DnsExterno
Escrever-Ok 'endereço configurado'

Escrever-Passo 'Fuso horário de Brasília'
Set-TimeZone -Id 'E. South America Standard Time'
Escrever-Ok (Get-TimeZone).DisplayName

Escrever-Passo "Nome do servidor: $($Oasis.NomeServidor)"
if ($env:COMPUTERNAME -ne $Oasis.NomeServidor) {
    Rename-Computer -NewName $Oasis.NomeServidor -Force
    Escrever-Ok "renomeado (vale depois de reiniciar)"
} else {
    Escrever-Ok 'o nome já está certo'
}

ipconfig /all
Write-Host ''
Write-Host 'Reinicie agora (Restart-Computer) e depois rode o 02-dominio-ad.ps1.' -ForegroundColor Yellow
