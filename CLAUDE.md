# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## O que e esta pasta

**Vendor package — Ararat Synapse (CSL fork).** Esta pasta NAO e um projecto autonomo: e a biblioteca Synapse patched, consumida como vendor pelo modulo pai `ActiveDirectoryORM` (`projects/modules/ActiveDirectoryORM/`) via `-U"Packege\synapse"` (Delphi) / `-FuPackege/synapse` (FPC).

- **Package version:** 41.3 (2026-04-22) — ver [VERSION.md](VERSION.md)
- **Upstream base:** Ararat Synapse 41.0 (Lukas Gebauer, 1999-2023)
- **Fork CSL:** CSL Softwares — OpenSSL 4.0, DLL path helper, tri-plataforma POSIX, tipagem automatica de atributos LDAP, `AddRaw` preservando 100% bytes binarios
- **Licenca:** BSD 3-Clause (compativel com upstream)

**NAO tem `.dpr`/`.lpr` proprios.** Bootstrap interactivo (FASE 3 do template parent) nao se aplica aqui — este e vendor, nao projecto. O CLAUDE.md do modulo pai em [../../CLAUDE.md](../../CLAUDE.md) tem precedencia para assuntos transversais do ActiveDirectoryORM.

---

## Ambiente e idioma

- **SO:** Windows (Win32/Win64). Terminal: PowerShell.
- **Separador:** `\` (backslash).
- **Idioma:** pensar e responder em portugues (pt-PT por defeito; pt-BR se o utilizador usar). Identificadores e comentarios tecnicos em ingles (convencao upstream Synapse).

---

## Estrutura

```text
Packege/synapse/
  ldapsend.pas            # Core LDAP — CSL patched (001.007.005)
  blcksock.pas            # Core socket — CSL patched (009.011.001, inclui GetPeerCertSHA256Hash para CBT)
  synautil.pas            # Utils — CSL patched (FileTime AD helpers)
  synacode.pas, synaip.pas, synafpc.pas  # CSL patched (menores)
  ssl_openssl.pas         # SSL legacy (libeay32/ssleay32) — CSL patched
  ssl_openssl3.pas/_lib   # OpenSSL 3.x (upstream)
  ssl_openssl4.pas/_lib   # OpenSSL 4.0 — 100% novo CSL (fork mecanico de ssl_openssl3)
  ssl_openssl_paths.pas   # 100% novo CSL — TOpenSSLPaths.Apply(N) / SetDllDirectory
  ssl_openssl11*.pas      # OpenSSL 1.1 (upstream)
  ssl_*.pas               # Outros plugins SSL (cryptlib, libssh2, sbb, streamsec, capi)
  http/smtp/pop3/imap/ftp/...send.pas  # Protocolos de aplicacao (upstream)
  mimemess/mimepart/mimeinln.pas  # MIME
  asn1util.pas, synachar, synacrypt, synadbg, synaicnv, synamisc, tzutil  # Utils (upstream)
  jedi.inc                # Compiler defines (CSL — reescrita, ~4350 linhas)
  sswin32.inc / ssfpc.inc / ssposix.inc / sslinux.inc / kylix.inc / ssos2ws1.inc / ssdotnet.inc
  Synapse.Version.inc     # Tags {$DEFINE} de versao (SYNAPSE_V41_*, SYNAPSE_CSL_*)
  laz_synapse.lpk         # Package Lazarus runtime (42 units)
  synapse.dpk             # Package Delphi 12/13 runtime (simetrico ao .lpk)
  bak/                    # Backups dos ficheiros originais antes das modificacoes CSL
  Documentation/          # Hub de analise CSL (LDAPSend, TCPBlockSocket, SSLOpenSSL, FLOWCHART)
  .cursor/ .claude/ .vscode/ .continue/ .opencode/   # Pack SSOT + espelhos (ver SSOT abaixo)
  .workspace/             # Instancia concreta deste clone
```

---

## Compilacao

### Via package

```powershell
# Delphi 12/13 (gera synapse.bpl em $(BDSCOMMONDIR)\Bpl)
dcc32 -M -B Packege\synapse\synapse.dpk

