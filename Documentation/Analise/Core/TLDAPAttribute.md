# TLDAPAttribute / ldapsend.pas

**Unit:** `ldapsend.pas` | **Versao:** 001.007.005 (CSL fork V1.7.2) | **Tipo:** Classe | **Origem:** Upstream Synapse + extensoes CSL

---

## 1. O que e?

`TLDAPAttribute` representa um atributo LDAP unico com nome (`AttributeName`) e uma ou mais valores associados. Herda de `TStringList`, o que significa que todos os valores sao armazenados como strings na lista interna — cada `Strings[i]` contem um valor do atributo.

A classe e usada como unidade atomica de entrada/saida em operacoes LDAP: em `TLDAPSend.Modify` representa o alvo da modificacao (delete, add ou replace), em `TLDAPSend.Add` faz parte de um `TLDAPAttributeList` que descreve o objeto novo, e em resultados de `Search` povoa os atributos de cada `TLDAPResult`.

Uma caracteristica importante e a deteccao automatica de atributos binarios: quando o nome do atributo contem o sufixo `;binary`, a property `IsBinary` torna-se `True` e os metodos `Get` / `Put` fazem encoding/decoding Base64 transparente. Isto permite manipular `objectGUID`, `objectSid`, `userCertificate;binary` e `nTSecurityDescriptor` como strings Base64 na interface publica enquanto a serializacao ASN.1 trabalha com bytes raw.

### V1.7.2 (2026-04-22) — `AddRaw` + Put defensivo + Clear override

A V1.7.1 introduziu tipagem automatica mas mantinha um bug residual: o callsite do parser `a.Add(u: AnsiString)` passa `u` como `const S: string` (UnicodeString), e a conversao implicita usa CP_ACP (CP1252). Isto causava:

- **Bytes `0x22`** (ASCII `"`) eram consumidos silenciosamente por `UnquoteStr` no `Put`. **Bug critico**: o `objectGUID` real do `CN=Administrador,DC=cslsolucoes,DC=com,DC=br` chegava com 15 bytes (`BE1827E2555265461F4A630F4AE269`) em vez de 16 (o byte 16 era `0x22`).
- **Bytes `0x80-0xFF`** eram corrompidos por CP1252 best-fit (ex.: `0x80` → `€` (U+20AC) → `and $FF` = `0xAC`).

A V1.7.2 resolve via:

- Novo metodo publico **`TLDAPAttribute.AddRaw(const ARaw: AnsiString): Integer`** — bypassa `UnicodeToRawAnsi`, `UnquoteStr` e `EncodeBase64`. Armazena bytes directamente em `FRawValues` via `StoreRawValue`. Validado teste 16: 256 bytes (0x00-0xFF) preservados byte-a-byte.
- **Parser ASN.1 modificado em 2 callsites**: `TLDAPSend.Search` (~2157) e `TLDAPSend.DoSearchAD` (~2330) — `a.Add(u)` substituido por `a.AddRaw(u)`. Bytes ASN.1 preservados desde o socket ate ao consumidor.
- **`Put` defensivo**: salta `UnquoteStr` quando `FValueType in [vtGUID, vtSID, vtOctetString, vtBitString]` (protege paths publicos `a.Add('string')`).
- **`Get(Index)` blindado** com `try/except` duplo + fallback `RawToHex` final — nenhum decoder pode abortar a iteracao do consumidor.
- **`Clear` override** resetando `FRawValues` em sincronia com TStringList interno (futuro-proof contra paths que reusem instancia via `Clear+Add`).
- **`RawToFileTime`, `RawToGeneralizedTime`, `ParseGeneralizedTime`** usam `SafeUtf8Decode` em vez de `string(ARaw)` (defesa contra `EEncodingError` Delphi 12 strict).

**Validacao real (cslsolucoes.com.br):**

| Atributo | V1.7.1 (com bug) | V1.7.2 (corrigido) |
|---|---|---|
| `objectGUID` | `BE1827E2555265461F4A630F4AE269` (15B hex) | `<E22791BE-5255-4665-951F-4A630F4AE269>` (16B GUID) |
| Total atributos listados | 33 (com perda silenciosa) | 33 (sem perda) |
| Excepcao residual | `EEncodingError` esporadica | nenhuma |

### V1.7.1 (2026-04-22) — Tipagem automatica + fix `EEncodingError`

A partir de 001.007.004, `TLDAPAttribute` ganha **tipagem automatica** via enum [TLDAPValueType](TLDAPValueType.md) e **acessor tipado** via record [TLDAPAttributeValue](TLDAPAttributeValue.md):

