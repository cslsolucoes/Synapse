# TSSLLibSSH2 / ssl_libssh2.pas

**Unit:** `ssl_libssh2.pas` | **Versao:** 001.000.000 | **Tipo:** Classe | **Origem:** Upstream Synapse (Alexey Suhinin, Lukas Gebauer)

---

## 1. O que e?

`TSSLLibSSH2` e o plugin SSH2 client-only do Synapse baseado na biblioteca **libssh2** (projecto open-source, parte do ecossistema cURL). Apesar do nome `ssl_*` e do herdar de `TCustomSSL`, o plugin **nao faz SSL/TLS** — apenas SSHv2, o que reutiliza a infra-estrutura `TTCPBlockSocket` do Synapse para transporte sobre TCP.

A classe abre uma session SSH + um channel interactivo com pseudo-TTY (`'vanilla'`) e shell, permitindo uso como cliente SSH programatico. Suporta autenticacao por chave privada (`PrivateKeyFile` + `KeyPassword`) com fallback para `Username`/`Password`. Requer `libssh2.dll` (Windows) ou `libssh2.so` (Linux) em runtime. Os binarios podem ser extraidos da distribuicao cURL.

A API cobre apenas o essencial: connect, send, recv, shutdown. Nao expoe manipulacao de channels multiplos, port forwarding, SCP/SFTP, known-hosts nem host key verification — essas feitas precisam de bindings mais ricos da libssh2 (plugin intencionalmente minimalista).

---

## 2. Caracteristicas

- **SSHv2 client-only:** nao implementa servidor.
- **Runtime obrigatorio:** `libssh2.dll`/`libssh2.so`; binarios cURL.
- **Autenticacao multipla:** tenta `publickey` com `PrivateKeyFile`; fallback para `Username`/`Password`.
- **Shell interactivo:** abre channel com PTY `'vanilla'` e `channel_shell`.
- **Sem host key verification:** **nao valida fingerprint do servidor** — vulnerabilidade MITM se nao complementado externamente.
- **Nao e SSL/TLS:** apesar da classe `TCustomSSL`, o `GetSSLVersion` retorna sempre `'SSH2'`.
- **Minimalista:** nao suporta SCP/SFTP/port forwarding directamente pelo plugin.

---

## 3. Engine

| Diretiva / Dependencia | Efeito |
| --- | --- |
| `{$IFDEF FPC} {$MODE DELPHI} {$ENDIF}` | FPC em modo Delphi |
| `libssh2` (unit) | Bindings Pascal — ver Lazarus Forum para `libssh2.pas` |
| `libssh2.dll` / `libssh2.so` | Runtime obrigatorio (cURL distribui binarios) |
| `libssh2_init(0)` | Chamada em `initialization` da unit |
| `libssh2_exit` | Chamada em `finalization` |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create(const Value: TTCPBlockSocket); override` | `FSession := nil; FChannel := nil` |
| `Destroy` | `destructor Destroy; override` | `DeInit` + herdado |

### 4.2 Metodos protegidos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SSHCheck` | `function SSHCheck(Value: integer): Boolean` | Converte rc libssh2 negativo em `FLastError`/`FLastErrorDesc` via `libssh2_session_last_error` |
| `DeInit` | `function DeInit: Boolean` | `libssh2_channel_free` + `libssh2_session_disconnect` + `libssh2_session_free` |

### 4.3 Conexao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Connect` | `function Connect: boolean; override` | Inicializa session, faz handshake SSH, autentica (publickey then password), abre channel com PTY 'vanilla' e shell |
| `Shutdown` | `function Shutdown: boolean; override` | Alias para `DeInit` |
| `BiShutdown` | `function BiShutdown: boolean; override` | Alias para `DeInit` |

### 4.4 Transferencia

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SendBuffer` | `function SendBuffer(Buffer: TMemory; Len: Integer): Integer; override` | `libssh2_channel_write` |
| `RecvBuffer` | `function RecvBuffer(Buffer: TMemory; Len: Integer): Integer; override` | `libssh2_channel_read` |
| `WaitingData` | `function WaitingData: Integer; override` | `libssh2_poll_channel_read` |

### 4.5 Informacoes

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSSLVersion` | `function GetSSLVersion: string; override` | Retorna sempre `'SSH2'` |
| `LibVersion` | `function LibVersion: String; override` | `libssh2_version(0)` |
| `LibName` | `function LibName: String; override` | `'ssl_libssh2'` |

