# Subject CN — formatos historicos ICP-Brasil

ICP-Brasil v3 e o padrao atual. Versoes anteriores sao toleradas pelo parser
via fallback regex no Subject CN.

## Formatos por versao

### v1 (pre-2010)

```text
EMPRESA NOME LTDA
```

Sem `:` no CN. Documento (CNPJ) so vinha em extensao OtherName, nao no CN.
Parser **nao identifica** v1 sem o OID — retorna `ibtDesconhecido`.

### v2 (2010-2018)

```text
EMPRESA NOME LTDA:12345678000190
JOAO DA SILVA:12345678901
```

CN inclui `:DOC` no final. Parser `ParseSubjectCN` identifica corretamente.

### v3 (2018+)

Mesmo formato do CN do v2, mas o CNPJ/CPF tambem aparece em
`subjectAltName.otherName` com OID `2.16.76.1.3.{1,4,7}`. Parser usa OIDs
prioritariamente; CN e fallback.

## Tolerancia do parser

`ParseSubjectCN` usa o **ULTIMO** `:` como separador. Isso permite CN com
`:` no nome:

```text
EMPRESA COM:ESPACOS LTDA:11999000000159
^-------------- titular --------------^ ^-- doc --^
```

## Casos especiais

### CN sem `:` mas com documento extension

`ParseSubjectCN` retorna False; classificacao acontece via OID otherName.
Reader principal (`LerDoPfx`) usa o resultado da classificacao por OID se
disponivel.

### Documento com tamanho errado

CPF tem 11 digitos; CNPJ tem 14. Outros tamanhos -> `ibtDesconhecido`.

```text
'NOME:1234567890'        -> Falha (10 digitos, nao e CPF nem CNPJ)
'NOME:1234567890123'     -> Falha (13 digitos)
```

### Documento com checksum invalido

Parser aceita o documento (separa do CN) mas `IsCnpjValido`/`IsCpfValido`
retornam False. Reader principal popula `DocumentoValido = False` mas nao
falha.
