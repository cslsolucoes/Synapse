# PKCS#11 cross-platform (Cryptoki v3) — V42.0+

> Documentação da camada PKCS#11 entregue em **S13b (V42.0)**: enumera
> certificados em tokens/smartcards/HSMs em **Linux/Windows/macOS**.
> Synapse é a **única biblioteca Pascal com PKCS#11 portátil**.

## Visão geral

PKCS#11 (também conhecido como Cryptoki) é o padrão OASIS para
comunicação entre aplicações e tokens criptográficos (smartcards,
USB tokens, HSMs). Drivers PKCS#11 são fornecidos pelo fabricante:

- **eToken** (SafeNet/Aladdin) — `eTPKCS11.dll` (Win), `libeToken.so` (Linux)
- **SafeNet Authentication Client** — idem
- **Giesecke+Devrient** — `libgctop21.so` / `gtop21pkcs11.dll`
- **SoftHSM2** (open-source) — `libsofthsm2.so`
- **YubiKey HSM** — `libykcs11.so` / `libykcs11.dll`

ACBr só implementa A3 via Windows CryptoAPI (Win-only). Synapse V42.0
suporta PKCS#11 directamente, funcionando em Linux/Docker (eSocial em
containers, p.ex.).

## Componente

| Unit | Classe | Função |
|---|---|---|
| `ssl_openssl_icpbrasil_pkcs11.pas` | `TPkcs11Loader` | Loader PKCS#11 cross-platform com auto-detecção |

## Uso típico

```pascal
uses ssl_openssl_icpbrasil_pkcs11;

var
  LP11: TPkcs11Loader;
  LSlots: TArray<TP11SlotInfo>;
  LCerts: TArray<TP11CertInfo>;
  I: Integer;
begin
  LP11 := TPkcs11Loader.Create;
  try
    // 1. Auto-detecta driver instalado em paths conhecidos
    if not LP11.AutoDetectAndLoad then
    begin
      WriteLn('Erro: ', LP11.LastError);
      Exit;
    end;
    WriteLn('Driver: ', LP11.ModulePath);

    // 2. Enumera slots (apenas com token presente)
    LSlots := LP11.EnumerateSlots(True);
    if Length(LSlots) = 0 then
    begin
      WriteLn('Nenhum token detectado.');
      Exit;
    end;
    for I := 0 to High(LSlots) do
      WriteLn(Format('Slot %d: %s | Token: %s (%s)',
        [LSlots[I].SlotId, LSlots[I].Description,
         LSlots[I].TokenLabel, LSlots[I].TokenSerial]));

    // 3. Abre sessao no primeiro slot com PIN
    if not LP11.OpenSession(LSlots[0].SlotId, '1234') then
    begin
      WriteLn('Login falhou: ', LP11.LastError);
      Exit;
    end;

    // 4. Enumera certificados
    LCerts := LP11.EnumerateCertificates;
    for I := 0 to High(LCerts) do
    begin
      WriteLn('---');
      WriteLn('Label: ', LCerts[I].LabelStr);
      WriteLn('DER:   ', Length(LCerts[I].DerBytes), ' bytes');
      // LCerts[I].DerBytes pode ser convertido para PX509 e usado
      // pelo leitor ICP-Brasil
    end;
  finally
    LP11.Free;     // CloseSession + Unload automatico
  end;
end;
```

## Auto-detecção de drivers

`AutoDetectAndLoad` tenta carregar drivers em paths conhecidos:

### Linux

```text
/usr/lib/softhsm/libsofthsm2.so
/usr/lib/x86_64-linux-gnu/softhsm/libsofthsm2.so
/usr/lib64/libeToken.so
/usr/lib/pkcs11/libsofthsm2.so
```

### Windows

```text
C:\Windows\SysWOW64\eTPKCS11.dll
C:\Windows\System32\eTPKCS11.dll
C:\Program Files\SafeNet\Authentication\SAC\x64\eTPKCS11.dll
C:\Program Files (x86)\SafeNet\Authentication\SAC\Win32\eTPKCS11.dll
```

### macOS

```text
/usr/local/lib/softhsm/libsofthsm2.so
/Library/Frameworks/eToken.framework/Versions/Current/libeToken.dylib
/usr/local/lib/pkcs11/libsofthsm2.dylib
```

Para drivers em paths não-padrão, usar `LoadModule(APath: string)`
directamente.

## Setup SoftHSM2 (Linux para testes)

