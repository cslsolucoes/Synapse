# TSSLOpenSSL / ssl_openssl.pas

**Unit:** `ssl_openssl.pas` | **Versao:** 001.004.002 (CSL fork) | **Tipo:** Classe | **Origem:** Upstream Synapse (Lukas Gebauer) + CSL fork (2026)

---

## 1. O que e?

`TSSLOpenSSL` e o plugin SSL/TLS historico do Ararat Synapse que implementa o contrato `TCustomSSL` usando a biblioteca OpenSSL carregada dinamicamente em runtime via `ssl_openssl_lib`. Cobre as versoes OpenSSL 0.9.7 a 1.1.x num unico codigo — resolve simbolos com nomes distintos entre as varias ABIs da OpenSSL e expoe uma API uniforme ao resto do Synapse.

No fork CSL (v001.004.002, 2026-04-13) recebeu um unico metodo novo, `GetPeerCertSHA256Hash`, que devolve os 32 bytes raw do digest SHA-256 do certificado DER do servidor. Esse valor e o insumo obrigatorio para construir o Channel Binding Token `tls-server-end-point` (RFC 5929) usado em `TLDAPSend.BindGSSAPIWithCBT` — bind Kerberos sobre LDAPS resistente a MITM (requisito do Active Directory Windows Server 2025 com `LdapEnforceChannelBinding = 1` ou `2`).

A unit esta marcada como `deprecated` — para OpenSSL 3.x usar `ssl_openssl3.pas` ou, no fork CSL, `ssl_openssl4.pas` para OpenSSL 4.0.

---

## 2. Caracteristicas

- **Carregamento dinamico de OpenSSL:** DLLs `libssl`/`libcrypto` (ou `ssleay32.dll`/`libeay32.dll`) carregadas via `LoadLibrary` em `InitSSLInterface` de `ssl_openssl_lib`. A aplicacao compila e inicializa sem as DLLs presentes.
- **Multi-versao OpenSSL:** resolve simbolos para 0.9.7, 0.9.8, 1.0.x, 1.0.2 e 1.1.x. Vai testar por varios nomes de DLL (`SSLLibNames[]`/`CryptoLibNames[]`).
- **Auto-certificado Ad-Hoc:** servidores TLS sem certificado/chave configurados tem par RSA auto-gerado via `CreateSelfSignedCert`, um por handshake.
- **Suporte SNI:** `Connect` propaga `FSocket.SSL.SNIHost` via `SSL_CTRL_SET_TLSEXT_HOSTNAME`.
- **Verificacao configuravel:** `VerifyCert` habilita `SSL_VERIFY_PEER`; `OnVerifyCert` permite logica custom do caller.
- **Cross-compiler:** compila em Delphi (VCL, `CIL` parcial) e FPC via `{$INCLUDE 'jedi.inc'}`.
- **Extensao CSL (`GetPeerCertSHA256Hash`):** unico metodo adicionado pelo fork; 25 linhas de diff vs baseline upstream.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$INCLUDE 'jedi.inc'}` | Inclui defines JEDI (Delphi/FPC) |
| `{$IFDEF UNICODE}` | Suprime `IMPLICIT_STRING_CAST` e `IMPLICIT_STRING_CAST_LOSS` |
| `{$IFDEF CIL}` | Blocos .NET (sem callbacks CDECL — sem password callback nem lock multithread) |
| `{$IFDEF DELPHI23_UP}` | Usa `AnsiStrings.StrLCopy` em Delphi XE+ |
| `{$IFDEF SUPPORTS_DEPRECATED}` | Marca a unit como `deprecated` com mensagem `'Use ssl_openssl3 with OpenSSL 3.0 instead'` |
| `ssl_openssl_lib` (unit) | Declaracoes de todas as funcoes OpenSSL importadas dinamicamente |
| `InitSSLInterface` | Funcao de `ssl_openssl_lib` que carrega as DLLs OpenSSL; se falhar, `SSLImplementation` nao e alterado |
| OpenSSL 0.9.7 — 1.1.x | Versoes compativeis (testadas); OpenSSL 3.x requer `ssl_openssl3.pas`; OpenSSL 4.0 requer `ssl_openssl4.pas` |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida e conexao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create(const Value: TTCPBlockSocket); override` | Inicializa o plugin vinculado ao socket; cipher suite default `'DEFAULT'` |
| `Destroy` | `destructor Destroy; override` | Liberta contexto SSL/TLS via `DeInit` |
| `Connect` | `function Connect: boolean; override` | Handshake SSL/TLS client-side; propaga SNIHost; suporta timeout nao-bloqueante |
| `Accept` | `function Accept: boolean; override` | Handshake SSL/TLS server-side |
| `Shutdown` | `function Shutdown: boolean; override` | Encerra sessao SSL com um unico `SSL_shutdown` |
| `BiShutdown` | `function BiShutdown: boolean; override` | Encerramento bidireccional (envia e espera `close_notify`) |

