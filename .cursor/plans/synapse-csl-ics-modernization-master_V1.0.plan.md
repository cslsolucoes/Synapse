---
name: synapse-csl-ics-modernization-master
version: 1.0.0
date: 2026-04-22
author: CSL Softwares
status: draft
scope: >
  Plano mestre de modernizacao do fork Synapse CSL em 4 ondas inspiradas
  em ICS (OverByte Internet Component Suite) — TSslRootCAStore, HTTP
  moderno, SMTP moderno, IMAP moderno. Cada onda e um ficheiro .plan.md
  independente; este master coordena dependencias, licenciamento e
  cronograma.
depends-on:
  - Synapse CSL fork 001.007.004 / V41.2 (estado actual em 2026-04-22)
  - Politica de areas protegidas (Packege/synapse/ + Documentation/)
  - CLAUDE.md prerrogativas perenes 8 e 10 (engine LDAP Synapse-exclusivo; plan-mode obrigatorio em Packege/synapse/)
target-files:
  - Packege/synapse/blcksock.pas
  - Packege/synapse/httpsend.pas
  - Packege/synapse/smtpsend.pas
  - Packege/synapse/imapsend.pas
  - Packege/synapse/VERSION.md
  - Packege/synapse/Synapse.Version.inc
protected-area: Packege/synapse/ — TODAS as ondas requerem aprovacao antes de execucao
impact-on-adorm: NULO — nenhuma onda altera src/; ActiveDirectoryORM nao e consumidor directo dos protocolos HTTP/SMTP/IMAP
target-compilers:
  - Delphi 12.x (Win32 / Win64)
  - FPC 3.3.1+ (i386-win32 / x86_64-win64)
  - (pendente V1.7.2) FPC POSIX Linux/macOS apos fix sswin32.inc
out-of-scope:
  - Copy-paste de codigo ICS (bloqueado por licenca — ver secao 3)
  - Port para arquitectura event-driven (ICS e non-blocking; Synapse e blocking)
  - Alteracoes em src/ do ActiveDirectoryORM
  - Protocolos sem valor agregado (NNTP, Telnet, TFTP, PING, ClamAV, SNTP, Syslog)
  - POP3 (agendar para V41.7 se surgir consumidor)
ondas:
  - V41.3 — TSslRootCAStore (blcksock.pas)
  - V41.4 — HTTP modernization (httpsend.pas)
  - V41.5 — SMTP modernization (smtpsend.pas)
  - V41.6 — IMAP modernization (imapsend.pas)
---

# Synapse CSL — ICS-inspired modernization (Plano mestre)

> **Status:** draft — plano-de-planos. Cada onda e um `.plan.md` independente
> que pode ser aprovado, executado e auditado isoladamente.
> Carregar apenas o ficheiro da onda em execucao; este master so para visao geral.

---

## 1. Motivacao

O fork Synapse CSL 001.007.004 / V41.2 cobre **100% das necessidades actuais do
ActiveDirectoryORM** (LDAP v3 + LDAPS + SSPI GSSAPI + CBT + LDAP Signing + AD
controls + tipagem automatica de atributos). Porem, os protocolos nao-LDAP
(`httpsend`, `smtpsend`, `imapsend`) estao na versao upstream Synapse **inalterada
desde ~2014** e faltam-lhes features que o ecossistema moderno exige:

| Area | Gap actual (Synapse upstream) | Necessidade |
|---|---|---|
| TLS trust store | Cada unit tem que apontar CAFile manualmente; zero reuso entre `ldapsend`/`httpsend`/`smtpsend` | Trust store centralizado (padrao ICS `TSslRootCAStore`) |
| HTTP | Basic/Digest/NTLM only; sem OAuth 2.0 Bearer; cookies volateis; keepalive parcial | OAuth 2.0 Bearer; cookies persistentes; keepalive real; HTTP/2 parcial |
| SMTP | `AUTH LOGIN`/`AUTH PLAIN`/`AUTH CRAM-MD5`; sem XOAUTH2; STARTTLS manual | XOAUTH2 (Gmail/M365); STARTTLS automatico |
| IMAP | IMAP4rev1 basico; sem IDLE; SEARCH limitado; sem UIDPLUS | IDLE (notifications push); SEARCH estendido (RFC 3501); UIDPLUS (RFC 4315); XOAUTH2 |

Estes gaps nao afectam o ADORM hoje, mas bloqueiam futuros consumidores do fork
CSL (aplicacoes internas que possam precisar de webhook HTTPS, envio de email
via M365, leitura de inbox IMAP para processamento).

---

## 2. Princípios comuns a todas as ondas

### 2.1 Reimplementacao conceitual, nao copy-paste

ICS (Internet Component Suite de Francois Piette / OverByte) e distribuido sob
**Mozilla Public License 1.1 + free-for-any-use**. O Synapse e **BSD 3-Clause
puro**. Misturar codigo ICS em unidades Synapse **obrigaria MPL em toda a
unidade** — quebrando a licenca BSD do fork CSL.

