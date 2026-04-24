# TCustomSSL / blcksock.pas

**Unit:** `blcksock.pas` | **Versao:** 009.011.001 (CSL fork) | **Tipo:** Classe abstrata (interface de plugin SSL) | **Origem:** Upstream Synapse

---

## 1. O que e?

`TCustomSSL` e a classe abstrata que define a interface de plugin SSL/TLS no Synapse. Toda implementacao concreta de SSL (OpenSSL 1.0, 1.1, 3.x, 4.x, CryptLib, SecureBlackbox, StreamSec, SSH via libssh2) herda desta classe e implementa os metodos `Connect`, `Accept`, `Shutdown`, `SendBuffer`, `RecvBuffer`, `GetPeerSubject`, etc.

`TTCPBlockSocket` contem uma instancia de `TCustomSSL` (property `SSL`), cujo tipo concreto e determinado pela variavel global `SSLImplementation: TSSLClass = TSSLNone` (default) ou por passagem explicita ao construtor `CreateWithSSL(TSSLOpenSSL3)`. Isto permite trocar a implementacao SSL sem alterar o codigo consumidor: basta adicionar a unit do plugin (`ssl_openssl3`, `ssl_openssl4`, etc.) ao `uses` do projeto — o `initialization` do plugin atualiza `SSLImplementation`.

No fork CSL (V1.5.0+), a variante OpenSSL pode ser seleccionada via defines condicionais (`USE_OPENSSL3`, `USE_OPENSSL4`) que determinam qual plugin sera activo — ver `ORM.Defines.inc`.

---

## 2. Caracteristicas

* Classe abstrata (virtual methods com implementacao default vazia/`False`).
* Plugin-oriented architecture — troca de SSL runtime sem alterar consumidor.
* Suporta certificates em arquivo (PEM/PFX), em string binaria e autogerados.
* SNI (Server Name Indication) via property `SNIHost`.
* Callback de verificacao custom via `OnVerifyCert`.
* Cipher list configuravel.
* Suporte a SSH (via `ssl_libssh2.pas`) e SSL/TLS canal.
* Cross-compiler (Delphi + FPC).

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| [TTCPBlockSocket](TTCPBlockSocket.md) | Composicao — socket e passado no construtor |
| `TSSLClass = class of TCustomSSL` (metaclass) | Permite `CreateWithSSL(PluginClass)` |
| `SSLImplementation: TSSLClass = TSSLNone` (var global) | Default; plugins reais sobrescrevem no `initialization` |
| `TSSLType` | Enum: `LT_all`, `LT_SSLv2`, `LT_SSLv3`, `LT_TLSv1`, `LT_TLSv1_1`, `LT_TLSv1_2`, `LT_TLSv1_3`, `LT_SSHv2` |
| `THookVerifyCert` | `function (Sender: TObject): Boolean of object` — callback custom |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create(const Value: TTCPBlockSocket); virtual` | Associa plugin ao socket; chamado por `TTCPBlockSocket` internamente |
| `Assign` | `procedure Assign(const Value: TCustomSSL); virtual` | Copia configuracao (certs, chaves) de outra instancia |

### 4.2 Identificacao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `LibVersion` | `function LibVersion: String; virtual` | Versao da biblioteca (ex.: `OpenSSL 3.2.1`) |
| `LibName` | `function LibName: String; virtual` | Nome do plugin (ex.: `ssl_openssl3`) |

### 4.3 Handshake e shutdown (chamados internamente por TTCPBlockSocket)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Connect` | `function Connect: Boolean; virtual` | Inicia handshake SSL cliente |
| `Accept` | `function Accept: Boolean; virtual` | Handshake SSL lado servidor |
| `Shutdown` | `function Shutdown: Boolean; virtual` | Hard shutdown (antes de fechar socket) |
| `BiShutdown` | `function BiShutdown: Boolean; virtual` | Soft shutdown (continuar plaintext) |

