#Requires -RunAsAdministrator
# Passo 06 · Publica a aplicação web do Oásis no IIS: pastas, código, dependências (pip),
# migrações, pool de aplicativos, site, permissões NTFS e teste em http://localhost/health.
# Pode rodar de novo para publicar uma versão nova do código.

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"
Import-Module WebAdministration

$raiz = $Oasis.Raiz
$arquivoEnv = Join-Path $raiz 'config\oasis.env'
if (-not (Test-Path $arquivoEnv)) { throw 'Falta o arquivo de segredos: rode o 05 antes.' }
if (-not (Test-Path (Join-Path $Oasis.Repositorio 'requirements.txt'))) {
    throw "Não achei o repositório oasis-soa em $($Oasis.Repositorio). Copie o repositório para lá (git clone ou Download ZIP)."
}

# ------------------------------------------------------------ pastas
Escrever-Passo "Pastas da aplicação em $raiz"
foreach ($pasta in 'site', 'api', 'ml\modelo', 'config', 'logs', 'logs\perfmon', 'scripts', 'evidencias') {
    New-Item -ItemType Directory -Force -Path (Join-Path $raiz $pasta) | Out-Null
}

# ------------------------------------------------------------ código
Escrever-Passo 'Copiando a API, o modelo de IA e o web.config'
robocopy $Oasis.Repositorio (Join-Path $raiz 'api') /MIR /XD .venv .git .github __pycache__ .pytest_cache tests evidencias insomnia modelo docs /XF .env *.pyc /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy falhou ($LASTEXITCODE) ao copiar a API." }
robocopy (Join-Path $Oasis.Repositorio 'modelo') (Join-Path $raiz 'ml\modelo') /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy falhou ($LASTEXITCODE) ao copiar o modelo." }
Copy-Item -Path (Join-Path $Oasis.Repositorio 'deploy\web.config') -Destination (Join-Path $raiz 'site\web.config') -Force
Copy-Item -Path (Join-Path $PSScriptRoot '*') -Destination (Join-Path $raiz 'scripts') -Force
Escrever-Ok "$raiz\api, $raiz\ml\modelo, $raiz\site\web.config"

# ----------------------------------------------------- dependências
Escrever-Passo 'Dependências: ambiente virtual Python e pacotes do requirements.txt'
$venv = Join-Path $raiz 'api\.venv'
$python = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path $python)) { & $Oasis.Python -m venv $venv }
& $python -m pip install --upgrade pip --quiet
& $python -m pip install -r (Join-Path $raiz 'api\requirements.txt') --quiet
if ($LASTEXITCODE -ne 0) { throw 'pip install falhou: veja a mensagem acima (internet? DNS?).' }
& $python -m pip list --format=freeze | Select-String -Pattern '^(fastapi|uvicorn|SQLAlchemy|alembic|psycopg|paho-mqtt|scikit-learn)=='
# Pré-compila o código: o pool só tem leitura na pasta da API e não conseguiria gravar os .pyc.
& $python -m compileall -q (Join-Path $raiz 'api\oasis_api') | Out-Null

# ------------------------------------------------- migrações e seed
Escrever-Passo 'Migrações do banco (Alembic) e dados de exemplo'
$env:OASIS_ENV_FILE = $arquivoEnv
Push-Location (Join-Path $raiz 'api')
try {
    & $python -m alembic upgrade head
    if ($LASTEXITCODE -ne 0) { throw 'As migrações falharam: confira a senha do banco no oasis.env (rode o 05 de novo).' }
    & $python -m alembic current
    & $python -m oasis_api.seed
} finally {
    Pop-Location
    Remove-Item Env:\OASIS_ENV_FILE -ErrorAction SilentlyContinue
}

# ------------------------------------------------ pool de aplicativos
Escrever-Passo "Pool de aplicativos $($Oasis.Pool)"
$caminhoPool = "IIS:\AppPools\$($Oasis.Pool)"
if (-not (Test-Path $caminhoPool)) { New-WebAppPool -Name $Oasis.Pool | Out-Null }
Set-ItemProperty $caminhoPool -Name managedRuntimeVersion -Value ''                 # sem código gerenciado (.NET)
Set-ItemProperty $caminhoPool -Name startMode -Value 'AlwaysRunning'                # sobe junto com o IIS
Set-ItemProperty $caminhoPool -Name autoStart -Value $true
Set-ItemProperty $caminhoPool -Name processModel.identityType -Value 'ApplicationPoolIdentity'
Set-ItemProperty $caminhoPool -Name processModel.idleTimeout -Value ([TimeSpan]::Zero)  # nunca dorme (o MQTT fica conectado)
Set-ItemProperty $caminhoPool -Name recycling.periodicRestart.time -Value ([TimeSpan]::Zero)
Set-ItemProperty $caminhoPool -Name failure.rapidFailProtection -Value $true
Set-ItemProperty $caminhoPool -Name failure.rapidFailProtectionInterval -Value ([TimeSpan]::FromMinutes(5))
Set-ItemProperty $caminhoPool -Name failure.rapidFailProtectionMaxCrashes -Value 5
$appcmd = Join-Path $env:windir 'System32\inetsrv\appcmd.exe'
& $appcmd set apppool $Oasis.Pool "/-recycling.periodicRestart.schedule.[value='04:00:00']" 2>&1 | Out-Null
& $appcmd set apppool $Oasis.Pool "/+recycling.periodicRestart.schedule.[value='04:00:00']" | Out-Null
Escrever-Ok 'sem código gerenciado, AlwaysRunning, sem tempo ocioso, reciclagem às 4h'

