# TBlockSerial

**Unit:** `synaser.pas` | **Versao:** 007.007.003 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TBlockSerial` e a classe Synapse para comunicacao com portas serie (RS-232, RS-485, USB-serial) em Windows, Linux/Unix/BSD, macOS e Android. Oferece uma API simetrica a `TTCPBlockSocket` -- `Connect`, `CloseSocket`, `SendString`, `RecvString`, `SendBuffer`, `RecvBuffer` -- mas debaixo usa APIs nativas do SO (Win32 `CreateFile`/`CommConfig` ou POSIX `termios`/`tcsetattr`).

Suporta configuracao completa do link: baudrate (50 bps ate 4 Mbps), paridade (N/O/E/M/S), stop bits (1, 1.5, 2), data bits (5..8), flow control (XON/XOFF software ou RTS/CTS hardware). Permite manipulacao directa das linhas de controle: DTR, RTS, CTS, DSR, RI (Ring), DCD (Carrier), `SetBreak`.

Em Unix/Linux usa lockfiles em `/var/lock/LCK..ttyXX` (desde que `FLinuxLock=True`) para coordenar ownership com outras aplicacoes (getty, uucp, ppp). Em Windows, compartilhar a porta e impossivel (o primeiro a abrir tem exclusividade).

## 2. Caracteristicas

- Windows (32/64) + Linux/Unix/BSD + macOS + Android
- Baudrates de 50 bps a 4 Mbps (dependente de SO)
- Paridade: N (None), O (Odd), E (Even), M (Mark), S (Space)
- Stop bits: `SB1`, `SB1andHalf`, `SB2`
- Data bits: 5, 6, 7, 8
- Flow control software (XON/XOFF) e hardware (RTS/CTS, DTR/DSR)
- Acesso directo a linhas de controle (DTR, RTS, CTS, DSR, Ring, Carrier)
- AT commands para modems (`ATCommand`, `ATConnect`)
- Lockfile POSIX para single-ownership
- `OnStatus` hook para eventos (connect, read/write, close)
- Exception type dedicado `ESynaSerError` com codigo + mensagem

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| CRLF | `CR=#$0d`, `LF=#$0a`, `CRLF=CR+LF` |
| Chunk transfer | `cSerialChunk = 8192` |
| Stop bits | `SB1=0`, `SB1andHalf=1`, `SB2=2` |
| Lockfile Linux | `/var/lock` |
| sOK / sErr | 0 / -1 |
| INVALID_HANDLE_VALUE | -1 |

### 3.1 Error codes (9990..10003)

| Const | Valor | Significado |
| --- | --- | --- |
| `ErrAccessDenied` | 9990 | Sem permissao |
| `ErrAlreadyOwned` | 9991 | Outro processo ja tem a porta |
| `ErrAlreadyInUse` | 9992 | Porta em uso |
| `ErrWrongParameter` | 9993 | Argumento invalido |
| `ErrPortNotOpen` | 9994 | Porta nao aberta |
| `ErrNoDeviceAnswer` | 9995 | Dispositivo nao respondeu |
| `ErrMaxBuffer` | 9996 | Buffer excedido |
| `ErrTimeout` | 9997 | Timeout |
| `ErrNotRead` | 9998 | Erro na leitura |
| `ErrFrame` | 9999 | Framing error |
| `ErrOverrun` | 10000 | Overrun de input |
| `ErrRxOver` | 10001 | Buffer de RX cheio |
| `ErrRxParity` | 10002 | Parity error |
| `ErrTxFull` | 10003 | Buffer de TX cheio |

### 3.2 THookSerialReason

| Valor | Significado |
| --- | --- |
| `HR_SerialClose` | Porta fechada |
| `HR_Connect` | Porta aberta |
| `HR_CanRead` | Dados disponiveis |
| `HR_CanWrite` | Espaco no TX |
| `HR_ReadCount` | Bytes lidos |
| `HR_WriteCount` | Bytes escritos |
| `HR_Wait` | A aguardar |

### 3.3 DCB flags (Windows-compatible bitmap)

`dcb_Binary`, `dcb_ParityCheck`, `dcb_OutxCtsFlow`, `dcb_OutxDsrFlow`, `dcb_DtrControl{Disable,Enable,Handshake}`, `dcb_DsrSensivity`, `dcb_TXContinueOnXoff`, `dcb_OutX`, `dcb_InX`, `dcb_ErrorChar`, `dcb_NullStrip`, `dcb_RtsControl{Disable,Enable,Handshake,Toggle}`, `dcb_AbortOnError`.

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Create | `constructor Create;` | Aloca; porta ainda fechada. |
| Destroy | `destructor Destroy; override;` | Liberta; fecha porta se aberta. |
| GetVersion | `class function GetVersion: string; virtual;` | String de versao da unit. |
| CloseSocket | `procedure CloseSocket; virtual;` | Fecha handle + lockfile. |

### 4.2 Conexao / configuracao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Connect | `procedure Connect(const comport: string); virtual;` | Abre `COM3` (Windows) ou `/dev/ttyS1` (POSIX); cross-naming auto. |
| Config | `procedure Config(baud, bits: integer; parity: char; stop: integer; softflow, hardflow: boolean); virtual;` | Ajusta parametros on-the-fly. |
| ConfigEx | `procedure ConfigEx(...); virtual;` | Variante estendida (alguns SOs). |

### 4.3 I/O bloqueante (string)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| SendString | `procedure SendString(data: AnsiString); virtual;` | Envia string. |
| RecvString | `function RecvString(timeout: integer): AnsiString; virtual;` | Le linha terminada por `CRLF`. |
| SendByte | `procedure SendByte(data: Byte); virtual;` | Envia 1 byte. |
| RecvByte | `function RecvByte(timeout: integer): Byte; virtual;` | Le 1 byte. |

