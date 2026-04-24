# TCPBlockSocket

**Unit:** `blcksock.pas` | **Versao Synapse:** 009.011.001 | **Tipo:** Classe

---

## 1. O que e?

`TTCPBlockSocket` e a implementacao de socket TCP bloqueante (blocking) da biblioteca Ararat Synapse, versao 009.011.001. Herda de `TSocksBlockSocket` (que herda de `TBlockSocket`) e adiciona suporte a SSL/TLS (via plugin intercambiavel), proxy SOCKS4/5 e tunelamento HTTP CONNECT.

No contexto GestorERP, `TTCPBlockSocket` e o transporte TCP subjacente de `TLDAPSend`: o socket e acessivel via `TLDAPSend.Sock` e deve ser configurado com `SNIHost`, `CertCAFile` e `VerifyCert` antes de `TLDAPSend.Login` para garantir LDAPS seguro e autenticado.

A versao 009.011.001 inclui tratamento explicito de `WSAECONNRESET` em multiplos pontos do ciclo de recebimento/envio TCP — relevante para conexoes LDAPS de longa duracao onde o controlador de dominio pode fechar o canal de forma abrupta apos periodos de inatividade.

---

## 2. Caracteristicas

- **Bloqueante por padrao**: operacoes de I/O bloqueiam a thread ate conclusao ou timeout; modo nao-bloqueante disponivel via `NonBlockMode`.
- **Plugin SSL intercambiavel**: `TCustomSSL` e criado via `SSLImplementation`; trocar o plugin (ex.: `ssl_openssl3`) nao requer mudancas no codigo consumidor.
- **IPv4 e IPv6**: `SocketFamily` controla o modo; `SF_Any` permite conexao automatica com base no endereco destino.
- **Proxy SOCKS4/4a e SOCKS5**: suporte nativo para tunelamento de conexoes de saida.
- **HTTP CONNECT tunnel**: suporte a tunelamento via proxy HTTP corporativo.
- **OAuth2Token**: property `OAuth2Token` (herdada de `TSynaClient`) disponivel para protocolos que usam autenticacao Bearer.
- **Tratamento WSAECONNRESET**: versao 009.011.001 trata `WSAECONNRESET` em `RecvBuffer`, `RecvPacket` e `SendBuffer` — corrige crash silencioso em conexoes LDAPS longas.
- **Bandwidth limiting**: `MaxSendBandwidth` e `MaxRecvBandwidth` limitam taxa de transferencia.
- **Heartbeat**: `HeartbeatRate` e `OnHeartbeat` permitem chamadas periodicas durante operacoes longas.
- **Cross-platform**: compila em Windows (Winsock) e Linux/macOS (POSIX sockets); `{$IFDEF FPC}` ativa modo compatibilidade FPC.

---

## 3. Engine

| Diretiva / Condicional | Efeito |
| --- | --- |
| `{$DEFINE ONCEWINSOCK}` | Inicializa Winsock uma unica vez na inicializacao do programa (melhor performance para muitos sockets) |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC com sintaxe Delphi |
| `{$IFDEF WIN32}` / `{$IFDEF MSWINDOWS}` | Define `MSWINDOWS` em compiladores antigos que so tem `WIN32` |
| `{$IFDEF POSIX}` | Usa `System.Generics.Collections` para `TOptionList` e `TSocketList` em plataformas POSIX (Delphi mobile/Linux) |
| `{$IFDEF CIL}` | Blocos alternativos para .NET (`System.Net.Sockets`) |
| `{$IFDEF UNICODE}` | Suprime `IMPLICIT_STRING_CAST` em Delphi Unicode |
| `{$IFDEF NEXTGEN}` | `{$ZEROBASEDSTRINGS OFF}` para Delphi NextGen (mobile) |
| `{$Q-}` | Desabilita verificacoes de overflow (performance) |
| `synsock` | Camada de abstracao de socket (Winsock/POSIX); toda comunicacao real passa por ela |
| `secur32.dll` (via ldapsend) | Nao carregada por esta unit; o `TLDAPSend` e quem carrega para SSPI |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo / Property | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create` | Cria socket TCP com o plugin SSL padrao (`SSLImplementation`) |
| `CreateWithSSL` | `constructor CreateWithSSL(SSLPlugin: TSSLClass)` | Cria socket TCP com plugin SSL especifico (ex.: `TSSLOpenSSL3`) |
| `Destroy` | `destructor Destroy` | Libera plugin SSL e fecha socket |
| `CloseSocket` | `procedure CloseSocket` | Fecha o socket; dispara hook `HR_SocketClose` |

### 4.2 Conexao e TLS

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Connect` | `procedure Connect(IP, Port: string)` | Conecta ao host/porta; resolve DNS, aplica SOCKS/HTTP tunnel se configurado; dispara `OnAfterConnect` |
| `SSLDoConnect` | `procedure SSLDoConnect` | Faz upgrade TLS sobre TCP ja conectado (usado por StartTLS do LDAP) |
| `SSLDoShutdown` | `procedure SSLDoShutdown` | Faz downgrade de TLS para TCP plaintext |
| `SSLAcceptConnection` | `function SSLAcceptConnection: Boolean` | Inicia handshake TLS no lado servidor apos `Accept` |
| `Listen` | `procedure Listen` | Coloca socket em modo escuta; suporta SOCKS |
| `Accept` | `function Accept: TSocket` | Aguarda e aceita nova conexao de entrada |

