---
name: activedirectoryorm-ldap-attr-types
version: 1.0.0
date: 2026-04-21
author: CSL Softwares
status: draft
scope: >
  Synapse CSL fork 001.007.004 — adicionar sistema de tipos semânticos
  (TLDAPAttrSyntax), raw bytes (AddRaw / RawValue) e conversores
  (ValueAsGUID / ValueAsSID / ValueAsDisplay / AllValuesAsDisplay)
  directamente em ldapsend.pas. Zero alterações fora de Packege/synapse/.
depends-on: ldapsend.pas 001.007.003 (CSL fork — AD Windows Server 2025)
target-file: Packege/synapse/ldapsend.pas
target-version: 001.007.003 → 001.007.004
protected-area: Packege/synapse/ — requer aprovação antes de execução
impact-on-adorm: ZERO — ActiveDirectory.Service.pas e restante src/ não tocados
target-compilers:
  - Delphi 12.x (Win32 / Win64)
  - FPC 3.2.2+ (i386-win32 / x86_64-win64)
out-of-scope:
  - Qualquer alteração em src/ (ActiveDirectory.Service.pas, Commons, Main, Views)
  - Schema query ao AD (subschema subentry) — V2.x
  - Assembly / SIMD (avaliado e descartado — ver secção 3)
  - atributos personalizados do schema da empresa
---

# ldapsend.pas 001.007.004 — Sistema de Tipos para Atributos LDAP (DRAFT)

> **Status:** draft — requer aprovação (área protegida `Packege/synapse/`).
> Plano não-executável até aprovação explícita.
> Destino: `.cursor/plans/activedirectoryorm-ldap-attr-types_V1.0.plan.md`.

---

## 1. Contexto e objectivo

O protocolo LDAP (RFC 4511) transporta **todos os valores de atributo como `OCTET STRING`
puro** — bytes sem qualquer metadado de tipo. O Synapse actualmente expõe apenas uma
distinção binária:

```pascal
property IsBinary: Boolean read FIsBinary;  // True apenas se nome contém ';binary'
```

Isto é insuficiente para o AD real:

| Problema | Causa |
|---------|-------|
| `objectGUID` (16 bytes GUID) | AD não usa sufixo `;binary` → `IsBinary = False` → bytes chegam como string corrompida |
| `objectSid` (bytes SID) | Idem — bytes chegam mojibake ou causam EEncodingError no consumidor |
| `userAccountControl` | String numérica — consumidor não sabe que é bitmask |
| `pwdLastSet` | String numérica 64-bit — consumidor não sabe que é FileTime |
| `thumbnailPhoto` | Binário puro — sem forma de obter bytes originais com fidelidade |

O objectivo deste plano é adicionar, **exclusivamente em `ldapsend.pas`**, um sistema
completo de tipos e acesso a bytes brutos, de forma que qualquer consumidor do Synapse
(ActiveDirectoryORM ou outro) receba a informação completa sem precisar de camadas extras.

**ActiveDirectoryORM fica inalterado.** O serviço passa a ter acesso às novas
propriedades via `TLDAPAttribute` melhorado, mas nenhum ficheiro em `src/` precisa de
ser alterado para o sistema funcionar.

---

## 2. Diagnóstico do parser — pontos de inserção exactos

Existem **dois pontos** no código onde o parser ASN.1 popula atributos de resultado.
Ambos têm exactamente o mesmo padrão:

```pascal
// TLDAPSend.Search — linha 1489-1498
a := r.Attributes.Add;
u := ASNItem(n, t, x);       // u = nome do atributo (AnsiString)
a.AttributeName := u;
ASNItem(n, t, x);
if x = ASN1_SETOF then
  while n < i do
  begin
    u := ASNItem(n, t, x);   // u = bytes brutos do valor (OCTET STRING)
    a.Add(u);                 // ← PONTO A — linha 1497
  end;

// TLDAPSend.DoSearchAD — linha 1662-1671 (parser alternativo para controlo DirSync)
// Padrão idêntico → a.Add(u) na linha 1670  ← PONTO B
```

