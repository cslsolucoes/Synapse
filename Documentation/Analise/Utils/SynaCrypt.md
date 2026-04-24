# SynaCrypt

**Unit:** `synacrypt.pas` | **Versao:** 001.001.000 | **Tipo:** Unit | **Origem:** Upstream

---

## 1. O que e?

A `synacrypt` e a unit de cifra simetrica block-based do pacote Ararat Synapse. Implementa DES, 3DES (Triple-DES) e AES (128/192/256 bits) em Pascal puro, sem dependencia de OpenSSL ou bibliotecas nativas. Cada algoritmo suporta seis modos de operacao: ECB (Electronic Codebook), CBC (Cipher Block Chaining), CFB 8-bit, CFB block, OFB (Output Feedback) e CTR (Counter). Baseada no trabalho de David Barton (DCPcrypt) e Eric Young (libcrypt original C); portada para Pascal pelo autor original do Synapse. Suporta IV (Initialization Vector) para modos encadeados, reset de chaining, e tres testes internos (`TestDes`, `Test3Des`, `TestAes`) para validar a implementacao contra NIST test vectors.

## 2. Caracteristicas

- Zero DLLs: toda a cripto e Pascal puro com S-boxes tabulares pre-computadas.
- Hierarquia OOP: `TSynaBlockCipher` (abstracto) -> `TSynaCustomDes` (abstracto) -> `TSynaDes` / `TSyna3Des` / `TSynaAes`.
- Block size variavel: `GetSize` retorna 8 (DES/3DES) ou 16 (AES).
- Key size:
  - DES: 8 bytes (56 efectivos).
  - 3DES: 24 bytes (K1|K2|K3, 168 efectivos).
  - AES: 16/24/32 bytes (AES-128/192/256) — detectado automaticamente em `InitKey`.
- IV persistente via `SetIV`/`GetIV`; `Reset` restaura `CV` (chaining vector) para o IV original.
- Modos de operacao totalmente encapsulados: o consumidor chama so `EncryptCBC`/`DecryptCBC` etc.

## 3. Engine

Engine Pascal pura:

- **DES S-boxes:** `des_skb[0..7, 0..63]` + `des_SPtrans[0..7, 0..63]` hardcoded.
- **AES S-box:** `S[0..255]`, `SI[0..255]` (inverso) + `T1..T4` / `T5..T8` (multiplicacoes pre-computadas em GF(2^8)).
- **Round constants:** `Rcon` para key expansion AES.
- **Modos:**
  - ECB: cifra/decifra bloco isolado.
  - CBC: XOR com `CV` antes de cifrar; apos, `CV := Cipher`.
  - CFB-8bit: shift-register byte-a-byte.
  - CFB-block: shift-register bloco-a-bloco.
  - OFB: `CV := Enc(CV)`, XOR plaintext.
  - CTR: incrementa `IV` como contador, XOR plaintext.

## 4. Funcionalidades

