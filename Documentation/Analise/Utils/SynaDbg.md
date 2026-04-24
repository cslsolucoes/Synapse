# SynaDbg

**Unit:** `synadbg.pas` | **Versao:** 001.001.003 | **Tipo:** Unit | **Origem:** Upstream

---

## 1. O que e?

A `synadbg` e a unit de tracing/debug do Ararat Synapse para instrumentacao de sockets. Fornece uma classe `TSynaDebug` com dois metodos de classe estatica (`HookStatus` e `HookMonitor`) destinados a ser ligados directamente as properties `OnStatus` e `OnMonitor` dos `TBlockSocket` de `blcksock`. Cada hook formata um log line com timestamp `yyyymmdd-hhnnss.zzz`, o handle do socket (em hexadecimal) e a acao (`HR_Connect`, `HR_CanRead`, `HR_Error`, etc.) ou a direccao do I/O (`->` send, `<-` recv), e escreve no ficheiro definido pela variavel global `LogFile`. No `initialization` o LogFile e pre-definido para `<executable_name>.slog`.

## 2. Caracteristicas

- Classe com apenas dois metodos `class procedure` — zero state, thread-unsafe.
- Formato do log line fixo: `{SenderHex}{Reason}: {Value}` para HookStatus, `{SenderHex}-> {Buffer}` / `{SenderHex}<- {Buffer}` para HookMonitor.
- `AppendToLog` abre ficheiro em `fmShareDenyWrite` (permite varios processos escreverem se alinharem I/O) e escreve imediatamente; nao faz buffering.
- Bloco `initialization` define `LogFile := ChangeFileExt(ParamStr(0), '.slog')`.
- Extremamente simples (~156 linhas totais); destinado a dev/troubleshooting, nao a producao.

## 3. Engine

Engine minima baseada em `TFileStream` + `WriteStrToStream` de `synautil`:

- Abre o ficheiro em `fmOpenReadWrite` (se existe) ou `fmCreate` (nova entrada); move para `st.Size` antes de escrever (append).
- `FormatDateTime('yyyymmdd-hhnnss', dt) + Format('.%.3d', [ms])` para timestamp de alta resolucao (milissegundos).
- Case/of sobre `THookSocketReason` (do `blcksock`) traduz 14 razoes para strings simbolicas.

## 4. Funcionalidades

### 4.1 Classe `TSynaDebug`

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `HookStatus` | `class procedure HookStatus(Sender: TObject; Reason: THookSocketReason; const Value: string);` | Hook para `TBlockSocket.OnStatus`. Traduz `HR_ResolvingBegin`, `HR_Connect`, `HR_CanRead`, `HR_CanWrite`, `HR_ReadCount`, `HR_WriteCount`, `HR_Error`, etc. em texto + timestamp. |
| `HookMonitor` | `class procedure HookMonitor(Sender: TObject; Writing: Boolean; const Buffer: TMemory; Len: Integer);` | Hook para `TBlockSocket.OnMonitor`. Dumpa `Len` bytes do buffer com direccao (`->`/`<-`). |

### 4.2 Funcao de baixo nivel

| Funcao/Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `AppendToLog` | `procedure AppendToLog(const value: Ansistring);` | Escreve linha no ficheiro `LogFile` com timestamp corrente. Abre em `fmShareDenyWrite`. |

### 4.3 Variavel global

| Nome | Tipo | Valor default |
| --- | --- | --- |
| `LogFile` | `string` | `<executable>.slog` (set via `initialization`). |

### 4.4 Reasons suportadas (enum `THookSocketReason` de `blcksock`)