### 4.2 Metodos protegidos (internos)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `NeedSigningCertificate` | `function NeedSigningCertificate: boolean; virtual` | Sobrescrito em `TSSLOpenSSLCapi` para sinalizar uso de CAPI engine |
| `SSLCheck` | `function SSLCheck: Boolean` | Preenche `FLastError`/`FLastErrorDesc` a partir de `ERR_get_error` |
| `SetSslKeys` | `function SetSslKeys: boolean; virtual` | Carrega certificado/chave/PFX no `SSL_CTX` |
| `Init` | `function Init: Boolean` | Cria `SSL_CTX`, define protocolo e callbacks |
| `DeInit` | `function DeInit: Boolean` | Liberta `SSL` e `SSL_CTX` |
| `Prepare` | `function Prepare: Boolean` | Sequencia `Init` + `SetSslKeys` + config SNI/cipher |
| `LoadPFX` | `function LoadPFX(pfxdata: ansistring): Boolean` | Decodifica PFX binario em cert + chave |
| `CreateSelfSignedCert` | `function CreateSelfSignedCert(Host: string): Boolean; override` | Gera par RSA 2048 Ad-Hoc para servidor TLS sem cert |

### 4.3 Transferencia de dados

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBuffer` | `function SendBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Envia dados pela sessao; trata `SSL_ERROR_WANT_READ`/`WANT_WRITE` com retry |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Recebe dados com mesmo tratamento de retry |
| `WaitingData` | `function WaitingData: Integer; override` | Bytes pendentes no buffer SSL (`SSL_pending`) |

### 4.4 Informacoes do certificado e sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSSLVersion` | `function GetSSLVersion: string; override` | Versao do protocolo negociado (ex.: `TLSv1.2`) |
| `GetPeerSubject` | `function GetPeerSubject: string; override` | Subject DN do certificado servidor (`X509_NAME_oneline`) |
| `GetPeerIssuer` | `function GetPeerIssuer: string; override` | Issuer DN do certificado servidor |
| `GetPeerName` | `function GetPeerName: string; override` | Extrai apenas o CN do Subject DN |
| `GetPeerSerialNo` | `function GetPeerSerialNo: integer; override` | Numero serial do certificado (contrib. Petr Fejfar) |
| `GetPeerNameHash` | `function GetPeerNameHash: cardinal; override` | Hash do Subject Name (lookup de CAs) |
| `GetPeerFingerprint` | `function GetPeerFingerprint: ansistring; override` | Fingerprint MD5 do certificado (bytes raw) |
| `GetCertInfo` | `function GetCertInfo: string; override` | Dump textual completo via `X509_print` |
| `GetCipherName` | `function GetCipherName: string; override` | Nome da cipher suite (ex.: `ECDHE-RSA-AES256-GCM-SHA384`) |
| `GetCipherBits` | `function GetCipherBits: integer; override` | Bits efetivos da cipher atual |
| `GetCipherAlgBits` | `function GetCipherAlgBits: integer; override` | Bits do algoritmo da cipher atual |
| `GetVerifyCert` | `function GetVerifyCert: integer; override` | Resultado de `SSL_get_verify_result` (0 = OK) |
| `DoVerifyCert` | `function DoVerifyCert: Boolean; override` | Dispara callback `OnVerifyCert` do caller |
| `SetCertCAFile` | `procedure SetCertCAFile(const Value: string); override` | Carrega bundle CA PEM |

### 4.5 Extensao CSL

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetPeerCertSHA256Hash` | `function GetPeerCertSHA256Hash: AnsiString` | Retorna 32 bytes raw (SHA-256) do certificado servidor em formato DER. Retorna string vazia se nao houver peer cert. Usado em `TLDAPSend.BindGSSAPIWithCBT` para construir CBT `tls-server-end-point` (RFC 5929). |

### 4.6 Informacoes do plugin

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `LibVersion` | `function LibVersion: String; override` | Versao da biblioteca OpenSSL carregada (`SSLeay_version(0)`) |
| `LibName` | `function LibName: String; override` | Retorna `'ssl_openssl'` |
| `LibNameCrypto` | (via `ssl_openssl_lib`) | Identificador da DLL crypto efectivamente carregada |

---

## 5. Aplicabilidades

1. **LDAPS com Channel Binding** — `TLDAPSend.BindGSSAPIWithCBT` chama `GetPeerCertSHA256Hash` para obter o hash do certificado do controlador de dominio e construir o CBT antes de enviar o token GSSAPI no bind SASL.
2. **LDAPS convencional** — quando `TLDAPSend.FullSSL = True`, o `TTCPBlockSocket` usa `TSSLOpenSSL` para o canal TLS na porta 636 antes de qualquer operacao LDAP.
3. **StartTLS** — quando `TLDAPSend.AutoTLS = True`, o socket realiza handshake TLS sobre conexao LDAP plaintext via `SSLDoConnect`.
4. **Verificacao de identidade do servidor** — `GetPeerName` + `GetVerifyCert` permitem validar que o certificado do DC corresponde ao hostname esperado.
5. **Inspecao forense/debugging** — `GetCertInfo` retorna dump completo do certificado, util para diagnostico de TLS em ambiente corporativo.
6. **HTTPS, SMTPS, IMAPS, POP3S, FTPS** — todos os outros protocolos SSL cobertos pelo Synapse consomem este plugin transparentemente quando registado em `SSLImplementation`.

---

## 6. Exemplos de uso

### 6.1 Obter hash SHA-256 do certificado para CBT

```pascal
uses
  SysUtils, ldapsend, blcksock, ssl_openssl;

