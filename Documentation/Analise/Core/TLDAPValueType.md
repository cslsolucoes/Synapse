# TLDAPValueType / ldapsend.pas

**Unit:** `ldapsend.pas` | **Versao:** 001.007.005 (CSL fork V1.7.2; introduzido em V1.7.1 / 001.007.004) | **Tipo:** Enum publico + Mapa estatico + Funcao publica | **Origem:** 100% CSL (sem precedente upstream)

---

## 1. O que e?

`TLDAPValueType` e um enum publico introduzido em **Synapse CSL V41.2 / `ldapsend.pas` 001.007.004** (2026-04-22) que classifica o tipo semantico de um valor de atributo LDAP segundo os padroes **RFC 4517** (LDAP Syntaxes and Matching Rules) e **MS-ADTS** (Active Directory Technical Specification).

Existe para resolver dois problemas do LDAP generico em contexto Active Directory:

1. **AD nao marca atributos binarios com `;binary`** — `objectGUID`, `objectSid`, `thumbnailPhoto`, `userCertificate`, `nTSecurityDescriptor` sao devolvidos com o nome simples. O check `FIsBinary := Pos(';binary', ...)` falha e o Synapse tentava decodar como texto, levando a `EEncodingError` em Delphi 12 strict ou a "lixo" visualizado no consumidor.
2. **Consumidores duplicam logica de formatacao** — cada cliente LDAP implementa o seu proprio parser de `objectGUID` (16 bytes LE → `TGUID`), `objectSid` (MS-ADTS → `'S-1-5-21-...'`), `pwdLastSet` (FILETIME Int64 → `TDateTime`), `whenCreated` (Generalized Time → ISO). Com `TLDAPValueType` + `TLDAPAttributeValue` a formatacao passa a estar centralizada no vendor Synapse.

O enum e consultado por:

- **`TLDAPAttribute.SetAttributeName`** — resolve automaticamente `FValueType := ResolveLDAPValueType(Value)`.
- **`TLDAPAttribute.Get(Index)`** — despacho `case FValueType of ... end` para formatar a string devolvida.
- **`TLDAPAttributeValue` (record acessor)** — `AsString` / `AsInteger` / `AsDateTime` / `AsBinary` / `AsHex` / `AsSid` / `AsGuid` / `AsVariant` usam `FValueType` para despachar o decoder correcto.

---

## 2. Declaracao

```pascal
type
  TLDAPValueType = (
    vtUnknown,            // 0 — nao resolvido (cai em UTF-8 com fallback Latin-1)
    vtDirectoryString,    // 1 — RFC 4517 1.3.6.1.4.1.1466.115.121.1.15 — texto UTF-8
    vtIA5String,          // 2 — RFC 4517 1.3.6.1.4.1.1466.115.121.1.26 — ASCII
    vtInteger,            // 3 — RFC 4517 1.3.6.1.4.1.1466.115.121.1.27 — Int64
    vtBoolean,            // 4 — RFC 4517 1.3.6.1.4.1.1466.115.121.1.7  — TRUE/FALSE
    vtOctetString,        // 5 — RFC 4517 1.3.6.1.4.1.1466.115.121.1.40 — bytes → hex
    vtGeneralizedTime,    // 6 — RFC 4517 1.3.6.1.4.1.1466.115.121.1.24 — YYYYMMDDHHMMSS.0Z
    vtUTCTime,            // 7 — RFC 4517 1.3.6.1.4.1.1466.115.121.1.53 — YYMMDDHHMMSSZ
    vtDN,                 // 8 — RFC 4517 1.3.6.1.4.1.1466.115.121.1.12 — Distinguished Name
    vtOID,                // 9 — RFC 4517 1.3.6.1.4.1.1466.115.121.1.38 — dotted OID
    vtSID,                // 10 — MS-ADTS binary → 'S-1-5-21-...' (RawToSid)
    vtGUID,               // 11 — MS-ADTS 16 bytes LE → TGUID / '{XXXXXXXX-...}' (RawBytesToGuid)
    vtBitString,          // 12 — RFC 4517 1.3.6.1.4.1.1466.115.121.1.6
    vtNumericString,      // 13 — RFC 4517 1.3.6.1.4.1.1466.115.121.1.36
    vtEnhancedGuide,      // 14 — RFC 4517 1.3.6.1.4.1.1466.115.121.1.21
    vtFileTime            // 15 — MS-ADTS Int64 ASCII 100-ns desde 1601 → TDateTime
  );
```

