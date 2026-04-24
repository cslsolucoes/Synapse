# TLDAPResult / ldapsend.pas

**Unit:** `ldapsend.pas` | **Versao:** 001.007.003 (CSL fork) | **Tipo:** Classe | **Origem:** Upstream Synapse

---

## 1. O que e?

`TLDAPResult` representa um unico objeto LDAP retornado em uma busca (`Search`, `SearchDirSync`, `SearchAllPages`, etc.). Contem o DN do objeto (`ObjectName`) e a lista completa de atributos solicitados (`Attributes`) que o servidor retornou para aquele objeto.

A classe e um container simples que herda directamente de `TObject`. Internamente aloca uma `TLDAPAttributeList` no construtor e a libera em `Destroy`. O consumidor acessa os atributos via `Result.Attributes.Find('mail')` ou `Result.Attributes.Get('sAMAccountName')`.

Cada resposta ASN.1 BER do servidor para cada objeto encontrado produz um `TLDAPResult` novo; todos sao acumulados em um `TLDAPResultList` (property `TLDAPSend.SearchResult`).

---

## 2. Caracteristicas

* Container de um objeto LDAP retornado (DN + atributos).
* Owner da `TLDAPAttributeList` contida (liberacao automatica em `Destroy`).
* Sem logica: apenas estrutura de dados.
* `ObjectName` e `AnsiString` (compatibilidade camada ASN.1/LDAP).
* Cross-compiler (Delphi + FPC).

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| `TObject` | Classe base Delphi |
| [TLDAPAttributeList](TLDAPAttributeList.md) | Composicao automatica via construtor |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create` | Aloca `FAttributes := TLDAPAttributeList.Create` |
| `Destroy` | `destructor Destroy; override` | Libera `FAttributes` (que por sua vez libera todos os atributos contidos) |

### 4.2 Properties publicadas

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `ObjectName` | `AnsiString` | R/W | DN completo do objeto LDAP (ex.: `CN=Joao,OU=Users,DC=empresa,DC=local`) |
| `Attributes` | `TLDAPAttributeList` | R | Lista de atributos do objeto; popula automaticamente pelo decoder de `Search` |

---

## 5. Aplicabilidades

1. **Processar resultados de busca** — iterar `SearchResult[i]` e extrair `ObjectName` + atributos relevantes.
2. **Mapear para DTO de dominio** — copiar valores de `Attributes.Get('sAMAccountName')`, `Attributes.Get('mail')` para um `TUser` record.
3. **Construir filtros incrementais** — usar `ObjectName` de um resultado como `Base` para busca subsequente mais especifica.
4. **Auditoria / log de presenca** — registrar `ObjectName` + `whenCreated` / `whenChanged` para detectar objetos novos/alterados.
5. **DirSync incremental** — em resposta a `SearchDirSync`, cada `TLDAPResult` representa um objeto modificado desde o ultimo cookie.

---

## 6. Exemplos de uso

### 6.1 Extrair usuario completo de uma busca

```pascal
uses SysUtils, Classes, ldapsend;

type
  TUserDTO = record
    DN, SamAccount, Mail, DisplayName: string;
    UserAccountControl: Integer;
  end;

function CarregarUsuario(ALDAP: TLDAPSend;
                         const ASam: AnsiString): TUserDTO;
var
  LAttrs: TStringList;
  LItem: TLDAPResult;
begin
  FillChar(Result, SizeOf(Result), 0);
  LAttrs := TStringList.Create;
  try
    LAttrs.Add('sAMAccountName');
    LAttrs.Add('mail');
    LAttrs.Add('displayName');
    LAttrs.Add('userAccountControl');
    if ALDAP.Search('DC=empresa,DC=local', False,
                    '(sAMAccountName=' +
                    TLDAPSend.EscapeFilterValue(ASam) + ')', LAttrs) then
      if ALDAP.SearchResult.Count > 0 then
      begin
        LItem := ALDAP.SearchResult[0];
        Result.DN         := string(LItem.ObjectName);
        Result.SamAccount := LItem.Attributes.Get('sAMAccountName');
        Result.Mail       := LItem.Attributes.Get('mail');
        Result.DisplayName := LItem.Attributes.Get('displayName');
        Result.UserAccountControl :=
          StrToIntDef(LItem.Attributes.Get('userAccountControl'), 0);
      end;
  finally
    LAttrs.Free;
  end;
end;
```

### 6.2 Listar OUs filhas de um container

```pascal
uses SysUtils, Classes, ldapsend;

var
  LLDAP: TLDAPSend;
  LReq: TStringList;
  I: Integer;
begin
  LLDAP := TLDAPSend.Create;
  LReq := TStringList.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL := True;
    LLDAP.SearchScope := SS_SingleLevel;
    LLDAP.Login;
    LLDAP.Bind;

    LReq.Add('ou');
    LReq.Add('description');
    LLDAP.Search('OU=Filiais,DC=empresa,DC=local', False,
                 '(objectClass=organizationalUnit)', LReq);

    for I := 0 to LLDAP.SearchResult.Count - 1 do
      Writeln(LLDAP.SearchResult[I].ObjectName, ' -> ',
              LLDAP.SearchResult[I].Attributes.Get('description'));
  finally
    LReq.Free;
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TObject` | Heranca | Classe base Delphi |
| [TLDAPAttributeList](TLDAPAttributeList.md) | Composicao | Property `Attributes` (owner) |
| [TLDAPResultList](TLDAPResultList.md) | Container | `TLDAPResultList` contem multiplos `TLDAPResult` |
| [TLDAPSend](TLDAPSend.md) | Gerador | Cria `TLDAPResult` ao decodificar cada `LDAP_ASN1_SEARCH_ENTRY` |
