# Funções usadas pelos scripts do roteiro. Não rode este arquivo sozinho:
# cada script carrega ele com  . "$PSScriptRoot\funcoes.ps1"
# Compatível com o Windows PowerShell 5.1, que já vem no Windows Server.

function Escrever-Passo([string]$texto) {
    Write-Host ''
    Write-Host "==> $texto" -ForegroundColor Cyan
}

function Escrever-Ok([string]$texto) {
    Write-Host "    OK  $texto" -ForegroundColor Green
}

function Escrever-Aviso([string]$texto) {
    Write-Host "    !!  $texto" -ForegroundColor Yellow
}

# Converte a senha digitada (SecureString) em texto, só para repassar a um instalador ou ao psql.
function Converter-SenhaParaTexto([Security.SecureString]$senha) {
    $ponteiro = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($senha)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ponteiro)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ponteiro)
    }
}

# Senha aleatória só com letras e números (segura para colocar numa URL de banco).
function Nova-Senha([int]$tamanho = 24) {
    $bytes = New-Object byte[] 48
    $gerador = [Security.Cryptography.RandomNumberGenerator]::Create()
    $gerador.GetBytes($bytes)
    $texto = [Convert]::ToBase64String($bytes) -replace '[^A-Za-z0-9]', ''
    return $texto.Substring(0, $tamanho)
}

# Os nomes dos contadores de desempenho mudam com o idioma do Windows:
# "\Processor(_Total)\% Processor Time" vira "\Processador(_Total)\% Tempo de Processador".
# Esta função traduz o caminho em inglês para o idioma instalado (no Windows em inglês, nada muda).
function Traduzir-Contador([string]$caminho) {
    $base = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib'
    $ingles = (Get-ItemProperty -Path "$base\009" -Name Counter).Counter
    $local = (Get-ItemProperty -Path "$base\CurrentLanguage" -Name Counter -ErrorAction SilentlyContinue).Counter
    if (-not $local) { return $caminho }

    $indicePorNome = @{}
    for ($i = 0; $i -lt $ingles.Count - 1; $i += 2) {
        if (-not $indicePorNome.ContainsKey($ingles[$i + 1])) { $indicePorNome[$ingles[$i + 1]] = $ingles[$i] }
    }
    $nomePorIndice = @{}
    for ($i = 0; $i -lt $local.Count - 1; $i += 2) { $nomePorIndice[$local[$i]] = $local[$i + 1] }

    $traduzir = {
        param([string]$nome)
        if ($indicePorNome.ContainsKey($nome) -and $nomePorIndice.ContainsKey($indicePorNome[$nome])) {
            return $nomePorIndice[$indicePorNome[$nome]]
        }
        return $nome
    }
    if ($caminho -notmatch '^\\(?<objeto>[^\\(]+)(?<instancia>\([^)]*\))?\\(?<contador>.+)$') { return $caminho }
    return '\' + (& $traduzir $Matches['objeto']) + $Matches['instancia'] + '\' + (& $traduzir $Matches['contador'])
}

# Fonte "Oasis" no log Aplicativo do Visualizador de Eventos (usada pelo vigia).
function Garantir-FonteDeEventos([string]$fonte = 'Oasis') {
    if (-not [Diagnostics.EventLog]::SourceExists($fonte)) {
        New-EventLog -LogName Application -Source $fonte
    }
}

# True se a API responde 200 em /health (banco no ar).
function Testar-Saude([string]$url = 'http://localhost/health', [int]$tempoLimite = 10) {
    try {
        $resposta = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $tempoLimite
        return ($resposta.StatusCode -eq 200)
    } catch {
        return $false
    }
}

# Roda comandos e grava a saída em C:\oasis\evidencias\<arquivo>, com data e servidor no topo.
function Salvar-Evidencia([string]$arquivo, [scriptblock]$comandos) {
    $pasta = Join-Path $Oasis.Raiz 'evidencias'
    New-Item -ItemType Directory -Force -Path $pasta | Out-Null
    $destino = Join-Path $pasta $arquivo
    $cabecalho = "# $arquivo  |  $env:COMPUTERNAME  |  $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
    $saida = & $comandos 2>&1 | Out-String -Width 220
    Set-Content -Path $destino -Value ($cabecalho + [Environment]::NewLine + $saida) -Encoding UTF8
    Escrever-Ok "evidencias\$arquivo"
}