`u` nestes pontos é o `AnsiString` devolvido por `ASNItem` — contém os **bytes brutos**
do ASN.1 `OCTET STRING` antes de qualquer conversão. É o único momento em que os bytes
estão disponíveis sem perda.

`a.Add(u)` chama internamente `Put(Index, Value)`, que **pode codificar em Base64**
(quando `IsBinary = True`) — depois disso os bytes originais ficam inacessíveis.

A solução: substituir `a.Add(u)` por `a.AddRaw(u)` nos dois pontos. `AddRaw` armazena
os bytes numa estrutura paralela **antes** de chamar `Add`.

---

## 3. Avaliação de Assembly e SIMD

**Assembly descartado — tecnicamente desnecessário.**

| Candidato a SIMD | Viável? | Razão para descartar |
|-----------------|---------|----------------------|
| Varredura UTF-8 | Não | Volume de dados por query < 1 MB; tempo de parse < 1 ms — irrelevante |
| Detecção de padrão GUID/SID | Não | 8–20 bytes — qualquer loop Pascal termina em < 100 ns |
| Lookup de dicionário | Não | Busca binária em array de ~80 entradas = 7 comparações máximo |

O gargalo é sempre a **latência de rede** (1–50 ms por query LDAP). O parsing de bytes
é ordens de magnitude mais rápido. Assembly introduziria dependência de arquitectura
(`{$IFDEF CPUX86_64}`) quebrando o cross-compiler FPC/Delphi sem ganho mensurável.

**Conclusão: Pascal puro é a solução correcta e única necessária.**

---

## 4. Alterações à secção `interface` de `ldapsend.pas`

### 4.1 Enum `TLDAPAttrSyntax` — inserir antes de `TLDAPAttribute`

```pascal
{: Sintaxe semântica de um atributo LDAP / AD.
   Determinada pelo dicionário estático de nomes conhecidos + heurística nos bytes.
   O protocolo LDAP (RFC 4511) não transporta informação de tipo — esta enum é
   inferida pelo cliente. }
TLDAPAttrSyntax = (
  lasUnknown,         // não identificado — usar heurística ou tratar como string
  lasString,          // UTF-8 / IA5 — texto normal (cn, sAMAccountName, mail, ...)
  lasDN,              // Distinguished Name (CN=...,DC=...) — sempre ASCII
  lasInteger,         // inteiro signed 32-bit como string decimal
  lasLargeInteger,    // inteiro signed 64-bit como string decimal (FileTime, USN)
  lasBitFlags,        // inteiro com semântica de bitmask (userAccountControl, ...)
  lasBoolean,         // string "TRUE" ou "FALSE"
  lasBinaryGUID,      // 16 bytes little-endian → {xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}
  lasBinarySID,       // bytes binários SID → "S-1-5-21-..."
  lasBinaryRaw,       // binário opaco — representado em hex pelo consumidor
  lasGeneralizedTime, // "YYYYMMDDHHmmss.0Z" — timestamp AD
  lasOID,             // OID numérico (objectClass values, etc.)
  lasEnum             // inteiro com conjunto fixo de valores semânticos
);
```

### 4.2 `TLDAPAttribute` — novos membros

Adições ao bloco `private` / `public` / `published` existente:

```pascal
TLDAPAttribute = class(TStringList)
private
  FAttributeName: AnsiString;
  FIsBinary: Boolean;
  FAttributeSyntax: TLDAPAttrSyntax;   // NOVO — inferido em SetAttributeName
  FRawValues: array of TBytes;         // NOVO — bytes ASN.1 originais, paralelo ao TStringList
protected
  function Get(Index: integer): string; override;
  procedure Put(Index: integer; const Value: string); override;
  procedure SetAttributeName(Value: AnsiString);
public
  procedure Clear; override;                               // NOVO — reset FRawValues
  function Add(const S: string): Integer; override;
  procedure AddRaw(const ARaw: AnsiString);                // NOVO — parser usa este
  function RawValue(Index: Integer): TBytes;               // NOVO — bytes brutos [Index]
  function ValueAsGUID(Index: Integer = 0): string;        // NOVO — 16 bytes → GUID string
  function ValueAsSID(Index: Integer = 0): string;         // NOVO — bytes → S-1-5-21-...
  function ValueAsDisplay(Index: Integer = 0): string;     // NOVO — melhor repr. por sintaxe
  function AllValuesAsDisplay: string;                     // NOVO — todos os valores unidos
published
  property AttributeName: AnsiString read FAttributeName write SetAttributeName;
  property IsBinary: Boolean read FIsBinary;
  property AttributeSyntax: TLDAPAttrSyntax read FAttributeSyntax;  // NOVO
end;
```

