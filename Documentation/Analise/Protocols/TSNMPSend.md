# TSNMPSend

**Unit:** `snmpsend.pas` | **Versao:** 004.000.000 | **Tipo:** Classe (+ TSNMPRec + TSNMPMib) | **Origem:** Upstream

---

## 1. O que e?

`TSNMPSend` e o cliente SNMP do Synapse com suporte completo a SNMPv1 (RFC-1157), SNMPv2c (RFC-1901) e SNMPv3 (RFC-3412/3414/3416/3826). Implementa toda a familia de PDUs: GetRequest, GetNextRequest, GetResponse, SetRequest, GetBulkRequest, Trap (v1 e v2), InformRequest e Report.

Trabalha em conjunto com tres estruturas colaborantes: `TSNMPSend` (transporte UDP + gestao de sincronizacao v3), `TSNMPRec` (um packet SNMP decodificado/a-codificar com todas as PDU variables + metadata de auth/priv v3) e `TSNMPMib` (uma variable binding `OID + Value + ValueType`).

Para SNMPv3 suporta autenticacao MD5 e SHA1 e privacidade DES, 3DES e AES. Gere automaticamente a sincronizacao com o agente (discovery do EngineID, EngineBoots, EngineTime) antes do primeiro request autenticado.

## 2. Caracteristicas

- SNMPv1 / v2c / v3 (RFC-1157, 1901, 3412/3414/3416/3826)
- Auth hashes SNMPv3: MD5, SHA1
- Priv encryption SNMPv3: DES, 3DES, AES
- Community-based (v1/v2c) + User-based (v3)
- GetRequest, GetNextRequest, SetRequest, GetBulkRequest, InformRequest
- Trap v1 + Trap v2 (send e receive)
- Funcoes globais convenientes: `SNMPGet`, `SNMPSet`, `SNMPGetNext`, `SNMPGetTable`, `SendTrap`, `RecvTrap`

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Porta SNMP | `cSnmpProtocol = '161'` |
| Porta Traps | `cSnmpTrapProtocol = '162'` |
| Versao SNMP | `SNMP_V1=0`, `SNMP_V2C=1`, `SNMP_V3=3` |
| Herda de | `TSynaClient` |
| Transporte | UDP |
| MaxSize default SNMPv3 | 1472 bytes |

### 3.1 PDU Types

| Const | Valor | Significado |
| --- | --- | --- |
| `PDUGetRequest` | `$A0` | Query simples |
| `PDUGetNextRequest` | `$A1` | Walk |
| `PDUGetResponse` | `$A2` | Resposta |
| `PDUSetRequest` | `$A3` | Write |
| `PDUTrap` | `$A4` | Trap v1 (obsoleto) |
| `PDUGetBulkRequest` | `$A5` | Bulk (v2+) |
| `PDUInformRequest` | `$A6` | Inform |
| `PDUTrapV2` | `$A7` | Trap v2/v3 |
| `PDUReport` | `$A8` | Report (v3) |

### 3.2 Error codes

| Const | Valor | Significado |
| --- | --- | --- |
| `ENoError` | 0 | OK |
| `ETooBig` | 1 | Payload excede MaxSize |
| `ENoSuchName` | 2 | OID inexistente |
| `EBadValue` | 3 | Valor invalido em SET |
| `EReadOnly` | 4 | OID read-only |
| `EGenErr` | 5 | Erro generico |
| `ENoAccess` | 6 | Sem permissao (v2+) |
| `EAuthorizationError` | 16 | Falha v3 auth |
| ... | ... | ver codigo fonte para v2 extended errors (7..18) |

### 3.3 Enums SNMPv3

| Tipo | Valores |
| --- | --- |
| `TV3Flags` | `NoAuthNoPriv`, `AuthNoPriv`, `AuthPriv` |
| `TV3Auth` | `AuthMD5`, `AuthSHA1` |
| `TV3Priv` | `PrivDES`, `Priv3DES`, `PrivAES` |

