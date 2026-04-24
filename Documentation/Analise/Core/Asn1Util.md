# Asn1Util / asn1util.pas

**Unit:** `asn1util.pas` | **Versao:** 002.001.001 | **Tipo:** Unit (funcoes livres + constantes) | **Origem:** Upstream Synapse (Lukas Gebauer + Hernan Sanchez)

---

## 1. O que e?

`asn1util` e a unit da Ararat Synapse que implementa encoding e decoding ASN.1 BER (Basic Encoding Rules) — o formato binario usado por protocolos como LDAP (RFC 4511), SNMP, X.509, SMIME e outros baseados em ASN.1 (Abstract Syntax Notation One).

A unit e puramente funcional: exporta apenas funcoes livres e constantes — nao define classes. Fornece as primitivas necessarias para (a) codificar inteiros, strings, sequences e OIDs em bytes BER, (b) decodificar streams BER extraindo type + length + value, (c) converter OIDs entre formato textual (MIB) e binario, e (d) dump legivel para debugging.

No contexto do Synapse, `asn1util` e consumido directamente por `ldapsend.pas` (monta/parseia todas as PDUs LDAP) e por `snmpsend.pas`. E a unit fundacional de qualquer protocolo ASN.1 no Synapse.

---

## 2. Caracteristicas

* Puramente funcional (sem classes).
* Suporta BER (subset de ASN.1; DER nao e garantido mas frequentemente compativel).
* Suporta ASN.1 primitivos: BOOL, INTEGER, OCTET STRING, NULL, OBJECT IDENTIFIER, ENUMERATED.
* Suporta ASN.1 constructors: SEQUENCE, SET OF.
* Suporta tipos SNMP-especificos: IPADDR, COUNTER, GAUGE, TIMETICKS, OPAQUE, COUNTER64.
* `ASNdump` produz saida human-readable indentada para debug.
* Conversao MIB-string <-> OID-binario: `MibToId`, `IdToMib`.
* Dependencia minima: apenas `SysUtils`, `Classes`, `synautil`.
* Cross-compiler (Delphi + FPC).

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| `{$Q-}` | Desabilita overflow checks (performance) |
| `{$H+}` | Long strings |
| `{$IFDEF UNICODE}` | Suprime warnings `IMPLICIT_STRING_CAST` |
| `SysUtils`, `Classes`, `synautil` (uses) | Dependencias minimas |

---

## 4. Funcionalidades

### 4.1 Constantes de tipo ASN.1

| Constante | Valor | Descricao |
| --- | --- | --- |
| `ASN1_BOOL` | `$01` | BOOLEAN |
| `ASN1_INT` | `$02` | INTEGER |
| `ASN1_OCTSTR` | `$04` | OCTET STRING |
| `ASN1_NULL` | `$05` | NULL |
| `ASN1_OBJID` | `$06` | OBJECT IDENTIFIER (OID) |
| `ASN1_ENUM` | `$0A` | ENUMERATED |
| `ASN1_SEQ` | `$30` | SEQUENCE / SEQUENCE OF |
| `ASN1_SETOF` | `$31` | SET OF |
| `ASN1_IPADDR` | `$40` | SNMP IP Address |
| `ASN1_COUNTER` | `$41` | SNMP Counter |
| `ASN1_GAUGE` | `$42` | SNMP Gauge |
| `ASN1_TIMETICKS` | `$43` | SNMP TimeTicks |
| `ASN1_OPAQUE` | `$44` | SNMP Opaque |
| `ASN1_COUNTER64` | `$46` | SNMP Counter64 |

### 4.2 Encoding (producao BER)

