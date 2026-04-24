# TClamSend

**Unit:** `clamsend.pas` | **Versao:** 001.001.001 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TClamSend` e o cliente TCP do daemon ClamAV (ClamD), o motor open-source antivirus (http://www.clamav.net). Liga-se ao ClamD por TCP (porta 3310 default) e envia streams de dados para scan, recebendo a assinatura de malware detectado ou `OK`/`stream: OK`.

A classe mantem dois sockets: `Sock` (comando) e `DSock` (stream de dados, usado quando ClamD responde a `STREAM` com uma porta dinamica para upload do conteudo a scanear). Suporta tanto a API antiga (`ScanStream`, `ScanStrings` com cabecalho `STREAM`) como a API moderna do ClamAV 0.95+ (`ScanStream2`, `ScanStrings2` que usa `zINSTREAM`). O modo session (`Session=True`) permite multiplas queries sem re-conectar, mas e reportado como buggy pelos developers do ClamAV e default e `False`.

## 2. Caracteristicas

- Cliente TCP ClamD
- API legacy (STREAM) e moderna (zINSTREAM, ClamAV 0.95+)
- Suporte a session mode (broken no ClamAV historico)
- Comandos: PING, VERSION, RELOAD, SHUTDOWN, STREAM, INSTREAM
- Scan de `TStream` ou `TStrings`
- Response format: `stream: Eicar-Test-Signature FOUND` ou `stream: OK`

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Porta default | `cClamProtocol = '3310'` |
| Transporte | TCP |
| Herda de | `TSynaClient` |
| Session default | `False` (o modo session do ClamAV e historicamente bugado) |

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Create | `constructor Create;` | Aloca `Sock` + `DSock`. |
| Destroy | `destructor Destroy; override;` | Liberta. |

### 4.2 Operacoes

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| DoCommand | `function DoCommand(const Value: AnsiString): AnsiString; virtual;` | Comando generico. Tambem faz login/logout quando fora de session mode. |
| GetVersion | `function GetVersion: AnsiString; virtual;` | Emite `VERSION` -- retorna versao + database date. |
| ScanStrings | `function ScanStrings(const Value: TStrings): AnsiString; virtual;` | Scan via STREAM API legacy. |
| ScanStream | `function ScanStream(const Value: TStream): AnsiString; virtual;` | Scan via STREAM API legacy. |
| ScanStrings2 | `function ScanStrings2(const Value: TStrings): AnsiString; virtual;` | Scan via INSTREAM (ClamAV 0.95+). |
| ScanStream2 | `function ScanStream2(const Value: TStream): AnsiString; virtual;` | Scan via INSTREAM (ClamAV 0.95+). |

### 4.3 Properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Sock | `property TTCPBlockSocket;` | Socket de comandos. |
| DSock | `property TTCPBlockSocket;` | Socket de transferencia. |
| Session | `property Boolean;` | Activa modo session (NAO recomendado). |

## 5. Aplicabilidades

1. **Mail gateway antivirus** -- scan de anexos antes de forward.
2. **Upload proxy** -- verificar ficheiros submetidos a web apps antes de gravar.
3. **File server sentinel** -- scan em lote dos ficheiros novos.
4. **CI/CD de artifacts** -- scan de binarios antes de publicar no repositorio.
5. **DLP / compliance** -- detectar EICAR ou amostras de teste.

## 6. Exemplos de uso

### 6.1 Scan de ficheiro em disco

```pascal
uses
  SysUtils, Classes, clamsend;

var
  LClam: TClamSend;
  LFile: TFileStream;
  LResult: AnsiString;
begin
  LClam := TClamSend.Create;
  try
    LClam.TargetHost := '127.0.0.1';
    LClam.TargetPort := '3310';
    LFile := TFileStream.Create('/path/to/suspicious.bin', fmOpenRead);
    try
      LResult := LClam.ScanStream2(LFile);
      if Pos('FOUND', LResult) > 0 then
        Writeln('INFECTED: ', LResult)
      else if Pos('OK', LResult) > 0 then
        Writeln('CLEAN')
      else
        Writeln('ERROR: ', LResult);
    finally
      LFile.Free;
    end;
  finally
    LClam.Free;
  end;
end.
```

### 6.2 Obter versao do engine

```pascal
uses
  SysUtils, clamsend;

var
  LClam: TClamSend;
begin
  LClam := TClamSend.Create;
  try
    LClam.TargetHost := '127.0.0.1';
    Writeln(LClam.GetVersion);
  finally
    LClam.Free;
  end;
end.
```

### 6.3 Scan de buffer de texto (EICAR test)

```pascal
uses
  SysUtils, Classes, clamsend;

var
  LClam: TClamSend;
  LLines: TStringList;
begin
  LClam := TClamSend.Create;
  LLines := TStringList.Create;
  try
    LLines.Add('X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*');
    LClam.TargetHost := '127.0.0.1';
    Writeln(LClam.ScanStrings2(LLines));
  finally
    LLines.Free;
    LClam.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` | Superclasse | Host/porta/timeout. |
| `TTCPBlockSocket` (x2) | Composicao | Comando + data stream. |
| `synautil` | Dependencia | Stream helpers. |
| ClamAV daemon | Servico externo | Motor de scan instalado separadamente. |