# Lazarus: abrir laz_synapse.lpk e usar "Use -> Install"
```

### Via source units (modo consumido pelo ActiveDirectoryORM)

No `dcc32.cfg`/`dcc64.cfg` do projecto consumidor:

```text
-U"Packege\synapse"
```

No `fpc32.opts`/`fpc64.opts`:

```text
-FuPackege/synapse
```

### Selector OpenSSL (no projecto consumidor, em `ORM.Defines.inc`)

| Define         | Unit usada               | DLLs esperadas                                                          |
| -------------- | ------------------------ | ----------------------------------------------------------------------- |
| _(nenhum)_     | `ssl_openssl.pas` legacy | `libeay32.dll` / `ssleay32.dll` (PATH/System32)                         |
| `USE_OPENSSL3` | `ssl_openssl3.pas`       | `libcrypto-3*.dll` + `libssl-3*.dll` (via `TOpenSSLPaths.Apply(3)`)     |
| `USE_OPENSSL4` | `ssl_openssl4.pas` (CSL) | `libcrypto-4*.dll` + `libssl-4*.dll` (via `TOpenSSLPaths.Apply(4)`)     |

Definir `USE_OPENSSL3` e `USE_OPENSSL4` em simultaneo dispara `{$MESSAGE FATAL}` em compile time.

---

## Areas protegidas (plan mode obrigatorio)

Antes de criar, mover, renomear, fundir ou eliminar ficheiros nas areas abaixo, SEMPRE apresentar plano e aguardar aprovacao explicita — mesmo que o utilizador diga "execute" ou "faca":

| Area            | Caminho                                                                                                                            |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Vendor upstream | **toda esta pasta `Packege/synapse/` e area protegida** (fork CSL — qualquer modificacao requer backup em `bak/` + bump de versao) |
| Documentacao    | `Documentation/` (recursivo)                                                                                                       |
| Skills          | `.cursor/skills/` (recursivo)                                                                                                      |
| Templates       | `.cursor/Templates/` (recursivo)                                                                                                   |
| Agents          | `.cursor/agents/` (recursivo)                                                                                                      |
| Rules           | `.cursor/rules/` (recursivo)                                                                                                       |

**Politica de patch do vendor:**

1. Antes de modificar qualquer `.pas` existente, criar backup em `bak/<nome>.<timestamp>.bak`.
2. Bumpar o cabecalho da unit (`| Project : Ararat Synapse (CSL fork) | AAA.BBB.CCC |`) — `CCC` para patch mecanico, `BBB` para funcionalidade nova.
3. Bumpar package version em [VERSION.md](VERSION.md), `laz_synapse.lpk` e `synapse.dpk` (simetrico).
4. Acrescentar tag em `Synapse.Version.inc` (ex.: `SYNAPSE_V41_4_OR_HIGHER`) + tag de feature se aplicavel.
5. Registar mudancas em [VERSION.md](VERSION.md) §Changelog consolidado.

Excepcoes (dispensam plan mode): correccoes de typos isolados quando o utilizador fornece o texto exacto; conteudo adicionado quando o utilizador fornece o texto exacto.

---

## SSOT — Fonte canonica dos espelhos

`.cursor/` e a unica fonte canonica. Nunca editar directamente `.claude/`, `.vscode/`, `.continue/`, `.opencode/` — sao espelhos via symlinks gerados por `.cursor/scripts/bootstrap-mirror-symlinks.ps1`. Instancia concreta deste clone em `.workspace/`.

Validar espelhos no inicio de sessao:

```powershell
powershell -ExecutionPolicy Bypass -File ".cursor/scripts/bootstrap-mirror-symlinks.ps1" -ValidateOnly
```

Se falhar por falta de privilegios de Administrador: informar e parar.

---

## Prerrogativas perenes (vendor CSL)

Directrizes mandatorias e nao-negociaveis para esta pasta:

1. **Manter compatibilidade binaria e de API com upstream Ararat Synapse.** Qualquer nova classe, metodo ou property e extensao aditiva. Nunca remover simbolos existentes nem quebrar assinaturas.
2. **Cross-compiler obrigatorio:** Delphi (12.x+) e FPC (3.3.1+). Novas units precisam de `{$IFDEF FPC}...{$ELSE}...{$ENDIF}` quando tocam RTL (`System.*` vs unqualified).
3. **Windows-only code guardado:** qualquer uso de `Winapi.Windows`, `secur32.dll`, SSPI, Winsock directo em `IFDEF MSWINDOWS`. POSIX recebe stubs com mensagem explicita (padrao V1.7.0 em `ldapsend.pas`).
4. **Backups em `bak/` antes de patch:** `bak/<nome>.<YYYYMMDD_HHMM>.bak` preserva o baseline antes de cada modificacao CSL.
5. **Bump triplo sincronizado:** unit header (`.pas`) + `Synapse.Version.inc` (tags) + [VERSION.md](VERSION.md) + packages (`laz_synapse.lpk` + `synapse.dpk`).
6. **Pacotes simetricos:** `laz_synapse.lpk` (Lazarus) e `synapse.dpk` (Delphi) devem listar exactamente o mesmo conjunto de units.
7. **SSOT:** edicoes so em `.cursor/`; `.claude/`, `.vscode/`, `.continue/`, `.opencode/` sao espelhos.
8. **Naming:** proibido escapes `#NNN`/`#$NNNN` em strings literais Pascal (usar literais UTF-8). Excepcoes: `#0`, `#9`, `#10`, `#13` e outros caracteres de controlo. Rule: `.cursor/rules/pascal-encoding-no-escapes_V1.0.0.mdc`.