# --------------------------------------------------------------- site
Escrever-Passo "Site $($Oasis.Site) na porta 80"
if (Test-Path 'IIS:\Sites\Default Web Site') {
    Remove-Website -Name 'Default Web Site'
    Escrever-Ok 'Default Web Site removido (libera a porta 80 e reduz a superfície de ataque)'
}
if (-not (Test-Path "IIS:\Sites\$($Oasis.Site)")) {
    New-Website -Name $Oasis.Site -PhysicalPath (Join-Path $raiz 'site') -ApplicationPool $Oasis.Pool -Port 80 | Out-Null
}
Set-ItemProperty "IIS:\Sites\$($Oasis.Site)" -Name applicationDefaults.preloadEnabled -Value $true
Set-ItemProperty "IIS:\Sites\$($Oasis.Site)" -Name serverAutoStart -Value $true
# O IIS trava a seção <handlers> nos web.config por padrão (erro 500.19): libera a seção, que o web.config do site usa.
& $appcmd unlock config -section:system.webServer/handlers | Out-Null
Escrever-Ok "http://*:80 -> $raiz\site (pré-carregado, inicia com o servidor)"

# ------------------------------------------------------ NTFS
Escrever-Passo 'Permissões NTFS (menor privilégio)'
$pool = "IIS AppPool\$($Oasis.Pool)"
$admins = '*S-1-5-32-544'   # Administradores (por SID: vale em qualquer idioma)
$sistema = '*S-1-5-18'      # SISTEMA
icacls $raiz /inheritance:r /grant:r "${admins}:(OI)(CI)F" "${sistema}:(OI)(CI)F" /Q | Out-Null
icacls (Join-Path $raiz 'site') /grant:r "${pool}:(OI)(CI)RX" /Q | Out-Null
icacls (Join-Path $raiz 'api') /grant:r "${pool}:(OI)(CI)RX" /Q | Out-Null
icacls (Join-Path $raiz 'ml') /grant:r "${pool}:(OI)(CI)RX" /Q | Out-Null
icacls (Join-Path $raiz 'config') /grant:r "${pool}:(OI)(CI)R" /Q | Out-Null
icacls (Join-Path $raiz 'logs') /grant:r "${pool}:(OI)(CI)M" /Q | Out-Null
icacls (Split-Path $Oasis.Python) /grant "${pool}:(OI)(CI)RX" /Q | Out-Null
Escrever-Ok 'Usuários comuns não enxergam C:\oasis; o pool lê o código e só escreve em logs'
icacls (Join-Path $raiz 'config')

# ------------------------------------------------------ teste
Escrever-Passo 'Iniciando e testando http://localhost/health (o primeiro pedido inicia o Python)'
if ((Get-WebAppPoolState -Name $Oasis.Pool).Value -eq 'Started') {
    Restart-WebAppPool -Name $Oasis.Pool
} else {
    Start-WebAppPool -Name $Oasis.Pool
}
Start-Website -Name $Oasis.Site -ErrorAction SilentlyContinue
$ok = $false
for ($tentativa = 1; $tentativa -le 20; $tentativa++) {
    if (Testar-Saude 'http://localhost/health' 20) { $ok = $true; break }
    Start-Sleep -Seconds 3
}
if ($ok) {
    Invoke-RestMethod -Uri 'http://localhost/health' | Format-List
    Escrever-Ok "Abra http://$($Oasis.IP)/ no navegador do seu PC e do celular."
} else {
    Escrever-Aviso 'A API não respondeu. Veja C:\oasis\logs\uvicorn*.log, C:\oasis\logs\api.log e o Visualizador de Eventos.'
}
Write-Host 'Próximo: 07-gpo-e-auditoria.ps1' -ForegroundColor Yellow