var
  LLDAP: TLDAPSend;
  LHash: AnsiString;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.TargetPort := '636';
    LLDAP.FullSSL   := True;

    if not LLDAP.Login then
      raise Exception.Create('LDAPS falhou: ' + LLDAP.ResultString);

    LHash := (LLDAP.Sock.SSL as TSSLOpenSSL).GetPeerCertSHA256Hash;

    if Length(LHash) <> 32 then
      raise Exception.Create('Certificado servidor nao disponivel');

    if not LLDAP.BindGSSAPIWithCBT('ldap/dc01.empresa.local', LHash) then
      raise Exception.Create('Bind CBT falhou: ' + LLDAP.ResultString);
  finally
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.2 Inspeccionar cert e cipher apos handshake

```pascal
uses
  SysUtils, blcksock, ssl_openssl;

var
  LSock: TTCPBlockSocket;
  LSSL: TSSLOpenSSL;
begin
  LSock := TTCPBlockSocket.Create;
  try
    LSock.CertCAFile := 'certs\empresa-ca.pem';
    LSock.VerifyCert := True;
    LSock.SNIHost    := 'dc01.empresa.local';
    LSock.Connect('dc01.empresa.local', '636');
    LSock.SSLDoConnect;

    if LSock.LastError <> 0 then
      raise Exception.Create('TLS falhou: ' + LSock.GetErrorDescEx);

    LSSL := LSock.SSL as TSSLOpenSSL;
    WriteLn('Versao TLS : ', LSSL.GetSSLVersion);
    WriteLn('Cipher     : ', LSSL.GetCipherName, ' (', LSSL.GetCipherBits, ' bits)');
    WriteLn('CN servidor: ', LSSL.GetPeerName);
    WriteLn('Verify     : ', LSSL.GetVerifyCert);
  finally
    LSock.Free;
  end;
end;
```

### 6.3 Servidor TLS com certificado Ad-Hoc

```pascal
uses
  blcksock, ssl_openssl;

var
  LServer, LClient: TTCPBlockSocket;
  LClientSock: TSocket;
begin
  LServer := TTCPBlockSocket.Create;
  try
    LServer.Bind('0.0.0.0', '8443');
    LServer.Listen;
    LClientSock := LServer.Accept;

    LClient := TTCPBlockSocket.CreateWithSSL(TSSLOpenSSL);
    try
      LClient.Socket := LClientSock;
      LClient.SSLAcceptConnection;
      // conexao TLS estabelecida com cert Ad-Hoc
    finally
      LClient.Free;
    end;
  finally
    LServer.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| Herda de | `TCustomSSL` (blcksock.pas) | Interface base para plugins SSL — contrato Connect/Accept/Send/Recv + propriedades de cert/cipher |
| Vinculado a | `TTCPBlockSocket` (blcksock.pas) | Uma instancia criada/gerida pelo socket; acessivel via `TTCPBlockSocket.SSL` |
| Usa | `ssl_openssl_lib` (ssl_openssl_lib.pas) | Declaracoes de todas as funcoes OpenSSL importadas |
| Registado em | `SSLImplementation` (blcksock.pas) | `initialization` da unit atribui `TSSLOpenSSL` se `InitSSLInterface` retornar True |
| Consumido por | `TLDAPSend` (ldapsend.pas) | Cast `LLDAP.Sock.SSL as TSSLOpenSSL` para aceder `GetPeerCertSHA256Hash` |
| Sub-classe | `TSSLOpenSSLCapi` (ssl_openssl_capi.pas) | Extende com CAPI engine para Windows Certificate Store |
| Alternativa | `TSSLOpenSSL3` (ssl_openssl3.pas), `TSSLOpenSSL4` (ssl_openssl4.pas) | OpenSSL 3.x e 4.0 |
| Alternativas | `TSSLCryptLib`, `TSSLSBB`, `TSSLStreamSec` | Outros backends SSL no Synapse |
