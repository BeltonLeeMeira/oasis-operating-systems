#Requires -RunAsAdministrator
# Passo 08 · Acesso remoto seguro e firewall.
#  - Área de Trabalho Remota com NLA, só a partir da rede de administração (RedeAdmin)
#  - PowerShell remoto (WinRM) só da rede de administração
#  - HTTP 80 aberto para a rede (aplicação); PostgreSQL 5432 bloqueado para quem vem de fora
# As regras são achadas pelo nome interno, que é o mesmo em qualquer idioma do Windows.

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"

Escrever-Passo 'Área de Trabalho Remota com autenticação no nível da rede (NLA)'
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -Value 1
Get-NetFirewallRule -Name 'RemoteDesktop-UserMode-In-TCP', 'RemoteDesktop-UserMode-In-UDP' -ErrorAction SilentlyContinue |
    Set-NetFirewallRule -Enabled True -RemoteAddress $Oasis.RedeAdmin
Escrever-Ok "RDP (3389) só de $($Oasis.RedeAdmin); entram só os administradores (GG_Oasis_Admins)"

Escrever-Passo 'PowerShell remoto (WinRM) só da rede de administração'
Get-NetFirewallRule -Name 'WINRM-HTTP-In-TCP', 'WINRM-HTTP-In-TCP-PUBLIC' -ErrorAction SilentlyContinue |
    Set-NetFirewallRule -RemoteAddress $Oasis.RedeAdmin
Escrever-Ok "WinRM (5985) só de $($Oasis.RedeAdmin)"

Escrever-Passo 'Aplicação: HTTP 80 aberto para a rede'
Get-NetFirewallRule -Name 'IIS-WebServerRole-HTTP-In-TCP' -ErrorAction SilentlyContinue | Set-NetFirewallRule -Enabled True
Escrever-Ok 'porta 80'

Escrever-Passo 'Ping liberado na rede local (Test-NetConnection a partir do seu PC)'
Get-NetFirewallRule -Name 'FPS-ICMP4-ERQ-In' -ErrorAction SilentlyContinue | Set-NetFirewallRule -Enabled True -RemoteAddress LocalSubnet
Escrever-Ok 'ICMPv4 echo'

Escrever-Passo 'Banco: porta 5432 bloqueada para quem vem de fora'
if (-not (Get-NetFirewallRule -Name 'Oasis-Bloqueia-PostgreSQL' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'Oasis-Bloqueia-PostgreSQL' -DisplayName 'Oasis - bloqueia PostgreSQL (5432) de fora' `
        -Direction Inbound -Protocol TCP -LocalPort 5432 -Action Block | Out-Null
}
Escrever-Ok 'regra Oasis-Bloqueia-PostgreSQL'

Escrever-Passo 'Portas escutando neste servidor'
Get-NetTCPConnection -State Listen | Sort-Object LocalPort -Unique |
    Format-Table LocalAddress, LocalPort, @{ Name = 'Processo'; Expression = { (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName } } -AutoSize
Write-Host 'Próximo: 09-monitoramento.ps1' -ForegroundColor Yellow
