# LDAPSend

**Unit:** `ldapsend.pas` | **Versao Synapse:** 001.007.005 (fork CSL) | **Tipo:** Classe

---

## 1. O que e?

`TLDAPSend` e a implementacao do cliente LDAP v2/v3 da biblioteca Ararat Synapse, estendida pelo fork GestorERP v001.007.002 para suporte completo ao Active Directory (AD) do Windows. A classe herda de `TSynaClient` e utiliza internamente um `TTCPBlockSocket` para toda a comunicacao TCP/LDAPS.

O fork adiciona autenticacao Kerberos via SASL GSSAPI (SSPI inline sobre `secur32.dll`, sem dependencia externa como ICS ou unidades legadas `Windows.pas`), controles AD proprietarios (DirSync, SDFlags, ExtendedDN, ShowDeleted, ShowRecycled, ServerSort, Permissive Modify, TreeDelete), operacoes de senha AD, assinatura de PDU LDAP (LDAP Signing/RFC 4757), utilitarios de conversao FileTime e escaping RFC-conforme de filtros e componentes DN.

O papel arquitetural no GestorERP e ser o motor de autenticacao e consulta AD consumido por `M01LdapAuthenticator` (modulo de autenticacao LDAP do `Infrastructure.Integrations.ActiveDirectory`) e pelo modulo `ActiveDirectoryORM`.

---

## 2. Caracteristicas

