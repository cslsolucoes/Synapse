# TLDAPAttributeList / ldapsend.pas

**Unit:** `ldapsend.pas` | **Versao:** 001.007.003 (CSL fork) | **Tipo:** Classe | **Origem:** Upstream Synapse

---

## 1. O que e?

`TLDAPAttributeList` e uma colecao de `TLDAPAttribute` que representa o conjunto completo de atributos de um objeto LDAP. Herda directamente de `TObject` e usa um `TList` interno (`FAttributeList`) para armazenar ponteiros para as instancias de `TLDAPAttribute`.

A classe assume propriedade (ownership) dos objetos contidos: `Destroy` e `Clear` invocam `Free` em cada item, liberando a memoria. Isto simplifica o codigo consumidor que nao precisa se preocupar com liberacao individual de atributos.

Em operacoes de `Search`, cada `TLDAPResult.Attributes` e uma `TLDAPAttributeList` populada automaticamente pelo decoder ASN.1 com os atributos retornados pelo servidor. Em operacoes de `Add`, o consumidor constroi manualmente a lista de atributos do novo objeto antes de chamar `TLDAPSend.Add`.

---

## 2. Caracteristicas

* Container tipado de `TLDAPAttribute` (nao-generico; indexador tipado em `Items`).
* Owner dos atributos contidos (chamadas a `Del`, `Clear` e `Destroy` liberam memoria).
* Busca case-insensitive por nome de atributo via `Find` / `Get`.
* Acesso indexado default (`Items[Index]: TLDAPAttribute`) permite sintaxe `LList[0]`.
* Thread-safety: nao thread-safe (herda limitacoes do `TList`).
* Cross-compiler (Delphi + FPC).

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| `TList` (Classes / System.Classes) | Armazena ponteiros dos `TLDAPAttribute` internamente |
| `TLDAPAttribute` | Elemento contido; criado via `Add` e liberado automaticamente em `Del`/`Clear`/`Destroy` |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create` | Inicializa `TList` interno vazio |
| `Destroy` | `destructor Destroy; override` | Chama `Clear` (libera todos os atributos) e depois libera o `TList` |

### 4.2 Manipulacao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Clear` | `procedure Clear` | Libera todos os `TLDAPAttribute` e esvazia o `TList` |
| `Count` | `function Count: integer` | Numero de atributos na lista |
| `Add` | `function Add: TLDAPAttribute` | Cria novo `TLDAPAttribute` vazio, adiciona ao fim da lista e retorna referencia |
| `Del` | `procedure Del(Index: integer)` | Libera e remove o atributo na posicao `Index` |

### 4.3 Busca

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Find` | `function Find(AttributeName: AnsiString): TLDAPAttribute` | Procura atributo por nome (case-insensitive); retorna `nil` se nao encontrado |
| `Get` | `function Get(AttributeName: AnsiString): string` | Retorna primeiro valor do atributo com o nome dado; string vazia se nao encontrado ou atributo vazio |

### 4.4 Acesso indexado

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `Items[Index: Integer]` | `TLDAPAttribute` | R (default) | Indexador default; `Lista[0]` equivale a `Lista.Items[0]` |

---

## 5. Aplicabilidades

1. **Construir payload para `TLDAPSend.Add`** — criar `TLDAPAttributeList` + adicionar atributos (`objectClass`, `cn`, `sAMAccountName`, etc.) antes de chamar `Add('CN=Novo,OU=Users,...')`.
2. **Consumir resultados de busca** — iterar `SearchResult[i].Attributes[j]` para processar atributos retornados.
3. **Consulta rapida de atributo unico** — usar `Get('mail')` quando so interessa o primeiro valor (substitui `Find('mail').Strings[0]` com checagem de `nil`).
4. **Validacao de atributos obrigatorios** — antes de `Add`, testar `Find` para garantir que `objectClass`, `cn` estao presentes.
5. **Atualizacao em lote via caching** — carregar `Attributes` de busca, modificar valores em memoria, enviar de volta via `Modify` individual por atributo.

---

## 6. Exemplos de uso

### 6.1 Criar novo usuario AD (Add com AttributeList)

```pascal
uses SysUtils, ldapsend, ssl_openssl3;

var
  LLDAP: TLDAPSend;
  LAttrs: TLDAPAttributeList;
  LAttr: TLDAPAttribute;
begin
  LLDAP := TLDAPSend.Create;
  LAttrs := TLDAPAttributeList.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL := True;
    LLDAP.Login;
    LLDAP.Bind;

    LAttr := LAttrs.Add;
    LAttr.AttributeName := 'objectClass';
    LAttr.Add('top');
    LAttr.Add('person');
    LAttr.Add('organizationalPerson');
    LAttr.Add('user');

    LAttr := LAttrs.Add;
    LAttr.AttributeName := 'cn';
    LAttr.Add('Maria Souza');

    LAttr := LAttrs.Add;
    LAttr.AttributeName := 'sAMAccountName';
    LAttr.Add('maria.souza');

    if LLDAP.Add('CN=Maria Souza,OU=Users,DC=empresa,DC=local', LAttrs) then
      Writeln('Usuario criado')
    else
      Writeln('Erro: ', LLDAP.ResultString);
  finally
    LAttrs.Free;
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.2 Iterar todos os atributos de um resultado de busca

```pascal
uses SysUtils, Classes, ldapsend;

var
  LLDAP: TLDAPSend;
  LReq: TStringList;
  I, J: Integer;
  LAttr: TLDAPAttribute;
begin
  LLDAP := TLDAPSend.Create;
  LReq := TStringList.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL := True;
    LLDAP.Login;
    LLDAP.Bind;

    LReq.Add('*');
    LLDAP.Search('DC=empresa,DC=local', False,
                 '(sAMAccountName=maria.souza)', LReq);

    for I := 0 to LLDAP.SearchResult.Count - 1 do
      for J := 0 to LLDAP.SearchResult[I].Attributes.Count - 1 do
      begin
        LAttr := LLDAP.SearchResult[I].Attributes[J];
        Writeln(LAttr.AttributeName, ' = ', LAttr.CommaText);
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
| `TList` (Classes) | Composicao | Armazenamento interno dos ponteiros de atributos |
| [TLDAPAttribute](TLDAPAttribute.md) | Elemento contido | Cada item da lista |
| [TLDAPResult](TLDAPResult.md) | Usuario | `TLDAPResult.Attributes` e um `TLDAPAttributeList` |
| [TLDAPSend](TLDAPSend.md) | Consumidor | `TLDAPSend.Add` recebe `TLDAPAttributeList`; resultados de `Search` populam internamente |