### 4.3 Funções globais (interface)

```pascal
{ Devolve o nome legível da sintaxe — para debug / UI }
function LDAPAttrSyntaxName(const ASyntax: TLDAPAttrSyntax): string;

{ Lookup directo no dicionário estático — lasUnknown se não encontrado }
function LDAPAttrSyntaxFromName(const AName: AnsiString): TLDAPAttrSyntax;

{ Converte TBytes para string hexadecimal "xx xx xx ..." }
function LDAPBytesToHex(const ABytes: TBytes): string;
```

---

## 5. Alterações à secção `implementation` de `ldapsend.pas`

### 5.1 Dicionário estático — sorted array + binary search (cross-compiler)

Sem generics (`TDictionary` / `TFPGMap`) para garantir cross-compiler FPC ≥ 3.0 e
Delphi ≥ 10.x sem dependências extra. Busca binária em array ordenado = 7 comparações
no pior caso para ~80 entradas.

```pascal
type
  TLDAPAttrKnown = record
    Name: string;
    Syntax: TLDAPAttrSyntax;
  end;

const
  // Ordenado alfabeticamente (case insensitive) para binary search
  LDAP_KNOWN_ATTRS: array[0..84] of TLDAPAttrKnown = (
    // --- Binários GUID ---
    (Name: 'mS-DS-ConsistencyGuid';          Syntax: lasBinaryGUID),
    (Name: 'msDS-SourceObjectDN';            Syntax: lasBinaryGUID),
    (Name: 'msExchArchiveGUID';              Syntax: lasBinaryGUID),
    (Name: 'msExchMailboxGuid';              Syntax: lasBinaryGUID),
    (Name: 'objectGUID';                     Syntax: lasBinaryGUID),
    // --- Binários SID ---
    (Name: 'msDS-PrincipalName';             Syntax: lasBinarySID),
    (Name: 'objectSid';                      Syntax: lasBinarySID),
    (Name: 'sidHistory';                     Syntax: lasBinarySID),
    (Name: 'tokenGroups';                    Syntax: lasBinarySID),
    (Name: 'tokenGroupsGlobalAndUniversal';  Syntax: lasBinarySID),
    (Name: 'tokenGroupsNoGCAcceptable';      Syntax: lasBinarySID),
    // --- Binários opacos ---
    (Name: 'authorityRevocationList';        Syntax: lasBinaryRaw),
    (Name: 'cACertificate';                  Syntax: lasBinaryRaw),
    (Name: 'certificateRevocationList';      Syntax: lasBinaryRaw),
    (Name: 'crossCertificatePair';           Syntax: lasBinaryRaw),
    (Name: 'dNSProperty';                    Syntax: lasBinaryRaw),
    (Name: 'dnsRecord';                      Syntax: lasBinaryRaw),
    (Name: 'msExchSafeSendersHash';          Syntax: lasBinaryRaw),
    (Name: 'nTSecurityDescriptor';           Syntax: lasBinaryRaw),
    (Name: 'thumbnailPhoto';                 Syntax: lasBinaryRaw),
    (Name: 'userCertificate';               Syntax: lasBinaryRaw),
    (Name: 'userPKCS12';                     Syntax: lasBinaryRaw),
    (Name: 'userSMIMECertificate';           Syntax: lasBinaryRaw),
    // --- Boolean ---
    (Name: 'isCriticalSystemObject';         Syntax: lasBoolean),
    (Name: 'isDeleted';                      Syntax: lasBoolean),
    (Name: 'isRecycled';                     Syntax: lasBoolean),
    (Name: 'msNPAllowDialin';               Syntax: lasBoolean),
    (Name: 'showInAddressBook';              Syntax: lasBoolean),
    // --- Bitmask ---
    (Name: 'groupType';                      Syntax: lasBitFlags),
    (Name: 'instanceType';                   Syntax: lasBitFlags),
    (Name: 'msDS-Behavior-Version';          Syntax: lasBitFlags),
    (Name: 'msDS-SupportedEncryptionTypes';  Syntax: lasBitFlags),
    (Name: 'msDS-User-Account-Control-Computed'; Syntax: lasBitFlags),
    (Name: 'sAMAccountType';                 Syntax: lasBitFlags),
    (Name: 'searchFlags';                    Syntax: lasBitFlags),
    (Name: 'systemFlags';                    Syntax: lasBitFlags),
    (Name: 'userAccountControl';             Syntax: lasBitFlags),
    // --- Integer 32-bit ---
    (Name: 'adminCount';                     Syntax: lasInteger),
    (Name: 'badPwdCount';                    Syntax: lasInteger),
    (Name: 'codePage';                       Syntax: lasInteger),
    (Name: 'countryCode';                    Syntax: lasInteger),
    (Name: 'gidNumber';                      Syntax: lasInteger),
    (Name: 'logonCount';                     Syntax: lasInteger),
    (Name: 'primaryGroupID';                 Syntax: lasInteger),
    (Name: 'revision';                       Syntax: lasInteger),
    (Name: 'uidNumber';                      Syntax: lasInteger),
    (Name: 'versionNumber';                  Syntax: lasInteger),
    // --- LargeInteger / FileTime (64-bit) ---
    (Name: 'accountExpires';                 Syntax: lasLargeInteger),
    (Name: 'badPasswordTime';                Syntax: lasLargeInteger),
    (Name: 'creationTime';                   Syntax: lasLargeInteger),
    (Name: 'lastLogon';                      Syntax: lasLargeInteger),
    (Name: 'lastLogonTimestamp';             Syntax: lasLargeInteger),
    (Name: 'lockoutDuration';                Syntax: lasLargeInteger),
    (Name: 'lockoutObservationWindow';       Syntax: lasLargeInteger),
    (Name: 'lockoutTime';                    Syntax: lasLargeInteger),
    (Name: 'maxPwdAge';                      Syntax: lasLargeInteger),
    (Name: 'minPwdAge';                      Syntax: lasLargeInteger),
    (Name: 'msDS-LastSuccessfulInteractiveLogonTime'; Syntax: lasLargeInteger),
    (Name: 'pwdLastSet';                     Syntax: lasLargeInteger),
    (Name: 'uSNChanged';                     Syntax: lasLargeInteger),
    (Name: 'uSNCreated';                     Syntax: lasLargeInteger),
    (Name: 'uSNLastObjRem';                  Syntax: lasLargeInteger),
    // --- GeneralizedTime ---
    (Name: 'dsCorePropagationData';          Syntax: lasGeneralizedTime),
    (Name: 'whenChanged';                    Syntax: lasGeneralizedTime),
    (Name: 'whenCreated';                    Syntax: lasGeneralizedTime),
    // --- Distinguished Name ---
    (Name: 'defaultNamingContext';           Syntax: lasDN),
    (Name: 'directReports';                  Syntax: lasDN),
    (Name: 'distinguishedName';              Syntax: lasDN),
    (Name: 'managedBy';                      Syntax: lasDN),
    (Name: 'manager';                        Syntax: lasDN),
    (Name: 'member';                         Syntax: lasDN),
    (Name: 'memberOf';                       Syntax: lasDN),
    (Name: 'msDS-MembersOfResourcePropertyList'; Syntax: lasDN),
    (Name: 'msDS-PSOApplied';               Syntax: lasDN),
    (Name: 'objectCategory';                 Syntax: lasDN),
    (Name: 'rootDomainNamingContext';        Syntax: lasDN),
    (Name: 'schemaNamingContext';            Syntax: lasDN),
    // --- OID ---
    (Name: 'allowedAttributes';              Syntax: lasOID),
    (Name: 'objectClass';                    Syntax: lasOID),
    (Name: 'possibleInferiors';              Syntax: lasOID)
  );
```

