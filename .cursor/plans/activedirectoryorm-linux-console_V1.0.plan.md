---
name: activedirectoryorm-linux-console
version: 1.0.0
date: 2026-04-21
author: CSL Softwares
status: draft
scope: ActiveDirectoryORM V1.6.0 — adicionar suporte Linux console (FPC x86_64-linux) sem remover suporte Windows
depends-on: V1.5.0 (ssl_openssl_paths.pas + SetDllDirectory Windows)
target-compilers:
  - FPC 3.2.2+ (x86_64-linux)
  - FPC 3.2.2+ (i386-win32 / x86_64-win64) — mantido
  - Delphi 12.x (Win32/Win64) — mantido
out-of-scope:
  - Delphi LINUX64 (requer RAD Studio Enterprise)
  - Kerberos / GSSAPI / SSPI
  - LCL / GTK2 / GTK3 / Qt (Views continuam Windows-only)
  - macOS, FreeBSD, ARM64
---

# ActiveDirectoryORM V1.6.0 — Linux Console Support (DRAFT)

> **Status:** draft — aguarda aprovação. Plano não-executável.
> Destino final: `.cursor/plans/activedirectoryorm-linux-console_V1.0.plan.md`.

---

## 1. Context

A release **V1.5.0** consolidou o carregamento determinístico de OpenSSL em Windows via
`src/Common/ssl_openssl_paths.pas` (usando `SetDllDirectory` + `LoadLibrary` explícito).
O núcleo do ORM (`src/Main/*.pas` + `src/Commons/*.pas`) é **portátil** — não depende
de `Vcl.*`, `Winapi.*` nem de primitivas POSIX específicas. As únicas camadas Windows-only
são as views VCL (`src/Views/ufrmActiveDirectoryTeste.pas`, `ufrmLDAP_Teste.pas`).

O Synapse (transporte LDAP) já suporta POSIX nativamente via os includes `sslinux.inc`,
`ssposix.inc` e `ssfpc.inc`. O OpenSSL em Linux vem do package manager do distro:
`libssl.so.3` + `libcrypto.so.3` (`apt install libssl3` / `dnf install openssl-libs`).

V1.6.0 **adiciona** um alvo console Linux — não substitui o alvo Windows.

## 2. Decisões arquitecturais

1. **Console only.** Linux não terá GUI. Sem LCL, sem GTK, sem Qt. A única UI portada é
   o teste de smoke via `WriteLn`/`ReadLn`.
2. **FPC apenas.** Delphi LINUX64 exige RAD Studio Enterprise — fora de escopo nesta release.
3. **Sem Kerberos / GSSAPI.** Bind autenticado usa apenas `SIMPLE` sobre LDAP/LDAPS.
   Integração com `libgssapi_krb5.so.2` é considerada V2.x.
4. **Zero duplicação de núcleo.** `src/Main/` e `src/Commons/` compilam **os mesmos units**
   em ambos os SO. Divergências ficam isoladas por `{$IFDEF MSWINDOWS}`.
5. **Views excluídas.** `src/Views/` não entra no build Linux (paths `-Fu`/`-Fi` não incluem).
6. **OpenSSL carregado pelo loader do SO.** Em Linux confiamos em `ld.so` —
   `SetDllDirectory` é Windows-only e fica atrás de `{$IFDEF MSWINDOWS}`.

## 3. Estrutura de ficheiros alvo

```
projects/modules/ActiveDirectoryORM/
├── ActiveDirectoryORM.dpr              (mantido — Delphi VCL Windows)
├── ActiveDirectoryORM.lpr              (mantido — Lazarus LCL Windows)
├── ActiveDirectoryORM.Linux.lpr        (NOVO — console POSIX)
├── ActiveDirectoryORM.Linux.lpi        (NOVO — project file Lazarus)
├── fpc-linux-x64.opts                  (NOVO — opções FPC Linux)
├── fpc32.opts                          (mantido — FPC Win32)
├── fpc64.opts                          (mantido — FPC Win64)
├── dcc32.cfg / dcc64.cfg               (mantidos — Delphi)
├── src/
│   ├── Core/                           (compilado em ambos os SO)
│   ├── Commons/
│   │   └── ssl_openssl_paths.pas       (MODIFICADO — {$IFDEF MSWINDOWS})
│   └── Views/                          (Windows-only, NÃO entra no Linux)
└── CLAUDE.md                           (MODIFICADO — nova secção "Linux build")
```