### 4.3 Transferencia de dados

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBuffer` | `function SendBuffer(const Buffer: TMemory; Length: Integer): Integer` | Envia buffer; trata `WSAECONNRESET` definindo `FLastError` sem excecao |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Len: Integer): Integer` | Recebe dados; trata `WSAECONNRESET` em conexoes TCP/SSL |
| `RecvPacket` | `function RecvPacket(Timeout: Integer): AnsiString` | Recebe pacote completo com timeout; trata `WSAECONNRESET` e `SSL_ERROR_ZERO_RETURN` |
| `WaitingData` | `function WaitingData: Integer` | Retorna bytes disponiveis para leitura (considera buffer SSL se ativo) |

### 4.4 Informacoes de conexao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetLocalSinIP` | `function GetLocalSinIP: string` | IP local da conexao |
| `GetRemoteSinIP` | `function GetRemoteSinIP: string` | IP remoto da conexao |
| `GetLocalSinPort` | `function GetLocalSinPort: Integer` | Porta local |
| `GetRemoteSinPort` | `function GetRemoteSinPort: Integer` | Porta remota |
| `GetErrorDescEx` | `function GetErrorDescEx: string` | Descricao de erro incluindo erros do subsistema SSL |
| `GetSocketType` | `function GetSocketType: integer` | Retorna `SOCK_STREAM` |
| `GetSocketProtocol` | `function GetSocketProtocol: integer` | Retorna `IPPROTO_TCP` |

### 4.5 Properties de configuracao SSL/TLS (herdadas de TCustomSSL via SSL)

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `SSL` | `TCustomSSL` | R | Instancia do plugin SSL ativo; fazer cast para `TSSLOpenSSL` para acessar `GetPeerCertSHA256Hash` |
| `CertCAFile` | `string` | R/W | Caminho para bundle PEM de CAs raiz para verificacao do certificado servidor |
| `VerifyCert` | `Boolean` | R/W | Se `True`, rejeita conexoes com certificados invalidos ou nao verificaveis |
| `SNIHost` | `string` | R/W | Nome do servidor para Server Name Indication (TLS SNI); deve ser o FQDN do host |

### 4.6 Properties de configuracao do socket (herdadas de TBlockSocket)

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `TargetHost` | `string` | R/W | Host de destino (herdado via `TSynaClient`; em `TTCPBlockSocket` via parametro de `Connect`) |
| `Timeout` | `Integer` | R/W | Timeout padrao para operacoes de socket em milissegundos |
| `NonBlockMode` | `Boolean` | R/W | Modo nao-bloqueante (usado internamente por `TSSLOpenSSL.Connect` com `ConnectionTimeout`) |
| `ConnectionTimeout` | `Integer` | R/W | Timeout especifico para handshake de conexao |
| `RaiseExcept` | `Boolean` | R/W | Se `True`, erros geram `ESynapseError`; se `False` (padrao), apenas define `LastError` |
| `LastError` | `Integer` | R | Codigo do ultimo erro (Winsock ou SSL) |
| `RecvCounter` | `Int64` | R | Total de bytes recebidos na sessao |
| `SendCounter` | `Int64` | R | Total de bytes enviados na sessao |

