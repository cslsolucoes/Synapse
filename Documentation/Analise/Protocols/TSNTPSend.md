# TSNTPSend

**Unit:** `sntpsend.pas` | **Versao:** 003.000.003 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TSNTPSend` e um cliente Network Time Protocol (RFC-1305) e Simple Network Time Protocol (RFC-2030). Usa UDP na porta 123 e suporta tres modos: query unicast (`GetSNTP`), query unicast com correccoes adicionais (`GetNTP`) e passive listener para broadcasts (`GetBroadcastNTP`).

O protocolo NTP transporta timestamps de 64 bits (parte inteira em segundos desde 1 de Janeiro de 1900 + parte fraccionaria). A classe decodifica (`DecodeTs`) e codifica (`EncodeTs`) entre esse formato e `TDateTime`. Opcionalmente, se `SyncTime=True`, ajusta o relogio do sistema operativo (requer privilegios).

Mantem `NTPReply: TNtp` com o packet completo (mode, stratum, poll, precision, root delay/dispersion, refID, timestamps). `NTPOffset` e `NTPDelay` guardam o offset e a latencia calculados, uteis para analise de sincronia.

## 2. Caracteristicas

- NTP (RFC-1305) e SNTP (RFC-2030)
- Modo query unicast
- Modo passive listener para broadcast
- Decode/encode de timestamps NTP 64-bit
- Ajuste opcional do relogio do SO (`SyncTime=True`, requer privilegios)
- Proteccao de sync: nao ajusta se `abs(offset) > MaxSyncDiff`

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Porta NTP | `cNtpProtocol = '123'` |
| Timeout default | 5000 ms |
| MaxSyncDiff default | 3600 s (1h) |
| SyncTime default | `False` |
| Herda de | `TSynaClient` |

## 4. Funcionalidades

### 4.1 Construtor

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Create | `constructor Create;` | Aloca `TUDPBlockSocket`. |
| Destroy | `destructor Destroy; override;` | Liberta. |

### 4.2 Codec

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| DecodeTs | `function DecodeTs(Nsec, Nfrac: Longint): TDateTime;` | NTP 64-bit -> TDateTime (UTC). |
| EncodeTs | `procedure EncodeTs(dt: TDateTime; var Nsec, Nfrac: Longint);` | TDateTime -> NTP 64-bit. |

### 4.3 Operacoes

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| GetSNTP | `function GetSNTP: Boolean;` | Envia query SNTP simples. Preenche `NTPTime`. |
| GetNTP | `function GetNTP: Boolean;` | Envia query NTP completa com correccoes de latencia. |
| GetBroadcastNTP | `function GetBroadcastNTP: Boolean;` | Escuta passive broadcasts NTP. |

### 4.4 Properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| NTPReply | `property TNtp;` | Packet NTP cru. |
| NTPTime | `property TDateTime;` | Timestamp UTC ja decodificado. |
| NTPOffset | `property Double;` | Offset local-remote (s). |
| NTPDelay | `property Double;` | RTT (s). |
| MaxSyncDiff | `property Double;` | Diff maxima tolerada para ajuste de relogio. |
| SyncTime | `property Boolean;` | Activa ajuste do clock do SO. |
| Sock | `property TUDPBlockSocket;` | Socket UDP. |

## 5. Aplicabilidades

1. **Sincronizacao de clock em appliances** -- dispositivos sem NTP nativo.
2. **Estampa temporal confiavel** -- para auditoria, logs forenses, compliance.
3. **Sync batch-jobs** -- ajustar clock antes de jobs criticos.
4. **Monitor de drift** -- medir offset sem ajustar (`SyncTime=False`).
5. **Passive listening** -- nao enviar query em redes isoladas.

## 6. Exemplos de uso

### 6.1 Query SNTP simples

```pascal
uses
  SysUtils, sntpsend;

var
  LSntp: TSNTPSend;
begin
  LSntp := TSNTPSend.Create;
  try
    LSntp.TargetHost := 'pool.ntp.org';
    if LSntp.GetSNTP then
      Writeln('NTP UTC: ', FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', LSntp.NTPTime))
    else
      Writeln('Falhou');
  finally
    LSntp.Free;
  end;
end.
```

### 6.2 Ajuste do clock do SO (requer privilegios)

```pascal
uses
  SysUtils, sntpsend;

var
  LNtp: TSNTPSend;
begin
  LNtp := TSNTPSend.Create;
  try
    LNtp.TargetHost := 'time.example.com';
    LNtp.MaxSyncDiff := 600; // so ajusta se drift < 10 min
    LNtp.SyncTime := True;
    if LNtp.GetNTP then
      Writeln(Format('Clock ajustado. Offset=%.3fs Delay=%.3fs',
        [LNtp.NTPOffset, LNtp.NTPDelay]));
  finally
    LNtp.Free;
  end;
end.
```

### 6.3 Medir drift sem ajustar

```pascal
uses
  SysUtils, sntpsend;

var
  LNtp: TSNTPSend;
begin
  LNtp := TSNTPSend.Create;
  try
    LNtp.TargetHost := '0.pool.ntp.org';
    LNtp.SyncTime := False;
    if LNtp.GetNTP then
      Writeln(Format('Offset=%.3fs (RTT=%.3fs)', [LNtp.NTPOffset, LNtp.NTPDelay]));
  finally
    LNtp.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` | Superclasse | Host/porta/timeout. |
| `TUDPBlockSocket` | Composicao | Socket UDP. |
| `synautil` | Dependencia | Codec de inteiros 32-bit. |
| `TNtp` | Record | Estrutura de packet NTP (48 bytes). |
