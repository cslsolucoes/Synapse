# TFTPSend

**Unit:** `ftpsend.pas` | **Versao:** 004.001.000 | **Tipo:** Classe (+ TFTPList + TFTPListRec) | **Origem:** Upstream

---

## 1. O que e?

`TFTPSend` e o cliente FTP completo do Synapse (RFC-959) com extensoes IPv6 (RFC-2428, EPSV/EPRT), FTPS (RFC-2228 AUTH TLS) e MLSD. A unit declara tres classes cooperantes: `TFTPSend` (cliente stateful com controle + data channel), `TFTPList` (TList de entries) e `TFTPListRec` (uma entrada parseada com metadata).

A classe mantem dois sockets paralelos (`Sock` para controle na porta 21 e `DSock` para dados na porta 20 ou dinamica em PASV/EPSV). Suporta modo passivo (default, amigavel a firewall) e modo activo. Os dados sao transferidos em modo ASCII ou binario (`BinaryMode`) e podem ir para um `TMemoryStream` interno ou directamente para um ficheiro no disco (`DirectFile`/`DirectFileName`).

Suporta upgrade TLS mid-session via AUTH TLS (`AutoTLS` + `IsTLS`/`IsDataTLS`) para canal de controle e, opcionalmente, canal de dados (`TLSonData`). Implementa parser de listagens (`TFTPList.ParseLines`) com suporte a variados dialectos Unix/VMS/DOS/MLSD via mascaras configuraveis.

## 2. Caracteristicas

- FTP (RFC-959), FTPS (RFC-2228 AUTH TLS), IPv6 (RFC-2428 EPSV/EPRT)
- Modo passivo (default) e activo; porta 20 fixa vs dinamica
- ASCII vs binario
- Upload/download via `DataStream` (TMemoryStream) ou disco (`DirectFile=True`)
- Resume (REST/APPE): `RetrieveFile(..., Restore=True)` e `StoreFile(..., Restore=True)`
- Firewall: 11 modos predefinidos de login sequence (`FWMode`)
- Parser de LIST configuravel via `FTPList.Masks`
- MLSD support (`UseMLSDList`) com datetime ISO confiavel
- Abort / TelnetAbort para cancelar transferencias
- 3 funcoes globais: `FtpGetFile`, `FtpPutFile`, `FtpInterServerTransfer`

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Porta controle | `cFtpProtocol = '21'` |
| Porta dados | `cFtpDataProtocol = '20'` |
| Porta FTPS implicita | `990` (FullSSL) |
| Herda de | `TSynaClient` |
| Username default | `anonymous` |
| PassiveMode default | `True` |
| BinaryMode default | `True` |
| FTP_OK / FTP_ERR | 255 / 254 (sentinelas de `TLogonActions`) |

## 4. Funcionalidades

### 4.1 TFTPSend - sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Login | `function Login: Boolean; virtual;` | Conecta + USER/PASS/ACCT + opcional AUTH TLS. |
| Logout | `function Logout: Boolean; virtual;` | QUIT. |
| Abort | `procedure Abort; virtual;` | Cancela transferencia. |
| TelnetAbort | `procedure TelnetAbort; virtual;` | Abort + telnet IP + ABOR. |
| FTPCommand | `function FTPCommand(const Value: string): integer; virtual;` | Comando arbitrario. |
| ReadResult | `function ReadResult: Integer; virtual;` | Le resposta do control channel. |

### 4.2 TFTPSend - transferencias

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| List | `function List(Directory: string; NameList: Boolean): Boolean; virtual;` | LIST ou NLST; parse em `FTPList`. |
| RetrieveFile | `function RetrieveFile(const FileName: string; Restore: Boolean): Boolean; virtual;` | RETR, opcional resume. |
| StoreFile | `function StoreFile(const FileName: string; Restore: Boolean): Boolean; virtual;` | STOR, opcional resume. |
| StoreUniqueFile | `function StoreUniqueFile: Boolean; virtual;` | STOU. |
| AppendFile | `function AppendFile(const FileName: string): Boolean; virtual;` | APPE. |
| DataRead | `function DataRead(const DestStream: TStream): Boolean; virtual;` | Data channel explicit read. |
| DataWrite | `function DataWrite(const SourceStream: TStream): Boolean; virtual;` | Data channel explicit write. |

### 4.3 TFTPSend - filesystem

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| RenameFile | `function RenameFile(const OldName, NewName: string): Boolean; virtual;` | RNFR/RNTO. |
| DeleteFile | `function DeleteFile(const FileName: string): Boolean; virtual;` | DELE. |
| FileSize | `function FileSize(const FileName: string): int64; virtual;` | SIZE (ou -1). |
| NoOp | `function NoOp: Boolean; virtual;` | NOOP. |
| ChangeWorkingDir | `function ChangeWorkingDir(const Directory: string): Boolean; virtual;` | CWD. |
| ChangeToParentDir | `function ChangeToParentDir: Boolean; virtual;` | CDUP. |
| ChangeToRootDir | `function ChangeToRootDir: Boolean; virtual;` | CWD /. |
| DeleteDir | `function DeleteDir(const Directory: string): Boolean; virtual;` | RMD. |
| CreateDir | `function CreateDir(const Directory: string): Boolean; virtual;` | MKD. |
| GetCurrentDir | `function GetCurrentDir: String; virtual;` | PWD. |

