# =====================================================================
#  Oásis · Windows Server · configuração usada por todos os scripts
#  Ajuste os valores da SUA rede antes de rodar o 01-rede-e-nome.ps1.
# =====================================================================

$Oasis = [ordered]@{
    # ---- Rede e identidade -------------------------------------------
    NomeServidor  = 'SRV-OASIS'
    Interface     = 'Ethernet'                # Get-NetAdapter mostra o nome da placa
    IP            = '192.168.0.50'            # IP livre da sua rede, fora da faixa do DHCP do roteador
    Prefixo       = 24                        # 24 = máscara 255.255.255.0 (os scripts supõem uma rede /24)
    Gateway       = '192.168.0.1'             # IP do roteador
    DnsExterno    = @('1.1.1.1', '8.8.8.8')   # encaminhadores do DNS do AD (resolver a internet)
    Dominio       = 'oasis.local'
    NetBIOS       = 'OASIS'
    NomeApi       = 'api'                     # vira api.oasis.local
    RedeAdmin     = '192.168.0.0/24'          # de onde podem vir RDP e WinRM; troque pelo IP do seu PC para fechar mais

    # ---- Aplicação ----------------------------------------------------
    Raiz          = 'C:\oasis'
    Instaladores  = 'C:\instaladores'
    Repositorio   = 'C:\instaladores\oasis-soa'   # cópia do repositório oasis-soa (git clone ou "Download ZIP")
    Pool          = 'OasisPool'
    Site          = 'Oasis'
    Python        = 'C:\Program Files\Python313\python.exe'
    PastaPostgres = 'C:\Program Files\PostgreSQL\17'
    ServicoBanco  = 'postgresql-x64-17'

    # ---- Integração com a estação ESP32 (mesmos valores do iot/sketch.ino) ----
    MqttHost      = 'broker.hivemq.com'
    MqttPrefixo   = 'oasis-rm560760'
    MqttChaveHmac = 'oasis-demo-2026-troque-esta-chave'
}
