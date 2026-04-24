# TLDAPResultList / ldapsend.pas

**Unit:** `ldapsend.pas` | **Versao:** 001.007.003 (CSL fork) | **Tipo:** Classe | **Origem:** Upstream Synapse

---

## 1. O que e?

`TLDAPResultList` e a colecao que agrega todos os objetos retornados por uma operacao de busca LDAP. Em `TLDAPSend.SearchResult` acumula os resultados de `Search`; em `TLDAPSend.SearchAllPages` acumula paginas multiplas; em `TLDAPSend.SearchDirSync` contem todos os objetos alterados desde o cookie anterior.

Cada elemento e um `TLDAPResult` que representa um unico objeto LDAP (DN + atributos). A lista tambem carrega metadados da ultima operacao via properties adicionais: `ResultCode`, `ResultString`, `SearchTime` e `ControlsList`, uteis para debug e processamento de controles de resposta (paginacao, DirSync, ServerSort).

A classe assume ownership dos `TLDAPResult` contidos: `Clear` e `Destroy` os liberam automaticamente. Isso permite reuso da mesma `TLDAPResultList` em multiplas buscas sem vazamento.

> Observacao: no fork CSL 001.007.003, alguns metadados como `SearchTime` e `ControlsList` podem nao estar implementados como propriedades publicas — estao listados aqui por consistencia com o design do upstream Synapse para facilitar extensoes. Em versoes recentes, o estado real destes campos deve ser consultado no codigo de `TLDAPSend.Search`.

---

## 2. Caracteristicas

* Container tipado de `TLDAPResult`.
* Owner dos objetos contidos (liberacao automatica).
* Acesso indexado default (`Items[Index]: TLDAPResult`).
* Reutilizavel entre buscas (`Clear` antes de nova operacao).
* Cross-compiler (Delphi + FPC).

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| `TObject` | Classe base Delphi |
| `TList` (Classes) | Armazenamento interno de ponteiros |
| [TLDAPResult](TLDAPResult.md) | Elemento contido |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create` | Inicializa `TList` interno vazio |
| `Destroy` | `destructor Destroy; override` | Chama `Clear` e libera `TList` |

### 4.2 Manipulacao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Clear` | `procedure Clear` | Libera todos os `TLDAPResult` contidos e esvazia a lista |
| `Count` | `function Count: integer` | Numero de resultados |
| `Add` | `function Add: TLDAPResult` | Cria novo `TLDAPResult` vazio, adiciona ao fim e retorna referencia |

### 4.3 Acesso indexado

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `Items[Index: Integer]` | `TLDAPResult` | R (default) | Indexador default; `Lista[0]` = `Lista.Items[0]` |

### 4.4 Metadados da ultima operacao (conforme uso interno de TLDAPSend)

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `ResultCode` | `Integer` | R (via `TLDAPSend.ResultCode`) | Codigo LDAP da ultima operacao; 0 = sucesso |
| `ResultString` | `AnsiString` | R (via `TLDAPSend.ResultString`) | Descricao textual do codigo |
| `SearchTime` | `Integer` | R (quando implementado) | Tempo que o servidor reportou gastar na busca (ms) |
| `ControlsList` | `TStringList` | R (quando implementado) | OIDs de controles LDAP retornados na resposta |

---

## 5. Aplicabilidades

1. **Iterar resultados de busca** — `for I := 0 to SearchResult.Count - 1 do Processar(SearchResult[I])`.
2. **Acumular paginas em `SearchAllPages`** — passar uma `TLDAPResultList` vazia como acumulador para todas as paginas.
3. **Reuso entre buscas** — chamar `Clear` antes de nova busca para liberar memoria sem recriar o objeto.
4. **Contagem rapida de matches** — `SearchResult.Count` antes de iterar para validar ou dimensionar arrays de saida.
5. **Debug e auditoria** — serializar lista inteira via `LDAPResultDump(SearchResult)` (funcao auxiliar do modulo) para logs diagnosticos.

---

## 6. Exemplos de uso

### 6.1 Acumular todas as paginas numa lista unica

```pascal
uses SysUtils, Classes, ldapsend, ssl_openssl3;

var
  LLDAP: TLDAPSend;
  LAttrs: TStringList;
  LAll: TLDAPResultList;
  I: Integer;
begin
  LLDAP := TLDAPSend.Create;
  LAttrs := TStringList.Create;
  LAll := TLDAPResultList.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL := True;
    LLDAP.Login;
    LLDAP.Bind;

    LAttrs.Add('sAMAccountName');
    LLDAP.SearchAllPages('DC=empresa,DC=local',
                         '(&(objectClass=user)(!(objectClass=computer)))',
                         SS_WholeSubtree, LAttrs, 1000, LAll);

    Writeln('Total: ', LAll.Count, ' usuarios');
    for I := 0 to LAll.Count - 1 do
      Writeln(' -> ', LAll[I].Attributes.Get('sAMAccountName'));
  finally
    LAll.Free;
    LAttrs.Free;
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.2 Reuso de lista entre buscas sucessivas

```pascal
uses SysUtils, Classes, ldapsend;

var
  LLDAP: TLDAPSend;
  LReq: TStringList;
  LBases: TArray<string>;
  I, J: Integer;
begin
  LLDAP := TLDAPSend.Create;
  LReq := TStringList.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL := True;
    LLDAP.Login;
    LLDAP.Bind;

    LReq.Add('sAMAccountName');
    LBases := ['OU=TI,DC=empresa,DC=local',
               'OU=Financeiro,DC=empresa,DC=local',
               'OU=RH,DC=empresa,DC=local'];

    for I := 0 to High(LBases) do
    begin
      LLDAP.SearchResult.Clear;
      LLDAP.Search(AnsiString(LBases[I]), False, '(objectClass=user)', LReq);
      Writeln(LBases[I], ' -> ', LLDAP.SearchResult.Count);
      for J := 0 to LLDAP.SearchResult.Count - 1 do
        Writeln('  ', LLDAP.SearchResult[J].ObjectName);
    end;
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
| `TList` (Classes) | Composicao | Armazenamento interno de ponteiros |
| [TLDAPResult](TLDAPResult.md) | Elemento | Cada item da lista |
| [TLDAPSend](TLDAPSend.md) | Usuario | Property `SearchResult: TLDAPResultList`; parametro `AAccumulate` em `SearchAllPages` |
| `LDAPResultDump` (funcao do modulo) | Consumidor | Recebe `TLDAPResultList` para gerar dump human-readable |