---

## 5. Aplicabilidades

1. **Automacao SSH client:** executar comandos remotos em servidores Linux/BSD.
2. **Tunneling para servicos internos:** encapsular outro protocolo sobre SSH (manualmente, sem port forwarding built-in).
3. **Deploy scripts programaticos:** abrir shell interactivo, enviar comandos, capturar stdout.
4. **Ambientes sem cryptlib:** alternativa mais leve a `TSSLCryptLib` se so o SSHv2 e necessario.

---

## 6. Exemplos de uso

### 6.1 Shell remoto com password

```pascal
uses
  SysUtils, blcksock, ssl_libssh2;

var
  LSock: TTCPBlockSocket;
  LCmd, LResp: AnsiString;
begin
  LSock := TTCPBlockSocket.Create;
  try
    LSock.SSL := TSSLLibSSH2.Create(LSock);
    LSock.SSL.SSLType := LT_SSHv2;
    LSock.SSL.Username := 'admin';
    LSock.SSL.Password := 'secret';

    LSock.Connect('srv01.empresa.local', '22');
    LSock.SSLDoConnect;

    LCmd := 'uptime' + #10;
    LSock.SendString(LCmd);
    SetLength(LResp, 1024);
    SetLength(LResp, LSock.RecvBuffer(@LResp[1], 1024));
    WriteLn('Resposta: ', LResp);
  finally
    LSock.Free;
  end;
end;
```

### 6.2 Autenticacao por chave privada

```pascal
uses
  blcksock, ssl_libssh2;

var
  LSock: TTCPBlockSocket;
begin
  LSock := TTCPBlockSocket.Create;
  try
    LSock.SSL := TSSLLibSSH2.Create(LSock);
    LSock.SSL.SSLType := LT_SSHv2;
    LSock.SSL.Username := 'deploy';
    LSock.SSL.PrivateKeyFile := 'deploy-key.pem';
    LSock.SSL.KeyPassword := 'passphrase';

    LSock.Connect('srv02.empresa.local', '22');
    LSock.SSLDoConnect;
    WriteLn('libssh2: ', (LSock.SSL as TSSLLibSSH2).LibVersion);
  finally
    LSock.Free;
  end;
end;
```

### 6.3 Streaming de output longo

```pascal
uses
  blcksock, ssl_libssh2;

var
  LSock: TTCPBlockSocket;
  LBuf: array [0..4095] of AnsiChar;
  LRead: Integer;
begin
  LSock := TTCPBlockSocket.Create;
  try
    LSock.SSL := TSSLLibSSH2.Create(LSock);
    LSock.SSL.SSLType := LT_SSHv2;
    LSock.SSL.Username := 'admin';
    LSock.SSL.Password := 'pass';
    LSock.Connect('srv03', '22');
    LSock.SSLDoConnect;

    LSock.SendString('journalctl -n 1000' + #10);

    repeat
      LRead := LSock.SSL.RecvBuffer(@LBuf[0], SizeOf(LBuf));
      if LRead > 0 then
        Write(Copy(string(LBuf), 1, LRead));
    until (LRead <= 0) or (LSock.SSL.WaitingData = 0);
  finally
    LSock.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| Herda de | `TCustomSSL` (blcksock.pas) | Contrato comum — apesar do nome, nao faz SSL/TLS |
| Vinculado a | `TTCPBlockSocket` | Via `TTCPBlockSocket.SSL` |
| Depende de | `libssh2` (Pascal bindings) | Unit com prototipos |
| Runtime | `libssh2.dll` / `libssh2.so` | Distribuicao cURL |
| Registado em | `SSLImplementation` | Apenas se `libssh2_init(0) = 0` |
| Alternativa SSH | `TSSLCryptLib` (SSHv2 + TLS num so plugin) | Se cryptlib ja estiver em uso |
| Limite | Sem SCP/SFTP, sem port forward, sem host key verify | Plugin intencionalmente minimo |