- **AD-compatible 100% Windows**: todos os controles e extensoes LDAP sao especificos do Active Directory e funcionam em conexoes LDAP (389) e LDAPS (636).
- **SSPI inline**: autenticacao GSSAPI/Kerberos implementada diretamente com chamadas `secur32.dll` carregadas em runtime — sem dependencia de `JwaWindows`, ICS ou qualquer unidade de terceiros.
- **Channel Binding Token (CBT)**: `BindGSSAPIWithCBT` implementa `tls-server-end-point` (RFC 5929) usando o hash SHA-256 do certificado servidor obtido via `TSSLOpenSSL.GetPeerCertSHA256Hash`.
- **LDAP Signing**: integridade de PDU via SSPI `MakeSignature`/`VerifySignature` ativada pela property `SigningActive`.
- **Paginacao transparente**: `SearchAllPages` itera automaticamente sobre paginas de resultado LDAP sem expor o cookie de paginacao ao chamador.
- **Cross-compiler**: compila em Delphi 12+ e FPC (diretiva `{$IFDEF FPC}` / `{$MODE DELPHI}`).
- **Backward compatible**: toda a API original do Synapse (Bind, BindSasl, Search, Modify, Add, Delete, ModifyDN, Compare, Extended, StartTLS) permanece inalterada.
- **FileTime helpers**: conversao bidirecional entre `TDateTime` Delphi e o formato FileTime de 64 bits do AD.
- **V1.7.0 Tri-plataforma POSIX**: `ldapsend.pas` 001.007.003 destrava Linux/macOS FPC + Delphi LINUX64/macOS64 via 6 blocos SSPI envolvidos em `{$IFDEF MSWINDOWS}` + 4 stubs POSIX (`BindGSSAPI`, `BindGSSAPIWithCBT`, `SignLDAPMessage`, `VerifyLDAPMessage`). GSSAPI real em POSIX agendado para V2.0.0 (port `libgssapi_krb5`).
- **V1.7.1 Tipagem automatica de atributos**: `ldapsend.pas` 001.007.004 introduz enum publico `TLDAPValueType` (16 tipos RFC 4517 + MS-ADTS), mapa estatico `LDAP_KNOWN_ATTRIBUTE_TYPES` (~110 atributos AD default), funcao `ResolveLDAPValueType` e record publico `TLDAPAttributeValue` com API estilo `TField` (`AsString` / `AsInteger` / `AsFloat` / `AsBoolean` / `AsDateTime` / `AsBinary` / `AsHex` / `AsSid` / `AsGuid` / `AsVariant` / `IsNull`). `TLDAPAttribute` ganha properties `ValueType` / `Value` / `Values[Index]`. `TLDAPAttribute.Get(Index)` passa a devolver string ja decodificada conforme o tipo (ex.: `'{XXXXXXXX-...}'` para `objectGUID`, `'S-1-5-21-...'` para `objectSid`, inteiro para `userAccountControl`, data ISO-like para `whenCreated`/`pwdLastSet`, hex para `thumbnailPhoto`). **Fix cirurgico do `EEncodingError 'No mapping for the Unicode character...'`** em `TLDAPAttribute.Put` via novo helper `UnicodeToRawAnsi` byte-a-byte. API publica `Add`/`Put`/`Get`/`AttributeName`/`IsBinary` preservada — consumidores existentes nao precisam de alteracoes.
- **V1.7.2 `AddRaw` preservando 100% bytes binarios**: `ldapsend.pas` 001.007.005 resolve bug critico em que `Put -> UnquoteStr` consumia bytes `0x22` silenciosamente (`objectGUID` do AD real perdia 1 byte) e bytes `0x80-0xFF` eram corrompidos por CP1252 best-fit. Novo metodo publico `TLDAPAttribute.AddRaw(const ARaw: AnsiString): Integer` bypassa **TODA** a conversao (`UnicodeToRawAnsi`, `UnquoteStr`, `EncodeBase64`) e armazena bytes directamente em `FRawValues`. Parser ASN.1 modificado em 2 callsites criticos (`TLDAPSend.Search` ~2157 e `TLDAPSend.DoSearchAD` ~2330): `a.Add(u)` substituido por `a.AddRaw(u)`. `Put` defensivo salta `UnquoteStr` quando `FValueType in [vtGUID, vtSID, vtOctetString, vtBitString]`. `Get(Index)` blindado com `try/except` duplo + fallback `RawToHex`. `Clear` override reseta `FRawValues` em sincronia com `TStringList`. `RawToFileTime`/`RawToGeneralizedTime`/`ParseGeneralizedTime` usam `SafeUtf8Decode` em vez de `string(ARaw)`. **Validado contra AD real** `cslsolucoes.com.br` (`CN=Administrador`): `objectGUID = {E22791BE-5255-4665-951F-4A630F4AE269}` (16 bytes completos) em vez de `BE1827E2555265461F4A630F4AE269` (15 bytes truncados pelo fix antigo). 33/33 atributos do Administrador preservados sem regressao. API publica intacta.

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Ativa compatibilidade FPC; compilavel com FPC 3.2+ |
| `{$IFDEF UNICODE}` | Suprime warnings de cast implicito string/AnsiString no Delphi Unicode |
| `Winapi.Windows` (uses) | Necessario apenas para tipos SSPI (`TGUID`, `Cardinal`); carregamento de `secur32.dll` e feito via `LoadLibrary`/`GetProcAddress` em runtime |
| `secur32.dll` (runtime) | Carregada dinamicamente para SSPI: `AcquireCredentialsHandleW`, `InitializeSecurityContextW`, `MakeSignature`, `VerifySignature`, `FreeCredentialsHandle`, `DeleteSecurityContext` |
| `ssl_openssl.pas` / `ssl_openssl3.pas` | Plugin SSL ativo para LDAPS (porta 636) e StartTLS; selecionado via `SSLImplementation` em `initialization` |
| Delphi 12 / RAD Studio 12 Athens | Versao de desenvolvimento primaria; tipos `NativeUInt` e `AnsiString` usados sem adaptacao adicional |

---

## 4. Funcionalidades

### 4.1 Metodos originais Synapse (inalterados)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Login` | `function Login: Boolean` | Conecta ao servidor LDAP e inicia canal seguro (StartTLS) se `AutoTLS = True` ou usa LDAPS se `FullSSL = True` |
| `Bind` | `function Bind: Boolean` | Bind simples (texto claro) com `Username`/`Password`; bind anonimo se ambos vazios |
| `BindSasl` | `function BindSasl: Boolean` | Bind SASL DIGEST-MD5 para transferencia segura de senha |
| `Logout` | `function Logout: Boolean` | Fecha a conexao LDAP enviando UnbindRequest |
| `Search` | `function Search(obj: AnsiString; TypesOnly: Boolean; Filter: AnsiString; const Attributes: TStrings): Boolean` | Busca LDAP padrão; resultado em `SearchResult` |
| `Modify` | `function Modify(obj: AnsiString; Op: TLDAPModifyOp; const Value: TLDAPAttribute): Boolean` | Modifica atributos de um objeto LDAP |
| `Add` | `function Add(obj: AnsiString; const Value: TLDAPAttributeList): Boolean` | Adiciona novo objeto LDAP |
| `Delete` | `function Delete(obj: AnsiString): Boolean` | Remove objeto LDAP |
| `ModifyDN` | `function ModifyDN(obj, newRDN, newSuperior: AnsiString; DeleteoldRDN: Boolean): Boolean` | Renomeia ou move objeto LDAP |
| `Compare` | `function Compare(obj, AttributeValue: AnsiString): Boolean` | Compara valor de atributo com objeto LDAP |
| `Extended` | `function Extended(const Name, Value: AnsiString): Boolean` | Envia operacao estendida LDAPv3 arbitraria |
| `StartTLS` | `function StartTLS: Boolean` | Inicia upgrade TLS sobre conexao LDAP plaintext (porta 389) |