---

## Fork CSL — o que diverge do upstream

Duas camadas de modificacoes (detalhes em [VERSION.md](VERSION.md) e [README.md](README.md)):

1. **Fork historico (2026-04-13):** 8 ficheiros modificados com backup em `bak/` — `ldapsend.pas` (GSSAPI+CBT + 8 controles AD + LDAP Signing), `blcksock.pas` (`GetPeerCertSHA256Hash` para CBT RFC 5929), `synautil.pas` (FileTime AD helpers), `jedi.inc` (reescrita completa), `synafpc.pas`, `ssl_openssl.pas`, `synacode.pas`, `synaip.pas`.
2. **Fork sessao V1.5.0 -> V1.7.2 (2026-04-21/22):** 3 units 100% novas (`ssl_openssl4.pas`, `ssl_openssl4_lib.pas`, `ssl_openssl_paths.pas`); `ldapsend.pas` bumped 001.007.002 -> 001.007.005 (tri-plataforma POSIX V1.7.0 -> tipagem automatica V41.2 -> `AddRaw` V41.3); `blcksock.pas` 009.011.000 -> 009.011.001; novo `synapse.dpk` simetrico.

### Apenas no upstream (nao trazidos)

- `ssl_schannel.pas` / `ssl_schannel_lib.pas` — Windows Schannel (fora do escopo; projecto usa OpenSSL).

### Gap de versao vs upstream

Ficheiros onde o upstream ficou a frente (merge nao trivial — CSL tem modificacoes em cima do baseline antigo). Ver tabela em [README.md](README.md) §"Gap de versao vs upstream".

---

## Referencias canonicas

- [README.md](README.md) — visao geral do package CSL fork
- [VERSION.md](VERSION.md) — politica de versionamento + inventario de 50 units + changelog consolidado
- [Documentation/README.md](Documentation/README.md) — hub de analise vendor
- [Documentation/LDAPSend.md](Documentation/LDAPSend.md) — analise da `TLDAPSend`
- [Documentation/TCPBlockSocket.md](Documentation/TCPBlockSocket.md) — analise do `TTCPBlockSocket`
- [Documentation/SSLOpenSSL.md](Documentation/SSLOpenSSL.md) — analise da familia `TSSLOpenSSL*`
- [Documentation/FLOWCHART.md](Documentation/FLOWCHART.md) — diagrama de autenticacao LDAPS
- Modulo pai: [../../CLAUDE.md](../../CLAUDE.md) (ActiveDirectoryORM — consumidor deste vendor)
- Upstream Synapse: <https://github.com/geby/synapse>
- Ararat Synapse docs: <https://www.ararat.cz/synapse/doku.php>

---

## Changelog (CLAUDE.md)

- **2026-04-24** — Reescrita completa do CLAUDE.md local: eliminado o template generico (project-bootstrap, FASE 3, criacao de `.dpr`/`.lpr`) que nao se aplica a vendor. Ficheiro passa a descrever especificamente a pasta `Packege/synapse/` como fork CSL do Ararat Synapse 41.3 — estrutura, compilacao via package/source, selector OpenSSL, areas protegidas com politica de patch do vendor, prerrogativas perenes especificas (compatibilidade binaria upstream, cross-compiler, Windows-only guardado, backups em `bak/`, bump triplo sincronizado). Referencias rapidas apontam para [README.md](README.md), [VERSION.md](VERSION.md) e CLAUDE.md do modulo pai.
