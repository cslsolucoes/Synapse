# TLDAPAttributeValue / ldapsend.pas

**Unit:** `ldapsend.pas` | **Versao:** 001.007.005 (CSL fork V1.7.2; introduzido em V1.7.1 / 001.007.004) | **Tipo:** Record advanced publico | **Origem:** 100% CSL (sem precedente upstream)

---

## 1. O que e?

`TLDAPAttributeValue` e um **record advanced publico** (com metodos) introduzido em **Synapse CSL V41.2 / `ldapsend.pas` 001.007.004** (2026-04-22). Funciona como **acessor tipado** de um unico valor de um [TLDAPAttribute](TLDAPAttribute.md), com semantica idiomaticamente identica ao `TField` de `Data.DB`:

- `AsString` / `AsInteger` / `AsFloat` / `AsBoolean` / `AsDateTime` / `AsBinary` / `AsHex` / `AsSid` / `AsGuid` / `AsVariant` / `IsNull`.

Actua como ponte entre o **atributo LDAP** (bytes crus armazenados em `TLDAPAttribute.FRawValues`) e o **consumidor tipado** (codigo Delphi/FPC que quer `Int64`, `TDateTime`, `TGUID`, `TBytes` sem parse manual).

E obtido atraves das properties:

- `TLDAPAttribute.Value` — acessor do valor no indice 0 (caso mais comum, singular).
- `TLDAPAttribute.Values[Index]` — acessor multi-valued por indice.

**Record por valor** — sem alocacao de heap, sem necessidade de `Free`. O custo e apenas copiar dois campos (ponteiro `FOwner: TLDAPAttribute` + `FIndex: Integer`).

---

## 2. Caracteristicas

- **Semantica TField (Data.DB)**: API idiomatica familiar a qualquer programador Delphi.
- **Record por valor**: sem gestao de memoria; passado como parametro, devolvido como resultado, descartado automaticamente.
- **Zero alocacao**: armazena apenas referencia ao `TLDAPAttribute` owner + indice. Todos os accessors leem `FOwner.FRawValues[FIndex]` sob demanda.
- **Nunca levanta excepcao**: cada `AsXxx` devolve um default sintactico (`''`, `0`, `0.0`, `False`, `0` para TDateTime, `GUID_NULL` para TGUID) se o tipo nao casar ou se o parse falhar.
- **Despacho automatico por `ValueType`**: `AsDateTime` despacha para `ParseGeneralizedTime` ou `ParseFileTimeInt64` conforme `FOwner.ValueType`. `AsVariant` consulta `ValueType` para escolher o sub-accessor correcto.
- **Cross-compiler**: compila em Delphi 12+ (`{$MODE DELPHI}` em FPC); record advanced suportado em ambos desde Delphi 2006 / FPC 2.6+.
- **`uses` Variants**: requer `Variants` (FPC) / `System.Variants` (Delphi) para suportar `AsVariant`.

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| Record advanced (`strict private` + metodos) | Suporte em Delphi 2006+ e FPC 2.6+ com `{$MODE DELPHI}` |
| `FOwner: TLDAPAttribute` | Referencia ao dono (weak pointer; nao possui o objecto) |
| `FIndex: Integer` | Indice no array `FOwner.FRawValues` |
| `System.Variants` / `Variants` | Usada por `AsVariant` para empacotar o valor tipado |
| `FOwner.GetRawValueAt(FIndex)` | Fonte primaria dos bytes crus (chamado por todos os accessors) |
| Helpers file-private (`ParseGeneralizedTime`, `ParseFileTimeInt64`, `RawToSid`, `RawBytesToGuid`, `RawToHex`) | Decoders especializados reutilizados |

---

## 4. Funcionalidades