**Regra absoluta:** nenhuma linha de codigo ICS e copiada. O que se importa e o
**padrao de API** e **algoritmos publicos**. Codigo fonte e 100% BSD 3-Clause,
escrito de raiz em estilo Synapse blocking.

Quando uma unidade tiver inspiracao conceitual ICS, o header CSL documenta:

```
{ Inspired by ICS (OverByte Internet Component Suite) patterns.
  No ICS source code was copied — only public API design patterns were used
  as reference. All code in this unit is original BSD 3-Clause by CSL. }
```

### 2.2 Arquitectura mantida blocking

ICS e **event-driven** (`TWSocket` com callbacks `OnDataAvailable`). Synapse
e **blocking** (`TBlockSocket.RecvString` sincrono). Portar directamente
quebraria toda a API existente. Todas as ondas mantem o padrao blocking
Synapse — as novas features sao implementadas como extensoes aos metodos
sincronos existentes (ex.: `THTTPSend.BearerAuth` property; `TSMTPSend.UseSTARTTLS`
flag; `TIMAPSend.Idle(ACallback, AMs)` metodo blocking com callback periodico).

### 2.3 Compatibilidade retroactiva obrigatoria

Cada onda **so adiciona** API. Nunca remove ou altera assinaturas existentes.
Consumidores actuais do Synapse (incluindo ADORM via `ldapsend`, e aplicacoes
que ja usem `httpsend`/`smtpsend`) continuam a compilar sem alteracao.

### 2.4 Cross-compiler obrigatorio

Cada onda valida matriz:

| Target | Estado esperado |
|---|---|
| Delphi Win32 (dcc32) | Verde, 0 erros |
| Delphi Win64 (dcc64) | Verde, 0 erros |
| FPC Win32 (i386-win32) | Verde, 0 erros (excepto gap pre-existente `System.SyncObjs`) |
| FPC Win64 (x86_64-win64) | Idem |

FPC POSIX (Linux/macOS) permanece bloqueado pelo gap `sswin32.inc` ate V1.7.2
do ORM — nao e responsabilidade destas ondas.

### 2.5 Backup obrigatorio antes de editar

Cada ficheiro alvo e copiado para `Packege/synapse/bak/<ficheiro>.<YYYYMMDD_HHMM>.bak`
antes da primeira alteracao da onda. Sufixo `_a`/`_b`/`...` para resolver
colisoes de minuto. Nunca apagar backups existentes.

### 2.6 Documentacao sincronizada

Cada onda actualiza:

- `Packege/synapse/VERSION.md` — bump package + bump unit + changelog da onda.
- `Packege/synapse/Synapse.Version.inc` — novo define `SYNAPSE_V41_N_OR_HIGHER` + defines de features.
- `Packege/synapse/README.md` — inventario da onda na seccao "Fork sessao <data>".
- `Packege/synapse/Documentation/README.md` — menu actualizado.
- `Packege/synapse/Documentation/Analise/Core/<Classe>.md` — secao V41.N da classe afectada.
- Header CSL da unidade alvo com bloco historico da onda.

---

## 3. Licenciamento — analise detalhada

| Source | Licenca | Compativel com BSD 3-Clause? | Posso importar directamente? |
|---|---|---|---|
| Synapse upstream | BSD 3-Clause | Sim (mesma) | Sim |
| ICS OverByte (MPL 1.1) | MPL 1.1 | **Nao** — MPL requer disclosure do codigo modificado | **Nao** |
| ICS OverByte (free-for-any-use addendum) | Informal | **Ambiguo** — Piette permite uso livre mas nao especifica re-distribuicao em BSD | **Nao sem permissao** |
| RFC reference implementations | Public domain | Sim | Sim |

**Decisao:** todas as ondas reimplementam do zero em estilo Synapse BSD,
usando **apenas as RFCs publicas** (RFC 6750 OAuth Bearer, RFC 4954 SMTP AUTH,
RFC 2177 IMAP IDLE, RFC 4315 UIDPLUS, RFC 3501 IMAP, RFC 7540 HTTP/2) como
especificacao. ICS serve apenas como **referencia de design** — nao como fonte
de codigo.

Qualquer merge request que contenha codigo copiado do ICS **e rejeitado**.

---

## 4. Cronograma e dependencias

```text
V41.2 (actual, 2026-04-22) ────┐
                               │
                               ▼
              ┌── V41.3 TSslRootCAStore (Onda 1)
              │   blcksock.pas — trust store centralizado
              │   Sem dependencias externas
              │
              ├── V41.4 HTTP modernization (Onda 2)
              │   httpsend.pas — OAuth Bearer + cookies + keepalive
              │   Usa TSslRootCAStore da Onda 1 (se disponivel)
              │
              ├── V41.5 SMTP modernization (Onda 3)
              │   smtpsend.pas — XOAUTH2 + STARTTLS auto
              │   Usa TSslRootCAStore da Onda 1 (se disponivel)
              │
              └── V41.6 IMAP modernization (Onda 4)
                  imapsend.pas — IDLE + UIDPLUS + SEARCH estendido + XOAUTH2
                  Usa TSslRootCAStore da Onda 1 (se disponivel)
```