**Nota de manutenção:** a array deve manter-se ordenada por `Name` (case-insensitive)
para que a busca binária funcione. Se forem adicionadas entradas, inserir na posição
alfabética correcta.

### 5.2 Função de lookup com busca binária

```pascal
function LDAPAttrSyntaxFromName(const AName: AnsiString): TLDAPAttrSyntax;
var
  Lo, Hi, Mid, Cmp: Integer;
  LName: string;
begin
  Result := lasUnknown;
  LName := LowerCase(string(AName));
  // Remove sufixo ;binary se presente antes do lookup
  Mid := Pos(';', LName);
  if Mid > 0 then
    LName := Copy(LName, 1, Mid - 1);
  Lo := Low(LDAP_KNOWN_ATTRS);
  Hi := High(LDAP_KNOWN_ATTRS);
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    Cmp := CompareText(LDAP_KNOWN_ATTRS[Mid].Name, LName);
    if Cmp = 0 then
    begin
      Result := LDAP_KNOWN_ATTRS[Mid].Syntax;
      Exit;
    end
    else if Cmp < 0 then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
end;
```

### 5.3 Heurística de fallback

Chamada quando `LDAPAttrSyntaxFromName` retorna `lasUnknown`. Opera sobre o
**primeiro valor bruto** do atributo (se disponível) + `IsBinary`.