- `SetAttributeName` resolve automaticamente `FValueType := ResolveLDAPValueType(Value)` consultando o mapa estatico `LDAP_KNOWN_ATTRIBUTE_TYPES` (~110 atributos AD).
- `Get(Index)` devolve string **ja formatada** conforme `FValueType` (ex.: `objectGUID` → `'{XXXXXXXX-...}'`, `objectSid` → `'S-1-5-21-...'`, `userAccountControl` → inteiro, `whenCreated` → ISO-like, `pwdLastSet` → data, `thumbnailPhoto` → hex).
- `Put(Index, Value)` deixou de usar `s := Value;` (conversao implicita `UnicodeString → AnsiString` via `CP_ACP` que levantava `EEncodingError 'No mapping for the Unicode character...'` em Delphi 12 strict) e passou a usar novo helper file-private `UnicodeToRawAnsi` byte-a-byte (`AnsiChar(Ord(S[I]) and $FF)`). Bytes crus sao espelhados em campo novo `FRawValues: array of AnsiString`.
- Properties novas publicadas: `ValueType` (read-only; resolvido em `SetAttributeName`), `Value` (singular — indice 0), `Values[Index]` (multi-valued). Ambos retornam `TLDAPAttributeValue` (record por valor).
- **Compatibilidade:** assinaturas `Add` / `Put` / `Get` / `AttributeName` / `IsBinary` preservadas. Consumidores existentes do Synapse recebem strings ja decodificadas sem alteracao de codigo.

---

## 2. Caracteristicas

* Descende de `TStringList` (todos os metodos de lista herdados: `Count`, `Strings[]`, `Clear`, `Delete`, etc.).
* Deteccao automatica de atributo binario via sufixo `;binary` no nome.
* Encoding/decoding Base64 transparente para atributos binarios.
* Stripping automatico de aspas (`UnquoteStr`) ao atribuir valores nao-binarios.
* `AttributeName` e `AnsiString` (compativel com a camada LDAP/ASN.1 do Synapse, que opera em bytes).
* Sem necessidade de alocar/liberar valores — `TStringList` gerencia memoria internamente.
* Cross-compiler (Delphi + FPC).

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| `{$IFDEF UNICODE}` | Suprime warnings de cast string |
| `TStringList` (heranca) | Infraestrutura de lista de strings |
| `synacode.EncodeBase64` / `DecodeBase64` | Usado internamente para atributos `;binary` |
| `synautil.UnquoteStr` | Remove aspas duplas dos valores nao-binarios ao atribuir |

---

## 4. Funcionalidades

### 4.1 Metodos publicos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Add` | `function Add(const S: string): Integer; override` | Adiciona novo valor; passa por `Put` para tratar Base64/unquote + armazenar em `FRawValues` (V1.7.1) |
| `Get` (protected override) | `function Get(Index: integer): string; override` | **V1.7.1:** Devolve string ja formatada segundo `FValueType` (GUID/SID/Hex/Int/Data); usa `FRawValues` como fonte autoritativa. Fallback: inherited `Get` + `DecodeBase64` para compatibilidade retroactiva. |
| `Put` (protected override) | `procedure Put(Index: integer; const Value: string); override` | **V1.7.1:** Usa `UnicodeToRawAnsi` byte-a-byte em vez de `s := Value;` (fix `EEncodingError` Delphi 12 strict); se `IsBinary`, aplica `EncodeBase64`; senao, faz `UnquoteStr(s, '"')`. Espelha bytes crus em `FRawValues` via `StoreRawValue`. |
| `SetAttributeName` (protected) | `procedure SetAttributeName(Value: AnsiString)` | Setter da property `AttributeName`; detecta `;binary` em lowercase e atualiza `FIsBinary`. **V1.7.1:** tambem resolve `FValueType := ResolveLDAPValueType(Value)`; se `FIsBinary=True` e `FValueType=vtUnknown`, infere `vtOctetString`. |
| `StoreRawValue` (private, V1.7.1) | `procedure StoreRawValue(Index: Integer; const ARaw: AnsiString)` | Espelha bytes crus em `FRawValues[Index]`; cresce array dinamicamente se `Length(FRawValues) <= Index`. |
| `GetRawValueAt` (private, V1.7.1) | `function GetRawValueAt(Index: Integer): AnsiString` | Acessor usado por `TLDAPAttributeValue.GetRaw`. Aplica `DecodeBase64` se `IsBinary`. |
| `GetSingleValue` (private, V1.7.1) | `function GetSingleValue: TLDAPAttributeValue` | Getter da property `Value`. Equivale a `TLDAPAttributeValue.Create(Self, 0)`. |
| `GetValueAt` (private, V1.7.1) | `function GetValueAt(Index: Integer): TLDAPAttributeValue` | Getter da property `Values[Index]`. |

