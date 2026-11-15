#Requires -RunAsAdministrator
# Passo 07 · Políticas de grupo e auditoria.
#  - GPO "Oasis - Operadores" (OU Operadores): bloqueio de tela em 5 min e Painel de Controle fechado
#  - GPO "Oasis - Servidor" (OU Domain Controllers): aviso de uso no logon e auditoria por subcategoria
#  - Subcategorias de auditoria: logon, bloqueio de conta, arquivos, contas, grupos, política
#  - Auditoria de acesso (SACL) no arquivo de segredos e nas pastas do código

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"
Import-Module GroupPolicy, ActiveDirectory

$dominio = Get-ADDomain
$ouOperadores = "OU=Operadores,OU=Oasis,$($dominio.DistinguishedName)"
$ouControladores = $dominio.DomainControllersContainer

function Garantir-GPO([string]$nome, [string]$comentario) {
    if (-not (Get-GPO -Name $nome -ErrorAction SilentlyContinue)) {
        New-GPO -Name $nome -Comment $comentario | Out-Null
    }
}
function Garantir-Vinculo([string]$nome, [string]$alvo) {
    $existente = (Get-GPInheritance -Target $alvo).GpoLinks | Where-Object { $_.DisplayName -eq $nome }
    if (-not $existente) { New-GPLink -Name $nome -Target $alvo -LinkEnabled Yes -Order 1 | Out-Null }
    Escrever-Ok "$nome vinculada a $alvo"
}

# ------------------------------------------------ GPO dos operadores
Escrever-Passo 'GPO "Oasis - Operadores"'
$gpoOperadores = 'Oasis - Operadores'
Garantir-GPO $gpoOperadores 'Estações dos agentes do posto: bloqueio de tela e Painel de Controle fechado'
$tela = 'HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop'
Set-GPRegistryValue -Name $gpoOperadores -Key $tela -ValueName 'ScreenSaveActive' -Type String -Value '1' | Out-Null
Set-GPRegistryValue -Name $gpoOperadores -Key $tela -ValueName 'ScreenSaverIsSecure' -Type String -Value '1' | Out-Null
Set-GPRegistryValue -Name $gpoOperadores -Key $tela -ValueName 'ScreenSaveTimeOut' -Type String -Value '300' | Out-Null
Set-GPRegistryValue -Name $gpoOperadores -Key $tela -ValueName 'SCRNSAVE.EXE' -Type String -Value 'scrnsave.scr' | Out-Null
Set-GPRegistryValue -Name $gpoOperadores -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' `
    -ValueName 'NoControlPanel' -Type DWord -Value 1 | Out-Null
Garantir-Vinculo $gpoOperadores $ouOperadores

# ------------------------------------------------- GPO do servidor
Escrever-Passo 'GPO "Oasis - Servidor"'
$gpoServidor = 'Oasis - Servidor'
Garantir-GPO $gpoServidor 'Servidor do Oásis: aviso de uso no logon e auditoria por subcategoria'
$politicasSistema = 'HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System'
Set-GPRegistryValue -Name $gpoServidor -Key $politicasSistema -ValueName 'legalnoticecaption' -Type String `
    -Value 'Oásis - acesso restrito' | Out-Null
Set-GPRegistryValue -Name $gpoServidor -Key $politicasSistema -ValueName 'legalnoticetext' -Type String `
    -Value 'Uso permitido só para a administração do Oásis. Os acessos são registrados e auditados.' | Out-Null
# "Auditoria: forçar as configurações de subcategoria": faz valer a auditoria detalhada abaixo.
Set-GPRegistryValue -Name $gpoServidor -Key 'HKLM\System\CurrentControlSet\Control\Lsa' `
    -ValueName 'SCENoApplyLegacyAuditPolicy' -Type DWord -Value 1 | Out-Null
Garantir-Vinculo $gpoServidor $ouControladores

# --------------------------------------------- subcategorias de auditoria
Escrever-Passo 'Auditoria por subcategoria (sucesso e falha)'
# Pelo GUID, o auditpol funciona em qualquer idioma do Windows.
$subcategorias = [ordered]@{
    'Logon'                                = '{0CCE9215-69AE-11D9-BED3-505054503030}'
    'Bloqueio de conta'                    = '{0CCE9217-69AE-11D9-BED3-505054503030}'
    'Sistema de arquivos'                  = '{0CCE921D-69AE-11D9-BED3-505054503030}'
    'Alteração da política de auditoria'   = '{0CCE922F-69AE-11D9-BED3-505054503030}'
    'Gerenciamento de contas de usuário'   = '{0CCE9235-69AE-11D9-BED3-505054503030}'
    'Gerenciamento de grupos de segurança' = '{0CCE9237-69AE-11D9-BED3-505054503030}'
}
foreach ($item in $subcategorias.GetEnumerator()) {
    auditpol /set "/subcategory:$($item.Value)" /success:enable /failure:enable | Out-Null
    Escrever-Ok $item.Key
}

# ------------------------------------------------------- SACL
Escrever-Passo 'Auditoria de acesso (SACL): quem leu os segredos e quem mexeu no código'
$todos = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0')   # Todos
$heranca = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
$propagacao = [System.Security.AccessControl.PropagationFlags]::None
$sucessoEFalha = [System.Security.AccessControl.AuditFlags]'Success, Failure'

function Auditar-Pasta([string]$pasta, [string]$direitos) {
    $acl = Get-Acl -Path $pasta -Audit
    $regra = New-Object System.Security.AccessControl.FileSystemAuditRule(
        $todos, [System.Security.AccessControl.FileSystemRights]$direitos, $heranca, $propagacao, $sucessoEFalha)
    $acl.AddAuditRule($regra)
    Set-Acl -Path $pasta -AclObject $acl
    Escrever-Ok "$pasta ($direitos)"
}
Auditar-Pasta (Join-Path $Oasis.Raiz 'config') 'ReadData, WriteData, Delete, ChangePermissions'
Auditar-Pasta (Join-Path $Oasis.Raiz 'api') 'WriteData, AppendData, Delete, ChangePermissions'
Auditar-Pasta (Join-Path $Oasis.Raiz 'site') 'WriteData, AppendData, Delete, ChangePermissions'

# ------------------------------------------------------ aplicar
Escrever-Passo 'Aplicando as políticas e conferindo'
gpupdate /force | Out-Null
auditpol /get "/subcategory:$($subcategorias.Values -join ',')"
Get-GPInheritance -Target $ouOperadores | Select-Object -ExpandProperty GpoLinks | Format-Table DisplayName, Enabled, Order -AutoSize
Get-GPInheritance -Target $ouControladores | Select-Object -ExpandProperty GpoLinks | Format-Table DisplayName, Enabled, Order -AutoSize
Write-Host 'Próximo: 08-acesso-remoto-e-firewall.ps1' -ForegroundColor Yellow