### 4.4 I/O

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBuffer` | `function SendBuffer(Buffer: TMemory; Len: Integer): Integer; virtual` | Envia dados cifrados |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Len: Integer): Integer; virtual` | Recebe dados cifrados |
| `WaitingData` | `function WaitingData: Integer; virtual` | Bytes disponiveis no buffer SSL |
| `ImplementsEOF` | `function ImplementsEOF: Boolean; virtual` | `True` se o plugin detecta EOF correctamente |

### 4.5 Inspeccao da sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSSLVersion` | `function GetSSLVersion: string; virtual` | Ex.: `TLSv1.3` |
| `GetPeerSubject` | `function GetPeerSubject: string; virtual` | Subject DN do certificado peer |
| `GetPeerSerialNo` | `function GetPeerSerialNo: integer; virtual` | Serial do cert |
| `GetPeerIssuer` | `function GetPeerIssuer: string; virtual` | Issuer DN |
| `GetPeerName` | `function GetPeerName: string; virtual` | CN do peer (validar contra hostname) |
| `GetPeerNameHash` | `function GetPeerNameHash: cardinal; virtual` | Hash rapido |
| `GetPeerFingerprint` | `function GetPeerFingerprint: AnsiString; virtual` | Fingerprint binario |
| `GetCertInfo` | `function GetCertInfo: string; virtual` | Multi-linha com todos os campos |
| `GetCipherName` | `function GetCipherName: string; virtual` | Ex.: `TLS_AES_256_GCM_SHA384` |
| `GetCipherBits` | `function GetCipherBits: integer; virtual` | Bits efetivos |
| `GetCipherAlgBits` | `function GetCipherAlgBits: integer; virtual` | Bits algoritmicos |
| `GetVerifyCert` | `function GetVerifyCert: integer; virtual` | 0 = OK; outros codigos = erro OpenSSL |

### 4.6 Operacoes auxiliares (protected)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `ReturnError` | `procedure ReturnError` | Registra `LastError` do plugin |
| `SetCertCAFile` | `procedure SetCertCAFile(const Value: string); virtual` | Setter que recarrega o CA bundle |
| `DoVerifyCert` | `function DoVerifyCert: boolean` | Dispara `OnVerifyCert` hook |
| `CreateSelfSignedCert` | `function CreateSelfSignedCert(Host: string): Boolean; virtual` | Gera cert self-signed (para servidor teste) |

### 4.7 Properties publicadas

| Property | Tipo | Descricao |
| --- | --- | --- |
| `SSLEnabled` | `Boolean` R | `True` durante sessao TLS ativa |
| `LastError` | `Integer` R | Ultimo codigo de erro SSL |
| `LastErrorDesc` | `string` R | Texto do erro |
| `SSLType` | `TSSLType` R/W | Versao TLS requerida |
| `KeyPassword` | `string` R/W | Senha da chave privada |
| `Username` / `Password` | `string` R/W | Credenciais (SSH) |
| `Ciphers` | `string` R/W | Lista de ciphers separada por `:` |
| `CertificateFile` | `string` R/W | Cert cliente em arquivo PEM |
| `PrivateKeyFile` | `string` R/W | Chave privada PEM |
| `Certificate` | `AnsiString` R/W | Cert cliente em string binaria |
| `PrivateKey` | `AnsiString` R/W | Chave privada em string binaria |
| `PFX` | `AnsiString` R/W | PKCS#12 em string binaria |
| `PFXfile` | `string` R/W | PKCS#12 em arquivo |
| `TrustCertificateFile` / `TrustCertificate` | `string`/`AnsiString` R/W | Certs confiaveis custom |
| `CertCA` | `AnsiString` R/W | CA bundle em string |
| `CertCAFile` | `string` R/W | CA bundle em arquivo PEM |
| `VerifyCert` | `Boolean` R/W | Rejeitar cert invalido |
| `SSHChannelType` / `SSHChannelArg1` / `SSHChannelArg2` | `string` | SSH channel config |
| `CertComplianceLevel` | `Integer` R/W | Nivel compliance (CryptLib) |
| `OnVerifyCert` | `THookVerifyCert` R/W | Callback validacao custom |
| `SNIHost` | `string` R/W | Server Name Indication |
| `EOF` | `Boolean` R/W | Sinaliza stream fechada (WSAECONNRESET) |

---

## 5. Aplicabilidades