### 4.7 Properties HTTP Tunnel

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `HTTPTunnelIP` | `string` | R/W | IP do proxy HTTP; atribuir ativa modo tunnel |
| `HTTPTunnelPort` | `string` | R/W | Porta do proxy HTTP |
| `HTTPTunnelUser` | `string` | R/W | Usuario para autenticacao no proxy HTTP |
| `HTTPTunnelPass` | `string` | R/W | Senha para autenticacao no proxy HTTP |
| `HTTPTunnelTimeout` | `Integer` | R/W | Timeout para comunicacao com proxy HTTP |

### 4.8 OAuth2 (herdado de TSynaClient)

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `OAuth2Token` | `string` | R/W | Token Bearer para protocolos que suportam autenticacao OAuth2 |

---

## 5. Aplicabilidades

1. **Transporte LDAPS para TLDAPSend** — `TLDAPSend` cria internamente um `TTCPBlockSocket`; o caller configura `LLDAP.Sock.SNIHost`, `LLDAP.Sock.CertCAFile` e `LLDAP.Sock.VerifyCert` antes de `Login` para garantir LDAPS autenticado.

2. **LDAPS de longa duracao** — o fix de `WSAECONNRESET` da versao 009.011.001 evita crash silencioso quando o controlador de dominio fecha a conexao LDAPS apos periodos de inatividade (common em DCs Windows Server 2019+).

3. **LDAP sobre HTTP proxy** — em redes corporativas com inspecao de trafego, configurar `HTTPTunnelIP`/`HTTPTunnelPort` permite tunelar LDAPS atraves do proxy HTTP sem alteracoes no codigo de nivel superior.

4. **Multiplos protocolos Synapse** — a mesma classe serve de base para SMTP, IMAP, HTTP e outros clientes Synapse; o modelo de plugin SSL torna o transporte intercambiavel.

5. **Diagnostico de TLS** — apos `SSLDoConnect`, `GetErrorDescEx` retorna mensagens de erro SSL detalhadas; `SSL.GetSSLVersion`, `SSL.GetCipherName` e `SSL.GetVerifyCert` permitem auditoria da sessao.

---

## 6. Exemplos de Uso

### 6.1 Configurar LDAPS seguro antes de TLDAPSend.Login

```pascal
uses ldapsend, ssl_openssl3;

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.com.br';
    LLDAP.TargetPort := '636';
    LLDAP.FullSSL   := True;
    LLDAP.Timeout   := 15000;

    // Configura o TTCPBlockSocket interno via TLDAPSend.Sock
    LLDAP.Sock.SNIHost    := 'dc01.empresa.com.br';
    LLDAP.Sock.CertCAFile := 'C:\certs\empresa-ca-bundle.pem';
    LLDAP.Sock.VerifyCert := True;

    if not LLDAP.Login then
      raise Exception.Create('LDAPS falhou: ' + LLDAP.ResultString);

    // A partir daqui o socket esta em sessao TLS verificada
    LLDAP.BindGSSAPI('ldap/dc01.empresa.com.br');
  finally
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.2 Uso direto com plugin SSL especifico e verificacao de estado

```pascal
uses blcksock, ssl_openssl3;

var
  LSock: TTCPBlockSocket;
begin
  // Cria socket com plugin OpenSSL 3.x explicito
  LSock := TTCPBlockSocket.CreateWithSSL(TSSLOpenSSL3);
  try
    LSock.SNIHost    := 'dc01.empresa.com.br';
    LSock.CertCAFile := 'C:\certs\ca-bundle.pem';
    LSock.VerifyCert := True;
    LSock.ConnectionTimeout := 5000;

    LSock.Connect('dc01.empresa.com.br', '636');
    if LSock.LastError <> 0 then
      raise Exception.Create('TCP falhou: ' + LSock.GetErrorDescEx);

    LSock.SSLDoConnect;
    if LSock.LastError <> 0 then
      raise Exception.Create('TLS falhou: ' + LSock.GetErrorDescEx);

    // Verifica resultado da verificacao de certificado
    if LSock.SSL.GetVerifyCert <> 0 then
      raise Exception.Create('Certificado invalido (codigo: ' +
                             IntToStr(LSock.SSL.GetVerifyCert) + ')');

    // Socket pronto para protocolo LDAP manual ou uso com TLDAPSend
    Writeln('TLS ativo — cipher: ', LSock.SSL.GetCipherName);
  finally
    LSock.Free;
  end;