**Dependencia unica:** Ondas 2–4 ficam mais simples se a Onda 1
(`TSslRootCAStore`) for concluida primeiro, mas **nao sao bloqueadas** por ela —
cada onda pode cair de volta ao modo actual (`CertCAFile` string) se o
trust store nao estiver disponivel.

**Ordem recomendada:** 1 → 2 → 3 → 4. Ondas 2–4 podem ser paralelizadas se
equipa tiver >1 dev.

---

## 5. Estimativa de esforco

| Onda | LoC novo | LoC modificado | Docs | Tests | Dias-dev |
|---|---:|---:|---:|---:|---:|
| V41.3 TSslRootCAStore | ~400 | ~80 (em `blcksock.pas`) | 3 docs (+1 novo) | Smoke TLS verify | 3–4 |
| V41.4 HTTP | ~500 | ~120 (em `httpsend.pas`) | 3 docs | Smoke contra httpbin.org | 4–5 |
| V41.5 SMTP | ~350 | ~80 (em `smtpsend.pas`) | 2 docs | Smoke sandbox SMTP | 3 |
| V41.6 IMAP | ~600 | ~150 (em `imapsend.pas`) | 3 docs | Smoke contra Gmail IMAP | 5–6 |
| **Total** | **~1850** | **~430** | **11 docs** | **4 smokes** | **15–18** |

---

## 6. Criterios de aceitacao (transversais a todas as ondas)

- [ ] Header CSL da unidade alterada documenta a onda com bloco historico.
- [ ] Bump da versao da unidade (`AAA.BBB.CCC`) conforme convencao existente.
- [ ] Bump do package (`V41.N`) em `VERSION.md` e `Synapse.Version.inc`.
- [ ] Defines novos em `Synapse.Version.inc` (`SYNAPSE_<FEATURE>_<FLAG>`).
- [ ] Backup timestamped da unidade alterada em `bak/`.
- [ ] Matriz Delphi Win32+Win64 + FPC Win32+Win64 verde.
- [ ] Smoke test minimo da onda passa (`SMOKE_OK`).
- [ ] API retroactiva preservada — codigo existente compila sem alteracao.
- [ ] Nenhuma linha de codigo ICS copiada (auditoria textual antes de merge).
- [ ] Header CSL acrescenta nota "Inspired by ICS patterns — no source code copied".
- [ ] Documentacao `Packege/synapse/Documentation/Analise/` actualizada.
- [ ] README hub e VERSION.md mantidos sincronizados.

---

## 7. Indice das ondas

| Onda | Ficheiro do plano | Status |
|---|---|---|
| **V41.3** | [synapse-csl-ssl-rootcastore_V1.0.plan.md](synapse-csl-ssl-rootcastore_V1.0.plan.md) | draft |
| **V41.4** | [synapse-csl-http-modernization_V1.0.plan.md](synapse-csl-http-modernization_V1.0.plan.md) | draft |
| **V41.5** | [synapse-csl-smtp-modernization_V1.0.plan.md](synapse-csl-smtp-modernization_V1.0.plan.md) | draft |
| **V41.6** | [synapse-csl-imap-modernization_V1.0.plan.md](synapse-csl-imap-modernization_V1.0.plan.md) | draft |

---

## 8. Referencias

- **RFC 4511** — LDAP v3 (para consistencia com `ldapsend`)
- **RFC 5246 / 8446** — TLS 1.2 / 1.3 (base do trust store)
- **RFC 6750** — OAuth 2.0 Bearer Token (Onda 2 HTTP, Onda 3 SMTP XOAUTH2, Onda 4 IMAP XOAUTH2)
- **RFC 4954** — SMTP Service Extension for Authentication (Onda 3)
- **RFC 3501** — IMAP4rev1 (Onda 4)
- **RFC 2177** — IMAP IDLE (Onda 4)
- **RFC 4315** — IMAP UIDPLUS (Onda 4)
- **RFC 7540** — HTTP/2 (Onda 2 parcial)
- **ICS OverByte** — <https://www.overbyte.eu/> (referencia conceitual APENAS, sem copia de codigo)
- **Ararat Synapse docs** — <https://www.ararat.cz/synapse/doku.php>
- **Plano ADORM V1.7.1** — `D:\Users\claiton.linhares\.claude\plans\project-activedirectoryorm-exe-raised-ex-snoopy-ocean.md`

---

**Changelog (este arquivo):**

- 1.0.0 (22/04/2026): Criacao. Plano mestre de 4 ondas ICS-inspired para fork Synapse CSL V41.3+. Status draft — cada onda requer aprovacao antes de execucao.