### 4.1 Metodos publicos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` (class function) | `class function Create(AOwner: TLDAPAttribute; AIndex: Integer): TLDAPAttributeValue; static` | Factory — cria record inicializado. Chamado indirectamente pelas properties `Value` e `Values[Index]` do `TLDAPAttribute`. |
| `IsNull` | `function IsNull: Boolean` | `True` se `FOwner = nil` ou se `FOwner.FRawValues[FIndex]` esta vazio. |
| `AsString` | `function AsString: string` | Delega a `FOwner.Get(FIndex)` — devolve string ja formatada conforme `ValueType` (GUID em `'{XXXXXXXX-...}'`, SID em `'S-1-5-21-...'`, FileTime em ISO-like, hex, UTF-8 decoded). |
| `AsInteger` | `function AsInteger: Int64` | Parse ASCII decimal dos bytes crus via `Val`. Devolve `0` se parse falhar. Usado para `userAccountControl`, `primaryGroupID`, `pwdLastSet` (bruto, antes da conversao FILETIME), etc. |
| `AsFloat` | `function AsFloat: Double` | Parse ASCII decimal via `Val`. Devolve `0.0` se parse falhar. AD nao usa floats nativos; disponivel para schemas custom. |
| `AsBoolean` | `function AsBoolean: Boolean` | `True` se `SameText(raw, 'TRUE')`. Usado para `showInAdvancedViewOnly`, `isDeleted`, `isRecycled`. |
| `AsDateTime` | `function AsDateTime: TDateTime` | Despacho por `ValueType`: `vtGeneralizedTime`/`vtUTCTime` → `ParseGeneralizedTime` (formato `YYYYMMDDHHMMSS.0Z`); `vtFileTime` → `ParseFileTimeInt64` (Int64 100-ns desde 1601). Devolve `0` se parse falhar ou tipo nao casar. |
| `AsBinary` | `function AsBinary: TBytes` | Bytes crus em `TBytes`. Sem decodificacao — serve para passar o payload original ao consumidor (ex.: parser ASN.1 externo de `nTSecurityDescriptor`). |
| `AsHex` | `function AsHex: string` | Bytes crus → hex ASCII maiusculo via `RawToHex`. Independente de `ValueType` — util para debugging de qualquer atributo. |
| `AsSid` | `function AsSid: string` | MS-ADTS binary → `'S-1-5-21-...'` via `RawToSid`. Independente de `ValueType` — util para decode de qualquer atributo conhecidamente SID (mesmo se mapa ainda nao cobre). |
| `AsGuid` | `function AsGuid: TGUID` | 16 bytes LE → `TGUID` via `RawBytesToGuid`. Aplica swap correcto em `Data1`/`Data2`/`Data3` (LE) + `Data4` (BE). Devolve `GUID_NULL` se `Length(Raw) <> 16`. |
| `AsVariant` | `function AsVariant: Variant` | Despacho automatico por `ValueType`: `vtInteger`→`AsInteger`, `vtBoolean`→`AsBoolean`, `vtFileTime`/`vtGeneralizedTime`/`vtUTCTime`→`AsDateTime`, `vtOctetString`/`vtBitString`→`AsHex`, `vtSID`→`AsSid`, `vtGUID`→`GUIDToString(AsGuid)`, senao `AsString`. |

### 4.2 Properties publicas

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `Raw` | `AnsiString` | R | Bytes crus do socket. Aplica `DecodeBase64` se `FOwner.FIsBinary`. Util para passar payload ao decoder externo sem cadeias intermedias. |
| `ValueType` | [TLDAPValueType](TLDAPValueType.md) | R | Reflecte `FOwner.FValueType`. Usado pelos accessors internamente para despacho. |

### 4.3 Campos privados

| Campo | Tipo | Descricao |
| --- | --- | --- |
| `FOwner` | `TLDAPAttribute` | Referencia ao atributo dono. Weak pointer — o record nao possui o `TLDAPAttribute`; o ciclo de vida e do `TLDAPAttributeList`. |
| `FIndex` | `Integer` | Indice no `FOwner.FRawValues`. Valores invalidos (`<0`, `>= Length`) tratados como null (`IsNull` devolve `True`). |

---

## 5. Aplicabilidades

1. **Codigo tipado em novos consumidores** — em vez de `StrToIntDef(Attr.Items[0], 0)`, usar `Attr.Value.AsInteger`. Em vez de parse manual de `objectGUID`, usar `Attr.Value.AsGuid` → `TGUID`.
2. **Despacho generico por Variant** — serialize/desserialize automatico via `AsVariant`, despachando o tipo correcto sem `case` no consumidor.
3. **Bypass de conversoes intermedias** — aceder directamente aos bytes crus via `AsBinary` (`TBytes`) ou `Raw` (`AnsiString`) para passar a parsers externos (ex.: parser ASN.1 de `nTSecurityDescriptor`, decoder X.509 de `userCertificate`).
4. **Multi-valued** — `for I := 0 to Attr.Count - 1 do ... Attr.Values[I].AsXxx` substitui loops manuais que antes dependiam de decoders duplicados.
5. **IsNull check** — padrao consistente para tratar atributos ausentes ou vazios (ex.: `if not Attr.Value.IsNull then UseIt`).

---

## 6. Exemplos de uso

### 6.1 Ler inteiro e verificar flag

```pascal
uses SysUtils, ldapsend;

var
  LAttr: TLDAPAttribute;
  LUAC: Int64;
begin
  LAttr := LLDAP.SearchResult[0].Attributes.Find('userAccountControl');
  if Assigned(LAttr) then
  begin
    LUAC := LAttr.Value.AsInteger;
    if (LUAC and UAC_ACCOUNTDISABLE) <> 0 then
      Writeln('Conta desactivada');
    if (LUAC and UAC_DONT_EXPIRE_PASSWD) <> 0 then
      Writeln('Password nunca expira');
  end;
end;
```

### 6.2 Ler TGUID e TDateTime tipados