```pascal
function LDAPAttrSyntaxHeuristic(const AIsBinary: Boolean;
  const ARawFirst: TBytes): TLDAPAttrSyntax;
var
  I: Integer;
  S: string;
  AllDigits: Boolean;
begin
  // 1. IsBinary detectado pelo Synapse (nome contém ;binary)
  if AIsBinary then
  begin
    Result := lasBinaryRaw;
    Exit;
  end;
  if Length(ARawFirst) = 0 then
  begin
    Result := lasString;
    Exit;
  end;
  // 2. GUID — exactamente 16 bytes
  if Length(ARawFirst) = 16 then
  begin
    Result := lasBinaryGUID;
    Exit;
  end;
  // 3. SID — byte[0]=$01, byte[1]=1 ou 5 (revision + sub-authority count plausível)
  if (Length(ARawFirst) >= 8) and
     (ARawFirst[0] = $01) and
     (ARawFirst[1] in [$01, $02, $05]) then
  begin
    Result := lasBinarySID;
    Exit;
  end;
  // 4. Todo numérico → Integer ou LargeInteger
  AllDigits := True;
  for I := Low(ARawFirst) to High(ARawFirst) do
    if not (Char(ARawFirst[I]) in ['0'..'9', '-']) then
    begin
      AllDigits := False;
      Break;
    end;
  if AllDigits and (Length(ARawFirst) > 0) then
  begin
    if Length(ARawFirst) > 10 then
      Result := lasLargeInteger
    else
      Result := lasInteger;
    Exit;
  end;
  // 5. Boolean
  S := UpperCase(string(AnsiString(ARawFirst)));
  if (S = 'TRUE') or (S = 'FALSE') then
  begin
    Result := lasBoolean;
    Exit;
  end;
  // 6. DN — começa com CN=, DC=, OU=
  if (Length(S) > 3) and
     ((Copy(S, 1, 3) = 'CN=') or (Copy(S, 1, 3) = 'DC=') or (Copy(S, 1, 3) = 'OU=')) then
  begin
    Result := lasDN;
    Exit;
  end;
  // 7. GeneralizedTime — 14 dígitos + ".0Z"
  if (Length(S) = 17) and
     (Copy(S, 15, 3) = '.0Z') then
  begin
    Result := lasGeneralizedTime;
    Exit;
  end;
  // 8. Fallback
  Result := lasString;
end;
```

### 5.4 `SetAttributeName` — trigger de detecção de sintaxe

