# Windows Certificate Store + A3 detection — V42.0+

> Documentação da camada de leitura do Windows Certificate Store entregue
> em **S13a (V42.0)**: enumera certificados instalados no Windows
> (CurrentUser/LocalMachine, store My/CA/Root) e detecta certificados em
> hardware (A3 — eToken/SafeNet/Giesecke).

## Visão geral

Em Windows, certificados ICP-Brasil podem ser instalados:

1. **A1 importado** — PFX importado para o Windows Store (chave em
   software, no perfil do usuário).
2. **A3 (token/smartcard)** — driver PKCS#11 do fabricante (eToken,
   SafeNet, etc.) instala middleware que **expõe o cert no Windows Store
   via CSP/CNG**, mas a chave privada permanece no hardware.

Antes de V42.0, o Synapse só lia PFX em arquivo. V42.0 adiciona
`TWinCertStore` para enumerar Windows Store + `IsCertificadoEmHardware`
para detectar A3 — espelhando o que ACBr faz com `TDFeWinCrypt`.

> **Limitação:** esta unit é **Windows-only**. Em Linux/macOS use
> `ssl_openssl_icpbrasil_pkcs11.pas` para PKCS#11 cross-platform — ver
> [pkcs11.md](pkcs11.md).

## Componente

| Unit | Classe | Função |
|---|---|---|
| `ssl_openssl_icpbrasil_winstore.pas` (Windows-only) | `TWinCertStore` | Enumeração CertStore + helper `IsCertificadoEmHardware` |

## Uso típico

```pascal
uses ssl_openssl_icpbrasil_winstore;

var
  LStore: TWinCertStore;
  LCerts: TArray<TWinCertEntry>;
  I: Integer;
begin
  LStore := TWinCertStore.Create;
  try
    if not LStore.OpenStore(slMy, slCurrentUser) then
    begin
      WriteLn('Erro: ', LStore.LastError);
      Exit;
    end;
    LCerts := LStore.EnumerateCertificates;
    WriteLn('Certs encontrados: ', Length(LCerts));
    for I := 0 to High(LCerts) do
    begin
      WriteLn('---');
      WriteLn('Subject:    ', LCerts[I].Subject);
      WriteLn('Issuer:     ', LCerts[I].Issuer);
      WriteLn('Thumbprint: ', LCerts[I].Thumbprint);
      WriteLn('Hardware:   ', BoolToStr(LCerts[I].IsHardware, True));
      WriteLn('DER size:   ', Length(LCerts[I].DerBytes));
    end;
  finally
    LStore.Free;
  end;
end;
```

## Stores suportados (`TWinCertStoreLocation`)

| Constante | Windows Name | Conteúdo típico |
|---|---|---|
| `slMy` | `MY` | Personal — certs do usuário (A1 importado, A3 do token) |
| `slAddressBook` | `AddressBook` | Outros usuários |
| `slCA` | `CA` | Intermediate CAs |
| `slRoot` | `ROOT` | Trusted Root CAs |
| `slTrustedPublisher` | `TrustedPublisher` | Publishers de código assinado |

## Escopo (`TWinCertStoreScope`)

| Constante | Equivalente | Observação |
|---|---|---|
| `slCurrentUser` | `CERT_SYSTEM_STORE_CURRENT_USER` | Default; certs do usuário logado |
| `slLocalMachine` | `CERT_SYSTEM_STORE_LOCAL_MACHINE` | Globais; geralmente exigem admin |

## Detecção A3

```pascal
function IsCertificadoEmHardware(const ACertDer: TBytes): Boolean;
```

Verifica se a chave privada associada ao cert está em hardware (token,
smartcard, HSM). Implementa:

1. `CertGetCertificateContextProperty(CERT_KEY_PROV_INFO_PROP_ID)` →
   obtém CSP/container info.
2. `CryptAcquireContext` no provider indicado.
3. `CryptGetProvParam(PP_IMPTYPE)` → bitmask com `CRYPT_IMPL_HARDWARE`
   se em hardware.

> **Atribuição LGPL:** Este helper é adaptação directa de
> `ACBrDFeWinCrypt.GetCertIsHardware` ([ACBr](https://acbr.com.br) sob
> LGPL v2.1). Header da unit Synapse documenta a atribuição explícita.

### Uso integrado

```pascal
var
  LCerts: TArray<TWinCertEntry>;
  I: Integer;
  LCert: TIcpBrasilCertificado;
begin
  LCerts := LStore.EnumerateCertificates;
  for I := 0 to High(LCerts) do
    if LCerts[I].IsHardware then
      WriteLn('A3: ', LCerts[I].Subject)
    else
      WriteLn('A1: ', LCerts[I].Subject);

  // Para usar o cert do Store no leitor ICP-Brasil:
  // 1. Pegar DerBytes do TWinCertEntry
  // 2. Converter para PX509 via d2i_X509 (TODO: helper dedicado em V42.2)
  // 3. Passar para ClassificarPorExtensoes
end;
```

## Filtro por thumbprint

```pascal
var
  LEntry: TWinCertEntry;
begin
  if LStore.FindByThumbprint('AB1234CD56EF...', LEntry) then
    WriteLn('Achou: ', LEntry.Subject);
end;
```

Útil quando aplicação tem o thumbprint pinado por configuração.

## Limitações V42.0

- **Conversão `TWinCertEntry.DerBytes` → `PX509` para usar em
  `LerDoPfx`** — ainda manual. Helper `LerCertWindowsStore(thumbprint,
  options): TIcpBrasilCertificado` é roadmap para V42.2.
- **PIN handling para A3** — `CryptAcquireContext` em A3 normalmente
  exige PIN. V42.0 usa `CRYPT_VERIFYCONTEXT` para evitar PIN prompt
  durante enumeração. Para signing real (que exige a chave privada),
  caller é responsável por gerenciar o PIN.
- **Linux/macOS** — não aplicável; usar `ssl_openssl_icpbrasil_pkcs11.pas`.

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `OpenStore` retorna False | Crypt32.dll não disponível ou store name errado | Verificar GetLastError em `LastError` |
| `EnumerateCertificates` vazio | Store realmente vazio ou escopo errado | Tentar `slLocalMachine` (admin); confirmar Mgmt Console |
| `IsHardware` False mas é A3 | Driver PKCS#11 instalado mas CSP wrapper não | Verificar driver expõe via CryptoAPI legacy (não só CNG) |
| Crash em `EnumerateCertificates` | DerBytes acesso a CERT_CONTEXT obsoleto | Bug Synapse — reportar; layout `_CertContextRec` pode variar |

## Referências

- [Microsoft CryptoAPI - CertOpenStore](https://learn.microsoft.com/windows/win32/api/wincrypt/nf-wincrypt-certopenstore)
- [CRYPT_KEY_PROV_INFO](https://learn.microsoft.com/windows/win32/api/wincrypt/ns-wincrypt-crypt_key_prov_info)
- [PP_IMPTYPE — CRYPT_IMPL_HARDWARE](https://learn.microsoft.com/windows/win32/seccrypto/cryptgetprovparam)
- ACBr referência (LGPL): `Fontes/ACBrDFe/ACBrDFeWinCrypt.pas`
