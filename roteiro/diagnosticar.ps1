# Diagnóstico rápido da aplicação no IIS: módulo, pool, site, resposta local e últimos logs.
# Uso: .\diagnosticar.ps1   (PowerShell como Administrador)

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"
Import-Module WebAdministration

Escrever-Passo 'Módulo HttpPlatformHandler'
Get-WebGlobalModule | Where-Object Name -like '*httpPlatform*' | Format-Table Name, Image -AutoSize
Test-Path "$env:windir\System32\inetsrv\httpPlatformHandler.dll"

Escrever-Passo 'Pool e site'
Get-WebAppPoolState -Name $Oasis.Pool | Format-Table @{ n = 'Pool'; e = { $Oasis.Pool } }, Value -AutoSize
Get-Website -Name $Oasis.Site | Format-Table Name, State, PhysicalPath -AutoSize

Escrever-Passo 'Resposta em http://localhost/health (o erro completo só aparece na própria máquina)'
try {
    $r = Invoke-WebRequest 'http://localhost/health' -UseBasicParsing -TimeoutSec 60
    "HTTP $($r.StatusCode)"; $r.Content
} catch {
    $resp = $_.Exception.Response
    if ($resp) {
        "HTTP $([int]$resp.StatusCode)"
        $leitor = New-Object IO.StreamReader($resp.GetResponseStream())
        $html = $leitor.ReadToEnd()
        # Tira as tags e mostra só o texto do erro detalhado do IIS
        (($html -replace '(?s)<style.*?</style>', '' -replace '<[^>]+>', ' ' -replace '&nbsp;', ' ') -replace '\s{2,}', "`n").Trim() |
            Select-Object -First 1 | ForEach-Object { $_.Substring(0, [Math]::Min(2500, $_.Length)) }
    } else {
        $_.Exception.Message
    }
}

Escrever-Passo 'Últimas linhas dos logs da aplicação'
Get-ChildItem "$($Oasis.Raiz)\logs\uvicorn*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 |
    ForEach-Object { "--- $($_.Name)"; Get-Content $_.FullName -Tail 30 }
if (Test-Path "$($Oasis.Raiz)\logs\api.log") { '--- api.log'; Get-Content "$($Oasis.Raiz)\logs\api.log" -Tail 15 }

Escrever-Passo 'Erros recentes do IIS/WAS no Visualizador de Eventos'
Get-WinEvent -FilterHashtable @{ LogName = 'System', 'Application'; Level = 1, 2; StartTime = (Get-Date).AddHours(-2) } -MaxEvents 8 -ErrorAction SilentlyContinue |
    Format-List TimeCreated, ProviderName, Id, Message
