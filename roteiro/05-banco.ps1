#Requires -RunAsAdministrator
# Passo 05 · Banco da aplicação: PostgreSQL só em localhost, usuário "oasis" com senha
# aleatória e o arquivo de segredos C:\oasis\config\oasis.env (lido pela API).

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"

$psql = Join-Path $Oasis.PastaPostgres 'bin\psql.exe'
if (-not (Test-Path $psql)) { throw "Não achei $psql. Rode o 04 antes." }

# ------------------------------------------------ só a própria máquina
Escrever-Passo 'PostgreSQL escuta só em localhost (a porta 5432 não aparece na rede)'
$arquivoConf = Join-Path $Oasis.PastaPostgres 'data\postgresql.conf'
$linhas = Get-Content -Path $arquivoConf
$linhas = $linhas -replace '^\s*#?\s*listen_addresses\s*=.*$', "listen_addresses = 'localhost'    # Oasis: so a propria maquina"
[IO.File]::WriteAllLines($arquivoConf, $linhas)
Restart-Service -Name $Oasis.ServicoBanco
Get-NetFirewallPortFilter -Protocol TCP | Where-Object { $_.LocalPort -eq '5432' } | Get-NetFirewallRule |
    Where-Object { $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' } | Disable-NetFirewallRule
Escrever-Ok "listen_addresses = 'localhost'"

# ------------------------------------------------- usuário e banco
Escrever-Passo 'Usuário e banco "oasis"'
$senhaSuper = Converter-SenhaParaTexto (Read-Host 'Senha do superusuário "postgres"' -AsSecureString)
$senhaApp = Nova-Senha 24
$env:PGPASSWORD = $senhaSuper
try {
    $existe = & $psql -h localhost -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname = 'oasis'"
    if ("$existe".Trim() -eq '1') {
        & $psql -h localhost -U postgres -c "ALTER ROLE oasis WITH LOGIN PASSWORD '$senhaApp';"
    } else {
        & $psql -h localhost -U postgres -c "CREATE ROLE oasis WITH LOGIN PASSWORD '$senhaApp';"
    }
    $banco = & $psql -h localhost -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'oasis'"
    if ("$banco".Trim() -ne '1') {
        & $psql -h localhost -U postgres -c 'CREATE DATABASE oasis OWNER oasis;'
    }
} finally {
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}
Escrever-Ok 'usuário oasis (senha aleatória, só no arquivo de segredos)'

# ------------------------------------------------ arquivo de segredos
Escrever-Passo 'Arquivo de segredos C:\oasis\config\oasis.env'
$pastaConfig = Join-Path $Oasis.Raiz 'config'
New-Item -ItemType Directory -Force -Path $pastaConfig | Out-Null
$arquivoEnv = Join-Path $pastaConfig 'oasis.env'

# Mantém a chave do posto se ela já existe (o Painel do Posto já usa essa chave).
$chavePosto = Nova-Senha 32
if (Test-Path $arquivoEnv) {
    $anterior = Select-String -Path $arquivoEnv -Pattern '^OASIS_CHAVE_POSTO=(.+)$' | Select-Object -First 1
    if ($anterior) { $chavePosto = $anterior.Matches[0].Groups[1].Value }
}

$conteudo = @(
    '# Segredos da API Oasis neste servidor. NTFS: so OasisPool e Administradores (passo 06).'
    "OASIS_DATABASE_URL=postgresql+psycopg://oasis:$senhaApp@localhost:5432/oasis"
    "OASIS_CHAVE_POSTO=$chavePosto"
    'OASIS_MQTT_HABILITADO=true'
    "OASIS_MQTT_HOST=$($Oasis.MqttHost)"
    'OASIS_MQTT_PORTA=1883'
    "OASIS_MQTT_PREFIXO=$($Oasis.MqttPrefixo)"
    "OASIS_MQTT_HMAC_CHAVE=$($Oasis.MqttChaveHmac)"
    "OASIS_MODELO_DIR=$(Join-Path $Oasis.Raiz 'ml\modelo')"
    "OASIS_LOG_ARQUIVO=$(Join-Path $Oasis.Raiz 'logs\api.log')"
    '# /docs desligado no servidor (mude para true se quiser mostrar no video)'
    'OASIS_DOCS_HABILITADA=false'
)
[IO.File]::WriteAllLines($arquivoEnv, $conteudo)
Escrever-Ok $arquivoEnv
Write-Host ''
Write-Host "Chave do posto (use no Painel do Posto e no Insomnia): $chavePosto" -ForegroundColor Yellow
Write-Host 'Próximo: 06-publicar-aplicacao.ps1' -ForegroundColor Yellow
