#Requires -RunAsAdministrator
# Passo 03 · DNS (encaminhadores, zona reversa, api.oasis.local) e identidades no AD
# (OUs, grupos, usuários de exemplo e política de senha do domínio).

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"
Import-Module ActiveDirectory, DnsServer

# ---------------------------------------------------------------- DNS
Escrever-Passo 'O servidor usa o próprio DNS'
Set-DnsClientServerAddress -InterfaceAlias $Oasis.Interface -ServerAddresses @($Oasis.IP, '127.0.0.1')

Escrever-Passo 'Encaminhadores: o DNS do AD resolve a internet (broker MQTT, pip, atualizações)'
Set-DnsServerForwarder -IPAddress $Oasis.DnsExterno
Escrever-Ok ($Oasis.DnsExterno -join ', ')

Escrever-Passo 'Zona reversa e registros'
$octetos = $Oasis.IP.Split('.')
$rede = '{0}.{1}.{2}.0/24' -f $octetos[0], $octetos[1], $octetos[2]
$zonaReversa = '{2}.{1}.{0}.in-addr.arpa' -f $octetos[0], $octetos[1], $octetos[2]
if (-not (Get-DnsServerZone -Name $zonaReversa -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -NetworkId $rede -ReplicationScope Forest
    Escrever-Ok "zona reversa $zonaReversa"
}
if (-not (Get-DnsServerResourceRecord -ZoneName $Oasis.Dominio -Name $Oasis.NomeApi -RRType A -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordA -ZoneName $Oasis.Dominio -Name $Oasis.NomeApi -IPv4Address $Oasis.IP -CreatePtr
}
Escrever-Ok "$($Oasis.NomeApi).$($Oasis.Dominio) -> $($Oasis.IP)"
ipconfig /registerdns | Out-Null

# --------------------------------------------------- política de senha
Escrever-Passo 'Política de senha e bloqueio do domínio (Default Domain Policy)'
$dominio = Get-ADDomain
Set-ADDefaultDomainPasswordPolicy -Identity $dominio.DNSRoot -MinPasswordLength 10 -ComplexityEnabled $true `
    -LockoutThreshold 5 -LockoutDuration '00:15:00' -LockoutObservationWindow '00:15:00' -MaxPasswordAge '90.00:00:00'
Get-ADDefaultDomainPasswordPolicy | Format-List MinPasswordLength, ComplexityEnabled, LockoutThreshold, LockoutDuration, MaxPasswordAge

# --------------------------------------------------------- OUs e grupos
Escrever-Passo 'Unidades organizacionais e grupos'
$base = "OU=Oasis,$($dominio.DistinguishedName)"

function Garantir-OU([string]$nome, [string]$caminho) {
    $existe = Get-ADOrganizationalUnit -Filter "Name -eq '$nome'" -SearchBase $caminho -SearchScope OneLevel -ErrorAction SilentlyContinue
    if (-not $existe) {
        New-ADOrganizationalUnit -Name $nome -Path $caminho -ProtectedFromAccidentalDeletion $true
    }
    Escrever-Ok "OU $nome"
}
Garantir-OU 'Oasis' $dominio.DistinguishedName
Garantir-OU 'Administradores' $base
Garantir-OU 'Operadores' $base
Garantir-OU 'Grupos' $base

function Garantir-Grupo([string]$nome, [string]$descricao) {
    if (-not (Get-ADGroup -Filter "Name -eq '$nome'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $nome -GroupScope Global -GroupCategory Security -Path "OU=Grupos,$base" -Description $descricao
    }
    Escrever-Ok "grupo $nome"
}
Garantir-Grupo 'GG_Oasis_Admins' 'Administram o servidor do Oásis (inclui acesso remoto)'
Garantir-Grupo 'GG_Oasis_Operadores' 'Agentes do posto: usam o Painel do Posto e a pasta de boletins'

# ------------------------------------------------- usuários de exemplo
Escrever-Passo 'Usuários de exemplo (fictícios)'
$senha = ConvertTo-SecureString (Obter-SenhaInicial 'usuarios-de-exemplo') -AsPlainText -Force

function Garantir-Usuario([string]$login, [string]$nome, [string]$ou, [string]$grupo) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$login'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name $nome -SamAccountName $login -UserPrincipalName "$login@$($Oasis.Dominio)" `
            -Path "OU=$ou,$base" -AccountPassword $senha -Enabled $true -ChangePasswordAtLogon $false
    }
    Add-ADGroupMember -Identity $grupo -Members $login -ErrorAction SilentlyContinue
    Escrever-Ok "$login em $grupo"
}
Garantir-Usuario 'admin.oasis' 'Admin Oásis' 'Administradores' 'GG_Oasis_Admins'
Garantir-Usuario 'op.vilamariana' 'Operador Vila Mariana' 'Operadores' 'GG_Oasis_Operadores'

# O grupo dos admins entra no "Administradores" interno (SID S-1-5-32-544, que funciona em qualquer idioma).
# Só ele pode usar a Área de Trabalho Remota neste servidor; os operadores não entram no servidor.
Add-ADGroupMember -Identity 'S-1-5-32-544' -Members 'GG_Oasis_Admins' -ErrorAction SilentlyContinue
Escrever-Ok 'GG_Oasis_Admins é administrador do servidor'

Escrever-Passo 'Conferência'
nslookup "$($Oasis.NomeApi).$($Oasis.Dominio)"
Get-ADUser -Filter * -SearchBase $base | Format-Table Name, SamAccountName, Enabled, DistinguishedName -AutoSize
Write-Host 'Próximo: baixe os instaladores (ver README) e rode o 04-iis-e-dependencias.ps1.' -ForegroundColor Yellow