end;
```

### 6.3 Conexao LDAPS via proxy HTTP corporativo

```pascal
uses ldapsend, ssl_openssl3;

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.com.br';
    LLDAP.TargetPort := '636';
    LLDAP.FullSSL   := True;

    // Proxy HTTP corporativo — tunel CONNECT para dc01:636
    LLDAP.Sock.HTTPTunnelIP      := '10.0.0.1';
    LLDAP.Sock.HTTPTunnelPort    := '3128';
    LLDAP.Sock.HTTPTunnelUser    := 'proxyuser';
    LLDAP.Sock.HTTPTunnelPass    := 'proxypass';
    LLDAP.Sock.HTTPTunnelTimeout := 10000;
    LLDAP.Sock.SNIHost           := 'dc01.empresa.com.br';
    LLDAP.Sock.VerifyCert        := True;

    if not LLDAP.Login then
      raise Exception.Create('Falha via proxy: ' + LLDAP.ResultString);

    LLDAP.BindGSSAPI('ldap/dc01.empresa.com.br');
  finally
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.4 Tratamento de WSAECONNRESET em reconexao automatica

```pascal
uses ldapsend, ssl_openssl3, blcksock;

function ConectarLDAP(const AHost: string): TLDAPSend;
begin
  Result := TLDAPSend.Create;
  Result.TargetHost := AHost;
  Result.TargetPort := '636';
  Result.FullSSL   := True;
  Result.Sock.SNIHost    := AHost;
  Result.Sock.VerifyCert := True;
  Result.Timeout := 30000;

  if not (Result.Login and Result.BindGSSAPI('ldap/' + AHost)) then
  begin
    Result.Free;
    raise Exception.Create('Falha ao conectar LDAP');
  end;
end;

procedure ExecutarBusca(ALDAP: TLDAPSend; const AFilter: AnsiString);
var
  LAttrs: TStringList;
begin
  LAttrs := TStringList.Create;
  try
    LAttrs.Add('sAMAccountName');
    if not ALDAP.Search('DC=empresa,DC=com,DC=br', False, AFilter, LAttrs) then
    begin
      // WSAECONNRESET retorna LastError no socket sem excecao
      if ALDAP.Sock.LastError = WSAECONNRESET then
      begin
        // Reconecta e retenta uma vez
        ALDAP.Logout;
        ALDAP.Login;
        ALDAP.BindGSSAPI('ldap/dc01.empresa.com.br');
        ALDAP.Search('DC=empresa,DC=com,DC=br', False, AFilter, LAttrs);
      end;
    end;
  finally
    LAttrs.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| **Herda de** | `TSocksBlockSocket` (blcksock.pas) | Adiciona suporte a proxies SOCKS4/5 |
| **Herda de** | `TBlockSocket` (blcksock.pas) | Classe base de todos os sockets Synapse; define I/O, hooks, bandwidth limiting e contadores |
| **Contem** | `TCustomSSL` (blcksock.pas) | Plugin SSL acessivel via property `SSL`; tipo concreto determinado por `SSLImplementation` |
| **Plugin padrao** | `TSSLOpenSSL` (ssl_openssl.pas) | Registrado em `SSLImplementation` pelo `initialization` de `ssl_openssl.pas` se OpenSSL disponivel |
| **Plugin alternativo** | `TSSLOpenSSL3` (ssl_openssl3.pas) | Preferido para OpenSSL 3.x; deve ser adicionado ao `uses` do projeto |
| **Consumido por** | `TLDAPSend` (ldapsend.pas) | Unico consumidor no contexto GestorERP; acessivel via `TLDAPSend.Sock` |
| **Consumido por** | `TUDPBlockSocket` (blcksock.pas) | Usa `TTCPBlockSocket` internamente para controle SOCKS |
| **Pai de** | `TSynaClient` (blcksock.pas) | `TSynaClient` nao herda de `TTCPBlockSocket`, mas cria e encapsula um; `TLDAPSend` e `THTTPSend` seguem este padrao |
| **Hooks relacionados** | `THookSocketStatus`, `THookDataFilter`, `THookMonitor`, `THookAfterConnect`, `THookVerifyCert`, `THookHeartbeat` | Eventos de monitoramento e customizacao acessiveis via properties `OnStatus`, `OnAfterConnect`, `OnVerifyCert`, etc. |
| **Excecao** | `ESynapseError` (blcksock.pas) | Levantada quando `RaiseExcept = True`; contem `ErrorCode` e `ErrorMessage` |
