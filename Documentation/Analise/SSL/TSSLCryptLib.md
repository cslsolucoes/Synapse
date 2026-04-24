# TSSLCryptLib / ssl_cryptlib.pas

**Unit:** `ssl_cryptlib.pas` | **Versao:** 001.001.002 | **Tipo:** Classe | **Origem:** Upstream Synapse (Lukas Gebauer)

---

## 1. O que e?

`TSSLCryptLib` e um plugin SSL/SSH alternativo a OpenSSL, baseado na biblioteca **cryptlib** de Peter Gutmann (University of Auckland). cryptlib e uma toolkit criptografica comercial (licenciamento dual GPL/proprietario) conhecida por auditoria rigorosa, certificacao FIPS 140-2 e suporte nativo a SSHv2 no mesmo plugin.

Diferentemente dos plugins OpenSSL, cryptlib e **estaticamente linkada**: compilar com `ssl_cryptlib` requer distribuir `cl32.dll` (v3.2.0+) — sem ela a aplicacao nao inicia. O plugin opera com keys/certs em formato **PKCS#15** (smart card standard), carregados de ficheiro em disco (nao de memoria) e identificados por "label" string. O mesmo ficheiro PKCS#15 pode conter multiplas chaves/certs, cada um com label unico.

O plugin cobre SSL/TLS (client + server) e SSHv2 (apenas cliente). Para SSH usar `TCustomSSL.SSLType := LT_SSHv2` e preencher `Username`/`Password`.

---

## 2. Caracteristicas

- **Engine cryptlib (Peter Gutmann):** toolkit fechada mas auditavel; FIPS 140-2 Level 2.
- **Static link:** requer `cl32.dll` distribuida; se ausente aplicacao nao arranca.
- **PKCS#15 only:** formato unico para chaves/certs — nao aceita PEM/ASN.1 DER directos para chave privada.
- **Label-based lookup:** `PrivateKeyLabel` identifica cert/chave dentro do PKCS#15 file.
- **SSL/TLS + SSHv2:** um unico plugin cobre ambos os protocolos.
- **Ad-Hoc certs:** gera cert auto-assinado se servidor nao tiver cert explicito.
- **Client cert verification:** `CertCAFile` apontando para PKCS#15 com chaves publicas permite rejeicao automatica de clientes nao autorizados.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$IFDEF FPC} {$MODE DELPHI} {$ENDIF}` | FPC em modo Delphi |
| `{$IFDEF NEXTGEN} {$ZEROBASEDSTRINGS OFF} {$ENDIF}` | Suprime strings 0-based em NextGen (iOS/Android antigo) |
| `cryptlib` (unit) | Bindings Pascal para `cl32.dll` |
| `cl32.dll` 3.2.0+ | Runtime obrigatorio — Windows/Linux |
| `CRYPT_SESSION` | Tipo handle opaco para sessao TLS/SSH |
| `CRYPT_HANDLE` | Handle generico para cert/key no cryptlib |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create(const Value: TTCPBlockSocket); override` | Label default `'synapse'`; `CRYPT_SESSION_NONE` |
| `Destroy` | `destructor Destroy; override` | Liberta certs trusted, sessao, e super |
| `Assign` | `procedure Assign(const Value: TCustomSSL); override` | Copia `PrivateKeyLabel` de outro TSSLCryptLib |

### 4.2 Metodos protegidos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SSLCheck` | `function SSLCheck(Value: integer): Boolean` | Converte codigos cryptlib em `FLastError`/`FLastErrorDesc` |
| `Init` | `function Init(server: Boolean): Boolean` | Cria `CRYPT_SESSION` tipo `SSL_SERVER`/`SSL_CLIENT`/`SSH_CLIENT` conforme `SSLType` |
| `DeInit` | `function DeInit: Boolean` | `cryptDestroySession` + cleanup de certs Ad-Hoc |
| `Prepare` | `function Prepare(server: Boolean): Boolean` | Init + carregamento de chaves/certs do PKCS#15 |
| `GetString` | `function GetString(const cryptHandle: CRYPT_HANDLE; const attributeType: CRYPT_ATTRIBUTE_TYPE): string` | Le atributo string do handle cryptlib |
| `CreateSelfSignedCert` | `function CreateSelfSignedCert(Host: string): Boolean; override` | Gera par RSA/cert Ad-Hoc via `cryptCreateCert` |
| `PopAll` | `function PopAll: string` | Drena todo o buffer de recepcao |

### 4.3 Conexao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Connect` | `function Connect: boolean; override` | Handshake client-side (TLS ou SSHv2) |
| `Accept` | `function Accept: boolean; override` | Handshake server-side (TLS) |
| `Shutdown` | `function Shutdown: boolean; override` | Encerra sessao uni-direccional |
| `BiShutdown` | `function BiShutdown: boolean; override` | Encerramento bi-direccional |
| `SetCertCAFile` | `procedure SetCertCAFile(const Value: string); override` | Carrega PKCS#15 como trust store |