| Reason | String gerada |
| --- | --- |
| `HR_ResolvingBegin` | `'HR_ResolvingBegin'` |
| `HR_ResolvingEnd` | `'HR_ResolvingEnd'` |
| `HR_SocketCreate` | `'HR_SocketCreate'` |
| `HR_SocketClose` | `'HR_SocketClose'` |
| `HR_Bind` | `'HR_Bind'` |
| `HR_Connect` | `'HR_Connect'` |
| `HR_CanRead` | `'HR_CanRead'` |
| `HR_CanWrite` | `'HR_CanWrite'` |
| `HR_Listen` | `'HR_Listen'` |
| `HR_Accept` | `'HR_Accept'` |
| `HR_ReadCount` | `'HR_ReadCount'` |
| `HR_WriteCount` | `'HR_WriteCount'` |
| `HR_Wait` | `'HR_Wait'` |
| `HR_Error` | `'HR_Error'` |
| `outro` | `'-unknown-'` |

## 5. Aplicabilidades

- **Troubleshooting LDAP/LDAPS:** ligar `TSynaDebug.HookStatus` a `TLDAPSend.Sock.OnStatus` para capturar cada fase de conexao (resolve DNS, connect, bind, read/write counts).
- **Deep debug MIME/SMTP:** `TSynaDebug.HookMonitor` imprime TODO o trafego (incluindo senhas!) — usar apenas em dev.
- **Investigacao de timeouts:** `HR_Wait` mostra cada iteracao de select/poll.
- **Auditoria simples:** gravar todas as conexoes abertas por um processo, sem precisar de Wireshark.
- **Nao recomendado em producao:** escrita sincrona sem rotacao de log, escritas partilhadas podem corromper se varios sockets chamarem em paralelo de threads diferentes.

## 6. Exemplos de uso

```pascal
uses
  SysUtils, blcksock, synadbg;
var
  sock: TTCPBlockSocket;
begin
  // Redireccionar log para ficheiro custom
  synadbg.LogFile := 'C:\Temp\ldap-trace.slog';

  sock := TTCPBlockSocket.Create;
  try
    sock.OnStatus := TSynaDebug.HookStatus;
    sock.Connect('dc01.empresa.local', '389');
    sock.SendString('HELO'#13#10);
    sock.RecvString(5000);
  finally
    sock.Free;
  end;
end;
```

```pascal
uses
  SysUtils, ldapsend, synadbg;
var
  ld: TLDAPSend;
begin
  // Activar dump total do trafego LDAP (inclui bind password em claro!)
  synadbg.LogFile := ChangeFileExt(ParamStr(0), '-ldap.slog');

  ld := TLDAPSend.Create;
  try
    ld.Sock.OnStatus := TSynaDebug.HookStatus;
    ld.Sock.OnMonitor := TSynaDebug.HookMonitor;
    ld.TargetHost := 'dc01.empresa.local';
    ld.TargetPort := '389';
    ld.UserName := 'CN=admin,DC=empresa,DC=local';
    ld.Password := 'secret';
    ld.Login;
    ld.Bind;
    // ...
    ld.Logout;
  finally
    ld.Free;
  end;
end;
```

```pascal
uses
  SysUtils, synadbg;
begin
  // Log livre (fora de socket) — aproveitar timestamp+append
  synadbg.LogFile := 'C:\Temp\myapp.slog';
  AppendToLog('Inicio do processo'#13#10);
  AppendToLog('Carregando config...'#13#10);
  // saida:
  // 20260421-143205.123 Inicio do processo
  // 20260421-143205.124 Carregando config...
end;
```

## 7. Relacionamentos

- **Consumida por:** qualquer consumidor Synapse que queira debug via `OnStatus`/`OnMonitor` (nao obrigatorio).
- **Depende de:** `blcksock`, `synsock`, `synautil`, `classes`, `sysutils`, `synafpc`.
- **Interage com:** `LogFile` e global — um processo completo so pode ter um ficheiro activo por vez.
- **Fork CSL:** sem modificacoes (upstream puro 001.001.003).
- **Sem substituto directo:** para logging estruturado usar frameworks dedicados (Quick.Logger, Log4Delphi, etc.); `synadbg` e apenas tracing low-level.
