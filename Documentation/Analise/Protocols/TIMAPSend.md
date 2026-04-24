# TIMAPSend

**Unit:** `imapsend.pas` | **Versao:** 002.005.004 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TIMAPSend` e o cliente IMAP4rev1 (RFC-2060) do Synapse, com extensoes STARTTLS (RFC-2595). Ao contrario do POP3, IMAP e stateful com pastas (mailboxes / folders) e flags por mensagem (Seen, Flagged, Deleted, Answered, Draft, Recent).

Cada comando IMAP e identificado por uma tag sequencial (`FTagCommand`) e a resposta do servidor pode ser multi-linha com literais `{N}` (octet count). A classe gere esse parsing internamente via `IMAPcommand`/`IMAPuploadCommand` e oferece metodos de alto nivel para operacoes comuns: `List`, `Select`, `Search`, `Fetch`, `Store`, `Expunge`, `Copy`.

Suporta modo UID (`UID=True`): quando ligado, todas as referencias a mensagens usam UIDs persistentes em vez de sequence numbers voläteis. Isto e obrigatorio em aplicacoes de sincronizacao (IDLE / Offline IMAP).

## 2. Caracteristicas

- IMAP4rev1 (RFC-2060) + STARTTLS (RFC-2595)
- Gestao de folders: List, Select, Examine (readonly), Create, Delete, Rename, Subscribe/Unsubscribe
- Operacoes em mensagens: Fetch full / headers, Store flags, Copy, Append, Delete, Expunge
- Busca server-side (`SearchMess`): criterios SQL-like (`FROM user@x`, `UNSEEN`, `SINCE 1-Jan-2026`, etc.)
- UID mode: referencias persistentes a mensagens
- StatusFolder: query de contadores (UNSEEN, MESSAGES, UIDNEXT, etc.)
- Processamento de literais `{N}` automatico
- AutoTLS + FullSSL

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Porta IMAP | `cIMAPProtocol = '143'` |
| Porta IMAPS (FullSSL) | `993` (convencional) |
| Herda de | `TSynaClient` |
| UID default | `False` (sequence numbers) |
| Auth | LOGIN via `AuthLogin` (USER/PASS) |

## 4. Funcionalidades

### 4.1 Sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Login | `function Login: Boolean;` | Conecta + CAPABILITY + AUTH + opcional STARTTLS. |
| Logout | `function Logout: Boolean;` | LOGOUT. |
| StartTLS | `function StartTLS: Boolean;` | Upgrade STARTTLS. |
| NoOp | `function NoOp: Boolean;` | Keep-alive + flush de notifications. |
| Capability | `function Capability: Boolean;` | Preenche `IMAPcap`. |
| IMAPcommand | `function IMAPcommand(Value: string): string;` | Comando arbitrario. |
| IMAPuploadCommand | `function IMAPuploadCommand(Value: string; const Data: TStrings): string;` | Comando com upload (APPEND). |
| FindCap | `function FindCap(const Value: string): string;` | Procura capability. |

### 4.2 Folders

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| List | `function List(FromFolder: string; const FolderList: TStrings): Boolean;` | LIST. |
| ListSearch | `function ListSearch(FromFolder, Search: string; const FolderList: TStrings): Boolean;` | LIST com padrao. |
| ListSubscribed | `function ListSubscribed(...): Boolean;` | LSUB. |
| ListSearchSubscribed | `function ListSearchSubscribed(...): Boolean;` | LSUB com padrao. |
| CreateFolder | `function CreateFolder(FolderName: string): Boolean;` | CREATE. |
| DeleteFolder | `function DeleteFolder(FolderName: string): Boolean;` | DELETE. |
| RenameFolder | `function RenameFolder(FolderName, NewFolderName: string): Boolean;` | RENAME. |
| SubscribeFolder | `function SubscribeFolder(FolderName: string): Boolean;` | SUBSCRIBE. |
| UnsubscribeFolder | `function UnsubscribeFolder(FolderName: string): Boolean;` | UNSUBSCRIBE. |
| SelectFolder | `function SelectFolder(FolderName: string): Boolean;` | SELECT (read-write). |
| SelectROFolder | `function SelectROFolder(FolderName: string): Boolean;` | EXAMINE (read-only). |
| CloseFolder | `function CloseFolder: Boolean;` | CLOSE (expunge implicito). |
| StatusFolder | `function StatusFolder(FolderName, Value: string): integer;` | STATUS. |
| ExpungeFolder | `function ExpungeFolder: Boolean;` | EXPUNGE. |
| CheckFolder | `function CheckFolder: Boolean;` | CHECK. |

### 4.3 Mensagens

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| AppendMess | `function AppendMess(ToFolder: string; const Mess: TStrings): Boolean;` | APPEND. |
| DeleteMess | `function DeleteMess(MessID: integer): boolean;` | Marca \\Deleted. |
| FetchMess | `function FetchMess(MessID: integer; const Mess: TStrings): Boolean;` | FETCH RFC822 full. |
| FetchHeader | `function FetchHeader(MessID: integer; const Headers: TStrings): Boolean;` | FETCH RFC822.HEADER. |
| MessageSize | `function MessageSize(MessID: integer): integer;` | FETCH RFC822.SIZE. |
| CopyMess | `function CopyMess(MessID: integer; ToFolder: string): Boolean;` | COPY. |
| SearchMess | `function SearchMess(Criteria: string; const FoundMess: TStrings): Boolean;` | SEARCH. |
| SetFlagsMess | `function SetFlagsMess(MessID: integer; Flags: string): Boolean;` | STORE FLAGS. |
| GetFlagsMess | `function GetFlagsMess(MessID: integer; var Flags: string): Boolean;` | FETCH FLAGS. |
| AddFlagsMess | `function AddFlagsMess(MessID: integer; Flags: string): Boolean;` | STORE +FLAGS. |
| DelFlagsMess | `function DelFlagsMess(MessID: integer; Flags: string): Boolean;` | STORE -FLAGS. |
| GetUID | `function GetUID(MessID: integer; var UID: Integer): Boolean;` | Converte MSN -> UID. |

### 4.4 Properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| ResultString | `property ResultString: string;` | Linha de status do ultimo comando. |
| FullResult | `property FullResult: TStringList;` | Todas as linhas. |
| IMAPcap | `property IMAPcap: TStringList;` | Capabilities. |
| AuthDone | `property AuthDone: Boolean;` | Auth bem sucedida. |
| UID | `property UID: Boolean;` | Liga modo UID-based. |
| SelectedFolder | `property SelectedFolder: string;` | Folder corrente. |
| SelectedCount | `property SelectedCount: integer;` | Mensagens no folder. |
| SelectedRecent | `property SelectedRecent: integer;` | Mensagens \\Recent. |
| SelectedUIDvalidity | `property SelectedUIDvalidity: integer;` | UIDVALIDITY (muda se folder foi recriado). |
| AutoTLS | `property AutoTLS: Boolean;` | STARTTLS se disponivel. |
| FullSSL | `property FullSSL: Boolean;` | IMAPS. |
| Sock | `property Sock: TTCPBlockSocket;` | Socket. |

## 5. Aplicabilidades

1. **Sync incremental de mailbox** -- uso de UID + UIDVALIDITY para replicar estado em cache local.
2. **Arquivo hierarquico** -- manipulacao de folders (Inbox, Arquivo/2026, etc.) com Create/Rename/Delete.
3. **Busca server-side** -- `SearchMess` com criterios para extraccao targetada.
4. **Sistemas de ticketing** -- leitura de email -> criacao de ticket + flag custom.
5. **Flagging automatizado** -- marcacao de spam/important por regras no cliente.

## 6. Exemplos de uso

### 6.1 List folders + select + read unseen

```pascal
uses
  SysUtils, Classes, imapsend;

