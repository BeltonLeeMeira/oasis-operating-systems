#Requires -RunAsAdministrator
# Passo 12 · Coleta as evidências em texto (saídas de comandos) em C:\oasis\evidencias.
# Copie a pasta para evidencias no repositório oasis-operating-systems.

. "$PSScriptRoot\00-config.ps1"
. "$PSScriptRoot\funcoes.ps1"
Import-Module WebAdministration, ActiveDirectory, DnsServer, GroupPolicy

$nomeApi = "$($Oasis.NomeApi).$($Oasis.Dominio)"
Escrever-Passo "Gravando em $($Oasis.Raiz)\evidencias"

Salvar-Evidencia '01-ipconfig.txt' {
    'PS> hostname'; hostname
    'PS> ipconfig /all'; ipconfig /all
}
Salvar-Evidencia '02-nslookup.txt' {
    "PS> nslookup $nomeApi"; nslookup $nomeApi
    "PS> nslookup $($Oasis.NomeServidor)"; nslookup $Oasis.NomeServidor
    "PS> nslookup $($Oasis.IP)"; nslookup $Oasis.IP
    "PS> nslookup $($Oasis.MqttHost)   (encaminhadores)"; nslookup $Oasis.MqttHost
}
Salvar-Evidencia '03-test-netconnection.txt' {
    "PS> Test-NetConnection $nomeApi -Port 80"; Test-NetConnection $nomeApi -Port 80 | Format-List
    'PS> Test-NetConnection localhost -Port 5432   (banco, só local)'; Test-NetConnection localhost -Port 5432 | Format-List
    "PS> Test-NetConnection $($Oasis.MqttHost) -Port 1883   (saída para o broker MQTT)"; Test-NetConnection $Oasis.MqttHost -Port 1883 | Format-List
}
Salvar-Evidencia '04-active-directory.txt' {
    Get-ADDomain | Format-List DNSRoot, NetBIOSName, DomainMode, PDCEmulator, DistinguishedName
    Get-ADForest | Format-List Name, ForestMode, GlobalCatalogs
    Get-ADOrganizationalUnit -Filter * | Format-Table Name, DistinguishedName -AutoSize
    Get-ADGroup -Filter "Name -like 'GG_Oasis*'" | ForEach-Object {
        "Grupo $($_.Name):"; Get-ADGroupMember $_ | Format-Table Name, SamAccountName -AutoSize
    }
    Get-ADDefaultDomainPasswordPolicy | Format-List MinPasswordLength, ComplexityEnabled, LockoutThreshold, LockoutDuration, MaxPasswordAge
}
Salvar-Evidencia '05-dns.txt' {
    Get-DnsServerZone | Format-Table ZoneName, ZoneType, IsDsIntegrated, IsReverseLookupZone -AutoSize
    Get-DnsServerResourceRecord -ZoneName $Oasis.Dominio -Name $Oasis.NomeApi | Format-Table -AutoSize
    Get-DnsServerForwarder | Format-List IPAddress
}
Salvar-Evidencia '06-funcoes-instaladas.txt' {
    Get-WindowsFeature | Where-Object Installed | Format-Table Name, DisplayName -AutoSize
}
Salvar-Evidencia '07-iis.txt' {
    Get-Website | Format-Table Name, State, PhysicalPath, ApplicationPool -AutoSize
    Get-WebBinding | Format-Table protocol, bindingInformation -AutoSize
    $appcmd = Join-Path $env:windir 'System32\inetsrv\appcmd.exe'
    "PS> appcmd list apppool $($Oasis.Pool) /text:*"; & $appcmd list apppool $Oasis.Pool /text:*
    Get-WebGlobalModule -Name httpPlatformHandler | Format-List Name, Image
    "PS> & $($Oasis.Raiz)\api\.venv\Scripts\python.exe --version"; & (Join-Path $Oasis.Raiz 'api\.venv\Scripts\python.exe') --version
    'PS> Get-Content C:\oasis\site\web.config'; Get-Content (Join-Path $Oasis.Raiz 'site\web.config')
}
Salvar-Evidencia '08-ntfs.txt' {
    foreach ($pasta in '', 'site', 'api', 'ml', 'config', 'config\oasis.env', 'logs', 'scripts') {
        $caminho = Join-Path $Oasis.Raiz $pasta
        "PS> icacls $caminho"; icacls $caminho
    }
}
Salvar-Evidencia '09-servicos-e-recuperacao.txt' {
    Get-Service -Name 'WAS', 'W3SVC', $Oasis.ServicoBanco | Format-Table Name, Status, StartType -AutoSize
    foreach ($servico in 'WAS', 'W3SVC', $Oasis.ServicoBanco) { "PS> sc.exe qfailure $servico"; sc.exe qfailure $servico }
    Get-ScheduledTask -TaskName 'Oasis-*' | Format-Table TaskName, State -AutoSize
}
Salvar-Evidencia '10-gpo-e-auditoria.txt' {
    Get-GPO -All | Format-Table DisplayName, GpoStatus, ModificationTime -AutoSize
    'PS> gpresult /r /scope computer'; gpresult /r /scope computer
    'PS> auditpol /get /category:*'; auditpol /get /category:*
}
gpresult /h (Join-Path $Oasis.Raiz 'evidencias\10-gpresult.html') /f | Out-Null
Escrever-Ok 'evidencias\10-gpresult.html'

