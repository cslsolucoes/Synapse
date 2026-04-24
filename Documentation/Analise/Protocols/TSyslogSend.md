# TSyslogSend

**Unit:** `slogsend.pas` | **Versao:** 002.000.000 | **Tipo:** Classe (+ TSyslogMessage) | **Origem:** Upstream

---

## 1. O que e?

`TSyslogSend` e o cliente Syslog BSD do Synapse (RFC-3164 e RFC-5424). Envia mensagens de log para um servidor Syslog por UDP (porta 514). A mensagem e composta por `TSyslogMessage`, que encapsula facility, severity, timestamp, tag, message body e, no formato RFC-5424, procID e msgID.

RFC-5424 traz melhorias importantes sobre RFC-3164: timestamps com precisao de milissegundos, suporte UTF-8 completo, campos estruturados adicionais. `TSyslogMessage.Version` alterna entre as duas versoes. A propriedade `PacketBuf` de leitura funciona para ambas mas a escrita directa via `PacketBuf:=...` so suporta RFC-3164 (deprecated).

A facility identifica a origem logica (Kernel, User, Mail, Daemon, Auth, Syslog, Lpr, News, Uucp, Cron, Authpriv, Ftp, NTP, LogAudit, LogAlert, Time, Local0..Local7 -- 24 valores) e a severity o nivel (Emergency, Alert, Critical, Error, Warning, Notice, Info, Debug -- 8 niveis, crescentes de importancia decrescente).

## 2. Caracteristicas

- RFC-3164 (BSD Syslog classico)
- RFC-5424 (versao 1, ms timestamps, UTF-8)
- 24 facilities predefinidas + 8 severities
- Transporte UDP
- Mensagem encapsulada em `TSyslogMessage` autonoma (reutilizavel)
- Funcoes globais one-shot: `ToSysLog` (RFC-3164) e `ToSysLog1` (RFC-5424)

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Porta Syslog | `cSysLogProtocol = '514'` |
| Transporte | UDP |
| Herda de | `TSynaClient` |

### 3.1 Facilities (24)

| Const | Valor | Significado |
| --- | --- | --- |
| `FCL_Kernel` | 0 | Kernel messages |
| `FCL_UserLevel` | 1 | User-level messages |
| `FCL_MailSystem` | 2 | Mail |
| `FCL_System` | 3 | System daemons |
| `FCL_Security` | 4 | Auth (deprecated) |
| `FCL_Syslogd` | 5 | Internal syslog |
| `FCL_Printer` | 6 | Lpr |
| `FCL_News` | 7 | Usenet |
| `FCL_UUCP` | 8 | Uucp |
| `FCL_Clock` | 9 | Cron |
| `FCL_Authorization` | 10 | Authpriv |
| `FCL_FTP` | 11 | Ftp |
| `FCL_NTP` | 12 | NTP |
| `FCL_LogAudit` | 13 | Audit |
| `FCL_LogAlert` | 14 | Alert |
| `FCL_Time` | 15 | Clock (v2) |
| `FCL_Local0..FCL_Local7` | 16..23 | Aplicacao-customizavel |

### 3.2 Severities (TSyslogSeverity)

| Valor | Label |
| --- | --- |
| `Emergency` | Sistema inutilizavel |
| `Alert` | Accao imediata necessaria |
| `Critical` | Condicao critica |
| `Error` | Erro |
| `Warning` | Aviso |
| `Notice` | Normal mas significativo |
| `Info` | Informativo |
| `Debug` | Debug |

### 3.3 Version

| Valor | Significado |
| --- | --- |
| `RFC3164` | Formato classico |
| `RFC5424` | V1 com ms timestamp e campos estruturados |

## 4. Funcionalidades