```pascal
procedure TLDAPAttribute.SetAttributeName(Value: AnsiString);
begin
  FAttributeName := Value;
  FIsBinary := Pos(';binary', LowerCase(string(Value))) > 0;
  // Lookup no dicionário — heurística aplicada em AddRaw quando há bytes disponíveis
  FAttributeSyntax := LDAPAttrSyntaxFromName(Value);
  if FAttributeSyntax = lasUnknown then
  begin
    if FIsBinary then
      FAttributeSyntax := lasBinaryRaw;
    // Se ainda Unknown, a heurística será aplicada em AddRaw no primeiro valor
  end;
end;
```

### 5.5 `AddRaw` — armazena bytes brutos + chama `Add` existente

```pascal
procedure TLDAPAttribute.AddRaw(const ARaw: AnsiString);
var
  LBytes: TBytes;
  LIdx: Integer;
begin
  // 1. Guardar bytes originais antes de qualquer conversão
  LIdx := Count;  // índice que o próximo Add irá ocupar
  SetLength(FRawValues, LIdx + 1);
  SetLength(FRawValues[LIdx], Length(ARaw));
  if Length(ARaw) > 0 then
    Move(ARaw[1], FRawValues[LIdx][0], Length(ARaw));
  // 2. Refinar heurística com os bytes reais (apenas no primeiro valor)
  if (LIdx = 0) and (FAttributeSyntax = lasUnknown) then
    FAttributeSyntax := LDAPAttrSyntaxHeuristic(FIsBinary, FRawValues[0]);
  // 3. Caminho existente — Add pode codificar em Base64 se IsBinary=True
  Add(ARaw);
end;
```

### 5.6 Override de `Clear` — mantém FRawValues sincronizado

```pascal
procedure TLDAPAttribute.Clear;
begin
  inherited Clear;
  SetLength(FRawValues, 0);
end;
```

### 5.7 `RawValue` — acesso por índice

```pascal
function TLDAPAttribute.RawValue(Index: Integer): TBytes;
begin
  if (Index >= 0) and (Index < Length(FRawValues)) then
    Result := FRawValues[Index]
  else
    SetLength(Result, 0);
end;
```

### 5.8 `ValueAsGUID` — 16 bytes little-endian → string UUID

O AD armazena o GUID em codificação mixed-endian:
componentes 1-3 little-endian (inversos), 4-5 big-endian.

```pascal
function TLDAPAttribute.ValueAsGUID(Index: Integer): string;
var
  B: TBytes;
begin
  B := RawValue(Index);
  if Length(B) <> 16 then
  begin
    Result := '';
    Exit;
  end;
  Result := Format('{%.2x%.2x%.2x%.2x-%.2x%.2x-%.2x%.2x-%.2x%.2x-%.2x%.2x%.2x%.2x%.2x%.2x}',
    [B[3], B[2], B[1], B[0],        // Data1 (little-endian → big)
     B[5], B[4],                    // Data2
     B[7], B[6],                    // Data3
     B[8], B[9],                    // Data4[0..1]
     B[10], B[11], B[12], B[13], B[14], B[15]]);  // Data4[2..7]
end;
```

### 5.9 `ValueAsSID` — bytes SID binário → string S-1-5-21-...

```pascal
function TLDAPAttribute.ValueAsSID(Index: Integer): string;
var
  B: TBytes;
  Revision, SubAuthCount: Byte;
  IdAuth: Int64;
  SubAuth: Cardinal;
  I: Integer;
begin
  B := RawValue(Index);
  Result := '';
  if Length(B) < 8 then Exit;
  Revision    := B[0];
  SubAuthCount := B[1];
  // Identifier Authority: 6 bytes big-endian (bytes 2..7)
  IdAuth := 0;
  for I := 2 to 7 do
    IdAuth := (IdAuth shl 8) or B[I];
  Result := 'S-' + IntToStr(Revision) + '-' + IntToStr(IdAuth);
  // Sub-authorities: 4 bytes each, little-endian
  for I := 0 to SubAuthCount - 1 do
  begin
    if (8 + I * 4 + 3) > High(B) then Break;
    SubAuth :=
      Cardinal(B[8 + I * 4]) or
      (Cardinal(B[9 + I * 4])  shl 8) or
      (Cardinal(B[10 + I * 4]) shl 16) or
      (Cardinal(B[11 + I * 4]) shl 24);
    Result := Result + '-' + IntToStr(SubAuth);
  end;
end;
```