### 4.4 I/O bloqueante (buffer)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| SendBuffer | `function SendBuffer(buffer: pointer; length: integer): integer; virtual;` | Envia N bytes. |
| RecvBuffer | `function RecvBuffer(buffer: pointer; length: integer): integer; virtual;` | Le N bytes (bloqueante). |
| WaitingData | `function WaitingData: integer; virtual;` | Bytes disponiveis RX. |
| WaitingDataEx | `function WaitingDataEx: integer; virtual;` | Variante. |
| Purge | `procedure Purge; virtual;` | Descarta RX+TX buffers. |
| Flush | `procedure Flush; virtual;` | Aguarda TX vazio. |

### 4.5 Linhas de controle

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| SetDTR | `procedure SetDTR(Value: Boolean); virtual;` | Seta DTR. |
| SetRTS | `procedure SetRTS(Value: Boolean); virtual;` | Seta RTS. |
| SetBreak | `procedure SetBreak(Duration: integer); virtual;` | Break (ms). |
| DTR | `property Boolean;` | Estado actual. |
| RTS | `property Boolean;` | Estado actual. |
| CTS | `property Boolean; (read-only);` | Estado CTS. |
| DSR | `property Boolean; (read-only);` | Estado DSR. |
| Ring | `property Boolean; (read-only);` | Ring indicator. |
| Carrier | `property Boolean; (read-only);` | DCD. |
| ModemStatus | `function ModemStatus: integer; virtual;` | Bitmap consolidado. |

### 4.6 Properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Device | `property string;` | Nome da porta. |
| Handle | `property THandle;` | Handle nativo. |
| LastError | `property integer;` | Codigo do ultimo erro. |
| LastErrorDesc | `property string;` | Texto do ultimo erro. |
| InstanceActive | `property Boolean;` | Porta aberta. |
| RTSFlowControl / DTRFlowControl | `property Boolean;` | Liga handshake linha-a-linha. |
| SoftwareFlowControl / HardwareFlowControl | `property Boolean;` | Macro-switches. |
| TestDSR / TestCTS | `property Boolean;` | Verificar estado antes de TX. |
| MaxLineLength | `property Integer;` | Para `RecvString`. |
| OnStatus | `property THookSerialStatus;` | Hook de eventos. |
| RaiseExcept | `property Boolean;` | Se `True`, erros geram `ESynaSerError`. |
| LinuxLock | `property Boolean;` | Activa `/var/lock` no POSIX. |
| MaxSendBandwidth / MaxRecvBandwidth | `property Integer;` | Rate-limit. |

## 5. Aplicabilidades

1. **Automacao industrial / Modbus** -- comunicacao RS-485 com PLC.
2. **Leitores de cartoes / biometria** -- USB serial com dispositivo de captura.
3. **Modems GSM** -- AT commands (`ATCommand`, `ATConnect`) para SMS e dial-up.
4. **Balances / terminais POS** -- leitura de peso / impressao em impressora fiscal.
5. **IoT / Arduino** -- captura de sensores.
6. **GPS NMEA** -- stream continuo de sentences GPS.

## 6. Exemplos de uso

### 6.1 Leitura de balance em COM3

```pascal
uses
  SysUtils, synaser;

var
  LSer: TBlockSerial;
  LLine: AnsiString;
begin
  LSer := TBlockSerial.Create;
  try
    LSer.RaiseExcept := True;
    LSer.Connect('COM3');
    LSer.Config(9600, 8, 'N', SB1, False, False);
    LLine := LSer.RecvString(2000); // timeout 2s
    Writeln('Peso: ', LLine);
  finally
    LSer.Free;
  end;
end.
```

### 6.2 Modem GSM -- enviar SMS

```pascal
uses
  SysUtils, synaser;

var
  LModem: TBlockSerial;
begin
  LModem := TBlockSerial.Create;
  try
    LModem.Connect('/dev/ttyUSB0');
    LModem.Config(115200, 8, 'N', SB1, False, True);
    LModem.SendString('AT' + #13);
    Writeln(LModem.RecvString(1000)); // OK
    LModem.SendString('AT+CMGF=1' + #13); // text mode
    LModem.RecvString(1000);
    LModem.SendString('AT+CMGS="+351912345678"' + #13);
    LModem.SendString('Hello SMS' + #26); // CTRL-Z
    Writeln(LModem.RecvString(10000));
  finally
    LModem.Free;
  end;
end.
```

### 6.3 Manipulacao de DTR/RTS (reset de Arduino)

```pascal
uses
  SysUtils, synaser;

var
  LSer: TBlockSerial;
begin
  LSer := TBlockSerial.Create;
  try
    LSer.Connect('COM4');
    LSer.Config(115200, 8, 'N', SB1, False, False);
    // toggle DTR low/high para reset de Arduino
    LSer.SetDTR(False);
    Sleep(50);
    LSer.SetDTR(True);
    // aguarda boot
    Sleep(2000);
    LSer.SendString('PING' + #10);
    Writeln(LSer.RecvString(1000));
  finally
    LSer.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `ESynaSerError` | Excepcao dedicada | Lanca em erros quando `RaiseExcept=True`. |
| `TDCB` (record) | Estrutura nativa | Data Control Block compativel Windows. |
| `termios` (POSIX) | Estrutura nativa | Config terminal Unix. |
| `synafpc` | Dependencia | Cross-compiler FPC. |
| `synautil` | Dependencia | Helpers binarios. |
| `THookSerialStatus` | Type | Callback de eventos. |
| `THookSerialReason` | Enum | Razao do callback. |