## 4. Fases

### F1 — Isolamento da API Windows-only

- Adicionar `{$IFDEF MSWINDOWS}` em `src/Commons/ssl_openssl_paths.pas`
  em volta de:
  - `uses Windows` (ou equivalente que traga `SetDllDirectory`).
  - Chamada a `SetDllDirectory`.
  - Chamada a `LoadLibrary` explícita.
- Em Linux, a função exportada torna-se no-op: confia em `ld.so` + `LD_LIBRARY_PATH`.
- Sem breaking change na assinatura pública.

### F2 — Entry-point Linux console

- Criar `ActiveDirectoryORM.Linux.lpr`:
  - `program ActiveDirectoryORM_Linux;`
  - `{$mode objfpc}{$H+}` — sem `uses Interfaces`, sem `uses Forms`.
  - `uses SysUtils, ActiveDirectoryORM.Core.Connection, ActiveDirectoryORM.Core.Authenticator;`
  - Lê env vars: `AD_HOST`, `AD_PORT` (default 389), `AD_USE_SSL`, `AD_USER`, `AD_PWD`, `AD_BASE_DN`.
  - Instancia `TActiveDirectoryConnection.New.Host(...).Port(...).UseSSL(...).Build`.
  - Chama `.Authenticate(User, Pwd)` e imprime resultado em stdout.
  - Exit code: `0` sucesso, `1` falha, `2` erro de configuração.

### F3 — Project file + opções FPC

- Criar `ActiveDirectoryORM.Linux.lpi` (schema Lazarus mínimo, sem LCL).
- Criar `fpc-linux-x64.opts`:
  - `-Tlinux -Px86_64`
  - `-FU.output/linux-x64/lib`
  - `-FE.output/linux-x64/bin`
  - `-Fusrc/Main;src/Commons;src/Common`
  - `-Fisrc/Main;src/Commons`
  - `-Fl/usr/lib/x86_64-linux-gnu` (path para `libssl.so.3` / `libcrypto.so.3`)
  - `-O2 -gl -Sh`
  - `-dFPC_LINUX`

### F4 — Documentação

- Nova secção em `CLAUDE.md` → "Linux build (V1.6.0)":
  - Pré-requisitos: `apt install fpc libssl3` (Debian/Ubuntu) ou `dnf install fpc openssl-libs` (Fedora/RHEL).
  - Comando canónico:
    `fpc @fpc-linux-x64.opts ActiveDirectoryORM.Linux.lpr`
  - Variáveis de ambiente obrigatórias para smoke test.
  - Nota explícita: `src/Views/` **não** entra no build Linux.
  - Nota explícita: Kerberos/SSPI/GSSAPI fora de escopo nesta release.

### F5 — Empirical validation (em VM Linux)

- Provisionar VM (Ubuntu 22.04 LTS ou Fedora 40) com `fpc` + `libssl3`.
- Compilar G1 → verde.
- Configurar AD_HOST para um Domain Controller acessível (VPN ou lab).
- Executar binário com LDAP 389 → G2.
- Executar binário com LDAPS 636 → G3.
- Executar `Authenticate` com credenciais válidas → G4.
- Rodar `fpc -vwn` sobre `src/Main/*` e `src/Commons/*` → G5 (sem warnings novos).

## 5. Gates