### 4.4 Transferencia

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBuffer` | `function SendBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Envio cifrado |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Len: Integer): Integer; override` | Recepcao cifrada |
| `WaitingData` | `function WaitingData: Integer; override` | Bytes pendentes |

### 4.5 Informacoes de cert e sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSSLVersion` | `function GetSSLVersion: string; override` | Versao TLS ou `'SSH2'` |
| `GetPeerSubject` | `function GetPeerSubject: string; override` | Subject DN |
| `GetPeerIssuer` | `function GetPeerIssuer: string; override` | Issuer DN |
| `GetPeerName` | `function GetPeerName: string; override` | CN |
| `GetPeerFingerprint` | `function GetPeerFingerprint: ansistring; override` | Fingerprint |
| `GetVerifyCert` | `function GetVerifyCert: integer; override` | Resultado de validacao |

### 4.6 Publicadas (propriedades)

| Propriedade | Tipo | Descricao |
| --- | --- | --- |
| `PrivateKeyLabel` | `string` | Label dentro do PKCS#15 (default `'synapse'`) |

### 4.7 Plugin info

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `LibVersion` | `function LibVersion: String; override` | Versao cryptlib |
| `LibName` | `function LibName: String; override` | `'ssl_cryptlib'` |

---

## 5. Aplicabilidades

1. **Ambientes FIPS 140-2:** cryptlib tem certificacao; `ssl_openssl` depende de build especifica FIPS-certificado.
2. **Smart cards com PKCS#15:** formato nativo — `TSSLCryptLib` le directamente do token.
3. **SSHv2 cliente com mesma lib:** automacao SSH sem precisar de `libssh2` adicional.
4. **Deploy auditavel:** cryptlib tem codigo-fonte revisto por Gutmann; ambientes regulados (banca, defesa).
5. **Alternativa a OpenSSL:** quando politicas corporativas proibem OpenSSL especificamente.

---

## 6. Exemplos de uso

### 6.1 LDAPS com chave do PKCS#15

```pascal
uses
  ldapsend, ssl_cryptlib;

var
  LLDAP: TLDAPSend;
  LSSL: TSSLCryptLib;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.Sock.SSL := TSSLCryptLib.Create(LLDAP.Sock);
    LSSL := LLDAP.Sock.SSL as TSSLCryptLib;
    LSSL.PrivateKeyFile := 'auth.p15';
    LSSL.PrivateKeyLabel := 'client-signing';
    LSSL.KeyPassword := 'p15-passphrase';

    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.TargetPort := '636';
    LLDAP.FullSSL   := True;
    if LLDAP.Login then
      WriteLn('LDAPS+cryptlib OK');
  finally
    LLDAP.Free;
  end;
end;
```

### 6.2 Cliente SSHv2

```pascal
uses
  blcksock, ssl_cryptlib;

var
  LSock: TTCPBlockSocket;
begin
  LSock := TTCPBlockSocket.Create;
  try
    LSock.SSL := TSSLCryptLib.Create(LSock);
    LSock.SSL.SSLType := LT_SSHv2;
    LSock.SSL.Username := 'admin';
    LSock.SSL.Password := 'secret';
    LSock.Connect('srv01.empresa.local', '22');
    LSock.SSLDoConnect;
    WriteLn('SSH session: ', LSock.SSL.GetSSLVersion);
  finally
    LSock.Free;
  end;
end;
```

### 6.3 Servidor TLS com verify de client cert

```pascal
uses
  blcksock, ssl_cryptlib;

var
  LServer, LClient: TTCPBlockSocket;
  LClientSock: TSocket;
  LSSL: TSSLCryptLib;
begin
  LServer := TTCPBlockSocket.Create;
  try
    LServer.Bind('0.0.0.0', '8443');
    LServer.Listen;
    LClientSock := LServer.Accept;

    LClient := TTCPBlockSocket.CreateWithSSL(TSSLCryptLib);
    try
      LClient.Socket := LClientSock;
      LSSL := LClient.SSL as TSSLCryptLib;
      LSSL.PrivateKeyFile := 'server.p15';
      LSSL.PrivateKeyLabel := 'server-tls';
      LSSL.CertCAFile := 'trusted-clients.p15';  // rejeita clientes fora desta lista
      LSSL.VerifyCert := True;
      LClient.SSLAcceptConnection;
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
| Herda de | `TCustomSSL` (blcksock.pas) | Contrato base |
| Vinculado a | `TTCPBlockSocket` | Via `TTCPBlockSocket.SSL` |
| Depende de | `cryptlib` (Pascal bindings) | Unit com prototipos de `cl32.dll` |
| Runtime | `cl32.dll` 3.2.0+ | Distribuicao obrigatoria junto com `.exe` |
| Formato chave | PKCS#15 | Unico formato aceite — nao ha suporte PEM directo |
| Alternativas | `TSSLOpenSSL`, `TSSLOpenSSL3/4`, `TSSLSBB`, `TSSLStreamSec` | Outros backends |
| Sub-capacidade | `TSSLLibSSH2` (ssl_libssh2.pas) | Alternativa SSH-only baseada em libssh2 |
