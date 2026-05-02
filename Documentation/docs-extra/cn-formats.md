# Subject CN — formatos historicos ICP-Brasil

ICP-Brasil v3 e o padrao atual; v8 esta em vigor desde 2024 (DOC-ICP-04 v8.x).
Versoes anteriores sao toleradas pelo parser via fallback regex no Subject CN.

> **V41.5 (S8) — actualizacao:** alem do parser do CN, o leitor agora lida
> com OIDs legacy `.3` (CNPJ pre-v3) — fluxo de classificacao reordenado em
> [`ssl_openssl_icpbrasil.pas`](../ssl_openssl_icpbrasil.pas) (funcao nova
> `TentarExtrairCnpjPJ`). Mais detalhes em [icpbrasil-oids.md](icpbrasil-oids.md).

## Formatos por versao do DOC-ICP-04

### v1 (pre-2008)

```text
EMPRESA NOME LTDA
```

Sem `:` no CN. Documento (CNPJ) so vinha em extensao OtherName usando OID
`2.16.76.1.3.3` (legacy). Parser **nao identifica** v1 pelo CN — depende do
fallback OID `.3`. **A partir de V41.5**, o reader trata isso correctamente
via `TentarExtrairCnpjPJ`.

### v2 (2008-2018)

```text
EMPRESA NOME LTDA:12345678000190
JOAO DA SILVA:12345678901
```

CN inclui `:DOC` no final. Parser `ParseSubjectCN` identifica corretamente.
Documento tambem em `subjectAltName.otherName` com OID `.7` (moderno) e
frequentemente tambem `.3` (legacy, redundante).

### v3 (2018+, ainda em circulacao em A1 longa-duracao)

Mesmo formato do CN do v2, mas o CNPJ/CPF tambem aparece em
`subjectAltName.otherName` com OID `2.16.76.1.3.{1,4,7}`. Parser usa OIDs
prioritariamente; CN e fallback. **V41.5 adiciona fallback para `.3`** quando
o cert nao tiver `.7`.

### v6 (2020+)

Identico ao v3 do ponto de vista do CN. Diferenca principal: substitui CEI
por CAEPF no OID `2.16.76.1.3.6` (Receita Federal desactivou CEI em
2018/01/01). V41.5 parser `ParsePisOuCaepf` aceita 11/12/14 digitos.

### v8 (2024+, vigente actualmente)

Identico ao v6 no formato CN. OIDs adicionais (`.10` OAB digital, `.11+`
extensoes) opcionais. V41.5 reconhece `.10` mas parser dedicado fica para
S11.

## Tolerancia do parser

`ParseSubjectCN` usa o **ULTIMO** `:` como separador. Isso permite CN com
`:` no nome:

```text
EMPRESA COM:ESPACOS LTDA:11999000000159
^-------------- titular --------------^ ^-- doc --^
```

## Fluxo de classificacao (V41.5)

1. **OID `.7`** (e-CNPJ moderno) → se presente, popula `SubjectDocumento`.
2. **OID `.3`** (e-CNPJ legacy) → fallback se `.7` ausente. **Novo em V41.5.**
3. **OID `.1`** (e-CPF) → se cert e PF.
4. **OIDs adicionais** (`.4`, `.5`, `.6`, `.8`) → popula campos derivados
   no record (`ResponsavelCpf`, `TituloEleitor`, `PisOuCaepf`, `RgSeparado`).
5. **CN do Subject** (fallback) → se nenhum OID classificou, tenta
   `ParseSubjectCN` (formato `TITULAR:DOCUMENTO`).
6. **`ibtDesconhecido`** → se tudo falha. `LerDoPfx` lanca
   `EIcpBrasilNaoIcpBrasil`; `TentarLerDoPfx` retorna `False`.

## Casos especiais

### CN sem `:` mas com documento extension

`ParseSubjectCN` retorna False; classificacao acontece via OID otherName.
Reader principal (`LerDoPfx`) usa o resultado da classificacao por OID se
disponivel.

### Documento com tamanho errado no CN

CPF tem 11 digitos; CNPJ tem 14. Outros tamanhos → `ibtDesconhecido` (se
nao houver OID que classifique).

```text
'NOME:1234567890'        -> Falha (10 digitos, nao e CPF nem CNPJ)
'NOME:1234567890123'     -> Falha (13 digitos)
```

### Documento com checksum invalido

Parser aceita o documento (separa do CN) mas `IsCnpjValido`/`IsCpfValido`
retornam False. Reader principal popula `DocumentoValido = False` mas nao
falha.

### CN com sufixos profissionais (V41.5+)

Cert OAB digital (OID `.10`) tem CN no formato:

```text
JOAO DA SILVA:12345678901:OAB-MG-1234
```

`ParseSubjectCN` retorna `Titular = 'JOAO DA SILVA:12345678901'` e
`Documento = 'OAB-MG-1234'` (ULTIMO `:` ganha) — **isso esta errado para
OAB**. Workaround actual: usar `IsOidIcpBrasilPF` para detectar OAB e
extrair via `ExtractFieldOrRaw` da extensao. Parser dedicado em S11.

### Suporte a Unicode no CN

Pascal `string` em Delphi 12+ e UnicodeString. `ParseSubjectCN` aceita
caracteres acentuados em PT-BR (ZE PEDRO ALCANTARA, JOAO MUNHOZ etc.)
sem normalizacao especial.

## Helpers relacionados (V41.5)

```pascal
function MatchCnpjRaiz(const ACertCnpj, ADocCnpj: string): Boolean;
//   Compara apenas os 8 primeiros digitos. Permite filiais usarem cert da
//   matriz (politica espelha ACBr `ValidarCNPJCertificado`).

// No record:
function TIcpBrasilCertificado.EstaValidoEm(const AData: TDateTime): Boolean;
function TIcpBrasilCertificado.EstaValido: Boolean;
function TIcpBrasilCertificado.DiasParaExpirar: Integer;
```
