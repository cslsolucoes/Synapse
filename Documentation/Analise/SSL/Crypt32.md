# Crypt32 / Crypt32.pas

**Unit:** `Crypt32.pas` | **Versao:** 001.000.000 | **Tipo:** Unit (imports Win32 API) | **Origem:** Upstream Synapse (Pepak, 2018)

---

## 1. O que e?

`Crypt32.pas` e o binding Pascal minimalista para a API **Microsoft Cryptographic API (CAPI)** via `crypt32.dll`, usada para aceder ao **Windows Certificate Store** (onde o Windows armazena certificados do utilizador, da maquina, dos servicos, etc.). Foi criada por Pepak em 2018 como suporte directo de `ssl_openssl_capi.pas` — nao tenta ser um wrapper completo da `crypt32.dll`, apenas os simbolos estritamente necessarios para busca e acesso a contextos de certificado CNG/CAPI.

A unit declara tipos essenciais (`HCERTSTORE`, `PCCERT_CONTEXT`, `CERT_INFO`, `CRYPT_DATA_BLOB`, `CRYPT_HASH_BLOB`, `CRL_CONTEXT`, `CRYPT_KEY_PROV_INFO`), dezenas de constantes com codigos OID (`szOID_RSA_*`, `szOID_ECC_*`, `szOID_NIST_*`), flags de busca (`CERT_FIND_*`), property IDs (`CERT_*_PROP_ID`), e imports directos de `crypt32.dll`, `advapi32.dll` e `cryptdlg.dll`. Comentario do autor: "Pozor, tohle je naprosto minimalni mnozina toho, co Crypt32.dll nabizi. Prevedl jsem jen to, co jsem potreboval." (apenas o minimo necessario).

Consumida por `ssl_openssl_capi.pas` para localizar o certificado pelo `SigningCertificateID` (`CertFindCertificateInStore`), abrir o Certificate Store certo (`CertOpenStore`), e extrair o contexto PCCERT_CONTEXT que sera passado a ENGINE CAPI do OpenSSL.

---

## 2. Caracteristicas

- **Binding minimalista:** so os simbolos efectivamente usados pelo plugin CAPI.
- **Windows-only:** depende de `Windows.pas` — nao compila em Linux/macOS.
- **Tres DLLs:** `crypt32.dll` (main), `advapi32.dll` (crypto basico), `cryptdlg.dll` (UI dialogs de cert).
- **8 store locations:** CurrentUser, LocalMachine, Services, Users e variantes com Group Policy/Enterprise.
- **OIDs exhaustivos:** RSA, ECC, NIST (AES, SHA2), DH, PKCS, X957 (DSA), OIWSEC (legacy), INFOSEC — mesmo os depreciados.
- **PFX import:** `PFXImportCertStore` para PKCS#12.
- **Sistema-register ready:** tipos compativeis com `CryptoAPI2` do .NET.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `uses Windows` | Base Win32 API |
| `external CryptoLib` | Binding com `crypt32.dll` |
| `external AdvapiLib` | Binding com `advapi32.dll` |
| `external CryptDlgLib` | Binding com `cryptdlg.dll` |
| `stdcall` | Calling convention Win32 |

Constantes de DLL:

| Constante | Valor | Uso |
| --- | --- | --- |
| `CryptoLib` | `'crypt32.dll'` | Main certificate API |
| `AdvapiLib` | `'advapi32.dll'` | CryptAcquireContext etc |
| `CryptDlgLib` | `'cryptdlg.dll'` | Dialogs de selector de cert |

---

## 4. Funcionalidades

### 4.1 Tipos principais

| Tipo | Definicao | Descricao |
| --- | --- | --- |
| `HCERTSTORE` | `THandle` | Handle opaco de Cert Store |
| `HCRYPTPROV` | `THandle` | Handle de Cryptographic Provider |
| `HCRYPTKEY` | `THandle` | Handle de chave |
| `PCCERT_CONTEXT` | `^CERT_CONTEXT` | Ponteiro para contexto de cert |
| `CERT_CONTEXT` | record | Cert encoded + `pCertInfo` + `hCertStore` |
| `PCERT_INFO` | `^CERT_INFO` | Dados decoded do cert |
| `CERT_INFO` | record | Version, serial, subject, issuer, validity, pub key |
| `CRYPT_DATA_BLOB` | `cbData + pbData: PByte` | Blob de dados binarios |
| `CRYPT_HASH_BLOB` | `cbData + pbData: Pointer` | Blob de hash |
| `PCCRL_CONTEXT` | `^CRL_CONTEXT` | CRL (Certificate Revocation List) |
| `CRYPT_KEY_PROV_INFO` | record | Metadata de provider de chave |
| `CRYPT_ALGORITHM_IDENTIFIER` | `pszObjId + Parameters` | Identificacao OID |
| `CERT_PUBLIC_KEY_INFO` | record | Algoritmo + chave publica |
| `PCERT_EXTENSION` | `^CERT_EXTENSION` | Extensao X509 |
| `CRYPT_SIGN_MESSAGE_PARA` | record | Params para `CryptSignMessage` |
| `TWindowsCertStoreLocation` | (implementado em ssl_openssl_capi) | Enum das 8 locations |