### 4.2 Controles AD — Search

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SearchDirSync` | `function SearchDirSync(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings): Boolean` | Busca incremental com controle DirSync (OID `1.2.840.113556.1.4.841`); cookie mantido em `DirSyncCookie` |
| `SearchWithSDFlags` | `function SearchWithSDFlags(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; ASDFlags: Integer; const AAttributes: TStrings): Boolean` | Busca com controle SDFlags para obter partes do `nTSecurityDescriptor` (OWNER, GROUP, DACL, SACL) |
| `SearchWithExtendedDN` | `function SearchWithExtendedDN(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings; AFlag: Integer = LDAP_EXTENDED_DN_STANDARD): Boolean` | Retorna DNs com GUID e SID embutidos no formato estendido do AD |
| `SearchShowDeleted` | `function SearchShowDeleted(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings): Boolean` | Inclui objetos excluidos na busca (Deleted Objects container) |
| `SearchShowRecycled` | `function SearchShowRecycled(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings): Boolean` | Inclui objetos na Recycle Bin do AD |
| `SearchWithServerSort` | `function SearchWithServerSort(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const ASortAttribute: AnsiString; const AAttributes: TStrings): Boolean` | Busca com ordenacao server-side via controle Server Side Sort (OID `1.2.840.113556.1.4.473`) |

### 4.3 Controles AD — Modify e Delete

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `ModifyPermissive` | `function ModifyPermissive(const AObj: AnsiString; AOp: TLDAPModifyOp; const AValue: TLDAPAttribute): Boolean` | Modify com controle Permissive Modify (OID `1.2.840.113556.1.4.1413`); ignora erros de atributo ja existente ou ja removido |
| `DeleteTree` | `function DeleteTree(const AObj: AnsiString): Boolean` | Remove objeto e todos os descendentes em uma unica operacao (controle TreeDelete, OID `1.2.840.113556.1.4.805`) |

### 4.4 Autenticacao SASL GSSAPI/Kerberos

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `BindGSSAPI` | `function BindGSSAPI(const ASPN: AnsiString): Boolean` | Bind Kerberos via SSPI sem Channel Binding; `ASPN` no formato `ldap/servidor.dominio.com` |
| `BindGSSAPIWithCBT` | `function BindGSSAPIWithCBT(const ASPN, ACertHash: AnsiString): Boolean` | Bind Kerberos com Channel Binding Token `tls-server-end-point` (RFC 5929); `ACertHash` e o hash SHA-256 raw de 32 bytes do certificado servidor |

### 4.5 Operacoes de Senha AD

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `ChangePassword` | `function ChangePassword(const AUserDN, AOldPassword, ANewPassword: AnsiString): Boolean` | Troca senha AD via modify delete+add do atributo `unicodePwd`; requer LDAPS ou StartTLS |
| `SetPassword` | `function SetPassword(const AUserDN, ANewPassword: AnsiString): Boolean` | Define senha AD diretamente (requer privilegio de Reset Password no AD); requer LDAPS ou StartTLS |
| `ForcePasswordChange` | `function ForcePasswordChange(const AUserDN: AnsiString): Boolean` | Seta `pwdLastSet = 0` forcando troca na proxima autenticacao |

### 4.6 Status de Conta (class functions)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `IsAccountLocked` | `class function IsAccountLocked(AUac: Integer): Boolean` | Retorna `True` se bit `UAC_LOCKOUT` ($10) estiver setado em `userAccountControl` |
| `IsAccountDisabled` | `class function IsAccountDisabled(AUac: Integer): Boolean` | Retorna `True` se bit `UAC_ACCOUNTDISABLE` ($02) estiver setado |
| `IsPasswordExpired` | `class function IsPasswordExpired(AUac: Integer): Boolean` | Retorna `True` se bit `UAC_PASSWORD_EXPIRED` ($800000) estiver setado |

### 4.7 FileTime Helpers (class functions)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `FileTimeToDateTime` | `class function FileTimeToDateTime(AFileTime: Int64): TDateTime` | Converte FileTime AD (100ns desde 1601-01-01) para `TDateTime` Delphi |
| `DateTimeToFileTime` | `class function DateTimeToFileTime(ADateTime: TDateTime): Int64` | Converte `TDateTime` Delphi para FileTime AD de 64 bits |

### 4.8 RootDSE e Utilitarios

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetRootDSE` | `function GetRootDSE(const AAttributes: TStrings): Boolean` | Consulta o RootDSE do AD para obter `defaultNamingContext`, `schemaNamingContext`, versao, etc. |
| `EscapeFilterValue` | `class function EscapeFilterValue(const AValue: AnsiString): AnsiString` | Escapa caracteres especiais em valores de filtro LDAP conforme RFC 4515 |
| `EscapeDNComponent` | `class function EscapeDNComponent(const AValue: AnsiString): AnsiString` | Escapa caracteres especiais em componentes DN conforme RFC 4514 |
| `GUIDToLDAPEscape` | `class function GUIDToLDAPEscape(const AGUID: TGUID): AnsiString` | Converte `TGUID` para sequencia de escape hexadecimal LDAP (`\XX`) usavel em filtros |
| `SIDToLDAPEscape` | `class function SIDToLDAPEscape(const ASIDBytes: AnsiString): AnsiString` | Converte bytes raw de SID para sequencia de escape hexadecimal LDAP |