```bash
# Instalar
sudo apt install softhsm2

# Inicializar token
softhsm2-util --init-token --slot 0 --label "TestToken" --pin 1234 --so-pin 5678

# Importar PFX como par chave-certificado
pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so \
  --pin 1234 --login \
  --write-object cert.der --type cert --label "MyCert" \
  --id 01

# Usar no Synapse
LP11.LoadModule('/usr/lib/softhsm/libsofthsm2.so');
LP11.OpenSession(0, '1234');
LCerts := LP11.EnumerateCertificates;   // retorna MyCert
```

## Records expostos

```pascal
TP11SlotInfo = record
  SlotId:            CK_SLOT_ID;     // ID do slot na lib
  Description:       string;          // 'SoftHSM slot ID 0x...'
  Manufacturer:      string;          // 'SoftHSM project'
  HasToken:          Boolean;         // true se token presente
  TokenLabel:        string;          // 'TestToken'
  TokenSerial:       string;
  TokenManufacturer: string;
  TokenModel:        string;
end;

TP11CertInfo = record
  Handle:     CK_OBJECT_HANDLE;       // handle PKCS#11 do object
  LabelStr:   string;                 // CKA_LABEL
  DerBytes:   TBytes;                 // CKA_VALUE (cert DER)
  SubjectRaw: TBytes;                 // CKA_SUBJECT (DER name)
  IdRaw:      TBytes;                 // CKA_ID (id binário do par)
end;
```

## Conversão para `PX509` OpenSSL

Para usar o cert do token no leitor ICP-Brasil (que precisa de `PX509`):

```pascal
uses
  ssl_openssl3_lib;

function CertDerToPX509(const ADer: TBytes): PX509;
var
  LBuf: PByte;
  LSrcPtrPtr: PPointer;
begin
  Result := nil;
  if Length(ADer) = 0 then Exit;
  LBuf := @ADer[0];
  LSrcPtrPtr := @LBuf;
  Result := d2iX509(nil, PPointer(LSrcPtrPtr), Length(ADer));
end;
```

> Helper dedicado roadmap V42.2: `LerCertPkcs11(slot, pin,
> token_label): TIcpBrasilCertificado` orquestrando tudo.

## Limitações V42.0

- **Signing remoto via PKCS#11** (chave privada permanece no token —
  operação de sign delega ao token) — **não implementado**. Roadmap V42.x
  via OpenSSL engine PKCS#11.
- **OpenSSL engine bridge** (carregar engine PKCS#11 e usar em PKCS#7 sign)
  — não implementado. Workaround actual: extrair `DerBytes` do cert e usar
  para validação offline (chain/CRL/OCSP); para signing usar OpenSSL CLI
  com engine `pkcs11` ou biblioteca externa.
- **Cryptoki v3.0 features novas** — Synapse usa subset compatível com
  Cryptoki v2.40+ (ampla compatibilidade); features v3.0 específicas
  (e.g., `C_LoginUser`, message-based ops) não implementadas.

## Cobertura testada

| Driver | Plataforma | Status |
|---|---|---|
| SoftHSM2 | Linux | ✅ Tested (CI) |
| eToken | Windows | ✅ Loader resolve; enumeração depende do hardware |
| SafeNet | Windows | ✅ Loader resolve |
| YubiKey HSM | Linux | ⚠️ Não testado mas API compatível |
| AWS CloudHSM | Linux | ⚠️ Não testado |
| Giesecke+Devrient | — | ⚠️ Não testado |

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `AutoDetectAndLoad` retorna False | Nenhum driver nos paths default | Usar `LoadModule(path)` explícito |
| `LoadModule` retorna False | DLL/SO não existe ou versão de bits errada | Confirmar arquitectura (`uname -m` Linux; build target Win) |
| `EnumerateSlots` vazio | Token não inserido ou driver não detecta | Verificar com `pkcs11-tool --list-slots` (Linux) |
| `OpenSession` falha CKR=0xA0 (PIN_INCORRECT) | PIN errado | Cuidado: 3-5 tentativas erradas bloqueiam token (PUK necessário) |
| `EnumerateCertificates` retorna 0 mas tem certs | Cert não tem CKA_TOKEN=true | Driver/import errado; verificar com `pkcs11-tool --list-objects --type cert` |

## Referências

- [PKCS #11 v3.0 (OASIS)](https://docs.oasis-open.org/pkcs11/pkcs11-base/v3.0/os/pkcs11-base-v3.0-os.html)
- [SoftHSM2 documentation](https://www.opendnssec.org/softhsm/)
- [pkcs11-tool man page](https://manpages.debian.org/testing/opensc/pkcs11-tool.1.en.html)