---

## 3. Mapa `LDAP_KNOWN_ATTRIBUTE_TYPES`

Constante estatica em `implementation` do `ldapsend.pas` mapeando **~110 atributos AD** mais comuns para `TLDAPValueType`. Cobre:

| Categoria | Exemplos |
| --- | --- |
| **GUID** | `objectGUID`, `schemaIDGUID`, `attributeSecurityGUID`, `msExchMailboxGuid`, `parentGUID` |
| **SID** | `objectSid`, `sIDHistory`, `msExchMasterAccountSid`, `tokenGroups`, `tokenGroupsGlobalAndUniversal`, `tokenGroupsNoGCAcceptable` |
| **Octet String (hex)** | `thumbnailPhoto`, `jpegPhoto`, `thumbnailLogo`, `userCertificate`, `userSMIMECertificate`, `cACertificate`, `logonHours`, `nTSecurityDescriptor`, `replPropertyMetaData`, `replUpToDateVector`, `msPKIAccountCredentials`, `msPKIDPAPIMasterKeys`, `msPKIRoamingTimeStamp`, `mSMQSignCertificates`, `terminalServer`, `audio`, `photo`, `unicodePwd`, `dnsRecord`, `dNSProperty` |
| **FileTime (Int64 ASCII)** | `pwdLastSet`, `accountExpires`, `badPasswordTime`, `lastLogon`, `lastLogonTimestamp`, `lockoutTime`, `msDS-UserPasswordExpiryTimeComputed` |
| **Integer** | `userAccountControl`, `logonCount`, `badPwdCount`, `primaryGroupID`, `sAMAccountType`, `groupType`, `instanceType`, `uSNCreated`, `uSNChanged`, `uSNSource`, `revision`, `systemFlags`, `countryCode`, `codePage` |
| **Generalized Time** | `whenCreated`, `whenChanged`, `dSCorePropagationData`, `msDS-Entry-Time-To-Die` |
| **DN** | `distinguishedName`, `objectCategory`, `managedBy`, `manager`, `member`, `memberOf`, `directReports`, `secretary`, `owner`, `seeAlso` |
| **Boolean** | `showInAdvancedViewOnly`, `isDeleted`, `isRecycled` |
| **OID** | `governsID`, `attributeID`, `attributeSyntax` |
| **Directory String** | `sAMAccountName`, `userPrincipalName`, `displayName`, `givenName`, `sn`, `cn`, `description`, `ou`, `mail`, `proxyAddresses`, `mobile`, `telephoneNumber`, `facsimileTelephoneNumber`, `homePhone`, `pager`, `ipPhone`, `objectClass`, `title`, `department`, `company`, `physicalDeliveryOfficeName`, `streetAddress`, `postOfficeBox`, `postalCode`, `l`, `st`, `co`, `c`, `employeeID`, `employeeNumber`, `employeeType`, `initials`, `middleName`, `info`, `name` |
| **IA5 String** | `url`, `wWWHomePage`, `dNSHostName`, `servicePrincipalName` |

Atributos fora do mapa caem em `vtUnknown` e sao decodificados como UTF-8 com fallback Latin-1 (nunca lancam).

---

## 4. Funcao publica `ResolveLDAPValueType`

```pascal
function ResolveLDAPValueType(const AAttributeName: AnsiString): TLDAPValueType;
```

**Comportamento:**

1. Normaliza o nome: tudo apos `;` e descartado (tolera sufixos `;binary`, `;range=0-1499`).
2. Itera `LDAP_KNOWN_ATTRIBUTE_TYPES` com `SameText` (case-insensitive).
3. Retorna o match ou `vtUnknown` se o nome normalizado nao estiver no mapa.

**Exemplos:**