### 4.2 Properties publicadas

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `AttributeName` | `AnsiString` | R/W | Nome do atributo LDAP (ex.: `sAMAccountName`, `objectGUID;binary`). Setter actualiza `FIsBinary` e (V1.7.1) `FValueType`. |
| `IsBinary` | `Boolean` | R | `True` quando `AttributeName` contem `;binary` (lowercase compared) — determina codificacao Base64. |
| `ValueType` (V1.7.1) | [TLDAPValueType](TLDAPValueType.md) | R | Tipo LDAP inferido automaticamente via `ResolveLDAPValueType`. Read-only; `TLDAPAttributeValue` consulta para despachar `AsXxx` correctamente. |
| `Value` (V1.7.1) | [TLDAPAttributeValue](TLDAPAttributeValue.md) | R | Acessor do valor no indice 0 (caso mais comum). Equivale a `Values[0]`. |
| `Values[Index]` (V1.7.1) | [TLDAPAttributeValue](TLDAPAttributeValue.md) | R | Acessor multi-valued por indice. Usado em `memberOf`, `proxyAddresses`, `objectClass`, etc. |

### 4.3 Campos privados

| Campo | Tipo | Descricao |
| --- | --- | --- |
| `FAttributeName` | `AnsiString` | Nome do atributo (setter em `SetAttributeName`). |
| `FIsBinary` | `Boolean` | Flag `;binary`. |
| `FValueType` (V1.7.1) | `TLDAPValueType` | Tipo LDAP inferido; resolvido em `SetAttributeName`. |
| `FRawValues` (V1.7.1) | `array of AnsiString` | **Bytes crus** do socket preservados por indice antes de qualquer conversao. Fonte autoritativa para `Get`, `GetRawValueAt` e `TLDAPAttributeValue`. Espelha o TStringList interno sem passar por `CP_ACP`. |

### 4.3 Metodos herdados de TStringList (usados comumente)

| Metodo | Descricao |
| --- | --- |
| `Count: Integer` | Numero de valores |
| `Strings[Index]: string` | Acesso indexado (equivalente a `Get(Index)`) |
| `Clear` | Remove todos os valores |
| `Delete(Index: Integer)` | Remove valor especifico |
| `IndexOf(const S: string): Integer` | Procura valor |

---

## 5. Aplicabilidades

1. **Passar valor de atributo a `TLDAPSend.Modify`** — construir um `TLDAPAttribute` com `AttributeName := 'mail'` + `Add('joao@empresa.local')` e passar para `MO_Replace`.
2. **Ler valores de resultado de busca** — iterar `Strings[0..Count-1]` sobre um atributo retornado em `TLDAPResult.Attributes.Items[i]`.
3. **Manipular atributos multivalorados** — `memberOf` retorna varios DNs de grupo em um unico atributo; cada `Strings[i]` e um DN.
4. **Trabalhar com atributos binarios** — ao acessar `Get('objectGUID;binary')`, o valor retornado e Base64-encoded; usar `DecodeBase64` para obter bytes raw.
5. **Atualizar senha AD** — construir atributo `unicodePwd;binary` com valor UTF-16 LE encoded e aspas-envolvido, depois `MO_Replace` (ver `TLDAPSend.SetPassword`).

---

## 6. Exemplos de uso

### 6.1 Adicionar email a um usuario (Modify replace)

```pascal
uses SysUtils, ldapsend;

var
  LLDAP: TLDAPSend;
  LAttr: TLDAPAttribute;
begin
  LLDAP := TLDAPSend.Create;
  LAttr := TLDAPAttribute.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL := True;
    LLDAP.Login;
    LLDAP.Bind;

    LAttr.AttributeName := 'mail';
    LAttr.Add('joao.silva@empresa.local');

    if LLDAP.Modify('CN=Joao,OU=Users,DC=empresa,DC=local',
                    MO_Replace, LAttr) then
      Writeln('Email atualizado')
    else
      Writeln('Erro: ', LLDAP.ResultString);
  finally
    LAttr.Free;
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.2 Ler valores de atributo multivalorado (memberOf)

```pascal
uses SysUtils, ldapsend, Classes;

var
  LLDAP: TLDAPSend;
  LAttrs: TStringList;
  LAttr: TLDAPAttribute;
  I: Integer;