var
  LImap: TIMAPSend;
  LFolders, LFound, LMess: TStringList;
  I: Integer;
begin
  LImap := TIMAPSend.Create;
  LFolders := TStringList.Create;
  LFound := TStringList.Create;
  LMess := TStringList.Create;
  try
    LImap.TargetHost := 'imap.example.com';
    LImap.TargetPort := '993';
    LImap.Username := 'u@example.com';
    LImap.Password := 'p';
    LImap.FullSSL := True;
    LImap.UID := True;
    if LImap.Login then
    try
      LImap.List('', LFolders);
      Writeln('Folders:'); Writeln(LFolders.Text);
      LImap.SelectFolder('INBOX');
      LImap.SearchMess('UNSEEN', LFound);
      for I := 0 to LFound.Count - 1 do
      begin
        LImap.FetchHeader(StrToInt(LFound[I]), LMess);
        Writeln('--- ', LFound[I], ' ---');
        Writeln(LMess.Text);
      end;
    finally
      LImap.Logout;
    end;
  finally
    LMess.Free; LFound.Free; LFolders.Free; LImap.Free;
  end;
end.
```

### 6.2 Move mensagem para "Arquivo"

```pascal
uses
  SysUtils, imapsend;

var
  LImap: TIMAPSend;
begin
  LImap := TIMAPSend.Create;
  try
    LImap.TargetHost := 'imap.example.com';
    LImap.Username := 'u'; LImap.Password := 'p';
    LImap.FullSSL := True;
    if LImap.Login then
    try
      LImap.SelectFolder('INBOX');
      LImap.CopyMess(42, 'Arquivo');
      LImap.DeleteMess(42);
      LImap.ExpungeFolder;
    finally
      LImap.Logout;
    end;
  finally
    LImap.Free;
  end;
end.
```

### 6.3 APPEND de mensagem gerada localmente

```pascal
uses
  SysUtils, Classes, imapsend;

var
  LImap: TIMAPSend;
  LMess: TStringList;
begin
  LImap := TIMAPSend.Create;
  LMess := TStringList.Create;
  try
    LMess.Add('From: me@example.com');
    LMess.Add('To: me@example.com');
    LMess.Add('Subject: Nota interna');
    LMess.Add('');
    LMess.Add('Corpo do lembrete.');
    LImap.TargetHost := 'imap.example.com';
    LImap.Username := 'me'; LImap.Password := 'p';
    LImap.FullSSL := True;
    if LImap.Login then
    try
      LImap.AppendMess('Drafts', LMess);
    finally
      LImap.Logout;
    end;
  finally
    LMess.Free; LImap.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` | Superclasse | Host/porta/credenciais. |
| `TTCPBlockSocket` | Composicao | TCP + TLS. |
| `synautil` | Dependencia | Parser de linhas/literals. |
| `TMimeMess` (mimemess) | Parceiro | Decompor mensagem baixada. |
| Plugin SSL | Dependencia opcional | STARTTLS / IMAPS. |