```pascal
ResolveLDAPValueType('objectGUID')              = vtGUID
ResolveLDAPValueType('objectGUID;binary')       = vtGUID    // sufixo tolerado
ResolveLDAPValueType('userAccountControl')      = vtInteger
ResolveLDAPValueType('whenCreated')             = vtGeneralizedTime
ResolveLDAPValueType('pwdLastSet')              = vtFileTime
ResolveLDAPValueType('memberOf;range=0-1499')   = vtDN      // tolera ;range=...
ResolveLDAPValueType('foobarCustomAttribute')   = vtUnknown // fallback
```

---

## 5. Aplicabilidades

1. **Formatacao automatica em `TLDAPAttribute.Get`** — o consumidor recebe strings ja decodificadas (`'{XXXXXXXX-...}'` para GUID, `'S-1-5-21-...'` para SID, `'2020-03-15 14:22:00'` para Generalized Time, inteiro decimal para Integer, hex para Octet String) sem precisar de decoders locais.
2. **Despacho tipado em `TLDAPAttributeValue`** — `AsString` / `AsInteger` / `AsDateTime` / `AsBinary` / `AsHex` / `AsSid` / `AsGuid` / `AsVariant` consultam `ValueType` para escolher o decoder correcto.
3. **Compatibilidade com schema AD custom** — atributos proprietarios nao mapeados caem em `vtUnknown` e saem como texto com fallback Latin-1 (nunca lancam EEncodingError). Para schemas extendidos, o roadmap V2.0.0 preve query ao `subschema` AD on-demand.
4. **Filtros e validacoes client-side** — o consumidor pode iterar atributos de um `TLDAPResult` e tratar condicionalmente cada tipo (ex.: nao mostrar `vtOctetString` em listas de utilizadores, formatar FILETIMEs em tooltip, destacar `objectSid` em cor).

---

## 6. Exemplos de uso

### 6.1 Descobrir o tipo de um atributo

```pascal
uses ldapsend;

var
  LType: TLDAPValueType;
begin
  LType := ResolveLDAPValueType('whenCreated');
  case LType of
    vtGeneralizedTime: Writeln('Atributo de data/hora LDAP');
    vtFileTime:        Writeln('Atributo AD FILETIME');
    vtGUID:            Writeln('Atributo AD GUID');
    vtSID:             Writeln('Atributo AD SID');
    vtInteger:         Writeln('Inteiro decimal ASCII');
    vtOctetString:     Writeln('Bytes arbitrarios (representado em hex)');
  else
    Writeln('Outro tipo ou desconhecido');
  end;
end;
```

### 6.2 Consultar `ValueType` directamente no atributo

```pascal
var
  LAttr: TLDAPAttribute;
begin
  LAttr := LLDAP.SearchResult[0].Attributes.Find('pwdLastSet');
  if Assigned(LAttr) and (LAttr.ValueType = vtFileTime) then
    Writeln('pwdLastSet = ', LAttr.Value.AsDateTime);
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| [TLDAPAttribute](TLDAPAttribute.md) | Consumidor | Property `ValueType: TLDAPValueType` resolvida automaticamente em `SetAttributeName`. |
| [TLDAPAttributeValue](TLDAPAttributeValue.md) | Consumidor | Record acessor cuja property `ValueType` reflecte o `FValueType` do owner; os metodos `AsXxx` fazem despacho `case ValueType of ... end`. |
| [TLDAPSend](TLDAPSend.md) | Indirecto | `Search` povoa `TLDAPResult.Attributes`, onde cada `TLDAPAttribute` tem `ValueType` resolvido. |
| `LDAP_KNOWN_ATTRIBUTE_TYPES` | Mapa estatico | Constante de `array of record Name: AnsiString; ValueType: TLDAPValueType end` no `implementation` do `ldapsend.pas`. Alimenta `ResolveLDAPValueType`. |
| **RFC 4517** | Referencia | LDAP Syntaxes and Matching Rules (BNF dos syntaxes OID). |
| **MS-ADTS** | Referencia | Active Directory Technical Specification — atributos AD proprietarios (FILETIME, objectSid, objectGUID). |

---

## 8. Roadmap

- **V2.0.0** — Query ao `subschema` do AD on-demand para resolver atributos de schema custom/extendido alem do mapa estatico. Suporta OIDs `1.3.6.1.4.1.*` especificos de aplicacoes (Exchange, Lync, etc.).
- **V1.7.2** — Mais atributos MS-ADTS no mapa estatico (replicacao, DRS, directory synchronization).