| Funcao | Assinatura | Descricao |
| --- | --- | --- |
| `ASNEncOIDItem` | `function ASNEncOIDItem(Value: Int64): AnsiString` | Codifica componente unico de OID (base-128, high-bit continuation) |
| `ASNEncLen` | `function ASNEncLen(Len: Integer): AnsiString` | Codifica comprimento ASN.1 (short/long form conforme valor) |
| `ASNEncInt` | `function ASNEncInt(Value: Int64): AnsiString` | Inteiro ASN.1 assinado (two's complement, big-endian, minimal bytes) |
| `ASNEncUInt` | `function ASNEncUInt(Value: Integer): AnsiString` | Inteiro ASN.1 unsigned (padding zero byte se high bit setado) |
| `ASNObject` | `function ASNObject(const Data: AnsiString; ASNType: Integer): AnsiString` | Encapsula `Data` em TLV: `AnsiChar(ASNType) + ASNEncLen(Length(Data)) + Data` |

### 4.3 Decoding (parse BER)

| Funcao | Assinatura | Descricao |
| --- | --- | --- |
| `ASNDecOIDItem` | `function ASNDecOIDItem(var Start: Integer; const Buffer: AnsiString): Int64` | Decodifica componente de OID (base-128, avanca `Start`) |
| `ASNDecLen` | `function ASNDecLen(var Start: Integer; const Buffer: AnsiString): Integer` | Decodifica comprimento ASN.1; retorna tamanho + avanca `Start` |
| `ASNItem` | `function ASNItem(var Start: Integer; const Buffer: AnsiString; var ValueType: Integer): AnsiString` | Decodifica proximo TLV; retorna Value como AnsiString, tipo em `ValueType`, avanca `Start` |

### 4.4 Conversao OID textual <-> binario

| Funcao | Assinatura | Descricao |
| --- | --- | --- |
| `MibToId` | `function MibToId(Mib: String): AnsiString` | Converte OID textual (`'1.3.6.1.4.1.311'`) para binario ASN.1 OID |
| `IdToMib` | `function IdToMib(const Id: AnsiString): String` | Converte OID binario de volta para texto |
| `IntMibToStr` | `function IntMibToStr(const Value: AnsiString): AnsiString` | Auxiliar interno (componente individual MIB -> string) |

### 4.5 Debugging

| Funcao | Assinatura | Descricao |
| --- | --- | --- |
| `ASNdump` | `function ASNdump(const Value: AnsiString): AnsiString` | Renderiza buffer ASN.1 como texto human-readable indentado |

---

## 5. Aplicabilidades

1. **Montagem de PDUs LDAP** — `ldapsend.pas` usa `ASNObject`, `ASNEncInt`, `MibToId` para todas as requisicoes (`Bind`, `Search`, `Modify`).
2. **Parse de respostas LDAP** — `ASNItem` extrai TLVs da resposta do servidor.
3. **Monte/parse de controles AD** — `BuildADControl` no `TLDAPSend` codifica OIDs em `ASN1_SEQ` envolvendo o controle.
4. **SNMP** — `snmpsend.pas` reutiliza todo o encoding/decoding.
5. **Dump de pacotes LDAP para debug** — `ASNdump(LLDAP.FullResult)` produz dump legivel das respostas brutas.
6. **Ferramentas de seguranca** — parse de certificados X.509 (que sao ASN.1 DER-encoded).

---

## 6. Exemplos de uso

### 6.1 Codificar uma SEQUENCE LDAP manualmente

```pascal
uses SysUtils, asn1util;

var
  LInt, LStr, LSeq: AnsiString;
begin
  LInt := ASNObject(ASNEncInt(42),        ASN1_INT);     // INTEGER 42
  LStr := ASNObject(AnsiString('hello'),   ASN1_OCTSTR); // OCTET STRING "hello"
  LSeq := ASNObject(LInt + LStr,           ASN1_SEQ);    // SEQUENCE { 42, "hello" }

  Writeln(ASNdump(LSeq));
end;
```

### 6.2 Parse de uma resposta ASN.1 BER

```pascal
uses SysUtils, asn1util;

procedure ParseResposta(const AResponse: AnsiString);
var
  LPos, LType: Integer;
  LValue: AnsiString;
begin
  LPos := 1;
  while LPos <= Length(AResponse) do
  begin
    LValue := ASNItem(LPos, AResponse, LType);
    case LType of
      ASN1_INT:    Writeln('INTEGER: ', Integer(LValue[1]));
      ASN1_OCTSTR: Writeln('STRING:  ', LValue);
      ASN1_OBJID:  Writeln('OID:     ', IdToMib(LValue));
      ASN1_SEQ:    Writeln('SEQUENCE (', Length(LValue), ' bytes)');
    else
      Writeln('Tipo 0x', IntToHex(LType, 2));
    end;
  end;
end;
```

### 6.3 Conversao OID texto <-> binario

```pascal
uses SysUtils, asn1util;

var
  LBin: AnsiString;
  LText: string;
begin
  LBin := MibToId('1.3.6.1.4.1.311.21.17');      // AD control OID
  Writeln('Bytes: ', Length(LBin));
  LText := IdToMib(LBin);
  Writeln('Back:  ', LText);
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `SysUtils` | Dependencia | `IntToStr`, string functions |
| `Classes` | Dependencia | Auxiliares |
| `synautil` | Dependencia | Utilitarios de string/byte |
| [TLDAPSend](TLDAPSend.md) | Consumidor principal | Toda PDU LDAP passa por `ASNObject`/`ASNItem` |
| `TSnmpSend` (snmpsend.pas) | Consumidor | Codificacao de requisicoes SNMP |
| X.509 / certificados | Dominio aplicavel | Certs sao ASN.1 DER — parseaveis com essas funcoes |