### 4.1 TSyslogMessage

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Clear | `procedure Clear;` | Reset para defaults. |
| Version | `property TSyslogVersion;` | `RFC3164` ou `RFC5424`. |
| Facility | `property Byte;` | Usar `FCL_*`. Default `FCL_Local0`. |
| Severity | `property TSyslogSeverity;` | Default `Debug`. |
| DateTime | `property TDateTime;` | Timestamp da mensagem. |
| Tag | `property String;` | Identificador do processo (default: basename do executavel). |
| AppName | `property String;` | Alias para `Tag` (naming RFC-5424). |
| ProcID | `property String;` | Handle / transacao. |
| MsgID | `property String;` | Categoria da mensagem. |
| LogMessage | `property String;` | Corpo. |
| LocalIP | `property String;` | IP de origem. |
| PacketBuf | `property AnsiString;` | Packet binario (leitura OK nas duas versoes; escrita so RFC3164 -- deprecated). |

### 4.2 TSyslogSend

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Create | `constructor Create;` | Aloca `TUDPBlockSocket` + `TSyslogMessage`. |
| Destroy | `destructor Destroy; override;` | Liberta. |
| DoIt | `function DoIt: Boolean;` | Envia pacote UDP para `TargetHost:TargetPort`. |
| SysLogMessage | `property TSysLogMessage;` | Mensagem a enviar. |

### 4.3 Funcoes globais

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| ToSysLog | `function ToSysLog(const SyslogServer: string; Facil: Byte; Sever: TSyslogSeverity; const Content: string): Boolean;` | One-shot RFC-3164. |
| ToSysLog1 | `function ToSysLog1(const SyslogServer: string; Facil: Byte; Sever: TSyslogSeverity; const ProcID, MsgID, Content: string): Boolean;` | One-shot RFC-5424. |

## 5. Aplicabilidades

1. **Centralizacao de logs** -- enviar para rsyslog/syslog-ng/Graylog de todo o parque.
2. **SIEM integration** -- feed de eventos para Splunk/QRadar.
3. **Audit trails** -- com `FCL_LogAudit` para nao misturar com logs aplicacionais.
4. **Alertas hardware** -- firmware embarcado emitindo para NOC.
5. **Multi-tenant custom** -- `FCL_Local0..Local7` para separar produtos internos.

## 6. Exemplos de uso

### 6.1 One-shot RFC-3164

```pascal
uses
  SysUtils, slogsend;

begin
  ToSysLog('10.0.0.10',
           FCL_Local0,
           Warning,
           'Servico X reiniciou apos timeout');
end.
```

### 6.2 Mensagem RFC-5424 estruturada

```pascal
uses
  SysUtils, slogsend;

begin
  ToSysLog1('logserver.example.com',
            FCL_LogAudit,
            Notice,
            '12345',       // ProcID
            'USR-LOGIN',   // MsgID
            'Utilizador joao autenticado com sucesso');
end.
```

### 6.3 Construcao manual de `TSyslogSend`

```pascal
uses
  SysUtils, slogsend;

var
  LSyslog: TSyslogSend;
begin
  LSyslog := TSyslogSend.Create;
  try
    LSyslog.TargetHost := '10.0.0.10';
    LSyslog.TargetPort := '514';
    LSyslog.SysLogMessage.Version := RFC5424;
    LSyslog.SysLogMessage.Facility := FCL_Local3;
    LSyslog.SysLogMessage.Severity := Error;
    LSyslog.SysLogMessage.AppName := 'GestorERP';
    LSyslog.SysLogMessage.ProcID := IntToStr(GetProcessID);
    LSyslog.SysLogMessage.MsgID := 'DB-CONN-FAIL';
    LSyslog.SysLogMessage.LogMessage := 'Falha ao conectar a base de dados';
    LSyslog.SysLogMessage.DateTime := Now;
    LSyslog.DoIt;
  finally
    LSyslog.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` | Superclasse | Host/porta. |
| `TUDPBlockSocket` | Composicao | Socket UDP. |
| `TSyslogMessage` | Composicao | Body da mensagem. |
| `synautil` | Dependencia | Helpers de data/string. |