### 4.4 TFTPSend - properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| ResultCode / ResultString / FullResult | `...` | Resposta do ultimo comando. |
| Sock / DSock | `property ...: TTCPBlockSocket;` | Control e data sockets. |
| DataStream | `property DataStream: TMemoryStream;` | Buffer de dados. |
| DirectFile / DirectFileName | `Boolean / string;` | Disco directo em vez de memoria. |
| PassiveMode | `Boolean;` | PASV/EPSV. |
| BinaryMode | `Boolean;` | TYPE I vs TYPE A. |
| CanResume | `Boolean;` | Servidor suporta REST. |
| AutoTLS / FullSSL / IsTLS / IsDataTLS / TLSonData | `Boolean;` | Controle de TLS. |
| UseMLSDList | `Boolean;` | MLSD em vez de LIST. |
| FtpList | `property FtpList: TFTPList;` | Listagem parseada. |
| FWHost / FWPort / FWUsername / FWPassword / FWMode | `...` | Firewall config. |
| OnStatus | `property OnStatus: TFTPStatus;` | Hook de comandos/respostas. |

### 4.5 TFTPList

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Create / Destroy | Constructor / destructor | Ciclo normal. |
| Clear | `procedure Clear; virtual;` | Limpa entries. |
| Count | `function Count: integer; virtual;` | Numero de entries. |
| Assign | `procedure Assign(Value: TFTPList); virtual;` | Copia. |
| ParseLines | `procedure ParseLines; virtual;` | Parse LIST em `TFTPListRec`. |
| ParseMLSDLines | `procedure ParseMLSDLines; virtual;` | Parse MLSD. |
| Items[I] | `property TFTPListRec;` | Default array. |
| Lines | `property TStringList;` | RAW listing. |
| Masks | `property TStringList;` | Dialectos. |
| UnparsedLines | `property TStringList;` | Linhas sem match. |

### 4.6 TFTPListRec

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Assign | `procedure Assign(Value: TFTPListRec); virtual;` | Copia. |
| FileName | `property string;` | Nome. |
| Directory | `property Boolean;` | Subdir. |
| Readable | `property Boolean;` | Permissao leitura. |
| FileSize | `property int64;` | Tamanho. |
| FileTime | `property TDateTime;` | Mtime (sem TZ). |
| OriginalLine | `property string;` | Linha raw. |
| Mask | `property string;` | Mascara usada no parse. |
| Permission | `property string;` | String de permissoes. |

### 4.7 Funcoes globais

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| FtpGetFile | `function FtpGetFile(const IP, Port, FileName, LocalFile, User, Pass: string): Boolean;` | One-shot download. |
| FtpPutFile | `function FtpPutFile(const IP, Port, FileName, LocalFile, User, Pass: string): Boolean;` | One-shot upload. |
| FtpInterServerTransfer | `function FtpInterServerTransfer(const FromIP, FromPort, ...; const ToIP, ToPort, ...): Boolean;` | Server-to-server (proxy-less). |

## 5. Aplicabilidades

1. **Deploy automatico** -- upload de releases para servidor FTP embebido em routers/industrial.
2. **Backups incrementais** -- listagem + comparacao de mtime + resume.
3. **Integracao EDI** -- trocar ficheiros entre parceiros via FTPS com certificado.
4. **Site mirroring** -- recursive download de arvore com `ChangeWorkingDir`.
5. **Firewall corporativo** -- uso de `FWMode` + `FWHost` para passar por gateway.

## 6. Exemplos de uso

### 6.1 Upload FTPS com AUTH TLS

```pascal
uses
  SysUtils, ftpsend;

var
  LFtp: TFTPSend;
begin
  LFtp := TFTPSend.Create;
  try
    LFtp.TargetHost := 'ftp.example.com';
    LFtp.TargetPort := '21';
    LFtp.Username := 'backup';
    LFtp.Password := 'secret';
    LFtp.AutoTLS := True;
    LFtp.TLSonData := True;
    LFtp.PassiveMode := True;
    if LFtp.Login then
    try
      LFtp.DirectFile := True;
      LFtp.DirectFileName := '/path/to/local/dump.sql';
      LFtp.StoreFile('backup/dump-2026-04-21.sql', False);
    finally
      LFtp.Logout;
    end;
  finally
    LFtp.Free;
  end;
end.
```

### 6.2 Listar + filtrar + download

```pascal
uses
  SysUtils, ftpsend;

var
  LFtp: TFTPSend;
  I: Integer;
  LRec: TFTPListRec;
begin
  LFtp := TFTPSend.Create;
  try
    LFtp.TargetHost := 'ftp.example.com';
    LFtp.Username := 'anonymous'; LFtp.Password := 'guest@';
    if LFtp.Login then
    try
      LFtp.UseMLSDList := True;
      if LFtp.List('/pub', False) then
        for I := 0 to LFtp.FtpList.Count - 1 do
        begin
          LRec := LFtp.FtpList.Items[I];
          if (not LRec.Directory) and ExtractFileExt(LRec.FileName).Equals('.zip') then
          begin
            LFtp.DirectFile := True;
            LFtp.DirectFileName := '/path/to/downloads/' + LRec.FileName;
            LFtp.RetrieveFile('/pub/' + LRec.FileName, False);
          end;
        end;
    finally
      LFtp.Logout;
    end;
  finally
    LFtp.Free;
  end;
end.
```

### 6.3 Download one-shot com `FtpGetFile`

```pascal
uses
  SysUtils, ftpsend;

begin
  if FtpGetFile('ftp.example.com', '21',
                '/pub/readme.txt',
                '/path/to/readme.txt',
                'anonymous', 'guest@') then
    Writeln('OK')
  else
    Writeln('Falhou');
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` | Superclasse | Host/porta/credenciais. |
| `TTCPBlockSocket` | Composicao dupla | Control + data sockets. |
| `TFTPList` | Composicao | Listagem parseada. |
| `TFTPListRec` | Elemento | Item de `TFTPList`. |
| `synautil` / `synaip` | Dependencia | Parse de host/porta/datas. |
| Plugin SSL | Dependencia opcional | AUTH TLS / FTPS. |