### 4.9 Membership e Paginacao

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `IsMemberOf` | `function IsMemberOf(const AUserDN, AGroupDN, ABase: AnsiString): Boolean` | Verifica pertencimento recursivo a grupo usando a regra de matching `LDAP_MATCHING_RULE_IN_CHAIN` |
| `SearchAllPages` | `function SearchAllPages(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings; APageSize: Integer; AAccumulate: TLDAPResultList): Boolean` | Itera paginacao LDAP automaticamente acumulando todos os resultados em `AAccumulate` |

### 4.10 Properties

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `Version` | `Integer` | R/W | Versao do protocolo LDAP (2 ou 3; padrao: 3) |
| `AutoTLS` | `Boolean` | R/W | Se `True`, tenta StartTLS automaticamente no `Login` |
| `FullSSL` | `Boolean` | R/W | Se `True`, conecta diretamente via LDAPS (porta 636) |
| `SearchScope` | `TLDAPSearchScope` | R/W | Escopo da busca: `SS_BaseObject`, `SS_SingleLevel`, `SS_WholeSubtree` |
| `SearchSizeLimit` | `Integer` | R/W | Limite de resultados por busca (0 = sem limite) |
| `SearchTimeLimit` | `Integer` | R/W | Timeout da busca em segundos (0 = sem limite) |
| `SearchPageSize` | `Integer` | R/W | Tamanho de pagina para paginacao LDAP (0 = sem paginacao) |
| `SearchCookie` | `AnsiString` | R/W | Cookie de paginacao (vazio na primeira chamada) |
| `SearchResult` | `TLDAPResultList` | R | Lista de resultados da ultima busca |
| `ResultCode` | `Integer` | R | Codigo de resultado da ultima operacao LDAP |
| `ResultString` | `AnsiString` | R | Descricao textual do ultimo resultado |
| `DirSyncCookie` | `AnsiString` | R/W | Cookie de estado para buscas DirSync incrementais |
| `DirSyncFlags` | `Integer` | R/W | Flags de controle DirSync (ex.: `LDAP_DIRSYNC_INCREMENTAL_VALUES`) |
| `DirSyncMaxBytes` | `Integer` | R/W | Tamanho maximo de resposta DirSync em bytes |
| `DirSyncResult` | `AnsiString` | R | Ultimo resultado raw do DirSync |
| `SigningActive` | `Boolean` | R | Indica se LDAP Signing esta ativo na sessao atual |
| `Sock` | `TTCPBlockSocket` | R | Socket TCP subjacente para configuracoes avancadas (SNIHost, CertCAFile, etc.) |
| `Referals` | `TStringList` | R | Lista de URLs de referencia retornados pelo servidor |

---

## 5. Aplicabilidades

1. **Autenticacao corporativa AD (M01)** — `M01LdapAuthenticator` usa `Login` + `BindGSSAPI` (ou `BindGSSAPIWithCBT` para LDAPS) para autenticar usuarios do GestorERP contra o Active Directory corporativo sem armazenar senhas.

