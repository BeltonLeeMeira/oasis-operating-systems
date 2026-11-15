#Requires -RunAsAdministrator
# Passo 02 · Instala AD DS e DNS e cria a floresta oasis.local.
# O servidor reinicia sozinho no fim. Depois, entre como OASIS\Administrador.

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"

if ($env:COMPUTERNAME -ne $Oasis.NomeServidor) {
    throw "O nome ainda é $env:COMPUTERNAME. Rode o 01 e reinicie antes."
}

Escrever-Passo 'Instalando as funções AD DS e DNS'
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools | Format-Table -AutoSize

$computador = Get-CimInstance Win32_ComputerSystem
if ($computador.PartOfDomain) {
    Escrever-Ok "o servidor já está no domínio $($computador.Domain); nada a fazer"
    return
}

Escrever-Passo "Criando a floresta $($Oasis.Dominio) (NetBIOS $($Oasis.NetBIOS))"
$senhaDsrm = Read-Host 'Crie a senha do modo de restauração do AD (DSRM)' -AsSecureString
Import-Module ADDSDeployment
Install-ADDSForest -DomainName $Oasis.Dominio -DomainNetbiosName $Oasis.NetBIOS -InstallDns `
    -SafeModeAdministratorPassword $senhaDsrm -Force
# Daqui o Windows reinicia. Ao voltar, rode o 03-dns-e-identidades.ps1.