begin
  LLDAP := TLDAPSend.Create;
  LAttrs := TStringList.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL := True;
    LLDAP.Login;
    LLDAP.Bind;

    LAttrs.Add('memberOf');
    LLDAP.Search('DC=empresa,DC=local', False,
                 '(sAMAccountName=joao)', LAttrs);

    if LLDAP.SearchResult.Count > 0 then
    begin
      LAttr := LLDAP.SearchResult[0].Attributes.Find('memberOf');
      if Assigned(LAttr) then
        for I := 0 to LAttr.Count - 1 do
          Writeln('Grupo: ', LAttr.Strings[I]);
    end;
  finally
    LAttrs.Free;
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

---

## 6.3 V1.7.1 — Uso tipado (estilo TField)

```pascal
uses SysUtils, ldapsend;

var
  LLDAP: TLDAPSend;
  LAttr: TLDAPAttribute;
  LAttrs: TStringList;
  LValue: TLDAPAttributeValue;
  LUAC: Int64;
  LGUID: TGUID;
  LCreated: TDateTime;
  I: Integer;
begin
  LLDAP := TLDAPSend.Create;
  LAttrs := TStringList.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL := True;
    LLDAP.Login;
    LLDAP.Bind;

    LAttrs.Add('*');
    LLDAP.Search('DC=empresa,DC=local', False,
                 '(sAMAccountName=joao)', LAttrs);

    if LLDAP.SearchResult.Count = 0 then Exit;

    // Inteiro tipado
    LAttr := LLDAP.SearchResult[0].Attributes.Find('userAccountControl');
    if Assigned(LAttr) then
    begin
      LUAC := LAttr.Value.AsInteger;   // 66048 por exemplo
      if (LUAC and UAC_ACCOUNTDISABLE) <> 0 then
        Writeln('Conta desactivada');
    end;

    // TGUID tipado (sem parse manual dos 16 bytes LE)
    LAttr := LLDAP.SearchResult[0].Attributes.Find('objectGUID');
    if Assigned(LAttr) then
    begin
      LGUID := LAttr.Value.AsGuid;     // TGUID directo
      Writeln('GUID = ', GUIDToString(LGUID));
    end;

    // TDateTime tipado a partir de FILETIME
    LAttr := LLDAP.SearchResult[0].Attributes.Find('pwdLastSet');
    if Assigned(LAttr) then
    begin
      LCreated := LAttr.Value.AsDateTime;
      if LCreated > 0 then
        Writeln('Password alterada em: ', DateTimeToStr(LCreated));
    end;

    // Multi-valued com AsString
    LAttr := LLDAP.SearchResult[0].Attributes.Find('memberOf');
    if Assigned(LAttr) then
      for I := 0 to LAttr.Count - 1 do
        Writeln('Grupo: ', LAttr.Values[I].AsString);
  finally
    LAttrs.Free;
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

Notar que codigo V1.7.0 e anteriores continua a funcionar sem modificacao — `LAttr[I]` / `LAttr.Strings[I]` agora devolve strings ja formatadas conforme o tipo (GUID em `'{XXXXXXXX-...}'`, SID em `'S-1-5-21-...'`, integer como string numerica, FileTime como data ISO-like, etc.).

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TStringList` (Classes / System.Classes) | Heranca | Herda todos os metodos de lista de strings |
| [TLDAPAttributeList](TLDAPAttributeList.md) | Container | Lista de `TLDAPAttribute` por objeto LDAP |
| [TLDAPResult](TLDAPResult.md) | Usado por | `TLDAPResult.Attributes[i]` e um `TLDAPAttribute` |
| [TLDAPSend](TLDAPSend.md) | Consumidor | `Modify`, `ModifyPermissive`, `Add`, `SetPassword` aceitam `TLDAPAttribute` como parametro |
| [TLDAPAttributeValue](TLDAPAttributeValue.md) (V1.7.1) | Acessor tipado | Record por valor criado pelas properties `Value` e `Values[Index]`; consulta `FRawValues` e `FValueType` |
| [TLDAPValueType](TLDAPValueType.md) (V1.7.1) | Tipo enumerado | Property `ValueType` resolvida automaticamente em `SetAttributeName` via `ResolveLDAPValueType` + `LDAP_KNOWN_ATTRIBUTE_TYPES` |
| `synacode` (EncodeBase64/DecodeBase64) | Dependencia | Codificacao transparente para atributos binarios |
| `synautil` (UnquoteStr) | Dependencia | Limpeza de aspas em valores nao-binarios |
| `System.Variants` / `Variants` (V1.7.1) | Dependencia | Usada por `TLDAPAttributeValue.AsVariant` para despacho automatico conforme `ValueType` |