2. **Sincronizacao incremental de diretorio** — `SearchDirSync` com persistencia de `DirSyncCookie` permite detectar alteracoes em contas, grupos e unidades organizacionais desde a ultima sincronizacao, alimentando o `ActiveDirectoryORM`.

3. **OBAC — Object-Based Access Control** — `IsMemberOf` com `LDAP_MATCHING_RULE_IN_CHAIN` verifica pertencimento recursivo a grupos AD para alimentar as permissoes de `Application.Seguranca.OBACService`.

4. **Gestao de contas** — `ChangePassword`, `SetPassword`, `ForcePasswordChange` e as class functions `IsAccountLocked`/`IsAccountDisabled` sao usadas em fluxos de self-service e desbloqueio de conta.

5. **Inventario de diretorio** — `SearchAllPages` com escopo `SS_WholeSubtree` percorre toda a arvore AD sem limitacao de pagina do servidor, util para listagem de usuarios, computadores e grupos em operacoes administrativas.

6. **Seguranca de filtros** — `EscapeFilterValue` e `EscapeDNComponent` evitam LDAP injection ao construir filtros e DNs a partir de entrada do usuario.

---

## 6. Exemplos de Uso

### 6.1 Bind Kerberos com Channel Binding Token (LDAPS)

```pascal
uses ldapsend, ssl_openssl3;  // ssl_openssl3 para OpenSSL 3.x

var
  LLDAP: TLDAPSend;
  LCertHash: AnsiString;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.com.br';
    LLDAP.TargetPort := '636';
    LLDAP.FullSSL   := True;
    LLDAP.Timeout   := 10000;

    if not LLDAP.Login then
      raise Exception.Create('Falha ao conectar LDAPS: ' + LLDAP.ResultString);

    // Obtem hash SHA-256 do certificado do servidor para CBT
    LCertHash := (LLDAP.Sock.SSL as TSSLOpenSSL).GetPeerCertSHA256Hash;

    if not LLDAP.BindGSSAPIWithCBT('ldap/dc01.empresa.com.br', LCertHash) then
      raise Exception.Create('Falha no bind Kerberos+CBT: ' + LLDAP.ResultString);

    // Sessao autenticada com integridade
    ShowMessage('Bind OK — Signing: ' + BoolToStr(LLDAP.SigningActive, True));
  finally
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.2 DirSync incremental — detectar alteracoes em contas

```pascal
var
  LLDAP: TLDAPSend;
  LAttrs: TStringList;
  I: Integer;
begin
  LLDAP := TLDAPSend.Create;
  LAttrs := TStringList.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.com.br';
    LLDAP.FullSSL   := True;

    if LLDAP.Login and LLDAP.BindGSSAPI('ldap/dc01.empresa.com.br') then
    begin
      LAttrs.Add('sAMAccountName');
      LAttrs.Add('userAccountControl');
      LAttrs.Add('pwdLastSet');

      // Primeira chamada: DirSyncCookie esta vazio — retorna estado completo
      LLDAP.SearchDirSync('DC=empresa,DC=com,DC=br',
                          '(objectClass=user)',
                          SS_WholeSubtree,
                          LAttrs);

      // Persiste cookie para proxima execucao
      SalvarCookie(LLDAP.DirSyncCookie);

      for I := 0 to LLDAP.SearchResult.Count - 1 do
        ProcessarAlteracao(LLDAP.SearchResult[I]);
    end;
  finally
    LAttrs.Free;
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.3 Verificar pertencimento a grupo (OBAC)

```pascal
var
  LLDAP: TLDAPSend;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.com.br';
    LLDAP.FullSSL   := True;
    LLDAP.Login;
    LLDAP.BindGSSAPI('ldap/dc01.empresa.com.br');

    if LLDAP.IsMemberOf(
         'CN=Joao Silva,OU=Usuarios,DC=empresa,DC=com,DC=br',
         'CN=GRP_Financeiro,OU=Grupos,DC=empresa,DC=com,DC=br',
         'DC=empresa,DC=com,DC=br') then
      ShowMessage('Usuario tem acesso ao modulo Financeiro')
    else
      ShowMessage('Acesso negado');
  finally
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.4 Conversao FileTime e status de conta

```pascal
var
  LLDAP: TLDAPSend;
  LAttrs: TStringList;
  LUac: Integer;
  LPwdLastSet: TDateTime;
  LFileTimeStr: string;
