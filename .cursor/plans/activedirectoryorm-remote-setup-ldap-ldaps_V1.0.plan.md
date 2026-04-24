---
name: activedirectoryorm-remote-setup-ldap-ldaps
version: 1.0.0
date: 2026-04-23
author: CSL Softwares
status: draft
scope: >
  ActiveDirectoryORM V1.8.0 — SETUP completo remoto de LDAP + LDAPS + StartTLS +
  Global Catalog num DC Windows Server, via canal SSH2 embebido (libssh2 + WinCNG).
  Cobre desde o bootstrap inicial (WinRM one-shot para distribuir chave SSH) até
  à validação end-to-end dos 5 protocolos no cliente Delphi.
depends-on:
  - Tutorial-LDAPS-AD-Conexao-Externa.md (fluxo manual validado em 2026-04-22)
  - Packege/synapse/ssl_libssh2.pas (wrapper Synapse, 252 linhas, já no fork)
  - projects/package/libssh2_delphi/libssh2.pas (bindings Pascal v2026.0312)
  - projects/package/libssh2/ (source C do libssh2 1.11.2_DEV, para rebuild WinCNG)
  - projects/package/libssh2_delphi/comp/uMySFTPClient.pas (TSSH2Client + ExecCommand)
  - E:/GestorERP/dll/<arch>/ (DLLs runtime actuais: libssh2 1.9 + OpenSSL 1.1)
  - E:/GestorERP/.ssh/administrators_authorized_keys (chave pública canónica CSL)
target-platforms:
  delphi:
    - Delphi 12.x Win32/Win64 (suporte total; Views VCL)
  fpc:
    - FPC 3.3.1+ i386-win32/x86_64-win64 (compilação sem Views VCL)
  servers-suportados:
    - Windows Server 2019/2022/2025 com AD DS role
protected-areas:
  - Packege/synapse/ — não tocado (só consumido)
  - Documentation/ — alterações via skill dedicada após execução
  - .cursor/ — alterações apenas via plan mode ou skill
