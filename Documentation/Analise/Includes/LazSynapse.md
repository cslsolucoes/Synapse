# laz_synapse

**Unit:** `laz_synapse.pas` | **Versao:** gerada automaticamente pelo Lazarus IDE | **Tipo:** Unit companion | **Origem:** Upstream

---

## 1. O que e?

`laz_synapse.pas` e a **unit companion do package Lazarus `laz_synapse.lpk`**. O ficheiro e auto-gerado pelo Lazarus IDE durante o build do package; o seu unico proposito e referenciar todas as units do Synapse no bloco `uses`, forcando o compilador Lazarus a compilar cada uma delas quando o package e instalado.

E o equivalente Lazarus do `synapse.dpk` (Delphi package) -- ambos servem como manifesto que agrupa as 30+ units do Synapse num pacote redistribuivel unico, usavel por outros projectos Lazarus via `OpenProject -> .lpk -> Compile -> Use`.

O cabecalho do ficheiro e explicitamente `This file was automatically created by Lazarus. Do not edit!`.

---

## 2. Caracteristicas

- **Auto-gerada** -- modificacoes directas sao sobrescritas no proximo build do package.
- **Vazia em `implementation`** -- nao contem codigo executavel; apenas o `uses` e o `end.`.
- **Sinaliza ao Lazarus quais as units incluidas no package** -- controlada atraves do IDE (Package -> Files).
- **Directiva `{$warn 5023 off}`** -- suprime avisos "unit not used" (intencional: as units sao re-exportadas, nao consumidas).
- **Alinhada com `laz_synapse.lpk`** -- a lista `uses` e espelho dos `<Files>` declarados no XML `.lpk`.

---

## 3. Engine

| Directiva / runtime | Efeito |
|---|---|
| `{$warn 5023 off}` | Suprime "Hint: Unit X not used" (FPC) |
| `unit laz_synapse;` | Declaracao da unit |
| `interface` / `uses` | Importacao transitiva das 32 units Synapse |
| `implementation` | Vazia -- o ficheiro nao adiciona comportamento |
| `end.` | Terminacao |

Zero dependencias dinamicas -- e metadata de compilacao/packaging.

---

## 4. Funcionalidades

### 4.1 Conteudo real do ficheiro

```pascal
unit laz_synapse;

{$warn 5023 off : no warning about unused units}
interface

uses
  asn1util, blcksock, clamsend, dnssend, ftpsend, ftptsend, httpsend,
  imapsend, ldapsend, mimeinln, mimemess, mimepart, nntpsend, pingsend,
  pop3send, slogsend, smtpsend, snmpsend, sntpsend, synachar, synacode,
  synacrypt, synadbg, synafpc, synaicnv, synaip, synamisc, synaser, synautil,
  synsock, tlntsend, ssl_openssl, ssl_openssl_lib;

implementation

end.
```

### 4.2 Units referenciadas (32 no ficheiro actual)

| # | Unit | Categoria |
|---|---|---|
| 1 | `asn1util` | Core ASN.1 BER |
| 2 | `blcksock` | Core Socket |
| 3 | `clamsend` | Protocolo ClamAV |
| 4 | `dnssend` | Protocolo DNS |
| 5 | `ftpsend` | Protocolo FTP |
| 6 | `ftptsend` | Protocolo TFTP |
| 7 | `httpsend` | Protocolo HTTP |
| 8 | `imapsend` | Protocolo IMAP |
| 9 | `ldapsend` | Protocolo LDAP |
| 10 | `mimeinln` | MIME inline |
| 11 | `mimemess` | MIME email |
| 12 | `mimepart` | MIME partes |
| 13 | `nntpsend` | Protocolo NNTP |
| 14 | `pingsend` | Protocolo PING |
| 15 | `pop3send` | Protocolo POP3 |
| 16 | `slogsend` | Protocolo Syslog |
| 17 | `smtpsend` | Protocolo SMTP |
| 18 | `snmpsend` | Protocolo SNMP |
| 19 | `sntpsend` | Protocolo SNTP |
| 20 | `synachar` | Utils character sets |
| 21 | `synacode` | Utils encoding |
| 22 | `synacrypt` | Utils crypto |
| 23 | `synadbg` | Utils debug |
| 24 | `synafpc` | Utils FPC compat |
| 25 | `synaicnv` | Utils iconv |
| 26 | `synaip` | Utils IP |
| 27 | `synamisc` | Utils misc |
| 28 | `synaser` | Serial port |
| 29 | `synautil` | Utils gerais |
| 30 | `synsock` | Core socket layer |
| 31 | `tlntsend` | Protocolo Telnet |
| 32 | `ssl_openssl` | SSL plugin legacy |
| 33 | `ssl_openssl_lib` | SSL imports legacy |

