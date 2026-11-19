#Requires -RunAsAdministrator
# Passo 13 · File Server e DFS.
# Pasta de boletins do posto (relatórios de calor, listas impressas), com permissões por grupo,
# publicada no namespace DFS \\oasis.local\Oasis\Boletins.

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"

Escrever-Passo 'Funções Servidor de Arquivos e Namespaces DFS'
Install-WindowsFeature -Name FS-FileServer, FS-DFS-Namespace -IncludeManagementTools | Format-Table -AutoSize

$netbios = $Oasis.NetBIOS
# Grupo Administradores interno pelo SID (o nome muda com o idioma do Windows).
$admins = ([Security.Principal.SecurityIdentifier]'S-1-5-32-544').Translate([Security.Principal.NTAccount]).Value
$boletins = 'C:\Compartilhamentos\Boletins'
$raizDfs = 'C:\DFSRoots\Oasis'
New-Item -ItemType Directory -Force -Path $boletins, $raizDfs | Out-Null

Escrever-Passo 'NTFS: admins controle total, operadores modificam, mais ninguém'
icacls $boletins /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' "$netbios\GG_Oasis_Admins:(OI)(CI)F" "$netbios\GG_Oasis_Operadores:(OI)(CI)M" /Q | Out-Null
icacls $boletins

Escrever-Passo 'Compartilhamentos SMB'
if (-not (Get-SmbShare -Name 'Boletins' -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name 'Boletins' -Path $boletins -FullAccess $admins, "$netbios\GG_Oasis_Admins" -ChangeAccess "$netbios\GG_Oasis_Operadores" `
        -FolderEnumerationMode AccessBased | Out-Null
}
if (-not (Get-SmbShare -Name 'Oasis' -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name 'Oasis' -Path $raizDfs -ReadAccess "$netbios\GG_Oasis_Operadores" -FullAccess $admins, "$netbios\GG_Oasis_Admins" | Out-Null
}
# Administradores do servidor (inclui OASIS\Administrator) também entram nos dois compartilhamentos.
foreach ($nome in 'Boletins', 'Oasis') {
    Grant-SmbShareAccess -Name $nome -AccountName $admins -AccessRight Full -Force | Out-Null
}
Get-SmbShare -Name 'Boletins', 'Oasis' | Format-Table Name, Path, FolderEnumerationMode -AutoSize

Escrever-Passo "Namespace DFS \\$($Oasis.Dominio)\Oasis"
$namespace = "\\$($Oasis.Dominio)\Oasis"
if (-not (Get-DfsnRoot -Path $namespace -ErrorAction SilentlyContinue)) {
    New-DfsnRoot -Path $namespace -TargetPath "\\$($Oasis.NomeServidor)\Oasis" -Type DomainV2 | Out-Null
}
if (-not (Get-DfsnFolder -Path "$namespace\Boletins" -ErrorAction SilentlyContinue)) {
    New-DfsnFolder -Path "$namespace\Boletins" -TargetPath "\\$($Oasis.NomeServidor)\Boletins" | Out-Null
}
Get-DfsnFolderTarget -Path "$namespace\Boletins" | Format-Table Path, TargetPath, State -AutoSize
Escrever-Ok "Os operadores abrem $namespace\Boletins"

Salvar-Evidencia '16-file-server-e-dfs.txt' {
    'PS> Get-WindowsFeature FS-FileServer, FS-DFS-Namespace'; Get-WindowsFeature FS-FileServer, FS-DFS-Namespace | Format-Table Name, InstallState -AutoSize
    'PS> Get-SmbShare'; Get-SmbShare -Name 'Boletins', 'Oasis' | Format-Table Name, Path, FolderEnumerationMode -AutoSize
    'PS> Get-SmbShareAccess Boletins'; Get-SmbShareAccess -Name 'Boletins' | Format-Table AccountName, AccessControlType, AccessRight -AutoSize
    "PS> icacls $boletins"; icacls $boletins
    "PS> Get-DfsnRoot / Get-DfsnFolderTarget"; Get-DfsnRoot -Path $namespace | Format-Table Path, Type, State -AutoSize
    Get-DfsnFolderTarget -Path "$namespace\Boletins" | Format-Table Path, TargetPath, State -AutoSize
    "PS> Get-ChildItem $namespace"; Get-ChildItem $namespace -ErrorAction Continue | Format-Table Name, FullName -AutoSize
}