## 4. Funcionalidades

### 4.1 TSNMPMib

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| OID | `property AnsiString;` | OID em formato string. |
| Value | `property AnsiString;` | Valor associado. |
| ValueType | `property Integer;` | Tipo ASN.1 (usar `ASN1_NULL` em queries). |

### 4.2 TSNMPRec - ciclo

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Create | `constructor Create;` | Aloca `TSNMPMibList`. |
| Destroy | `destructor Destroy; override;` | Liberta. |
| Clear | `procedure Clear;` | Reset para defaults. |

### 4.3 TSNMPRec - codec

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| DecodeBuf | `function DecodeBuf(Buffer: AnsiString): Boolean;` | Parse de packet SNMP. |
| EncodeBuf | `function EncodeBuf: AnsiString;` | Serializa propriedades em bytes. |
| MIBAdd | `procedure MIBAdd(const MIB, Value: AnsiString; ValueType: Integer);` | Adiciona variable binding. |
| MIBDelete | `procedure MIBDelete(Index: Integer);` | Remove entry. |
| MIBGet | `function MIBGet(const MIB: AnsiString): AnsiString;` | Valor por OID. |
| MIBCount | `function MIBCount: integer;` | Numero de bindings. |
| MIBByIndex | `function MIBByIndex(Index: Integer): TSNMPMib;` | Acesso por indice. |

### 4.4 TSNMPRec - properties principais

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Version | `property Integer;` | 0, 1, 3. |
| Community | `property AnsiString;` | Community v1/v2c. |
| PDUType | `property Integer;` | PDU\_* constants. |
| ID | `property Integer;` | Request ID. |
| ErrorStatus / ErrorIndex | `property Integer;` | Error info. |
| NonRepeaters / MaxRepetitions | `property Integer;` | Bulk request. |
| Flags | `property TV3Flags;` | SNMPv3 security level. |
| AuthMode / PrivMode | `property TV3Auth / TV3Priv;` | Hashes / cifras v3. |
| UserName / Password / PrivPassword | `property AnsiString;` | Creds v3. |
| AuthEngineID / AuthEngineBoots / AuthEngineTime | `property ...;` | State v3 sincronizado. |
| OldTrapEnterprise / OldTrapHost / OldTrapGen / OldTrapSpec / OldTrapTimeTicks | `property ...;` | Fields para trap v1. |
| SNMPMibList | `property TSNMPMibList;` | Lista de bindings. |

### 4.5 TSNMPSend

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| SendRequest | `function SendRequest: Boolean;` | Envia `Query` e le `Reply`. Em v3 faz discovery antes. |
| SendTrap | `function SendTrap: Boolean;` | Envia trap (sem esperar reply). |
| RecvTrap | `function RecvTrap: Boolean;` | Recebe trap entrante. |
| DoIt | `function DoIt: Boolean;` | Alias para `SendRequest` (compat). |
| Query | `property TSNMPRec;` | Packet de saida. |
| Reply | `property TSNMPRec;` | Packet de entrada. |
| Buffer | `property AnsiString;` | Raw bytes. |
| HostIP | `property AnsiString;` | IP do peer. |
| Sock | `property TUDPBlockSocket;` | UDP socket. |

