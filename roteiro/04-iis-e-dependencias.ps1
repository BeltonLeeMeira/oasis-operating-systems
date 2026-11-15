#Requires -RunAsAdministrator
# Passo 04 · Funções do IIS e dependências da aplicação: Python 3.13 (runtime),
# HttpPlatformHandler (liga o IIS ao Python) e PostgreSQL 17 (banco).
# Antes, deixe os três instaladores em C:\instaladores (links no README).

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"

function Achar-Instalador([string]$filtro, [string]$ondeBaixar) {
    $arquivo = Get-ChildItem -Path $Oasis.Instaladores -Filter $filtro -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $arquivo) {
        throw "Não achei '$filtro' em $($Oasis.Instaladores). Baixe em $ondeBaixar e rode de novo."
    }
    return $arquivo.FullName
}

# ------------------------------------------------------------- IIS
Escrever-Passo 'Funções do IIS'
$recursos = @(
    'Web-Server', 'Web-Common-Http', 'Web-Default-Doc', 'Web-Static-Content', 'Web-Http-Errors',
    'Web-Http-Logging', 'Web-Log-Libraries', 'Web-Request-Monitor', 'Web-Http-Tracing',
    'Web-Filtering', 'Web-Stat-Compression', 'Web-AppInit', 'Web-Mgmt-Console', 'Web-Scripting-Tools'
)
Install-WindowsFeature -Name $recursos | Format-Table -AutoSize

# ----------------------------------------------------------- Python
Escrever-Passo 'Runtime: Python 3.13 para todos os usuários'
if (-not (Test-Path $Oasis.Python)) {
    $instalador = Achar-Instalador 'python-3.13*-amd64.exe' 'https://www.python.org/downloads/windows/'
    Start-Process -FilePath $instalador -Wait -ArgumentList '/quiet', 'InstallAllUsers=1', 'PrependPath=1', 'Include_test=0', 'Include_launcher=0'
}
& $Oasis.Python --version

# -------------------------------------------------- HttpPlatformHandler
Escrever-Passo 'Módulo do IIS: HttpPlatformHandler'
Import-Module WebAdministration
if (-not (Get-WebGlobalModule -Name 'httpPlatformHandler' -ErrorAction SilentlyContinue)) {
    $msi = Achar-Instalador '*httpPlatformHandler*amd64*.msi' 'https://www.iis.net/downloads/microsoft/httpplatformhandler'
    Start-Process -FilePath 'msiexec.exe' -Wait -ArgumentList '/i', "`"$msi`"", '/qn', '/norestart'
}
Get-WebGlobalModule -Name 'httpPlatformHandler' | Format-Table Name, Image -AutoSize

# --------------------------------------------------------- PostgreSQL
Escrever-Passo 'Banco: PostgreSQL 17'
if (-not (Get-Service -Name $Oasis.ServicoBanco -ErrorAction SilentlyContinue)) {
    $instalador = Achar-Instalador 'postgresql-17*-windows-x64.exe' 'https://www.postgresql.org/download/windows/'
    $senha = Read-Host 'Crie a senha do superusuário "postgres" (sem aspas nem espaços)' -AsSecureString
    $texto = Converter-SenhaParaTexto $senha
    Write-Host '    instalando sem janelas, leva alguns minutos...'
    Start-Process -FilePath $instalador -Wait -ArgumentList '--mode', 'unattended', '--unattendedmodeui', 'minimal',
        '--superpassword', "`"$texto`"", '--serverport', '5432', '--disable-components', 'stackbuilder'
}
$servico = Get-Service -Name $Oasis.ServicoBanco -ErrorAction SilentlyContinue
if ($servico) {
    $servico | Format-Table Name, Status, StartType -AutoSize
} else {
    Escrever-Aviso 'O instalador silencioso não criou o serviço. Rode o instalador do PostgreSQL com duplo clique (porta 5432, sem Stack Builder) e siga para o 05.'
}

Write-Host 'Próximo: 05-banco.ps1' -ForegroundColor Yellow