1. **Interface comum para plugins** — codigo consumidor compilado contra `TCustomSSL` funciona com qualquer implementacao.
2. **Troca dinamica de OpenSSL** — atualizar de 1.1 -> 3.x -> 4.x mudando apenas o `uses`.
3. **Verificacao customizada de certificado** — via `OnVerifyCert` pode-se adicionar check de CN, validade ou CRL.
4. **Inspeccao de sessao TLS** — ler `GetCipherName`, `GetSSLVersion` para auditoria/log.
5. **Servidor TLS** — em conjuncao com `SSLAcceptConnection` de `TTCPBlockSocket`.
6. **SSH via libssh2** — quando `ssl_libssh2.pas` esta activo.

---

## 6. Exemplos de uso

### 6.1 Verificacao customizada de certificado (validacao de CN)

```pascal
uses SysUtils, blcksock, ldapsend, ssl_openssl3;

function VerifyCN(Sender: TObject): Boolean;
var
  LSSL: TCustomSSL;
  LPeerName, LExpected: string;
begin
  LSSL := TCustomSSL(Sender);
  LPeerName := LSSL.GetPeerName;
  LExpected := 'dc01.empresa.local';
  Result := SameText(LPeerName, LExpected);
  if not Result then
    Writeln('CN invalido: peer=', LPeerName, ' esperado=', LExpected);
end;

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL := True;
    LLDAP.Sock.SNIHost := 'dc01.empresa.local';
    LLDAP.Sock.VerifyCert := True;
    LLDAP.Sock.SSL.OnVerifyCert := VerifyCN;
    LLDAP.Login;
  finally
    LLDAP.Free;
  end;
end;
```

### 6.2 Auditoria da sessao TLS apos Login

```pascal
uses SysUtils, ldapsend, ssl_openssl3;

var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL := True;
    LLDAP.Login;

    Writeln('Lib:    ', LLDAP.Sock.SSL.LibName, ' ', LLDAP.Sock.SSL.LibVersion);
    Writeln('Version:', LLDAP.Sock.SSL.GetSSLVersion);
    Writeln('Cipher: ', LLDAP.Sock.SSL.GetCipherName,
            ' (', LLDAP.Sock.SSL.GetCipherBits, ' bits)');
    Writeln('Subject:', LLDAP.Sock.SSL.GetPeerSubject);
    Writeln('Issuer: ', LLDAP.Sock.SSL.GetPeerIssuer);
    Writeln('Verify: ', LLDAP.Sock.SSL.GetVerifyCert);
  finally
    LLDAP.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TObject` | Heranca | Base Delphi |
| [TTCPBlockSocket](TTCPBlockSocket.md) | Composicao/owner | Socket que contem o plugin |
| [TSSLNone](TSSLNone.md) | Subclasse default | Plugin sem SSL |
| `TSSLOpenSSL` (ssl_openssl.pas) | Subclasse legacy | OpenSSL 1.0 |
| `TSSLOpenSSL3` (ssl_openssl3.pas) | Subclasse V1.5.0+ | OpenSSL 3.x + DLLs em `dll/v3/` |
| `TSSLOpenSSL4` (ssl_openssl4.pas) | Subclasse V1.5.0+ | Fork CSL OpenSSL 4.0 + DLLs em `dll/v4/` |
| `TSSLOpenSSL11` (ssl_openssl11.pas) | Subclasse | OpenSSL 1.1.x |
| `TSSLCryptLib` (ssl_cryptlib.pas) | Subclasse | CryptLib |
| `TSSLSBB` / `TSSLSBB16` (ssl_sbb.pas) | Subclasse | SecureBlackbox |
| `TSSLStreamSec` (ssl_streamsec.pas) | Subclasse | StreamSec |
| `TSSLLibSSH2` (ssl_libssh2.pas) | Subclasse | SSH via libssh2 |
| `SSLImplementation` (var global) | Factory | `TSSLClass` com plugin default activo |
| `THookVerifyCert` | Procedural type | Callback de `OnVerifyCert` |
| `TSSLType` / `TSSLClass` | Tipos auxiliares | Enum e metaclass |
