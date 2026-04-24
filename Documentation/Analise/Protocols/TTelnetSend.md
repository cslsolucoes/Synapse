# TTelnetSend

**Unit:** `tlntsend.pas` | **Versao:** 001.003.001 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TTelnetSend` e um cliente Telnet (RFC-854) e SSH2 (via plugin TLS com suporte SSH -- ex. `ssl_cryptlib`). Implementa tambem uma maquina de estados para negociacao Telnet IAC (WILL/WONT/DO/DONT/SB/SE) para ignorar sub-negociacoes e converter o stream a texto limpo.

Mantem um buffer de sessao (`SessionLog`) que acumula tudo o que foi recebido, util para scripts de login automatizado onde comandos dependem de respostas anteriores (expect/respond). O metodo `WaitFor(Value)` bloqueia ate a string `Value` aparecer no stream ou timeout -- classico idiom de screen-scraping.

Herda de `TSynaClient` e pode conectar a Telnet (porta 23) ou a SSH2 (porta 22). No caso SSH e necessario um plugin SSL com suporte SSH -- por omissao o CryptLib (ssl_cryptlib.pas).

## 2. Caracteristicas

- Telnet (RFC-854) com negociacao IAC completa
- SSH2 (requer plugin SSL com suporte SSH, ex. CryptLib)
- Session log continuo (SessionLog) para expect/respond
- Hook de filtro no `OnReadFilter` do socket para decodificar IAC
- Terminal type configuravel (default: `SYNAPSE`)
- Comandos primitivos: `Send`, `Recv`, `WaitFor`, `RecvTerminated`

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Porta Telnet | `cTelnetProtocol = '23'` |
| Porta SSH | `cSSHProtocol = '22'` |
| Herda de | `TSynaClient` |
| TermType default | `SYNAPSE` |
| Timeout default | 60000 ms |
| IAC bytes | `TLNT_IAC = #255`, `TLNT_WILL = #251`, `TLNT_WONT = #252`, `TLNT_DO = #253`, `TLNT_DONT = #254`, `TLNT_SB = #250`, `TLNT_SE = #240` |
| State machine | `TTelnetState = (tsDATA, tsIAC, tsIAC_SB, tsIAC_WILL, tsIAC_DO, tsIAC_WONT, tsIAC_DONT, tsIAC_SBIAC, tsIAC_SBDATA, tsSBDATA_IAC)` |

## 4. Funcionalidades

### 4.1 Sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Login | `function Login: Boolean;` | Conecta a servidor Telnet (porta 23). |
| SSHLogin | `function SSHLogin: Boolean;` | Conecta a SSH2 com plugin CryptLib; usa `Username`/`Password`. |
| Logout | `procedure Logout;` | Fecha socket. |

### 4.2 I/O

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Send | `procedure Send(const Value: string);` | Envia texto para o host. |
| WaitFor | `function WaitFor(const Value: string): Boolean;` | Bloqueia ate `Value` aparecer ou timeout. |
| RecvTerminated | `function RecvTerminated(const Terminator: string): string;` | Le ate o terminador (e.g. `#>`). |
| RecvString | `function RecvString: string;` | Le uma linha. |

### 4.3 Properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Sock | `property Sock: TTCPBlockSocket;` | Socket TCP. |
| SessionLog | `property SessionLog: Ansistring;` | Log acumulado da sessao. |
| TermType | `property TermType: Ansistring;` | TERMINAL-TYPE reportado. |

## 5. Aplicabilidades

1. **Automacao de switches/routers Cisco/Huawei** -- scripts Telnet com expect `Username:` -> send user -> expect `Password:` -> send pwd -> expect `#` -> send commands.
2. **BBS / MUD clients** -- negociacao IAC correcta.
3. **Legacy mainframes** -- interaccao com aplicacoes 3270-via-Telnet.
4. **Gestao de UPS/PDU** -- CLI Telnet em dispositivos de datacenter.
5. **SSH scripted** -- conexao a Unix boxes legacy com CryptLib plugin.

## 6. Exemplos de uso

### 6.1 Login automatico em router

```pascal
uses
  SysUtils, tlntsend;

var
  LTelnet: TTelnetSend;
begin
  LTelnet := TTelnetSend.Create;
  try
    LTelnet.TargetHost := '192.168.1.1';
    LTelnet.TargetPort := '23';
    if LTelnet.Login then
    try
      LTelnet.WaitFor('Username:');
      LTelnet.Send('admin' + #13#10);
      LTelnet.WaitFor('Password:');
      LTelnet.Send('secret' + #13#10);
      LTelnet.WaitFor('#');
      LTelnet.Send('show running-config' + #13#10);
      LTelnet.WaitFor('#');
      Writeln(LTelnet.SessionLog);
    finally
      LTelnet.Logout;
    end;
  finally
    LTelnet.Free;
  end;
end.
```

### 6.2 Coleccao de prompts com `RecvTerminated`

```pascal
uses
  SysUtils, tlntsend;

var
  LTelnet: TTelnetSend;
  LLine: string;
begin
  LTelnet := TTelnetSend.Create;
  try
    LTelnet.TargetHost := 'host.example';
    if LTelnet.Login then
    try
      LTelnet.Send('help' + #13#10);
      repeat
        LLine := LTelnet.RecvTerminated(#10);
        Writeln('<< ', LLine);
      until LLine = '';
    finally
      LTelnet.Logout;
    end;
  finally
    LTelnet.Free;
  end;
end.
```

### 6.3 SSH2 com plugin CryptLib

```pascal
uses
  SysUtils, tlntsend, ssl_cryptlib; // registra plugin

var
  LSsh: TTelnetSend;
begin
  LSsh := TTelnetSend.Create;
  try
    LSsh.TargetHost := 'linux.example';
    LSsh.TargetPort := '22';
    LSsh.Username := 'root';
    LSsh.Password := 'secret';
    if LSsh.SSHLogin then
    try
      LSsh.WaitFor('$');
      LSsh.Send('uname -a' + #10);
      LSsh.WaitFor('$');
      Writeln(LSsh.SessionLog);
    finally
      LSsh.Logout;
    end;
  finally
    LSsh.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` | Superclasse | Host/porta/credenciais/timeout. |
| `TTCPBlockSocket` | Composicao | Socket + OnReadFilter. |
| `synautil` | Dependencia | Helpers de string. |
| `ssl_cryptlib` | Plugin opcional | Habilita SSH2. |