out-of-scope:
  - Kerberos/GSSAPI SASL bind (agendado V2.0.0 conforme Roadmap)
  - LDAP Channel Binding enforcement (só diagnostica, não altera política GPO)
  - Desabilitar/revogar LDAPS (rollback — agendado V1.8.1)
  - Suporte multi-DC simultâneo em uma chamada (agendado V1.9.0)
  - Cross-platform (POSIX) para o módulo Remote — Windows-only (invariante V1.7.0 #12)
  - Distribuir chave SSH automática via GPO (admin faz manualmente nas OUs onde precisa)
supersedes: none (funcionalidade nova)
---

# ActiveDirectoryORM V1.8.0 — SETUP completo LDAP + LDAPS + SSH remoto

> **Status:** draft — requer aprovação antes de execução.
> Destino: `.cursor/plans/activedirectoryorm-remote-setup-ldap-ldaps_V1.0.plan.md`
> Plano espelho para leitura livre: `Plano-Automacao-LDAPS-Setup.md` (raiz do projecto).

---

## 1. Contexto e motivação

Hoje o fluxo para habilitar LDAP+LDAPS num DC Windows Server é **totalmente manual** (ver `Tutorial-LDAPS-AD-Conexao-Externa.md`):

1. **Bootstrap SSH** (one-shot): OpenSSH Server + chave pública + `sshd_config` + ACLs + firewall 22
2. **LDAP 389:** confirmar firewall + logs
3. **LDAPS 636:** AD CS → certreq → restart NTDS → validar handshake
4. **StartTLS 389→TLS:** validar upgrade
5. **Global Catalog 3268/3269:** validar firewall + handshake

**Objectivo V1.8.0:** encapsular tudo em units Delphi + forms VCL, com API fluent.

### Protocolos cobertos

| Protocolo | Porta | TLS | Coberto V1.8.0 |
|---|---|---|---|
| LDAP (plain) | 389 | Nenhuma | ✅ Valida firewall + logs |
| LDAPS | 636 | TLS 1.2 | ✅ Full (AD CS + cert + restart) |
| LDAP+StartTLS | 389→TLS | Upgrade | ✅ Valida extended op |
| Global Catalog | 3268 | Nenhuma | ✅ Valida firewall + bind |
| Global Catalog SSL | 3269 | TLS | ✅ Valida firewall + handshake |
| SASL GSSAPI (Kerberos) | 389 encrypted | Kerberos | ❌ V2.0.0 (roadmap) |
| LDAP Channel Binding | — | Token bind | ⚠️ Só diagnóstico |

---

## 2. Viabilidade técnica

### Stack 100% disponível localmente (verificado 2026-04-22)

| Camada | Ficheiro | Localização |
|---|---|---|
| Wrapper SSH2 alto-nível | `uMySFTPClient.pas` — `TSSH2Client.ExecCommand` (L2608) | `projects/package/libssh2_delphi/comp/` ✅ |
| Wrapper SSH2 baixo-nível | `ssl_libssh2.pas` (252 L) | `Packege/synapse/` ✅ |
| Bindings Pascal libssh2 | `libssh2.pas` v2026.0312 | `projects/package/libssh2_delphi/` ✅ |
| Source C libssh2 | `libssh2 1.11.2_DEV` (5 backends: OpenSSL / WinCNG / mbedTLS / libgcrypt / OS400) | `projects/package/libssh2/` ✅ |
| DLL runtime Win32 | `libssh2.dll` (259 KB) + `libssl-1_1.dll` + `libcrypto-1_1.dll` | `E:/GestorERP/dll/win32/` ✅ |
| DLL runtime Win64 | `libssh2-x64.dll` (298 KB) + `libssl-1_1-x64.dll` + `libcrypto-1_1-x64.dll` | `E:/GestorERP/dll/win64/` ✅ |
| Chave pública canónica | `administrators_authorized_keys` (ssh-rsa 4096) | `E:/GestorERP/.ssh/` ✅ |
| EXE demo pronto | `ssh_delphi.exe` (Win32 + Win64, 2020-09-18) | `E:/GestorERP/dll/<arch>/` ✅ |

**Gap zero.** Pronto para teste-piloto sem baixar nada.

### Decisão crypto-backend

**Backend recomendado: WinCNG** (Windows Cryptography API Next Generation, nativo do SO).

| Critério | OpenSSL 1.1 (DLLs actuais) | WinCNG (a build) |
|---|---|---|
| Dependências runtime | 3 DLLs (`libssh2.dll` + 2 OpenSSL) | **1 DLL** (só `libssh2.dll`) |
| Tamanho total | ~2.5 MB | ~500 KB |
| Conflito com `ssl_openssl3.pas` / `ssl_openssl4.pas` do LDAPS | ⚠️ possível (OpenSSL 1.1 vs 3.x no mesmo processo) | **zero** |
| Hardware crypto accel | via OpenSSL | **nativa CNG (AES-NI auto)** |
| Updates de segurança | manual (rebuild) | **Windows Update** |
| Cross-platform | ✅ | ❌ Windows-only (OK — invariante #12) |
| Esforço de build | 0h (já temos) | 2-3h (CMake + MSVC) |

**Opção fallback:** manter libssh2 1.9 + OpenSSL 1.1 (Opção 4 status quo) se rebuild WinCNG falhar. Fica documentado mas não é o default.

### Decisão de wrapper Delphi

**Wrapper recomendado: `TSSH2Client` do pult** (classe base de `uMySFTPClient.pas`, L210):

- `ExecCommand(ACmd, out AOutput): Boolean` já implementado (L2608)
- Autenticação: password / publickey / keyboard-interactive
- Fingerprint hash callback
- Reconnect e codepage

**Alternativa:** `ssl_libssh2.pas` Synapse — minimalista mas sem `ExecCommand` pronto (precisaria chamar `libssh2_channel_exec` manualmente).

---

## 3. Prerrogativas invioláveis (transcritas de CLAUDE.md V1.7.0)

Valem em **TODAS** as ondas O0-O7:

1. **Cross-compiler:** Delphi 12.x + FPC 3.3.1+
2. **UTF-8 interno** preservado em todas as camadas
3. **Nomes de classes legadas imutáveis** (`TLDAPSend`, `TLDAPConfig`, `TServiceLDAP`) — módulo novo não toca
4. **Nomes de métodos + sequência de tipos imutáveis** em `IActiveDirectoryService`
5. **`deprecated` proibido** em símbolos legados
6. **Proibido classe concorrente** (novas classes em namespace `TRemote*`)
7. **GUID `IActiveDirectoryService` preservado** — módulo Remote é API separada
8. **Engine LDAP: apenas Ararat Synapse** — SSH é transport separado, não LDAP
9. **SSOT:** edições em `.cursor/` apenas via plan mode
10. **Áreas protegidas:** `Packege/synapse/` não tocado (só consumido)
11. **Factory + fluent builder** em todas as novas classes (`TActiveDirectoryRemote.New`)
12. **Views Windows-only:** forms VCL em `src/Views/` — não portar para Linux

---

## 4. Arquitectura proposta

### 4.1 Estrutura de pastas

```text
src/
  Remote/                                              # NOVO módulo (V1.8.0)
    ActiveDirectory.Remote.Interfaces.pas              # IRemoteSshClient, IRemoteConfigurator, IRemoteDiagnostic, IRemoteBootstrap
    ActiveDirectory.Remote.Types.pas                   # TRemoteConfig, TRemoteStepResult, TLdapsConfigResult, TRemoteDiagnosticResult
    ActiveDirectory.Remote.SshClient.pas               # TRemoteSshClient (wrapper TSSH2Client)
    ActiveDirectory.Remote.WinRMClient.pas             # TRemoteWinRMClient (wrapper winrs.exe) — Fase 0
    ActiveDirectory.Remote.SshPaths.pas                # SetDllDirectory para libssh2.dll
    ActiveDirectory.Remote.Scripts.pas                 # PowerShell embedded (27 scripts: B1-B8, L1-L4, S1-S9, T1, G1-G5)
    ActiveDirectory.Remote.Bootstrap.pas               # TRemoteBootstrap (Fase 0 — B1-B8)
    ActiveDirectory.Remote.Configurator.pas            # TRemoteConfigurator (Fases 1-4 — L*/S*/T*/G*)
    ActiveDirectory.Remote.Diagnostic.pas              # TRemoteDiagnostic (read-only, idempotente)
    ActiveDirectory.Remote.Setup.pas                   # TRemoteSetup — macro .EnableAll (bootstrap + configurator)
    ActiveDirectory.Remote.pas                         # TActiveDirectoryRemote.New (factory + fluent builder)
  Views/
    ufrmRemoteSshBootstrap.pas/.dfm                    # Wizard 3 passos (Fase 0)
    ufrmRemoteSetupTeste.pas/.dfm                      # Dashboard 4 protocolos

tests/
  Diag.SshConn.dpr                                     # Piloto O1 — ~60 linhas
  RemoteSetup.SmokeTest.dpr                            # Smoke O6 — end-to-end

Documentation/
  Fundamentos/
    08-Remote-Setup.md                                 # Doc canónica do módulo
```

### 4.2 Camadas

```text
Consumidor (form ou código)
    v
TActiveDirectoryRemote.New (factory)                   [Remote.pas]
    v
IRemoteBootstrap / IRemoteConfigurator / IRemoteDiagnostic
    v
TRemoteSshClient.ExecuteCommand  (via SSH chave RSA)
  ↔ TRemoteWinRMClient.ExecuteCommand  (fallback Fase 0 via winrs.exe)
    v
TSSH2Client.ExecCommand (pult)
    v
libssh2_* (via libssh2.pas bindings)
    v
libssh2.dll (WinCNG preferred)  ← em E:/GestorERP/dll/<arch>/
```

### 4.3 API fluent (exemplo canónico)

```pascal
uses
  ActiveDirectory.Remote, ActiveDirectory.Remote.Interfaces, ActiveDirectory.Remote.Types;

var
  LCfg     : TRemoteConfig;
  LBootRes : TRemoteStepResult;
  LSetupRes: TLdapsConfigResult;
begin
  LCfg := TActiveDirectoryRemote.New
    .Host('10.100.2.3')
    .Port(22)
    .SshUser('Administrador')
    .SshKeyFile(GetEnvironmentVariable('USERPROFILE') + '\.ssh\id_rsa_ad')
    .Timeout(60000)
    .Domain('cslsolucoes.com.br')
    .CaCommonName('cslsolucoes-CA')
    .CertTemplate('DomainController')
    .StrictHostKeyCheck(False)
    .GetConfig;

  // Fase 0 (só se SSH ainda não configurado)
  if not TRemoteDiagnostic.New(LCfg).IsSshAvailable then
  begin
    LBootRes := TRemoteBootstrap.New(LCfg)
      .WinRMCredential('Administrador', ReadPasswordFromUser)
      .PublicKeyFile('E:\GestorERP\.ssh\administrators_authorized_keys')
      .AutoDeploy
      .Execute;
    if not LBootRes.Success then Exit;
  end;

  // Fases 1-4 (via SSH já funcional)
  LSetupRes := TRemoteConfigurator.New(LCfg)
    .OnBeforeStep(procedure(const AName: string) begin Log('>>> ' + AName); end)
    .OnAfterStep(procedure(const AStep: TRemoteStepResult) begin Log(AStep.ToString); end)
    .EnableAll  // macro = L1-L4 + S1-S9 + T1 + G1-G5
    .Execute;

  if LSetupRes.Success then
    Log('LDAP+LDAPS+StartTLS+GC OK. Cert=' + LSetupRes.CertThumbprint)
  else
    Log('Falha no passo: ' + LSetupRes.FailedStep + ' — ' + LSetupRes.ErrorMessage);
end;
```

### 4.4 Passos granulares (27 total)

```pascal
// ============= FASE 0 — Bootstrap SSH (one-shot via WinRM) =============
TRemoteBootstrap.New(LCfg)
  .InstallOpenSshServer      // B1 — Add-WindowsCapability OpenSSH.Server
  .StartSshdService          // B2 — Start-Service sshd + Automatic
  .DeployPublicKey           // B3 — copia chave → administrators_authorized_keys
  .FixAuthorizedKeysAcl      // B4 — icacls /inheritance:r /grant SYSTEM + Admins
  .PatchSshdConfig           // B5 — PubkeyAuthentication + Match Group admins
  .CreateFirewallRule(22)    // B6
  .RestartSshd               // B7
  .ValidateSshKeyAuth        // B8 — ssh -i key Administrador@host whoami
  .Execute;

// ============= FASE 1 — LDAP 389 (validação) =============
TRemoteConfigurator.New(LCfg)
  .ValidateAddsRole          // L1
  .CreateFirewallRule(389, 'LDAP') // L2
  .EnableLdapLogging         // L3 (opcional)
  .ValidateLdapBind(389)     // L4
  .Execute;

// ============= FASE 2 — LDAPS 636 (full setup) =============
TRemoteConfigurator.New(LCfg)
  .InstallAdcsRole                  // S1
  .PromoteEnterpriseRootCA          // S2
  .StartCertSvc                     // S3
  .EnrollDomainControllerCert       // S4
  .GrantNtdsPrivateKeyAccess        // S5
  .CreateFirewallRule(636, 'LDAPS') // S6
  .RestartNtds                      // S7
  .ValidateSslHandshake(636)        // S8
  .ExportCaRootToPem(LCfg.LocalPemFile) // S9
  .Execute;

// ============= FASE 3 — StartTLS =============
TRemoteConfigurator.New(LCfg)
  .ValidateStartTlsCapability // T1
  .Execute;

// ============= FASE 4 — Global Catalog =============
TRemoteConfigurator.New(LCfg)
  .ValidateGlobalCatalogRole      // G1
  .CreateFirewallRule(3268, 'GC') // G2
  .CreateFirewallRule(3269, 'GC-SSL') // G3
  .ValidateGlobalCatalogBind(3268)    // G4
  .ValidateGlobalCatalogHandshake(3269) // G5
  .Execute;
```

### 4.5 Macros de conveniência

```pascal
TRemoteSetup.New(LCfg)
  .WinRMCredential('Administrador', pwd)
  .PublicKeyFile('E:\GestorERP\.ssh\administrators_authorized_keys')
  .EnableAll              // = bootstrap + L* + S* + T* + G*
  .Execute;

// Variantes
.EnableLdapOnly           // bootstrap + L1-L4
.EnableLdapsOnly          // bootstrap + L1-L4 + S1-S9
.EnableWithStartTls       // bootstrap + L1-L4 + S1-S9 + T1
.ValidateOnly             // não altera, só Diagnostic.RunAll em 4 protocolos
```

---

## 5. Scripts PowerShell embedded

27 scripts em `Remote.Scripts.pas` como `const string`. Marcadores textuais (`ADCS_INSTALLED=`, `ENROLL_OK`) para parse via regex → `TRemoteStepResult`.

Exemplo canónico:

```pascal
const
  SCRIPT_INSTALL_ADCS =
    '$f = Get-WindowsFeature AD-Certificate;' + sLineBreak +
    'if ($f.InstallState -ne "Installed") {' + sLineBreak +
    '    Install-WindowsFeature AD-Certificate, RSAT-ADCS-Mgmt -IncludeManagementTools | Out-Null' + sLineBreak +
    '}' + sLineBreak +
    'Write-Host "ADCS_INSTALLED=$((Get-WindowsFeature AD-Certificate).InstallState)"';

  SCRIPT_ENROLL_DC_CERT =
    'Start-Service CertSvc -ErrorAction SilentlyContinue;' + sLineBreak +
    'Start-Sleep -Seconds 5;' + sLineBreak +
    '$r = certreq -enroll -machine -q "DomainController" 2>&1;' + sLineBreak +
    'if ($r -match "O certificado solicitado foi emitido") {' + sLineBreak +
    '    Write-Host "ENROLL_OK"' + sLineBreak +
    '} else {' + sLineBreak +
    '    Write-Host "ENROLL_FAIL: $r"; exit 1' + sLineBreak +
    '}';
```

---

## 6. Forms VCL (UX)

### 6.1 Wizard `ufrmRemoteSshBootstrap` (3 passos)

1. **Identificar servidor** — Host/IP, Domínio, Porta WinRM (5985/5986), auto-detect WinRM
2. **Credencial administrativa** — user/password (one-shot) + chave pública (default: `E:\GestorERP\.ssh\administrators_authorized_keys`)
3. **Executar bootstrap** — log ao vivo dos 8 passos B1-B8 + opção "Habilitar LDAPS >" a seguir

### 6.2 Dashboard `ufrmRemoteSetupTeste`

Mostra matriz dos 5 protocolos com check/cross/warn:

- Bootstrap SSH (OpenSSH / sshd / chave aceite)
- AD DS + AD CS (roles, NTDS, CertSvc, cert thumbprint + issuer)
- LDAP 389 (porta listen, firewall, bind anon)
- LDAPS 636 (porta listen, firewall, SSL handshake Tls12 AES-256)
- StartTLS (upgrade 389→TLS)
- Global Catalog (3268/3269, bind, handshake)

Botões: `[Re-diagnosticar]` `[Habilitar LDAP]` `[Habilitar LDAPS]` `[Habilitar StartTLS]` `[Habilitar GC]` `[Habilitar TUDO]` `[Re-emitir cert DC]` `[Exportar CA → PEM]`

Log ao vivo + score 0-100%.

---

## 7. Ficheiros a criar / editar (22 total)

### 7.1 Novos ficheiros (13)

| # | Path | Conteúdo |
|---|---|---|
| 1 | `src/Remote/ActiveDirectory.Remote.Interfaces.pas` | Contratos |
| 2 | `src/Remote/ActiveDirectory.Remote.Types.pas` | Tipos + resultados |
| 3 | `src/Remote/ActiveDirectory.Remote.SshClient.pas` | Wrapper TSSH2Client |
| 4 | `src/Remote/ActiveDirectory.Remote.WinRMClient.pas` | Wrapper winrs.exe (Fase 0) |
| 5 | `src/Remote/ActiveDirectory.Remote.SshPaths.pas` | SetDllDirectory libssh2.dll |
| 6 | `src/Remote/ActiveDirectory.Remote.Scripts.pas` | 27 scripts PowerShell |
| 7 | `src/Remote/ActiveDirectory.Remote.Bootstrap.pas` | TRemoteBootstrap (B1-B8) |
| 8 | `src/Remote/ActiveDirectory.Remote.Configurator.pas` | TRemoteConfigurator (L*/S*/T*/G*) |
| 9 | `src/Remote/ActiveDirectory.Remote.Diagnostic.pas` | TRemoteDiagnostic |
| 10 | `src/Remote/ActiveDirectory.Remote.Setup.pas` | TRemoteSetup (macros) |
| 11 | `src/Remote/ActiveDirectory.Remote.pas` | Factory `TActiveDirectoryRemote.New` |
| 12 | `src/Views/ufrmRemoteSshBootstrap.pas/.dfm` | Wizard 3 passos |
| 13 | `src/Views/ufrmRemoteSetupTeste.pas/.dfm` | Dashboard protocolos |
| 14 | `tests/Diag.SshConn.dpr` | Piloto O1 |
| 15 | `tests/RemoteSetup.SmokeTest.dpr` | Smoke O6 |
| 16 | `Documentation/Fundamentos/08-Remote-Setup.md` | Doc canónica |

### 7.2 Edits (6)

| # | Path | Alteração |
|---|---|---|
| 17 | `ActiveDirectoryORM.dpr` / `.lpr` | uses + CreateForm |
| 18 | `dcc32.cfg` / `dcc64.cfg` | `-Usrc\Remote` + `-Uprojects\package\libssh2_delphi` + defines |
| 19 | `fpc32.opts` / `fpc64.opts` | `-Fisrc\Remote` + `-Fiprojects\package\libssh2_delphi` |
| 20 | `ORM.Defines.inc` | `{$DEFINE USE_REMOTE_SETUP}` + `{$DEFINE USE_SSL_LIBSSH2}` |
| 21 | `src/Commons/ActiveDirectory.Version.pas` | MINOR 7→8, `ADORM_VERSION_STRING='1.8.0'` |
| 22 | `ORM.Version.inc` | `{$DEFINE ADORM_V1_8_OR_HIGHER}` |
| 23 | `CHANGELOG.md` + `Documentation/Versionamento/CHANGELOG.md` | Entrada V1.8.0 |
| 24 | `Tutorial-LDAPS-AD-Conexao-Externa.md` | §"Automação via ActiveDirectoryORM" |
| 25 | `CLAUDE.md` | Secção "V1.8.0 — Remote Setup" |

### 7.3 DLLs — zero cópia (reusar `E:/GestorERP/dll/<arch>/`)

```text
E:\GestorERP\dll\win32\libssh2.dll              (259 KB)   [já presente]
E:\GestorERP\dll\win32\libssl-1_1.dll           (já presente)
E:\GestorERP\dll\win32\libcrypto-1_1.dll        (já presente)
E:\GestorERP\dll\win64\libssh2-x64.dll          (298 KB)   [já presente]
E:\GestorERP\dll\win64\libssl-1_1-x64.dll       (já presente)
E:\GestorERP\dll\win64\libcrypto-1_1-x64.dll    (já presente)
```

**Opcional V1.8.0+** (O0): rebuild WinCNG substitui 3 DLLs por 1 só (~500 KB).

---

## 8. Execução em 8 ondas (19-26h)

| Onda | Escopo | Duração | Gate |
|---|---|---|---|
| **O0** (opcional) | Rebuild libssh2 + WinCNG via CMake | 2-3h | DLL única em `E:/GestorERP/dll/<arch>/` (~500 KB) substitui libssh2 1.9 + OpenSSL 1.1 |
| **O1** | `tests/Diag.SshConn.dpr` (~60 L) — valida stack `TSSH2Client + libssh2.dll` contra `10.100.2.3:22` | 1-2h | `SSH_OK\ncslsolucoes\administrador` |
| **O2** | Interfaces + Types + `TRemoteSshClient` + `TRemoteWinRMClient` + `SshPaths` | 4-5h | `.Execute('whoami')` devolve `TRemoteStepResult(Success=True)` |
| **O3** | 27 scripts embedded + `TRemoteDiagnostic.RunAll` (4 protocolos) | 3-4h | `RunAll` preenche 20+ campos |
| **O4** | `TRemoteBootstrap` (B1-B8) + callbacks + TOFU fingerprint | 3-4h | Servidor novo habilita SSH+RSA em <30s |
| **O5** | `TRemoteConfigurator` (L1-L4 + S1-S9 + T1 + G1-G5) + macros + idempotência | 4-5h | `.EnableAll` num DC limpo → 5 protocolos activos em <5min |
| **O6** | Forms VCL `ufrmRemoteSshBootstrap` (wizard) + `ufrmRemoteSetupTeste` (dashboard) + `RemoteSetup.SmokeTest.dpr` | 3-4h | Wizard completa bootstrap; dashboard mostra matriz; smoke → `SETUP_OK` |
| **O7** | Docs + SemVer bump V1.8.0 | 1-2h | CHANGELOG + 08-Remote-Setup.md + CLAUDE.md |

### Dependências entre ondas

```text
     ┌─ O2 (wrappers SSH+WinRM) ──┐
O1 ──►                            ├── O4 (Bootstrap) ──┐
     └─ O3 (scripts + diag) ──────┘                    ├── O6 (forms + smoke) ── O7 (docs)
                                                       │
                                  ── O5 (Configurator) ─┘

O0 (opcional WinCNG) pode ser paralelo a O1 — se atrasar, mantém-se libssh2 1.9 + OpenSSL 1.1 actuais.
```

**Gate-bloqueador:** O1 — se o stack `TSSH2Client` não ligar ao `10.100.2.3:22`, rollback para fallback com `ssh.exe` externo.

---

## 9. Segurança e boas práticas

- **Zero credenciais em código** — password admin só em memória durante wizard Bootstrap
- **Chave RSA canónica** em `E:/GestorERP/.ssh/administrators_authorized_keys` (SSOT — actualizar = rotar chave em todos servidores via re-run bootstrap)
- **`StrictHostKeyCheck` default=True** em produção
- **TOFU** (trust-on-first-use) — fingerprint SHA256 capturado no B8 e validado em chamadas subsequentes
- **Timeout configurável** (default 60s; `EnableLdaps` pode demorar 30-60s por causa de restart NTDS)
- **Idempotência:** cada passo verifica estado antes de actuar (ex.: `InstallAdcsRole` pula se já instalado)
- **Logs estruturados:** `TRemoteStepResult(Name, Success, StdOut, StdErr, ElapsedMs)` — callback `OnAfterStep` permite UI log + file log
- **Audit trail opcional:** JSON com passos + timestamps para compliance

---

## 10. Verificação end-to-end (gate V1.8.0)

### Compilação

- [ ] `dcc32 ActiveDirectoryORM.dpr` compila verde com `USE_REMOTE_SETUP` + `USE_SSL_LIBSSH2`
- [ ] `dcc64` idem
- [ ] `fpc @fpc32.opts ActiveDirectoryORM.lpr` compila verde
- [ ] `tests/Diag.SshConn.dpr` compila e corre (gate O1)

### Bootstrap SSH (Fase 0) — servidor novo

- [ ] Wizard completa B1-B8 em <30s
- [ ] `ssh -i id_rsa_ad Administrador@<novo>` retorna `cslsolucoes\administrador`
- [ ] Re-execução idempotente (skip em <500ms)

### Setup LDAP+LDAPS (Fases 1-4) — DC já com SSH

- [ ] `tests/RemoteSetup.SmokeTest.exe` contra `10.100.2.3` devolve:

```text
[DIAG] Bootstrap: ✓ | ADDS: ✓ | ADCS: ✓ | Cert: ✓
[DIAG] LDAP 389: ✓ | LDAPS 636: ✓ | StartTLS: ✓ | GC 3268: ✓ | GC-SSL 3269: ✓
[DIAG] Score: 100%
[SKIP] EnableAll — todos os protocolos ja habilitados
[VALIDATE] LDAP bind plain       → OK (1 result)
[VALIDATE] LDAPS bind tmNoCert   → OK (1 result, Tls12 AES-256)
[VALIDATE] StartTLS bind         → OK (1 result, upgrade 389→Tls12)
[VALIDATE] GC 3268 bind plain    → OK
[VALIDATE] GC-SSL 3269 handshake → OK
SETUP_OK
```

### Setup num DC limpo (teste de stress)

- [ ] Partindo de Windows Server sem AD CS, `.EnableAll.Execute` conclui em <5min
- [ ] Após 5min, 5 protocolos mostram ✓ no dashboard
- [ ] Cliente Delphi consegue bind via `tmLDAPSNoCertCheck` e `tmLDAPSWithCA`

### UX / Forms

- [ ] Dashboard mostra diagnóstico em 3-5s
- [ ] Botão "Habilitar TUDO" executa sem erros visíveis
- [ ] Log grava em `%TEMP%\ActiveDirectoryORM_setup_<host>_<date>.log`

### Zero regressão

- [ ] `V1_6_0.Smoke.exe` → `SMOKE_OK`
- [ ] `ActiveDirectoryORM.exe` form principal abre sem warnings novos
- [ ] GUID `IActiveDirectoryService` preservado (binário-compat v1.6+/v1.7+/v1.8)

---

## 11. Alternativas consideradas

| Alternativa | Rejeitada porque |
|---|---|
| PowerShell via WinRM directo (sem SSH) | Requer WinRM habilitado em todos DCs; SSH já funciona; WinRM só usado em Fase 0 one-shot |
| WMI via ADSI | Não executa `Install-WindowsFeature`; scope limitado |
| `.ps1` solto + `ssh <cmd>` | Sem logs estruturados; sem API typed |
| Synapse SSH2 do zero | 10000+ linhas; 3-6 meses; inútil — já temos `ssl_libssh2.pas` + `TSSH2Client` |
| SecureBridge (DevArt) | Comercial ~$300+; zero benefício vs. libssh2 gratuito |
| Chilkat SSH | Comercial ~$250 |
| ICS SSH | ICS não tem SSH (só SSL/TLS) |
| Indy SSH | Só esqueleto abstract; zero implementação real |

---

## 12. Questões em aberto (responder antes de arrancar O1)

1. **Crypto-backend:** rebuild libssh2+WinCNG (O0) ou manter libssh2 1.9+OpenSSL 1.1 actual?
2. **Wrapper Delphi:** `TSSH2Client` (pult, 3800 L) ou extrair só ~500 L para `Remote.SshClient.Lowlevel.pas`?
3. **Multi-DC:** um DC por execução (V1.8.0) ou lista simultânea (V1.9.0)?
4. **Rollback/revoke:** `.DisableLdaps` em V1.8.0 ou V1.8.1?
5. **Credential store:** prompt interactivo sempre ou integrar Windows Credential Manager para segundo uso?

---

## 13. Rollback

Se qualquer onda falhar:

- **O0/O1 falha** → manter libssh2 1.9 + OpenSSL 1.1 (DLLs actuais); ou fallback `ssh.exe` externo
- **O2-O5 falha** → módulo `src/Remote/` isolado; rollback = remover pasta + reverter cfg/opts
- **O6 falha** → forms opcionais (defines `USE_REMOTE_SETUP` em `ORM.Defines.inc`); desligar = voltar ao V1.7.0 bit-a-bit
- **O7 falha** → só docs; zero impacto em runtime

Nenhuma onda toca `src/Main/ActiveDirectory.Main.*` nem `Packege/synapse/` — rollback determinístico.

---

## 14. Referências

- [Tutorial-LDAPS-AD-Conexao-Externa.md](../../Tutorial-LDAPS-AD-Conexao-Externa.md) — fluxo manual base
- [Plano-Automacao-LDAPS-Setup.md](../../Plano-Automacao-LDAPS-Setup.md) — plano espelho (leitura livre, com mockups completos de forms)
- [OpenSSH for Windows — Microsoft Docs](https://learn.microsoft.com/windows-server/administration/openssh/openssh_overview)
- `certreq` reference — https://learn.microsoft.com/windows-server/administration/windows-commands/certreq_1
- libssh2 source — `projects/package/libssh2/` (versão 1.11.2_DEV, 5 backends)
- libssh2 bindings Pascal — `projects/package/libssh2_delphi/` (pult, v2026.0312)
- Padrão fluent no ActiveDirectoryORM — `src/Main/ActiveDirectory.Main.pas`
- [Synapse SSH plugin howto](http://synapse.ararat.cz/doku.php/public:howto:sslplugin)

---

## Histórico

- **1.0.0 (2026-04-23):** Plano criado em formato Cursor a partir de `Plano-Automacao-LDAPS-Setup.md` (v4 SETUP completo). Escopo: Fase 0 Bootstrap + Fases 1-4 (LDAP + LDAPS + StartTLS + GC). Stack 100% local (libssh2 1.11.2 source + bindings pult + DLLs runtime). Onda O0 opcional (rebuild WinCNG) adicionada. Aguarda respostas às 5 questões em §12 + aprovação antes de arrancar O1.