begin
  LLDAP := TLDAPSend.Create;
  LAttrs := TStringList.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.com.br';
    LLDAP.FullSSL   := True;
    LLDAP.Login;
    LLDAP.BindGSSAPI('ldap/dc01.empresa.com.br');

    LAttrs.Add('userAccountControl');
    LAttrs.Add('pwdLastSet');
    LLDAP.Search('DC=empresa,DC=com,DC=br', False,
                 '(sAMAccountName=joao.silva)', LAttrs);

    if LLDAP.SearchResult.Count > 0 then
    begin
      LUac := StrToIntDef(
        LLDAP.SearchResult[0].Attributes.Get('userAccountControl'), 0);

      if TLDAPSend.IsAccountLocked(LUac) then
        ShowMessage('Conta bloqueada!');
      if TLDAPSend.IsPasswordExpired(LUac) then
        ShowMessage('Senha expirada!');

      LFileTimeStr := LLDAP.SearchResult[0].Attributes.Get('pwdLastSet');
      LPwdLastSet  := TLDAPSend.FileTimeToDateTime(StrToInt64Def(LFileTimeStr, 0));
      ShowMessage('Ultima troca de senha: ' + DateTimeToStr(LPwdLastSet));
    end;
  finally
    LAttrs.Free;
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.5 Escaping seguro de filtros e busca paginada

```pascal
var
  LLDAP: TLDAPSend;
  LAttrs: TStringList;
  LAll: TLDAPResultList;
  LFilter: AnsiString;
begin
  LLDAP := TLDAPSend.Create;
  LAttrs := TStringList.Create;
  LAll   := TLDAPResultList.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.com.br';
    LLDAP.FullSSL   := True;
    LLDAP.Login;
    LLDAP.BindGSSAPI('ldap/dc01.empresa.com.br');

    // Evita LDAP injection ao usar input do usuario em filtro
    LFilter := '(displayName=' +
               TLDAPSend.EscapeFilterValue('Joao (da) Silva & Filhos') + ')';

    LAttrs.Add('sAMAccountName');
    LAttrs.Add('mail');

    LLDAP.SearchAllPages('DC=empresa,DC=com,DC=br',
                         LFilter, SS_WholeSubtree,
                         LAttrs, 500, LAll);

    ShowMessage(IntToStr(LAll.Count) + ' resultado(s) encontrado(s)');
  finally
    LAll.Free;
    LAttrs.Free;
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Relacao | Tipo | Detalhe |
| --- | --- | --- |
| **Herda de** | `TSynaClient` (blcksock.pas) | Fornece `TargetHost`, `TargetPort`, `UserName`, `Password`, `OAuth2Token`, `Timeout` |
| **Contem** | `TTCPBlockSocket` (blcksock.pas) | Socket TCP interno acessivel via property `Sock`; carrega o plugin SSL via `SSLImplementation` |
| **Usa** | `TSSLOpenSSL` (ssl_openssl.pas) | Plugin SSL para LDAPS/StartTLS; extensao GestorERP adiciona `GetPeerCertSHA256Hash` necessario para CBT |
| **Usa** | `TSSLOpenSSL3` (ssl_openssl3.pas) | Plugin SSL alternativo para OpenSSL 3.x (recomendado para Delphi 12 em producao) |
| **Usa** | `secur32.dll` (runtime) | Carregada dinamicamente para SSPI Kerberos (`AcquireCredentialsHandleW`, `InitializeSecurityContextW`, `MakeSignature`, `VerifySignature`) |
| **Usa** | `TLDAPResultList`, `TLDAPResult`, `TLDAPAttribute`, `TLDAPAttributeList` | Tipos de dados internos do `ldapsend.pas` para representar resultados LDAP |
| **Consumido por** | `M01LdapAuthenticator` | `Infrastructure.Integrations.ActiveDirectory` — autenticacao corporativa modulo M01 |
| **Consumido por** | `ActiveDirectoryORM` | `app/modules/ActiveDirectoryORM` — ORM de diretorio AD |
| **Consumido por** | `Application.Seguranca.OBACService` | Verificacao de pertencimento a grupo para OBAC |
| **Constantes relacionadas** | `LDAP_OID_*`, `UAC_*`, `LDAP_DIRSYNC_*`, `LDAP_SD_*` | Definidas no proprio `ldapsend.pas`; OIDs e flags para controles AD |