### 4.2 Constantes de OID (selec)

| Constante | Valor | Significado |
| --- | --- | --- |
| `szOID_RSA_RSA` | `'1.2.840.113549.1.1.1'` | RSA encryption |
| `szOID_RSA_SHA256RSA` | `'1.2.840.113549.1.1.11'` | SHA256 with RSA |
| `szOID_ECC_PUBLIC_KEY` | `'1.2.840.10045.2.1'` | ECDSA public key |
| `szOID_ECDSA_SHA256` | `'1.2.840.10045.4.3.2'` | ECDSA-SHA256 |
| `szOID_NIST_AES256_CBC` | `'2.16.840.1.101.3.4.1.42'` | AES-256-CBC |
| `szOID_NIST_sha256` | `'2.16.840.1.101.3.4.2.1'` | SHA-256 |
| `szOID_NIST_sha384` | `'2.16.840.1.101.3.4.2.2'` | SHA-384 |
| `szOID_NIST_sha512` | `'2.16.840.1.101.3.4.2.3'` | SHA-512 |

### 4.3 Constantes de flags e stores

| Grupo | Constantes relevantes |
| --- | --- |
| Cert encoding | `X509_ASN_ENCODING = 1`, `PKCS_7_ASN_ENCODING = 65536` |
| Store providers | `CERT_STORE_PROV_MEMORY`, `CERT_STORE_PROV_FILE`, `CERT_STORE_PROV_SYSTEM_W` |
| System stores | `CERT_SYSTEM_STORE_CURRENT_USER`, `CERT_SYSTEM_STORE_LOCAL_MACHINE`, `CERT_SYSTEM_STORE_USERS`, etc. |
| Find types | `CERT_FIND_SUBJECT_STR_W = 524295`, `CERT_FIND_SHA1_HASH = 65536`, `CERT_FIND_ANY = 0` |
| Property IDs | `CERT_KEY_PROV_INFO_PROP_ID = 2`, `CERT_SHA1_HASH_PROP_ID = 3`, `CERT_FRIENDLY_NAME_PROP_ID = 11` |
| PFX | `PKCS12_PREFER_CNG_KSP`, `PKCS12_ALWAYS_CNG_KSP`, `PKCS12_INCLUDE_EXTENDED_PROPERTIES` |
| Crypt acquire | `CRYPT_ACQUIRE_CACHE_FLAG`, `CRYPT_ACQUIRE_SILENT_FLAG`, `CRYPT_ACQUIRE_ONLY_NCRYPT_KEY_FLAG` |
| Add disposition | `CERT_STORE_ADD_NEW = 1`, `CERT_STORE_ADD_REPLACE_EXISTING = 3` |
| Errors | `CRYPT_E_NOT_FOUND = $80092004` |

### 4.4 Funcoes importadas principais

| Funcao | Assinatura | Descricao |
| --- | --- | --- |
| `CertOpenStore` | `function(szStoreProvider, dwMsgAndCertEncodingType, hCryptProv, dwFlags, pvPara): HCERTSTORE; stdcall` | Abre cert store generico |
| `CertOpenSystemStore` | `function(hProv: HCRYPTPROV; szSubsystemProtocol: PChar): HCERTSTORE; stdcall` | Abre System store por nome ('MY', 'ROOT', 'CA', 'TRUST') |
| `CertCloseStore` | `function(hCertStore: HCERTSTORE; dwFlags: DWORD): BOOL; stdcall` | Fecha store |
| `CertFindCertificateInStore` | `function(hCertStore, dwCertEncodingType, dwFindFlags, dwFindType, pvFindPara, pPrevCertContext): PCCERT_CONTEXT; stdcall` | Busca cert por criterio (subject, hash, friendly name) |
| `CertEnumCertificatesInStore` | `function(hCertStore: HCERTSTORE; pPrevCertContext: PCCERT_CONTEXT): PCCERT_CONTEXT; stdcall` | Itera certificados do store |
| `PFXImportCertStore` | `function(pPFX: PCRYPT_DATA_BLOB; szPassword: PWideChar; dwFlags: DWORD): HCERTSTORE; stdcall` | Importa PFX para novo store em memoria |
| `CertGetCertificateContextProperty` (ver imports na unit) | Le propriedade do cert (SHA1 hash, friendly name, etc) |
| `CryptAcquireCertificatePrivateKey` | Obter handle da chave privada associada |