```pascal
var
  LGUID: TGUID;
  LCreated, LPwdLastSet: TDateTime;
  LAttr: TLDAPAttribute;
begin
  LAttr := LLDAP.SearchResult[0].Attributes.Find('objectGUID');
  if Assigned(LAttr) then
  begin
    LGUID := LAttr.Value.AsGuid;   // 16 bytes LE → TGUID directo
    Writeln('GUID = ', GUIDToString(LGUID));
  end;

  LAttr := LLDAP.SearchResult[0].Attributes.Find('whenCreated');
  if Assigned(LAttr) then
  begin
    LCreated := LAttr.Value.AsDateTime;  // Generalized Time → TDateTime
    Writeln('Criado em: ', DateTimeToStr(LCreated));
  end;

  LAttr := LLDAP.SearchResult[0].Attributes.Find('pwdLastSet');
  if Assigned(LAttr) then
  begin
    LPwdLastSet := LAttr.Value.AsDateTime;  // FILETIME → TDateTime
    if LPwdLastSet > 0 then
      Writeln('Password alterada em: ', DateTimeToStr(LPwdLastSet));
  end;
end;
```

### 6.3 Multi-valued com AsString

```pascal
var
  LAttr: TLDAPAttribute;
  I: Integer;
begin
  LAttr := LLDAP.SearchResult[0].Attributes.Find('memberOf');
  if Assigned(LAttr) then
    for I := 0 to LAttr.Count - 1 do
      Memo1.Lines.Add('Grupo: ' + LAttr.Values[I].AsString);
end;
```

### 6.4 Bytes crus para decoder externo

```pascal
uses System.NetEncoding;

var
  LAttr: TLDAPAttribute;
  LBytes: TBytes;
  LBase64: string;
begin
  LAttr := LLDAP.SearchResult[0].Attributes.Find('userCertificate');
  if Assigned(LAttr) and not LAttr.Value.IsNull then
  begin
    LBytes := LAttr.Value.AsBinary;
    LBase64 := TNetEncoding.Base64.EncodeBytesToString(LBytes);
    Writeln('-----BEGIN CERTIFICATE-----');
    Writeln(LBase64);
    Writeln('-----END CERTIFICATE-----');
  end;
end;
```

### 6.5 Despacho automatico via AsVariant

```pascal
var
  LAttr: TLDAPAttribute;
  LValue: Variant;
begin
  LAttr := LLDAP.SearchResult[0].Attributes.Find('whenCreated');
  LValue := LAttr.Value.AsVariant;  // TDateTime empacotado em Variant
  Writeln('Tipo: ', VarTypeAsText(VarType(LValue)));  // varDate
  Writeln('Valor: ', LValue);
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| [TLDAPAttribute](TLDAPAttribute.md) | Owner | Cria instancias via properties `Value` (`GetSingleValue` → `TLDAPAttributeValue.Create(Self, 0)`) e `Values[Index]` (`GetValueAt`). |
| [TLDAPValueType](TLDAPValueType.md) | Enum consultado | `ValueType` reflecte `FOwner.FValueType`; metodos `AsXxx` fazem despacho `case` conforme este enum. |
| Helpers file-private | Dependencias | `ParseGeneralizedTime`, `ParseFileTimeInt64`, `RawToSid`, `RawBytesToGuid`, `RawToHex` no `implementation` do `ldapsend.pas`. |
| `System.Variants` / `Variants` | Dependencia | Necessaria para `AsVariant`; adicionada a `uses` na V1.7.1. |
| `TField` (`Data.DB`) | Analogia conceptual | API semanticamente identica (AsString/AsInteger/AsFloat/AsBoolean/AsDateTime/IsNull); consumidor Delphi reconhece padrao imediatamente. |

---

## 8. Notas de design

- **Por que record, nao classe?** Evita alocacao e necessidade de `Free`. Consumidor recebe o record, usa-o, descarta automaticamente. O custo e copiar 2 campos (ponteiro + inteiro) — despezivel comparado com uma alocacao de heap.
- **Por que `strict private`?** Esconde `FOwner` e `FIndex` do consumidor — so se acede via `Raw` e `ValueType`. Evita criacao manual errada (consumidor nao tem como criar um `TLDAPAttributeValue` pendurando um `TLDAPAttribute` qualquer que nao seja dono).
- **Por que accessors nao levantam?** Defensive design — um atributo "problematico" (binario nao reconhecido, tipo errado no mapa, bytes corrompidos) nao pode abortar a enumeracao do chamador. Devolver default sintactico + `IsNull` permite validacoes explicitas sem `try/except` por atributo.

---

## 9. Roadmap

- **V1.7.2** — Adicionar `AsUtf8: RawByteString` e `AsRaw: AnsiString` como atalho directo (sem pasar por `GetRaw` + conversao).
- **V2.0.0** — Suportar `TField`-like formatting options (`DisplayFormat` para datas, `Precision` para floats) via property de `TLDAPAttributeValue`.
