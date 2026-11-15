# Evidências de Operating Systems

Duas partes: os **textos** que o `12-coletar-evidencias.ps1` gera em `C:\oasis\evidencias` (copie todos para esta pasta) e os **prints** abaixo, tirados dentro da VM. Salve os prints aqui com estes nomes e faça commit.

## Saídas de comandos (geradas pelo script 12)

| Arquivo | Conteúdo |
| --- | --- |
| `01-ipconfig.txt` | `hostname` e `ipconfig /all` (IP fixo, DNS) |
| `02-nslookup.txt` | `api.oasis.local`, `SRV-OASIS`, reverso do IP e um nome externo |
| `03-test-netconnection.txt` | Porta 80 da aplicação, 5432 local e 1883 do broker |
| `04-active-directory.txt` | Domínio, floresta, OUs, grupos e política de senha |
| `05-dns.txt` | Zonas, registro `api` e encaminhadores |
| `06-funcoes-instaladas.txt` | Funções e recursos instalados |
| `07-iis.txt` | Site, vínculos, pool, módulo HttpPlatformHandler, versão do Python e `web.config` |
| `08-ntfs.txt` | `icacls` de cada pasta da aplicação |
| `09-servicos-e-recuperacao.txt` | Serviços, `sc qfailure` e tarefas agendadas |
| `10-gpo-e-auditoria.txt` e `10-gpresult.html` | GPOs, `gpresult` e `auditpol` |
| `11-monitoramento.txt` | Conjuntos de coletores e alertas 2031 |
| `12-eventos.txt` | Eventos 7031/7034, vigia e auditoria |
| `13-logs-do-iis.txt` | Últimas linhas do log do IIS e da API |
| `14-aplicacao.txt` | `/health`, `/api/risco/agora` e a página pelo nome DNS |
| `15-firewall-e-portas.txt` | Regras de firewall e portas escutando |
| `teste-de-falha.txt` | Linha do tempo do script 11 |

## Prints

| Arquivo | O que capturar |
| --- | --- |
| `p01-vm.png` | Configuração da VM (CPU, memória, rede externa ou bridge) |
| `p02-gerenciador-do-servidor.png` | Gerenciador do Servidor com AD DS, DNS e IIS |
| `p03-ad-ous.png` | Usuários e Computadores do AD: OU Oasis com Administradores, Operadores e Grupos |
| `p04-dns.png` | Gerenciador de DNS: registro `api` em `oasis.local` e a zona reversa |
| `p05-nslookup-testnet.png` | Terminal com `nslookup api.oasis.local` e `Test-NetConnection api.oasis.local -Port 80` |
| `p06-iis-site-pool.png` | Gerenciador do IIS: site Oasis e pool OasisPool (Sem Código Gerenciado, AlwaysRunning) |
| `p07-iis-modulo.png` | Módulos do IIS com o `httpPlatformHandler` |
| `p08-ntfs-config.png` | Propriedades de `C:\oasis\config` → Segurança: só OasisPool, Administradores e SISTEMA |
| `p09-pagina-no-pc.png` | Navegador do seu PC em `http://IP-da-VM/` |
| `p10-app-no-iphone.png` | App no iPhone usando a API da VM |
| `p11-perfmon-alertas.png` | Monitor de Desempenho → Conjuntos de Coletores de Dados → Definido pelo Usuário → Oasis-Alertas, com os limites |
| `p12-evento-2031.png` | Visualizador de Eventos com um alerta de desempenho (2031) |
| `p13-teste-de-falha.png` | Terminal do script 11 com os tempos de volta |
| `p14-evento-7031.png` | Evento 7031 do W3SVC com a ação de recuperação |
| `p15-vigia.png` | Eventos 1001 e 1002 da fonte Oasis |
| `p16-recuperacao-servico.png` | services.msc → W3SVC → aba Recuperação |
| `p17-gpo.png` | GPMC com "Oasis - Operadores" e "Oasis - Servidor" vinculadas |
| `p18-auditoria-4663.png` | Evento 4663: acesso ao `oasis.env` |
| `p19-log-iis.png` | Log do IIS aberto com pedidos `/api` e `/health` |
| `p20-rdp.png` | Área de Trabalho Remota como `OASIS\admin.oasis`, com o aviso de logon |
