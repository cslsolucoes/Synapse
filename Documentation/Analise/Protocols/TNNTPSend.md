# TNNTPSend

**Unit:** `nntpsend.pas` | **Versao:** 001.005.003 | **Tipo:** Classe | **Origem:** Upstream

---

## 1. O que e?

`TNNTPSend` e o cliente Network News Transfer Protocol (RFC-977) com extensoes RFC-2980 (XOVER, XHDR, NEWGROUPS, NEWNEWS, LIST EXTENSIONS). NNTP e o protocolo dos grupos Usenet e de feeds interno de noticias corporativas (Exchange public folders historicamente).

Herda de `TSynaClient`, pode usar AUTHINFO USER/PASS, suporta STARTTLS (NNTPS em porta 563 via `FullSSL`) e mantem duas estruturas paralelas: `Data: TStringList` (dados recebidos ou a enviar) e `FullResult` (resultado multi-linha de ultimo comando).

O fluxo tipico e: Login -> SelectGroup -> (GetArticle | GetHead | GetBody | Xover | Post) -> Logout.

## 2. Caracteristicas

- NNTP (RFC-977) + extensoes (RFC-2980)
- Autenticacao AUTHINFO USER/PASS
- STARTTLS (pode sobre porta 119) e NNTPS (FullSSL sobre 563)
- Metodos wrapper para XOVER (overview), XHDR (header search)
- Post de novos artigos; IHAVE (modo server-to-server)
- NEWGROUPS/NEWNEWS para sync incremental

## 3. Engine

| Directiva / Runtime | Valor |
| --- | --- |
| Porta NNTP | `cNNTPProtocol = '119'` |
| Porta NNTPS (FullSSL) | `563` (convencional) |
| Herda de | `TSynaClient` |
| AutoTLS default | `False` |

## 4. Funcionalidades

### 4.1 Sessao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| Login | `function Login: Boolean;` | Conecta + AUTHINFO + opcional STARTTLS. |
| Logout | `function Logout: Boolean;` | QUIT. |
| StartTLS | `function StartTLS: Boolean;` | Upgrade TLS. |
| DoCommand | `function DoCommand(const Command: string): boolean;` | Comando arbitrario sem body. |
| DoCommandRead | `function DoCommandRead(const Command: string): boolean;` | Comando com download multi-linha. |
| DoCommandWrite | `function DoCommandWrite(const Command: string): boolean;` | Comando com upload (POST/IHAVE). |
| ListExtensions | `function ListExtensions: Boolean;` | LIST EXTENSIONS. |
| FindCap | `function FindCap(const Value: string): string;` | Pesquisa capability. |

### 4.2 Navegacao em grupos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| SelectGroup | `function SelectGroup(const Value: string): Boolean;` | GROUP. |
| GotoLast | `function GotoLast: Boolean;` | LAST. |
| GotoNext | `function GotoNext: Boolean;` | NEXT. |
| ListGroups | `function ListGroups: Boolean;` | LIST ACTIVE. |
| ListNewGroups | `function ListNewGroups(Since: TDateTime): Boolean;` | NEWGROUPS. |
| NewArticles | `function NewArticles(const Group: string; Since: TDateTime): Boolean;` | NEWNEWS. |

### 4.3 Artigos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| GetArticle | `function GetArticle(const Value: string): Boolean;` | ARTICLE (headers + body). |
| GetHead | `function GetHead(const Value: string): Boolean;` | HEAD. |
| GetBody | `function GetBody(const Value: string): Boolean;` | BODY. |
| GetStat | `function GetStat(const Value: string): Boolean;` | STAT. |
| PostArticle | `function PostArticle: Boolean;` | POST (envia `DataToSend`). |
| IHave | `function IHave(const MessID: string): Boolean;` | IHAVE. |
| SwitchToSlave | `function SwitchToSlave: Boolean;` | SLAVE. |
| Xover | `function Xover(xoStart, xoEnd: string): boolean;` | XOVER range. |

### 4.4 Properties

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| ResultCode | `property Integer;` | Codigo NNTP. |
| ResultString | `property string;` | Linha principal. |
| Data | `property TStringList;` | Resultado ou body para upload. |
| AutoTLS | `property Boolean;` | Upgrade TLS. |
| FullSSL | `property Boolean;` | NNTPS desde inicio. |
| Sock | `property TTCPBlockSocket;` | Socket. |

## 5. Aplicabilidades

1. **Leitor Usenet** -- newsreader multiplataforma.
2. **Sync de feeds internos** -- Exchange public folders via NNTP gateway.
3. **Monitor de lists** -- leitura de mailing lists replicadas em NNTP.
4. **Server-to-server feed** -- IHAVE para peering entre news servers.
5. **Archival** -- backup completo de grupos por XOVER + ARTICLE.

## 6. Exemplos de uso

### 6.1 Listar artigos novos num grupo

```pascal
uses
  SysUtils, Classes, nntpsend;

var
  LNntp: TNNTPSend;
  I: Integer;
begin
  LNntp := TNNTPSend.Create;
  try
    LNntp.TargetHost := 'news.example.com';
    LNntp.TargetPort := '119';
    if LNntp.Login then
    try
      LNntp.SelectGroup('comp.lang.pascal.delphi.misc');
      LNntp.Xover('1000', '1050');
      for I := 0 to LNntp.Data.Count - 1 do
        Writeln(LNntp.Data[I]);
    finally
      LNntp.Logout;
    end;
  finally
    LNntp.Free;
  end;
end.
```

### 6.2 Post de novo artigo

```pascal
uses
  SysUtils, Classes, nntpsend;

var
  LNntp: TNNTPSend;
begin
  LNntp := TNNTPSend.Create;
  try
    LNntp.TargetHost := 'news.example.com';
    LNntp.Username := 'u'; LNntp.Password := 'p';
    if LNntp.Login then
    try
      LNntp.Data.Clear;
      LNntp.Data.Add('From: me@example.com');
      LNntp.Data.Add('Newsgroups: local.test');
      LNntp.Data.Add('Subject: Test post');
      LNntp.Data.Add('');
      LNntp.Data.Add('Ola mundo NNTP.');
      LNntp.PostArticle;
    finally
      LNntp.Logout;
    end;
  finally
    LNntp.Free;
  end;
end.
```

### 6.3 Download full de artigo por message-id

```pascal
uses
  SysUtils, Classes, nntpsend;

var
  LNntp: TNNTPSend;
begin
  LNntp := TNNTPSend.Create;
  try
    LNntp.TargetHost := 'news.example.com';
    if LNntp.Login then
    try
      if LNntp.GetArticle('<abc123@example.com>') then
        LNntp.Data.SaveToFile('/path/to/article.txt');
    finally
      LNntp.Logout;
    end;
  finally
    LNntp.Free;
  end;
end.
```

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TSynaClient` | Superclasse | Host/porta/credenciais. |
| `TTCPBlockSocket` | Composicao | TCP + TLS. |
| `synautil` | Dependencia | Parse de datas (NEWGROUPS/NEWNEWS). |
| Plugin SSL | Dependencia opcional | STARTTLS / NNTPS. |