### 5.10 `ValueAsDisplay` — selecciona melhor representação por sintaxe

```pascal
function TLDAPAttribute.ValueAsDisplay(Index: Integer): string;
begin
  case FAttributeSyntax of
    lasBinaryGUID:      Result := ValueAsGUID(Index);
    lasBinarySID:       Result := ValueAsSID(Index);
    lasBinaryRaw:       Result := LDAPBytesToHex(RawValue(Index));
    lasBitFlags:
    begin
      Result := Items[Index];
      if Result <> '' then
        Result := Result + ' (0x' + IntToHex(StrToInt64Def(Result, 0), 1) + ')';
    end;
  else
    // lasString, lasDN, lasInteger, lasLargeInteger, lasBoolean,
    // lasGeneralizedTime, lasOID, lasEnum, lasUnknown
    Result := Items[Index];
  end;
end;
```

### 5.11 `AllValuesAsDisplay` — todos os valores separados por '; '

```pascal
function TLDAPAttribute.AllValuesAsDisplay: string;
var
  I: Integer;
begin
  if Count = 0 then
  begin
    Result := '';
    Exit;
  end;
  Result := ValueAsDisplay(0);
  for I := 1 to Count - 1 do
    Result := Result + '; ' + ValueAsDisplay(I);
end;
```

### 5.12 `LDAPBytesToHex` e `LDAPAttrSyntaxName` (funções globais)

```pascal
function LDAPBytesToHex(const ABytes: TBytes): string;
var
  I: Integer;
begin
  if Length(ABytes) = 0 then
  begin
    Result := '';
    Exit;
  end;
  Result := 'HEX:';
  for I := Low(ABytes) to High(ABytes) do
  begin
    if I > Low(ABytes) then
      Result := Result + ' ';
    Result := Result + IntToHex(ABytes[I], 2);
  end;
end;

function LDAPAttrSyntaxName(const ASyntax: TLDAPAttrSyntax): string;
const
  NAMES: array[TLDAPAttrSyntax] of string = (
    'Unknown', 'String', 'DN', 'Integer', 'LargeInteger',
    'BitFlags', 'Boolean', 'BinaryGUID', 'BinarySID',
    'BinaryRaw', 'GeneralizedTime', 'OID', 'Enum');
begin
  Result := NAMES[ASyntax];
end;
```

### 5.13 Dois pontos de substituição no parser — sem mais alterações

| Linha | Antes | Depois |
|-------|-------|--------|
| **1497** (`TLDAPSend.Search`) | `a.Add(u);` | `a.AddRaw(u);` |
| **1670** (`TLDAPSend.DoSearchAD`) | `a.Add(u);` | `a.AddRaw(u);` |

São as **únicas alterações ao código existente**. Todo o resto são adições puras.

---

## 6. Impacto em ActiveDirectoryORM — ZERO

Nenhum ficheiro em `src/` precisa de ser alterado:

- `GetAttributeValue` em `ActiveDirectory.Service.pas` continua a funcionar como está
  (usa `Items[0]`, `IsBinary`, etc. — tudo mantido).
- O EEncodingError fix (V1.5.1) mantém-se activo — `ADLdapBytesToDisplayString`
  continua válido.
- O consumidor que quiser tirar partido dos novos dados pode chamar directamente
  `AAttribute.ValueAsDisplay(0)`, `AAttribute.ValueAsGUID(0)`, etc. — sem precisar
  de qualquer camada adicional.

**O ActiveDirectoryORM beneficia automaticamente** na próxima vez que `GetAttributeValue`
for refactorizado (opcional, futuro) para delegar em `AllValuesAsDisplay`.

---

## 7. Ficheiro afectado

| Ficheiro | Acção | Versão |
|---------|-------|--------|
| `Packege/synapse/ldapsend.pas` | Adições na interface + implementation; 2 substituições no parser | **001.007.003 → 001.007.004** |