| Gate | Descrição | Evidência |
| ---- | --------- | --------- |
| G1   | `fpc @fpc-linux-x64.opts ActiveDirectoryORM.Linux.lpr` compila verde | exit code 0 + binário em `.output/linux-x64/bin/` |
| G2   | Runtime: programa abre socket TCP para `AD_HOST:389` | `tcpdump` ou log interno mostra SYN/SYN-ACK |
| G3   | LDAPS (porta 636) — handshake TLS com cert valida | log interno mostra "TLS handshake OK" |
| G4   | `Authenticate(User, Pwd)` retorna `True` com credenciais válidas | stdout imprime `AUTH_OK` e exit code 0 |
| G5   | `src/Main/*` e `src/Commons/*` compilam sem warnings novos em FPC Linux | diff de warnings vs. baseline Windows = 0 novos |

## 6. Deliverables

1. `ActiveDirectoryORM.Linux.lpr` — entry-point console POSIX.
2. `ActiveDirectoryORM.Linux.lpi` — project file Lazarus console.
3. `fpc-linux-x64.opts` — options FPC x86_64-linux.
4. `src/Commons/ssl_openssl_paths.pas` — com `{$IFDEF MSWINDOWS}` a proteger APIs Windows.
5. `CLAUDE.md` — nova secção "Linux build (V1.6.0)".
6. CHANGELOG entry para V1.6.0.

## 7. Riscos

| Risco | Probabilidade | Mitigação |
| ----- | ------------- | --------- |
| Certificados auto-assinados do AD rejeitados pelo OpenSSL Linux (CA root não instalada) | Alta | Documentar `update-ca-certificates` + fallback temporário `ValidateCert=false` para smoke test |
| Diferenças UTF-8 Linux vs Windows em atributos AD (displayName com acentos) | Média | Forçar `{$H+}` e testar `SetMultiByteConversionCodePage(CP_UTF8)` no entry-point |
| Necessidade de VM para teste empírico (AD requer rede de laboratório) | Alta | Assumir teste diferido — plano só garante compilação + handshake TCP; `Authenticate` validado em follow-up |
| Versões divergentes de OpenSSL entre distros (1.1 vs 3.x) | Média | Targetar apenas `libssl.so.3`; documentar requisito mínimo Ubuntu 22.04 / Fedora 38+ |
| Synapse incluir cabeçalhos Windows mesmo sob FPC Linux | Baixa | Verificar `ssl_openssl.pas` do Synapse usa `{$IFDEF UNIX}` correctamente |
| Paths absolutos `/usr/lib/x86_64-linux-gnu` quebrarem em distros Arch/NixOS | Baixa | Documentar override via env var `FPC_LIBS_PATH` |

## 8. Tempo estimado

- **Autoria** (F1–F4): 2–3 horas de engenharia.
- **Teste empírico** (F5): 1–2 horas em VM (provisionamento + execução dos 5 gates).
- **Total:** 3–5 horas.

## 9. Fora de escopo (explícito)

- Delphi LINUX64 (requer RAD Studio Enterprise — sem licença disponível).
- Kerberos / GSSAPI / SSPI (API totalmente diferente de bind simples; V2.x).
- Views GTK/Qt/LCL-Linux (mantidas Windows-only por decisão arquitectural).
- macOS (Cocoa + Secure Transport — V2.x).
- FreeBSD / OpenBSD / ARM64 (Raspberry Pi).
- Docker image oficial (follow-up separado).
- CI runner Linux (follow-up separado — depende de VM/container na infra).

## 10. Rationale

Linux console é o **menor incremento útil** para viabilizar M01-Segurança em servidores
Linux (docker, Kubernetes, bare-metal Ubuntu Server). Evita o overhead de portar Views
VCL para LCL/Qt (que seria 10× mais trabalho e sem valor imediato — backend GestorERP
não precisa de GUI no servidor). Alinha-se com a estratégia de Horse (já portátil para
FPC Linux) e ProvidersORM (Zeos compila Linux sem mudanças).

## 11. Changelog interno (deste plano)

- **1.0.0** (2026-04-21) — Draft inicial. Autoria CSL Softwares. Aguarda aprovação.

---

**Próximo passo:** aprovação explícita → copiar para
`.cursor/plans/activedirectoryorm-linux-console_V1.0.plan.md` (draft não-executável) →
abrir tarefa de implementação F1 após sign-off.
