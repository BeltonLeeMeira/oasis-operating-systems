# Oásis · Infraestrutura Windows Server (Operating Systems)

**Integrante:** Belton Lee Carr De Muzio Meira · RM560760 · 3ESPA

Um Windows Server em VM que hospeda a aplicação web do Oásis no IIS, com domínio, DNS, banco, monitoramento, auditoria e recuperação automática de falhas. Tudo é configurado pelos scripts PowerShell da pasta [`roteiro/`](roteiro/), em ordem, e cada passo deixa evidências.

## Ficha da CitizenTech

| Campo | Resposta |
| --- | --- |
| **Nome da CitizenTech** | Oásis |
| **Equipe** | Belton Lee Carr De Muzio Meira · RM560760 · 3ESPA (equipe individual) |
| **Cidade e bairro** | São Paulo, Vila Mariana |
| **Cidadão beneficiado** | Idosos que moram sozinhos e trabalhadores de rua (ambulantes, entregadores, garis) |
| **Problema, em uma frase** | Nos dias de calor extremo, idosos e trabalhadores de rua não ficam sabendo a tempo que o risco está alto nem onde há água e sombra por perto. |
| **Como funciona** | Estações com sensor medem temperatura e umidade e calculam o índice de calor. Um modelo treinado com 11 anos de dados do INMET prevê se amanhã será dia de risco. O app avisa e mostra os pontos de água e sombra mais próximos, e o posto comunitário valida os pontos e prioriza quem acompanhar nos dias críticos. |
| **O que cada parte faz** | API `oasis-soa` (SOA) guarda e serve os dados e a página pública · Modelo `oasis-ia-ml` (IA & ML) prevê o risco de amanhã · Painel do Posto `oasis-csharp` (C#) aprova pontos e organiza a busca ativa · Servidor `oasis-operating-systems` (Operating Systems) hospeda a API no IIS · App (Mobile) é a porta do cidadão · Estação ESP32 (Physical) mede e sinaliza no local · Relatório de riscos (Cyber) protege a solução · ArchiMate (Testing) descreve a arquitetura |
| **Link do repositório** | https://github.com/BeltonLeeMeira/oasis-operating-systems |
| **Indicador de impacto** | Percentual dos dias de risco avisados na véspera (recall do modelo: 85% no teste, contra 49% sem o modelo) e percentual das pessoas acompanhadas contatadas até 12h nos dias de risco (meta: 100%) |
| **ODS conectados** | 3 (saúde: alerta precoce, meta 3.d) · 10 (redução das desigualdades, meta 10.2) · 11 (cidades: espaços públicos acessíveis, meta 11.7) · 13 (clima: resiliência e alerta precoce, metas 13.1 e 13.3) |

## O que o servidor faz

```
                         rede local (ex.: 192.168.0.0/24)
 iPhone (app Oásis) ─┐
 PC (Painel do Posto)┼── HTTP 80 ──► SRV-OASIS · Windows Server (VM)
 Navegador ──────────┘               ├─ AD DS + DNS ........ domínio oasis.local, registro api.oasis.local
                                     ├─ IIS ................ site "Oasis", pool "OasisPool"
                                     │    └─ HttpPlatformHandler ─► Python 3.13 (API Oásis + página pública)
                                     ├─ PostgreSQL 17 ...... só em localhost (5432 fechada para a rede)
                                     ├─ Monitor de Desempenho: alertas de CPU, disco e memória
                                     ├─ Vigia a cada minuto + recuperação automática dos serviços
                                     └─ GPOs, auditoria, RDP com NLA restrito aos administradores

 Estação ESP32 (Wokwi) ── MQTT ──► broker.hivemq.com ◄── assina (conexão de saída) ── API no servidor
```

## Como a rubrica foi atendida

| Critério | Pontos | O que está configurado | Scripts | Evidência |
| --- | --- | --- | --- | --- |
| Infraestrutura de rede e identidade | 2 | IP fixo, hostname `SRV-OASIS`, floresta `oasis.local` no AD, DNS com `api.oasis.local`, zona reversa e encaminhadores, OUs, grupos, usuários e política de senha | 01, 02, 03 | `01-ipconfig`, `02-nslookup`, `03-test-netconnection`, `04-active-directory`, `05-dns` |
| Aplicação hospedada no IIS | 2 | Funções do IIS, runtime Python 3.13, módulo HttpPlatformHandler, dependências (pip), PostgreSQL, site `Oasis`, pool `OasisPool` sem código gerenciado e sempre ligado, pasta `C:\oasis` com NTFS de menor privilégio | 04, 05, 06 | `06-funcoes-instaladas`, `07-iis`, `08-ntfs`, `14-aplicacao` |
| Monitoramento de CPU, disco e memória | 2 | Conjunto `Oasis-Alertas` no Monitor de Desempenho (CPU acima de 85%, disco C: com menos de 15% livre, memória abaixo de 500 MB, a cada 15 s), cada alerta vira o evento 2031; registro `Oasis-Desempenho` para gráficos | 09 | `11-monitoramento` e prints |
| Serviços tolerantes a falhas e teste de falha | 1 | Recuperação automática de W3SVC, WAS e PostgreSQL; pool `AlwaysRunning` com proteção contra falhas rápidas; HttpPlatformHandler religa o Python; vigia confere `/health` a cada minuto | 10, 11 | `09-servicos-e-recuperacao`, `teste-de-falha.txt`, `12-eventos` |
| Logs de auditoria e acompanhamento | 1 | Auditoria por subcategoria, auditoria de acesso (SACL) ao arquivo de segredos e ao código, modo de exibição "Oásis" no Visualizador de Eventos, logs do IIS e da API | 07, 09 | `10-gpo-e-auditoria`, `10-gpresult.html`, `12-eventos`, `13-logs-do-iis` |
| Funcionamento completo | 2 | Página pública, app no iPhone, Painel do Posto e estação do Wokwi conversando com a API hospedada | 06 e vídeo | `14-aplicacao` e vídeo |

O percurso do PDF também pede GPO e acesso remoto (passos 07 e 08). O passo 13 é um extra com File Server e DFS, serviços do semestre que a rubrica não cobra.

## Antes de começar

1. **VM.** Baixe a ISO do Windows Server 2025 (ou 2022) Evaluation, de 180 dias, no Microsoft Evaluation Center. Instale a edição **Standard Evaluation (Experiência Desktop)**. Use 2 vCPUs, 6 GB de RAM e 60 GB de disco.
   - **Hyper-V** (Windows 11 Pro): conecte a VM a um comutador virtual **Externo**.
   - **VirtualBox**: placa de rede em modo **Bridge**.

   A rede precisa ser externa (ou bridge) para o iPhone e o seu PC enxergarem a VM.
2. **IP.** Escolha um IP livre da sua rede, fora da faixa de DHCP do roteador, e ajuste [`roteiro/00-config.ps1`](roteiro/00-config.ps1) (IP, gateway e nome da placa).
3. **Código.** Dentro da VM, copie os dois repositórios (**Code → Download ZIP** no GitHub, ou `git clone`): a aplicação, `oasis-soa`, em `C:\instaladores\oasis-soa`, e este, `oasis-operating-systems`, em `C:\instaladores\oasis-operating-systems`.
4. **Instaladores.** Baixe para `C:\instaladores`:
   - Python 3.13, Windows installer (64-bit): https://www.python.org/downloads/windows/
   - HttpPlatformHandler v1.2 (x64): https://www.iis.net/downloads/microsoft/httpplatformhandler
   - PostgreSQL 17 para Windows x86-64 (instalador da EDB): https://www.postgresql.org/download/windows/
5. **PowerShell como Administrador:**
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   cd C:\instaladores\oasis-operating-systems\roteiro
   Get-ChildItem -Recurse | Unblock-File
   ```

## Roteiro de configuração

Rode na ordem, sempre no PowerShell como Administrador. Os scripts funcionam no Windows em português ou em inglês: grupos internos entram por SID, regras de firewall pelo nome interno e contadores de desempenho são traduzidos para o idioma instalado.

| # | Script | O que faz | Reinicia? |
| --- | --- | --- | --- |
| 01 | `01-rede-e-nome.ps1` | IP fixo, DNS inicial, fuso de Brasília, nome `SRV-OASIS` | Sim (você reinicia) |
| 02 | `02-dominio-ad.ps1` | Funções AD DS e DNS, floresta `oasis.local` | Sim (sozinho) |
| 03 | `03-dns-e-identidades.ps1` | Encaminhadores, zona reversa, `api.oasis.local`, política de senha e bloqueio, OUs, grupos `GG_Oasis_Admins` e `GG_Oasis_Operadores`, usuários fictícios | Não |
| 04 | `04-iis-e-dependencias.ps1` | Funções do IIS, Python 3.13, HttpPlatformHandler, PostgreSQL 17 | Não |
| 05 | `05-banco.ps1` | PostgreSQL só em localhost, usuário `oasis` com senha aleatória, arquivo de segredos `C:\oasis\config\oasis.env`; mostra a **chave do posto** | Não |
| 06 | `06-publicar-aplicacao.ps1` | Copia o código, cria o ambiente Python, instala as dependências, roda as migrações e o seed, cria pool e site, aplica o NTFS e testa `/health` | Não |
| 07 | `07-gpo-e-auditoria.ps1` | GPOs "Oasis - Operadores" e "Oasis - Servidor", subcategorias de auditoria, auditoria de acesso nas pastas | Não |
| 08 | `08-acesso-remoto-e-firewall.ps1` | RDP com NLA e WinRM só da rede de administração, porta 80 aberta, 5432 bloqueada | Não |
| 09 | `09-monitoramento.ps1` | Alertas de CPU, disco e memória, registro de desempenho, modo de exibição "Oásis" | Não |
| 10 | `10-tolerancia-a-falhas.ps1` | Recuperação automática dos serviços e o vigia (tarefa a cada minuto) | Não |
| 11 | `11-teste-de-falha.ps1` | Cinco quedas cronometradas; **grave a tela** | Não |
| 12 | `12-coletar-evidencias.ps1` | Saídas de comandos em `C:\oasis\evidencias` | Não |
| 13 | `13-extra-file-server-dfs.ps1` | Extra: pasta de boletins do posto com NTFS por grupo e namespace DFS `\\oasis.local\Oasis` | Não |

### Ligando as outras partes ao servidor

| Parte | O que configurar |
| --- | --- |
| Navegador do PC | `http://192.168.0.50/` (o IP do `00-config.ps1`) |
| App no iPhone | Em `mobile/.env`: `EXPO_PUBLIC_API_URL=http://192.168.0.50`, com o iPhone na mesma Wi-Fi. Use o IP: o iOS resolve nomes `.local` por mDNS, não pelo DNS do AD |
| Painel do Posto | Aba **Configurações**: endereço `http://192.168.0.50` e a chave do posto mostrada no passo 05 (fica em `C:\oasis\config\oasis.env`) |
| Estação no Wokwi | Nada muda: a API do servidor assina o broker. Confira `"mqtt": "conectado"` em `http://192.168.0.50/health` |

### Auditoria pelo Gerenciamento de Política de Grupo

O passo 07 já liga as subcategorias de auditoria no servidor com o `auditpol`, e o efeito é imediato. Para gerenciar a mesma auditoria pelo domínio, que é o que aparece bem no vídeo, configure também a GPO:

1. `gpmc.msc` → Domínios → `oasis.local` → **Domain Controllers** → **Oasis - Servidor** → Editar.
2. Configuração do Computador → Políticas → Configurações do Windows → Configurações de Segurança → **Configuração Avançada de Política de Auditoria** → Políticas de Auditoria.
3. Marque **Êxito e Falha** em:
   - Logon/Logoff → Auditoria de Logon e Auditoria de Bloqueio de Conta
   - Acesso a Objetos → Auditoria do Sistema de Arquivos
   - Gerenciamento de Conta → Gerenciamento de Contas de Usuário e Gerenciamento de Grupos de Segurança
   - Alteração de Política → Auditoria de Alteração de Política
4. `gpupdate /force` e `auditpol /get /category:*` para conferir.

## Teste de falha

O `11-teste-de-falha.ps1` derruba a aplicação de cinco jeitos e cronometra a volta. A coluna de tempo traz o que se espera; o script mede o tempo real e grava em `C:\oasis\evidencias\teste-de-falha.txt`.

| Teste | Como derruba | Quem recupera | Tempo esperado |
| --- | --- | --- | --- |
| 1 | Mata o `python.exe` da API | HttpPlatformHandler sobe outro no próximo pedido | poucos segundos |
| 2 | Mata o `w3wp.exe` do pool | WAS cria outro processo (pool `AlwaysRunning`) | poucos segundos |
| 3 | Mata o processo do serviço W3SVC | Recuperação automática do serviço (5 s), com evento 7031 | cerca de 10 s |
| 4 | Para o pool `OasisPool` | Vigia percebe em até 1 minuto e religa (eventos 1001 e 1002) | até cerca de 70 s |
| 5 | Para o PostgreSQL (`/health` vira 503) | Vigia inicia o serviço | até cerca de 70 s |

## Onde ficam os logs

| O quê | Onde |
| --- | --- |
| Visão única dos eventos | Visualizador de Eventos → Modos de Exibição Personalizados → **Oásis**: 7031 e 7034 (serviço caiu), WAS (pool), 1001 a 1003 (vigia), 2031 (alerta de desempenho), 4625 (logon com falha), 4663 (acesso auditado ao `oasis.env` e ao código), 4720 e 4740 (contas), 4719 (auditoria alterada) |
| Logs do IIS | `C:\inetpub\logs\LogFiles\W3SVC<n>\u_ex*.log` |
| Log da API | `C:\oasis\logs\api.log`; saída do uvicorn em `C:\oasis\logs\uvicorn_*.log` |
| Desempenho | `C:\oasis\logs\perfmon\desempenho*.blg` (abra no Monitor de Desempenho) |

## Roteiro do vídeo (até 7 minutos)

| Tempo | O que mostrar |
| --- | --- |
| 0:00–0:30 | O Oásis em uma frase e o que esta VM hospeda (Ficha na tela) |
| 0:30–1:30 | Rede e identidade: Gerenciador do Servidor com as funções, `ipconfig`, Usuários e Computadores do AD (OUs, grupos), DNS com `api.oasis.local`, `nslookup` e `Test-NetConnection` |
| 1:30–2:45 | Aplicação no IIS: site e pool (sem código gerenciado, AlwaysRunning), módulo HttpPlatformHandler, `web.config`, NTFS de `C:\oasis\config`, página aberta no PC e no iPhone |
| 2:45–3:30 | GPO e acesso remoto: GPMC com as duas GPOs, RDP como `OASIS\admin.oasis` mostrando o aviso de logon |
| 3:30–4:30 | Monitoramento: `Oasis-Alertas` no Monitor de Desempenho, `.\09-monitoramento.ps1 -Testar` e o evento 2031 |
| 4:30–6:00 | Teste de falha: testes 1, 3 e 4 do script 11, com os eventos 7031, 1001 e 1002 (os testes 2 e 5 ficam no `teste-de-falha.txt`) |
| 6:00–6:40 | Logs e auditoria: visão "Oásis", evento 4663 do `oasis.env`, log do IIS com os pedidos |
| 6:40–7:00 | Funcionamento completo: no Wokwi, a temperatura sobe e o alerta aparece na página hospedada e no app |

## Evidências

Prints e saídas de comandos ficam em [`evidencias/`](evidencias/). A lista do que capturar está em [`evidencias/README.md`](evidencias/README.md).

## Problemas comuns

| Sintoma | O que fazer |
| --- | --- |
| "a execução de scripts foi desabilitada" | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` e `Get-ChildItem -Recurse \| Unblock-File` |
| O 01 não acha a placa | `Get-NetAdapter` e ajuste `Interface` no `00-config.ps1` |
| `pip install` falha no 06 | Sem internet ou DNS: `nslookup pypi.org` (os encaminhadores do passo 03 resolvem isso) |
| `/health` responde 503 | Banco parado ou senha errada no `oasis.env`: rode o 05 e depois o 06 de novo |
| `"mqtt": "desconectado"` | A rede bloqueia a porta 1883 de saída (comum em redes de faculdade): `Test-NetConnection broker.hivemq.com -Port 1883` |
| O iPhone não abre a página | Mesma Wi-Fi, IP certo, passo 08 rodado e, no iOS, permissão de **Rede Local** para o Expo Go |
| O instalador do PostgreSQL não instala sozinho | Rode o instalador com duplo clique (porta 5432, sem Stack Builder) e siga para o 05 |