Nenhum outro ficheiro é tocado.

---

## 8. Gates de validação

| Gate | Descrição | Evidência |
|------|-----------|-----------|
| G1 | `ldapsend.pas` compila em Delphi Win32 | `dcc32 ActiveDirectoryORM.dpr` exit code 0, zero warnings |
| G2 | `ldapsend.pas` compila em Delphi Win64 | `dcc64 ActiveDirectoryORM.dpr` exit code 0, zero warnings |
| G3 | `ldapsend.pas` compila em FPC Win32 | `fpc @fpc32.opts` exit code 0, zero warnings novos |
| G4 | `ldapsend.pas` compila em FPC Win64 | `fpc @fpc64.opts` exit code 0, zero warnings novos |
| G5 | `GetObjectAttributes` percorre todos os atributos sem excepção | Teste manual com `LAttrList.Add('*')` — sem EEncodingError |
| G6 | `objectGUID.ValueAsGUID(0)` → formato `{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}` | Comparar com PowerShell `(Get-ADUser ...).ObjectGUID` |
| G7 | `objectSid.ValueAsSID(0)` → formato `S-1-5-21-...` | Comparar com PowerShell `(Get-ADUser ...).SID` |
| G8 | `userAccountControl.AttributeSyntax` = `lasBitFlags` | Assert no form de teste |
| G9 | `pwdLastSet.AttributeSyntax` = `lasLargeInteger` | Assert no form de teste |
| G10 | `thumbnailPhoto.ValueAsDisplay(0)` começa com `HEX:ff d8` (JPEG) | Verificação manual |
| G11 | `whenCreated.AttributeSyntax` = `lasGeneralizedTime` | Assert no form de teste |
| G12 | Atributo desconhecido heurística: 16 bytes → `lasBinaryGUID` | Unit test com bytes sintéticos |
| G13 | Regressão: `TLDAPAttribute.IsBinary` e `TLDAPAttribute.AttributeName` inalterados | Comparação comportamental com V1.007.003 |

---

## 9. Fases de execução

### F1 — Interface (adições puras, sem quebrar nada)

1. Inserir `TLDAPAttrSyntax` antes de `TLDAPAttribute` na secção `interface`.
2. Adicionar campos `FAttributeSyntax` e `FRawValues` ao bloco `private`.
3. Declarar os novos métodos e propriedade `AttributeSyntax` em `public` / `published`.
4. Declarar funções globais `LDAPAttrSyntaxFromName`, `LDAPBytesToHex`, `LDAPAttrSyntaxName`.
5. Compilar interface → verificar zero erros antes de tocar na implementation.

### F2 — Implementation: dicionário, heurística, helpers

1. Implementar constante `LDAP_KNOWN_ATTRS` (array sorted).
2. Implementar `LDAPAttrSyntaxFromName` (binary search).
3. Implementar `LDAPAttrSyntaxHeuristic`.
4. Implementar `LDAPBytesToHex` e `LDAPAttrSyntaxName`.
5. Actualizar `SetAttributeName` com trigger de detecção.
6. Implementar `TLDAPAttribute.Clear` override.
7. Implementar `AddRaw`.
8. Implementar `RawValue`, `ValueAsGUID`, `ValueAsSID`, `ValueAsDisplay`, `AllValuesAsDisplay`.

### F3 — Parser: 2 substituições cirúrgicas

1. Linha **1497**: `a.Add(u);` → `a.AddRaw(u);`
2. Linha **1670**: `a.Add(u);` → `a.AddRaw(u);`

### F4 — Compilação e gates

1. Compilar Delphi Win32 / Win64 → Gates G1 e G2.
2. Compilar FPC Win32 / Win64 → Gates G3 e G4.
3. Teste manual no form de teste → Gates G5 a G13.
4. Bump cabeçalho: `001.007.003` → `001.007.004`.
5. Adicionar entrada de changelog no cabeçalho do ficheiro.

---

**Changelog (este arquivo):**

- 1.0.0 (2026-04-21): Versão inicial. Plano 100% focado em ldapsend.pas; zero impacto em ActiveDirectoryORM.