### 4.3 Units ADICIONAIS no pacote V41.1 (nao no `.pas` companion)

O `laz_synapse.lpk` V41.1 inclui mais **9 units** que nao estao neste `uses` (podem ser adicionadas em edicao futura -- o `.lpk` e autoritativo):

| Unit | Categoria | Origem |
|---|---|---|
| `ssl_openssl11` | SSL 1.1.x | Upstream |
| `ssl_openssl11_lib` | SSL 1.1.x imports | Upstream |
| `ssl_openssl3` | SSL 3.x | Upstream |
| `ssl_openssl3_lib` | SSL 3.x imports | Upstream |
| `ssl_openssl4` | SSL 4.0 | **CSL fork** |
| `ssl_openssl4_lib` | SSL 4.0 imports | **CSL fork** |
| `ssl_openssl_paths` | DLL path helper | **CSL fork** |
| `ssl_openssl_capi` | Windows CAPI | Upstream |
| `Crypt32` | Windows crypt32 imports | Upstream |

---

## 5. Aplicabilidades

1. **Instalacao do package no Lazarus IDE** -- o utilizador abre `laz_synapse.lpk`, clica em `Compile` + `Install`, e o IDE reinicializa com Synapse disponivel globalmente.
2. **Compilar projectos Lazarus que dependem de Synapse** -- basta adicionar `laz_synapse` a `Required Packages`.
3. **Registo de componentes no IDE** (se `synapse.dpk` adicionar `Register` procedure) -- disponibilizaria icons na Tool Palette; actualmente Synapse nao exporta componentes visuais.
4. **Build reproducivel cross-compiler** -- a mesma estrutura `.lpk` + `.dpk` garante que Delphi e Lazarus compilam o mesmo conjunto de units.
5. **Empacotamento para distribuicao** -- o `.lpk` + `.pas` companion + fontes podem ser distribuidos como ZIP e instalados em qualquer Lazarus 2.x+.

---

## 6. Exemplos de uso

### 6.1 Declarar dependencia num projecto Lazarus

No ficheiro `.lpi` do projecto:

```xml
<RequiredPackages Count="1">
  <Item1>
    <PackageName Value="laz_synapse"/>
  </Item1>
</RequiredPackages>
```

### 6.2 Adicionar uma nova unit CSL ao package

Via Lazarus IDE (nao editar `.pas` directamente):

1. Abrir `laz_synapse.lpk`.
2. `Add Files From Filesystem` -> seleccionar `ssl_openssl4.pas`.
3. Save + Compile + Install.
4. Lazarus regenera `laz_synapse.pas` automaticamente adicionando `ssl_openssl4` ao `uses`.

### 6.3 Instanciar classes apos instalacao

```pascal
program LazTesteSynapse;

uses
  ldapsend, blcksock;   // ja disponiveis porque laz_synapse foi instalado

var
  L: TLDAPSend;
begin
  L := TLDAPSend.Create;
  try
    L.TargetHost := 'dc.corp.com';
    L.TargetPort := '636';
    L.FullSSL := True;
    if L.Login then
      WriteLn('Connected to AD');
  finally
    L.Free;
  end;
end.
```

---

## 7. Relacionamentos

| Artefacto | Tipo de relacao | Descricao |
|---|---|---|
| `laz_synapse.lpk` | Parent | XML que define o package Lazarus; autoritativo sobre o `.pas` companion |
| `synapse.dpk` | Contrapartida Delphi | Package Delphi 12/13 simetrico (V41.1 novo no fork CSL) |
| Todas as units `.pas` do Synapse | Referenciadas | 32 units no `uses`; mais 9 adicionais no `.lpk` V41.1 |
| Lazarus IDE | Gerador / consumidor | Lazarus gera o ficheiro automaticamente |
| FPC compiler | Consumidor | Compila o `.pas` companion como parte do package |
| `ssl_openssl4.pas` | Potencial extensao | Sera adicionada quando o package for recompilado |
| `ssl_openssl_paths.pas` | Potencial extensao | idem |

---

**Gerado:** 2026-04-21 (CSL reverse-engineering V2)
