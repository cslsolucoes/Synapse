# TTFTPSend

**Unit:** `ftptsend.pas` | **Versao:** 001.001.001 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TTFTPSend` implementa o protocolo Trivial File Transfer (RFC-1350), tanto no papel cliente como no papel servidor. TFTP e um protocolo UDP minimalista usado historicamente em boot de switches/routers (PXE, Cisco IOS upgrades, firmware de appliances), leitura de ficheiros de configuracao por dispositivos embarcados e transferencia simples sem autenticacao.

Ao contrario de FTP, TFTP nao tem sessao, autenticacao, nem modo ASCII vs binario no sentido classico; apenas pacotes RRQ (read request), WRQ (write request), DATA (blocos de 512 bytes), ACK e ERROR. Cada bloco numerado e recebe ACK individual -- stop-and-wait sem sliding window.

A classe herda de `TSynaClient` e gere uma maquina de estados de serial-number + retransmissoes baseada no timeout herdado. O `Data` e um `TMemoryStream` que contem os bytes do ficheiro -- o mesmo buffer e usado para envio (`SendFile`) e para recepcao (`RecvFile`).

## 2. Caracteristicas

- TFTP cliente + servidor (RFC-1350)
- UDP sobre porta 69 (default)
- Pacotes: RRQ (1), WRQ (2), DTA (3), ACK (4), ERR (5)
- Stop-and-wait com serial de 16 bits
- Modo cliente: `SendFile` (WRQ) e `RecvFile` (RRQ)
- Modo servidor: `WaitForRequest`, `ReplyError`, `ReplyRecv`, `ReplySend`
- Gestao de error codes com descricao humana (`ErrorString`)
- Buffer unico `Data: TMemoryStream`

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Porta default | `cTFTPProtocol = '69'` |
| Opcodes | `cTFTP_RRQ=1`, `cTFTP_WRQ=2`, `cTFTP_DTA=3`, `cTFTP_ACK=4`, `cTFTP_ERR=5` |
| Transporte | UDP |
| Bloco | 512 bytes (fixo RFC-1350) |
| Herda de | `TSynaClient` |

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Create | `constructor Create;` | Cria + aloca `TUDPBlockSocket` + `Data`. |
| Destroy | `destructor Destroy; override;` | Liberta recursos. |

### 4.2 Cliente

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| SendFile | `function SendFile(const Filename: string): Boolean;` | WRQ -- envia `Data` para servidor TFTP com nome `Filename`. |
| RecvFile | `function RecvFile(const Filename: string): Boolean;` | RRQ -- recebe ficheiro `Filename` do servidor para `Data`. |

### 4.3 Servidor

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| WaitForRequest | `function WaitForRequest(var Req: word; var filename: string): Boolean;` | Escuta ate `Timeout`; devolve opcode e nome solicitado. |
| ReplyError | `procedure ReplyError(Error: word; Description: string);` | Envia ERR packet. |
| ReplyRecv | `function ReplyRecv: Boolean;` | Aceita WRQ pendente; body em `Data`. |
| ReplySend | `function ReplySend: Boolean;` | Aceita RRQ pendente; envia conteudo de `Data`. |

### 4.4 Properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| ErrorCode | `property ErrorCode: integer;` | Codigo TFTP do erro reportado. |
| ErrorString | `property ErrorString: string;` | Descricao humana. |
| Data | `property Data: TMemoryStream;` | Buffer in/out do ficheiro. |
| RequestIP | `property RequestIP: string;` | IP do peer. |
| RequestPort | `property RequestPort: string;` | Porta do peer. |

## 5. Aplicabilidades

1. **Upgrade de firmware Cisco / Mikrotik / Huawei** -- push de imagem IOS para `/flash:` via WRQ.
2. **PXE boot** -- implementacao de server TFTP para disparar `pxelinux.0` e kernels.
3. **Appliances embedded** -- download de configuracao inicial ao boot.
4. **Backup de configuracoes de switches** -- pull de `running-config` periodicamente.
5. **Testes de rede e labs** -- validar regras de firewall UDP/69.

## 6. Exemplos de uso

### 6.1 Cliente: upload de firmware

```pascal
uses
  SysUtils, Classes, ftptsend;

var
  LTftp: TTFTPSend;
begin
  LTftp := TTFTPSend.Create;
  try
    LTftp.TargetHost := '192.168.1.1';
    LTftp.TargetPort := '69';
    LTftp.Data.LoadFromFile('/path/to/firmware.bin');
    if LTftp.SendFile('firmware.bin') then
      Writeln('OK firmware enviado')
    else
      Writeln('Erro ', LTftp.ErrorCode, ': ', LTftp.ErrorString);
  finally
    LTftp.Free;
  end;
end.
```

### 6.2 Cliente: download de config

```pascal
uses
  SysUtils, ftptsend;

var
  LTftp: TTFTPSend;
begin
  LTftp := TTFTPSend.Create;
  try
    LTftp.TargetHost := '10.0.0.1';
    if LTftp.RecvFile('running-config') then
      LTftp.Data.SaveToFile('/path/to/backup/config-rt01.txt');
  finally
    LTftp.Free;
  end;
end.
```

### 6.3 Servidor simples

```pascal
uses
  SysUtils, Classes, ftptsend;

var
  LTftp: TTFTPSend;
  LReq: Word;
  LFileName: string;
begin
  LTftp := TTFTPSend.Create;
  try
    LTftp.TargetPort := '69';
    while True do
    begin
      if LTftp.WaitForRequest(LReq, LFileName) then
      begin
        case LReq of
          1: // RRQ: cliente pede ficheiro
          begin
            try
              LTftp.Data.LoadFromFile('/path/to/tftproot/' + LFileName);
              LTftp.ReplySend;
            except
              LTftp.ReplyError(1, 'File not found');
            end;
          end;
          2: // WRQ: cliente quer enviar
          begin
            if LTftp.ReplyRecv then
              LTftp.Data.SaveToFile('/path/to/tftproot/' + LFileName);
          end;
        end;
      end;
    end;
  finally
    LTftp.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` | Superclasse | Host/porta/timeout. |
| `TUDPBlockSocket` | Composicao | Socket UDP para transferencia. |
| `synautil` | Dependencia | Helpers binarios/stream. |