---

## 5. Aplicabilidades

1. **Suporte a `ssl_openssl_capi.pas`:** uso principal — resolve cert no Store antes de passar ao engine CAPI.
2. **Lookup de cert por friendly name:** `CertFindCertificateInStore` com `CERT_FIND_SUBJECT_STR_W` ou `CERT_FIND_PROPERTY`.
3. **Iteracao de certs de CurrentUser\MY:** listar todos os certs pessoais do utilizador.
4. **Import de PFX sem exportar chave:** `PFXImportCertStore` carrega PKCS#12 para memoria, chave nunca sai do contexto seguro.
5. **Integracao com smartcards:** `CRYPT_ACQUIRE_ONLY_NCRYPT_KEY_FLAG` forca uso de CNG (Next Generation) em vez de CryptoAPI legacy.

---

## 6. Exemplos de uso

### 6.1 Listar certs pessoais do utilizador

```pascal
uses
  Windows, Crypt32;

var
  LStore: HCERTSTORE;
  LCtx: PCCERT_CONTEXT;
begin
  LStore := CertOpenSystemStore(0, 'MY');
  if LStore <> 0 then
  try
    LCtx := nil;
    repeat
      LCtx := CertEnumCertificatesInStore(LStore, LCtx);
      if LCtx <> nil then
        WriteLn('Cert subject blob size: ', LCtx.pCertInfo.Subject.cbData);
    until LCtx = nil;
  finally
    CertCloseStore(LStore, 0);
  end;
end;
```

### 6.2 Buscar cert por Subject substring

```pascal
uses
  Windows, Crypt32;

var
  LStore: HCERTSTORE;
  LCtx: PCCERT_CONTEXT;
  LSearch: WideString;
begin
  LStore := CertOpenSystemStore(0, 'MY');
  try
    LSearch := 'Joao Silva';
    LCtx := CertFindCertificateInStore(
      LStore,
      X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
      0,
      CERT_FIND_SUBJECT_STR_W,
      PWideChar(LSearch),
      nil);
    if LCtx <> nil then
      WriteLn('Cert encontrado: ', LCtx.cbCertEncoded, ' bytes');
  finally
    CertCloseStore(LStore, 0);
  end;
end;
```

### 6.3 Import PFX para uso pelo OpenSSL CAPI engine

```pascal
uses
  Classes, SysUtils, Crypt32;

var
  LBlob: CRYPT_DATA_BLOB;
  LPFX: TMemoryStream;
  LStore: HCERTSTORE;
begin
  LPFX := TMemoryStream.Create;
  try
    LPFX.LoadFromFile('client.pfx');
    LBlob.cbData := LPFX.Size;
    LBlob.pbData := LPFX.Memory;
    LStore := PFXImportCertStore(@LBlob, 'pfx-password', PKCS12_INCLUDE_EXTENDED_PROPERTIES);
    if LStore <> 0 then
    try
      WriteLn('PFX importado; cert available in memory store');
    finally
      CertCloseStore(LStore, 0);
    end;
  finally
    LPFX.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| Consumida por | `ssl_openssl_capi.pas` (TSSLOpenSSLCapi) | Resolve certs no Windows Cert Store |
| Depende de | `Windows.pas` (RTL Win32) | Tipos base `THandle`, `DWORD`, `PChar` |
| Runtime | `crypt32.dll` | Main DLL (todas as certs APIs) |
| Runtime | `advapi32.dll` | CryptoAPI classica (`CryptAcquireContext`, etc) |
| Runtime | `cryptdlg.dll` | UI dialogs de selector de cert (raro) |
| Windows-only | Estrito | Nao compila/funciona em Linux/macOS |
| Consumidor indirecto | Qualquer codigo que chame `TSSLOpenSSLCapi` | Transitivamente usa esta unit |
| Minimalismo | Documentado | Autor: "apenas o minimo necessario" — para API completa ver jedi.inc ou Windows SDK |