### 4.6 Funcoes globais

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| SNMPGet | `function SNMPGet(const OID, Community, SNMPHost: AnsiString; var Value: AnsiString): Boolean;` | GET one-shot. |
| SNMPSet | `function SNMPSet(const OID, Community, SNMPHost, Value: AnsiString; ValueType: Integer): Boolean;` | SET one-shot. |
| SNMPGetNext | `function SNMPGetNext(var OID: AnsiString; const Community, SNMPHost: AnsiString; var Value: AnsiString): Boolean;` | Walk step. |
| SNMPGetTable | `function SNMPGetTable(const BaseOID, Community, SNMPHost: AnsiString; const Value: TStrings): Boolean;` | Ler tabela inteira. |
| SNMPGetTableElement | `function SNMPGetTableElement(const BaseOID, RowID, ColID, Community, SNMPHost: AnsiString; var Value: AnsiString): Boolean;` | Cell row x col. |
| SendTrap | `function SendTrap(const Dest, Source, Enterprise, Community: AnsiString; Generic, Specific, Seconds: Integer; const MIBName, MIBValue: AnsiString; MIBtype: Integer): Integer;` | Trap v1. |
| SendTrapV2c | `function SendTrap(...): Integer;` | Variante v2c. |
| RecvTrap | `function RecvTrap(var Dest, Source, Enterprise, Community: AnsiString; var Generic, Specific, Seconds: Integer; const MIBName, MIBValue: TStringList): Integer;` | Receber trap. |

## 5. Aplicabilidades

1. **Monitor de infraestrutura** -- query de switch/router/servidor (CPU, RAM, interfaces).
2. **Trap receiver** -- receber alarmes de equipamento e correlacionar.
3. **NOC dashboards** -- walk de IF-MIB para desenhar topologia.
4. **SNMPv3 secure management** -- comunicacao encriptada com equipamento de missao critica.
5. **Configuracao remota** -- SET em OIDs de configuracao em devices.

## 6. Exemplos de uso

### 6.1 Get simples com funcao global

```pascal
uses
  SysUtils, snmpsend;

var
  LValue: AnsiString;
begin
  if SNMPGet('1.3.6.1.2.1.1.5.0', // sysName
             'public',
             '192.168.1.1',
             LValue) then
    Writeln('sysName = ', LValue);
end.
```

### 6.2 Walk com SNMPGetNext

```pascal
uses
  SysUtils, snmpsend;

var
  LOID, LValue: AnsiString;
begin
  LOID := '1.3.6.1.2.1.2.2.1.2'; // ifDescr
  while SNMPGetNext(LOID, 'public', '10.0.0.1', LValue) do
    if Pos('1.3.6.1.2.1.2.2.1.2.', LOID) = 1 then
      Writeln(LOID, ' = ', LValue)
    else
      Break;
end.
```

### 6.3 SNMPv3 AuthPriv via TSNMPSend

```pascal
uses
  SysUtils, Classes, snmpsend, asn1util;

var
  LSnmp: TSNMPSend;
begin
  LSnmp := TSNMPSend.Create;
  try
    LSnmp.TargetHost := '10.0.0.1';
    LSnmp.Query.Clear;
    LSnmp.Query.Version := SNMP_V3;
    LSnmp.Query.PDUType := PDUGetRequest;
    LSnmp.Query.UserName := 'monitor';
    LSnmp.Query.Password := 'authSecret123';
    LSnmp.Query.PrivPassword := 'privSecret456';
    LSnmp.Query.AuthMode := AuthSHA1;
    LSnmp.Query.PrivMode := PrivAES;
    LSnmp.Query.Flags := AuthPriv;
    LSnmp.Query.MIBAdd('1.3.6.1.2.1.1.1.0', '', ASN1_NULL); // sysDescr
    if LSnmp.SendRequest then
      Writeln('sysDescr = ', LSnmp.Reply.MIBGet('1.3.6.1.2.1.1.1.0'));
  finally
    LSnmp.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` | Superclasse | Host/porta/timeout. |
| `TSNMPRec` | Composicao | Packet SNMP. |
| `TSNMPMib` | Elemento | Variable binding. |
| `TUDPBlockSocket` | Composicao | Socket UDP. |
| `asn1util` | Dependencia | Codec ASN.1 / BER. |
| `synacrypt` | Dependencia | MD5/SHA1/DES/3DES/AES para v3. |
| `synacode` | Dependencia | Base e utils. |
| `synaip` | Dependencia | Parse IP. |