Salvar-Evidencia '11-monitoramento.txt' {
    'PS> logman query'; logman query
    'PS> logman query Oasis-Desempenho'; logman query Oasis-Desempenho
    Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Diagnosis-PLA/Operational'; Id = 2031 } -MaxEvents 15 -ErrorAction SilentlyContinue |
        Format-Table TimeCreated, Message -Wrap
}
Salvar-Evidencia '12-eventos.txt' {
    'Serviços que caíram (7031/7034):'
    Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 7031, 7034 } -MaxEvents 15 -ErrorAction SilentlyContinue | Format-Table TimeCreated, Id, Message -Wrap
    'Vigia do Oásis (1001-1003):'
    Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'Oasis' } -MaxEvents 15 -ErrorAction SilentlyContinue | Format-Table TimeCreated, Id, LevelDisplayName, Message -Wrap
    'Auditoria: falhas de logon (4625), acesso a arquivos auditados (4663), contas (4720/4740):'
    Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4625, 4663, 4720, 4740 } -MaxEvents 20 -ErrorAction SilentlyContinue | Format-Table TimeCreated, Id, Message -Wrap
}
Salvar-Evidencia '13-logs-do-iis.txt' {
    $pastaLogs = 'C:\inetpub\logs\LogFiles'
    $ultimo = Get-ChildItem -Path $pastaLogs -Recurse -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    "Arquivo: $($ultimo.FullName)"
    Get-Content -Path $ultimo.FullName -Tail 40
    ''
    'Log da API (C:\oasis\logs\api.log):'
    Get-Content -Path (Join-Path $Oasis.Raiz 'logs\api.log') -Tail 30 -ErrorAction SilentlyContinue
}
Salvar-Evidencia '14-aplicacao.txt' {
    'PS> Invoke-RestMethod http://localhost/health'; Invoke-RestMethod -Uri 'http://localhost/health' | ConvertTo-Json
    'PS> Invoke-RestMethod http://localhost/api/risco/agora'; Invoke-RestMethod -Uri 'http://localhost/api/risco/agora' | ConvertTo-Json -Depth 4
    "PS> Invoke-WebRequest http://$nomeApi/"; (Invoke-WebRequest -Uri "http://$nomeApi/" -UseBasicParsing).StatusCode
}
Salvar-Evidencia '15-firewall-e-portas.txt' {
    Get-NetFirewallRule -Name 'RemoteDesktop-UserMode-In-TCP', 'WINRM-HTTP-In-TCP', 'IIS-WebServerRole-HTTP-In-TCP', 'FPS-ICMP4-ERQ-In', 'Oasis-Bloqueia-PostgreSQL' -ErrorAction SilentlyContinue |
        ForEach-Object {
            [pscustomobject]@{
                Regra   = $_.Name
                Ativa   = $_.Enabled
                Acao    = $_.Action
                Origens = ($_ | Get-NetFirewallAddressFilter).RemoteAddress -join ', '
            }
        } | Format-Table -AutoSize
    Get-NetTCPConnection -State Listen | Sort-Object LocalPort -Unique | Format-Table LocalAddress, LocalPort, OwningProcess -AutoSize
}

Write-Host ''
Write-Host "Pronto. Copie $($Oasis.Raiz)\evidencias para a pasta evidencias do repositório oasis-operating-systems." -ForegroundColor Yellow