### 4.1 Classe `TSynaBlockCipher` (base)

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create(Key: AnsiString);` | Inicializa com key. |
| `SetIV` | `procedure SetIV(const Value: AnsiString); virtual;` | Define vector inicial de chaining. |
| `GetIV` | `function GetIV: AnsiString; virtual;` | Retorna `CV` corrente. |
| `Reset` | `procedure Reset; virtual;` | Repoe `CV := IV`. |
| `EncryptECB` / `DecryptECB` | `function EncryptECB/DecryptECB(const InData: AnsiString): AnsiString; virtual;` | Modo ECB. |
| `EncryptCBC` / `DecryptCBC` | `function EncryptCBC/DecryptCBC(const InData: AnsiString): AnsiString; virtual;` | Modo CBC. |
| `EncryptCFB8bit` / `DecryptCFB8bit` | `function ...CFB8bit(const InData: AnsiString): AnsiString; virtual;` | CFB byte. |
| `EncryptCFBblock` / `DecryptCFBblock` | `function ...CFBblock(const InData: AnsiString): AnsiString; virtual;` | CFB bloco. |
| `EncryptOFB` / `DecryptOFB` | `function ...OFB(const InData: AnsiString): AnsiString; virtual;` | OFB. |
| `EncryptCTR` / `DecryptCTR` | `function ...CTR(const InData: AnsiString): AnsiString; virtual;` | CTR. |
| `InitKey` | `procedure InitKey(Key: AnsiString); virtual;` (protected) | Hook para derivar subkeys. |
| `GetSize` | `function GetSize: byte; virtual;` (protected) | Block size em bytes (default 8). |
| `IncCounter` | `procedure IncCounter;` (private) | Incrementa CTR. |

### 4.2 Classe `TSynaCustomDes` (abstracta)

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `DoInit` | `procedure DoInit(KeyB: AnsiString; var KeyData: TDesKeyData);` (protected) | Gera 16 subkeys DES (32 integer). |
| `EncryptBlock` | `function EncryptBlock(const InData: AnsiString; var KeyData: TDesKeyData): AnsiString;` (protected) | Cifra 1 bloco de 8 bytes. |
| `DecryptBlock` | `function DecryptBlock(const InData: AnsiString; var KeyData: TDesKeyData): AnsiString;` (protected) | Decifra 1 bloco. |

### 4.3 Classe `TSynaDes`

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `InitKey` | `override;` (protected) | Popula `KeyData: TDesKeyData` (8 bytes). |
| `EncryptECB` | `override;` | Cifra um bloco 64-bit. |
| `DecryptECB` | `override;` | Decifra um bloco 64-bit. |

### 4.4 Classe `TSyna3Des`

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `InitKey` | `override;` (protected) | Popula `KeyData[0..2]` (24 bytes -> tres chaves DES). |
| `EncryptECB` | `override;` | Encrypt(K1) -> Decrypt(K2) -> Encrypt(K3). |
| `DecryptECB` | `override;` | Decrypt(K3) -> Encrypt(K2) -> Decrypt(K1). |

### 4.5 Classe `TSynaAes`

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `InitKey` | `override;` (protected) | Derivado de 16/24/32 bytes; `numrounds` = 10/12/14. |
| `GetSize` | `override;` (protected) | Sempre 16 (AES block size). |
| `EncryptECB` | `override;` | Cifra bloco 128-bit. |
| `DecryptECB` | `override;` | Decifra bloco 128-bit. |

### 4.6 Funcoes de teste (self-test)

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `TestDes` | `function TestDes: boolean;` | NIST vectors para DES. |
| `Test3Des` | `function Test3Des: boolean;` | NIST vectors para 3DES. |
| `TestAes` | `function TestAes: boolean;` | NIST vectors para AES (128/192/256). |

### 4.7 Tipos e constantes

| Nome | Definicao |
| --- | --- |
| `TDesKeyData` | `array[0..31] of integer` (16 subkeys DES). |
| `BC` | Constante `= 4` (colunas do estado AES). |
| `MAXROUNDS` | Constante `= 14` (AES-256). |

## 5. Aplicabilidades

- **Proteccao de payloads em protocolos legacy:** DES em MSCHAPv2, 3DES em RADIUS/Kerberos v4 ticket.
- **AES:** encapsulamento de passwords em scripts standalone sem OpenSSL.
- **LDAP SASL GSSAPI:** sealing de mensagens via 3DES-CBC (pre-AES Kerberos).
- **Storage seguro:** cifrar ficheiros de config `.ini` com secret local.
- **Transferencias ad-hoc:** cifrar pacotes UDP em aplicacoes custom.
- **Nao usar em SSL/TLS:** Synapse SSL usa `ssl_openssl`/`ssl_sbb` — nao `synacrypt`.

## 6. Exemplos de uso

```pascal
uses
  SysUtils, synacrypt;
var
  aes: TSynaAes;
  plain, cipher, back: AnsiString;
begin
  aes := TSynaAes.Create('0123456789ABCDEF');  // 16 bytes = AES-128
  try
    aes.SetIV('1234567890123456');              // IV 16 bytes
    plain := 'Conteudo secreto com 32 bytes!!!';
    cipher := aes.EncryptCBC(plain);
    Writeln('Cipher hex: ', Length(cipher));

    aes.Reset;
    back := aes.DecryptCBC(cipher);
    Writeln('Plain de volta: ', back);
  finally
    aes.Free;
  end;
end;
```

```pascal
uses
  SysUtils, synacrypt, synautil;
var
  des3: TSyna3Des;
  key, iv, data, enc: AnsiString;
begin
  // 3DES em CFB-bloco (legacy MSCHAPv2 / Kerberos v4)
  key := PadString('chave3des-24bytes!!', 24, #0);
  iv  := PadString('IV8bytes', 8, #0);

  des3 := TSyna3Des.Create(key);
  try
    des3.SetIV(iv);
    data := 'Dados legacy';
    enc := des3.EncryptCFBblock(data);
    Writeln('3DES CFB len: ', Length(enc));
  finally
    des3.Free;
  end;
end;
```

```pascal
uses
  SysUtils, synacrypt;
begin
  // Self-test contra NIST vectors
  if TestDes then
    Writeln('DES    : PASS')
  else
    Writeln('DES    : FAIL');

  if Test3Des then
    Writeln('3DES   : PASS')
  else
    Writeln('3DES   : FAIL');

  if TestAes then
    Writeln('AES    : PASS')
  else
    Writeln('AES    : FAIL');
end;
```

## 7. Relacionamentos

- **Consumida por:** raramente por outras units Synapse; e disponibilizada como toolkit opcional. `smtpsend` e `pop3send` podem usar via CRAM-MD5 (`HMAC_MD5` de `synacode`).
- **Depende de:** `SysUtils`, `Classes`, `synautil`, `synafpc`.
- **Nao substitui:** OpenSSL/SSL stack (ver `ssl_openssl.pas`, `ssl_openssl3.pas`, `ssl_openssl4.pas`) — que e o caminho para TLS/LDAPS.
- **Fork CSL:** sem modificacoes especificas (upstream puro).
