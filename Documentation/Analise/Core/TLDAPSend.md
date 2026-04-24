# TLDAPSend / ldapsend.pas

**Unit:** `ldapsend.pas` | **Versao:** 001.007.005 (CSL fork V1.7.2) | **Tipo:** Classe | **Origem:** Upstream 001.007.001 (Lukas Gebauer) + CSL fork (Active Directory Windows Server 2025 compatibility + tri-plataforma POSIX V1.7.0 + tipagem automatica de atributos V1.7.1 + `AddRaw` preservando bytes binarios V1.7.2)

---

## 1. O que e?

`TLDAPSend` e a classe central do cliente LDAP v2/v3 da Ararat Synapse, estendida pelo fork CSL (versao 001.007.003) com suporte completo ao Active Directory moderno: controles proprietarios da Microsoft (DirSync, SDFlags, ExtendedDN, ShowDeleted, ShowRecycled, ServerSort, PermissiveModify, TreeDelete), autenticacao SASL GSSAPI/Kerberos via Windows SSPI (inline sobre `secur32.dll`), Channel Binding Token `tls-server-end-point` (RFC 5929), LDAP Signing (RFC 4757, HMAC-MD5), operacoes de senha AD (`ChangePassword`, `SetPassword`, `ForcePasswordChange`) e utilitarios FileTime.

A classe herda de `TSynaClient` (que fornece `TargetHost`, `TargetPort`, `Username`, `Password`, `Timeout`, `IPInterface` e `OAuth2Token`) e mantem internamente um `TTCPBlockSocket` (exposto via property `Sock`) que suporta LDAP (porta 389), LDAP+StartTLS e LDAPS (porta 636) com plugin SSL intercambiavel (`ssl_openssl`, `ssl_openssl3`, `ssl_openssl4`).

No fork CSL V1.7.0, o codigo passou a compilar em tres plataformas (Windows, Linux/POSIX via FPC, Delphi LINUX64/macOS64) mantendo assinatura publica 100% estavel: todos os metodos SSPI (`BindGSSAPI`, `BindGSSAPIWithCBT`, `SignLDAPMessage`, `VerifyLDAPMessage`) foram envolvidos em `{$IFDEF MSWINDOWS}`, com stubs POSIX documentados que retornam `False` e mensagem explicativa (port real agendado V2.0.0 via `libgssapi_krb5`).

No fork CSL V1.7.1 (001.007.004), **`TLDAPSend` ganha integracao implicita** com a tipagem automatica de atributos LDAP atraves do parceiro [TLDAPAttribute](TLDAPAttribute.md): apos `Search`, cada `TLDAPAttribute` dentro de `SearchResult[i].Attributes` tem automaticamente a property `ValueType` ([TLDAPValueType](TLDAPValueType.md)) resolvida, e os seus valores podem ser acedidos via [TLDAPAttributeValue](TLDAPAttributeValue.md) com API estilo `TField` (`AsString`/`AsInteger`/`AsDateTime`/`AsBinary`/`AsGuid`/`AsSid`/...). A API publica de `TLDAPSend` permanece inalterada — a funcionalidade e transparente para consumidores existentes.

No fork CSL V1.7.2 (001.007.005), **o parser ASN.1 interno passa a usar `TLDAPAttribute.AddRaw`** em 2 callsites criticos (`TLDAPSend.Search` ~linha 2157 e `TLDAPSend.DoSearchAD` ~linha 2330) em vez de `TLDAPAttribute.Add`. Isto bypassa `UnquoteStr` + conversao implicita `AnsiString -> UnicodeString` via CP1252 best-fit, preservando 100% os bytes binarios desde o socket ate ao consumidor. Fix validado contra AD real `cslsolucoes.com.br` (`CN=Administrador`): `objectGUID` agora chega com 16 bytes (`{E22791BE-5255-4665-951F-4A630F4AE269}`) em vez de 15 bytes truncados (`BE1827E2555265461F4A630F4AE269`) pela perda do byte `0x22` que `UnquoteStr` consumia. 33/33 atributos do Administrador preservados sem regressao. API publica intacta.

O papel arquitetural no ecossistema GestorERP/ActiveDirectoryORM e ser o motor de comunicacao LDAP consumido por `TActiveDirectoryService` (ActiveDirectoryORM) e pelos modulos de autenticacao M01 (Seguranca).

---

## 2. Caracteristicas

* **AD-compatible 100% Windows**: todos os controles proprietarios Microsoft funcionam em LDAP (389) e LDAPS (636), alinhado com hardening WS 2022/2025.
* **SSPI inline (Windows)**: autenticacao GSSAPI/Kerberos carregada dinamicamente via `LoadLibrary` sobre `secur32.dll`, sem dependencia de ICS, `JwaWindows` ou outras unidades externas.
* **Channel Binding Token (CBT)**: `BindGSSAPIWithCBT` implementa `tls-server-end-point` (RFC 5929) usando o hash SHA-256 do certificado servidor obtido via `TSSLOpenSSL.GetPeerCertSHA256Hash`.
* **LDAP Signing**: integridade de PDU via SSPI `MakeSignature`/`VerifySignature` com sequencia crescente; ativada automaticamente apos bind GSSAPI e verificavel via `SigningActive`.
* **Paginacao transparente**: `SearchAllPages` itera sobre paginas LDAP de tamanho configuravel, acumulando resultados sem expor `SearchCookie` ao chamador.
* **Cross-compiler**: compila em Delphi 12+ e FPC 3.2+ (diretiva `{$IFDEF FPC}` + `{$MODE DELPHI}`).
* **Cross-platform (V1.7.0)**: stubs POSIX para metodos SSPI preservam a assinatura publica; Windows mantem comportamento integral.
* **Backward compatible**: toda a API original do Synapse (`Bind`, `BindSasl`, `Search`, `Modify`, `Add`, `Delete`, `ModifyDN`, `Compare`, `Extended`, `StartTLS`) permanece inalterada.
* **FileTime helpers**: conversao bidirecional entre `TDateTime` Delphi e FileTime AD (100ns desde 1601-01-01) para atributos `pwdLastSet`, `lastLogon`, `accountExpires`.
* **RFC escaping**: `EscapeFilterValue` (RFC 4515), `EscapeDNComponent` (RFC 4514), `GUIDToLDAPEscape` e `SIDToLDAPEscape` previnem LDAP injection.

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` + `{$H+}` | Ativa compatibilidade FPC (compilavel com FPC 3.2+) |
| `{$IFDEF UNICODE}` | Suprime warnings `IMPLICIT_STRING_CAST` / `IMPLICIT_STRING_CAST_LOSS` em Delphi Unicode |
| `{$IFDEF MSWINDOWS}` | Declara blocos SSPI (B1 constantes, B2 tipos, B3 campos, B4 metodos, B5 ponteiros `LDAP_*`, B6 implementacoes) |
| `Winapi.Windows` / `Windows` (uses) | Carregado apenas em `MSWINDOWS`; ausente em POSIX |
| `secur32.dll` (runtime, Windows) | Carregada dinamicamente por `LoadSSPIFunctions` via `LoadLibrary` + 7 ponteiros (`AcquireCredentialsHandleW`, `InitializeSecurityContextW`, `CompleteAuthToken`, `MakeSignature`, `VerifySignature`, `DeleteSecurityContext`, `FreeCredentialsHandle`) |
| `ssl_openssl.pas` / `ssl_openssl3.pas` / `ssl_openssl4.pas` | Plugin SSL selecionado pelo `initialization` do modulo importado; determina variante OpenSSL para LDAPS / StartTLS |
| `blcksock` (uses) | Fornece `TTCPBlockSocket`, `TSynaClient`, hooks de status e plugin SSL |
| `asn1util` (uses) | Encoder/decoder ASN.1 BER para todas as PDUs LDAP (ver [Asn1Util.md](Asn1Util.md)) |
| `synautil` / `synacode` (uses) | Utilitarios Base64, MD5, HMAC-MD5 (LDAP Signing) e binding de portas |
| POSIX (FPC + Linux/macOS, Delphi LINUX64/macOS64) | Stubs SSPI: `BindGSSAPI` -> `False` + mensagem V2.0.0; `SignLDAPMessage` -> pass-through; `VerifyLDAPMessage` -> `True` |

---

## 4. Funcionalidades

### 4.1 Ciclo de vida e conexao (API original Synapse)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Create` | `constructor Create` | Aloca `TTCPBlockSocket` interno, `TLDAPResultList` vazia, `Referals`, inicializa `FVersion := 3`, `FTimeout := 60000`, `FDirSyncMaxBytes := LDAP_DIRSYNC_MAX_BYTES_DEFAULT` |
| `Destroy` | `destructor Destroy; override` | Libera socket, lista de resultados, referals e, em Windows, executa `SSPICleanup` (libera credenciais/contexto SSPI pendentes) |
| `Login` | `function Login: Boolean` | Conecta ao `TargetHost:TargetPort`; se `FullSSL = True` usa LDAPS direto; se `AutoTLS = True` faz `StartTLS` apos conexao plaintext |
| `Logout` | `function Logout: Boolean` | Envia UnbindRequest e fecha o socket |
| `StartTLS` | `function StartTLS: Boolean` | Envia operacao estendida `1.3.6.1.4.1.1466.20037` para upgrade TLS sobre LDAP 389 |

### 4.2 Bind (autenticacao)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Bind` | `function Bind: Boolean` | Bind simples (texto claro) usando `Username`/`Password` herdados; ambos vazios = bind anonimo. INSEGURO sem TLS. |
| `BindSasl` | `function BindSasl: Boolean` | Bind SASL DIGEST-MD5 (challenge-response); mantem sessao autenticada sem expor senha em texto claro |
| `BindGSSAPI` | `function BindGSSAPI(const ASPN: AnsiString): Boolean` | **Windows:** bind Kerberos via SSPI sem Channel Binding; `ASPN` no formato `ldap/dc.empresa.local`. **POSIX:** retorna `False` e `ResultString = 'GSSAPI nao disponivel em POSIX - agendado V2.0.0'` |
| `BindGSSAPIWithCBT` | `function BindGSSAPIWithCBT(const ASPN, ACertHash: AnsiString): Boolean` | **Windows:** bind Kerberos com CBT `tls-server-end-point` (RFC 5929); `ACertHash` = 32 bytes raw SHA-256 do cert servidor. **POSIX:** stub `False` |

### 4.3 Search - API classica

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Search` | `function Search(obj: AnsiString; TypesOnly: Boolean; Filter: AnsiString; const Attributes: TStrings): Boolean` | Busca LDAP padrao com escopo em `SearchScope`; resultado em `SearchResult` (`TLDAPResultList`) |
| `SearchAllPages` | `function SearchAllPages(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings; APageSize: Integer; AAccumulate: TLDAPResultList): Boolean` | Itera paginacao LDAP (RFC 2696) automaticamente acumulando em `AAccumulate`; reset de `SearchCookie` interno |

### 4.4 Search - Controles Active Directory

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `SearchDirSync` | `function SearchDirSync(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings): Boolean` | Busca incremental com controle DirSync (OID `1.2.840.113556.1.4.841`); estado persistido em `DirSyncCookie`, flags em `DirSyncFlags`, limite em `DirSyncMaxBytes` |
| `SearchWithSDFlags` | `function SearchWithSDFlags(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; ASDFlags: Integer; const AAttributes: TStrings): Boolean` | Busca com SDFlags (OID `1.2.840.113556.1.4.801`) para partes do `nTSecurityDescriptor`: `LDAP_SD_OWNER`, `LDAP_SD_GROUP`, `LDAP_SD_DACL`, `LDAP_SD_SACL`, `LDAP_SD_ALL` |
| `SearchWithExtendedDN` | `function SearchWithExtendedDN(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings; AFlag: Integer = LDAP_EXTENDED_DN_STANDARD): Boolean` | Retorna DNs com GUID/SID embutidos (OID `1.2.840.113556.1.4.529`); `AFlag` = `LDAP_EXTENDED_DN_HEX_STRING` (0) ou `LDAP_EXTENDED_DN_STANDARD` (1) |
| `SearchShowDeleted` | `function SearchShowDeleted(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings): Boolean` | Inclui objetos tombstoned (OID `1.2.840.113556.1.4.1338`) — container `Deleted Objects` |
| `SearchShowRecycled` | `function SearchShowRecycled(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const AAttributes: TStrings): Boolean` | Inclui objetos na Recycle Bin do AD (OID `1.2.840.113556.1.4.2064`) |
| `SearchWithServerSort` | `function SearchWithServerSort(const ABase, AFilter: AnsiString; AScope: TLDAPSearchScope; const ASortAttribute: AnsiString; const AAttributes: TStrings): Boolean` | Ordenacao server-side (OID `1.2.840.113556.1.4.473`) |

### 4.5 Modify / Add / Delete

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Modify` | `function Modify(obj: AnsiString; Op: TLDAPModifyOp; const Value: TLDAPAttribute): Boolean` | Modifica atributo; `Op` = `MO_Add`, `MO_Delete`, `MO_Replace` |
| `ModifyPermissive` | `function ModifyPermissive(const AObj: AnsiString; AOp: TLDAPModifyOp; const AValue: TLDAPAttribute): Boolean` | Modify com controle PermissiveModify (OID `1.2.840.113556.1.4.1413`); ignora `ATTRIBUTE_OR_VALUE_EXISTS` e `NO_SUCH_ATTRIBUTE` |
| `Add` | `function Add(obj: AnsiString; const Value: TLDAPAttributeList): Boolean` | Adiciona novo objeto LDAP com a lista de atributos |
| `Delete` | `function Delete(obj: AnsiString): Boolean` | Remove objeto simples (nao recursivo) |
| `DeleteTree` | `function DeleteTree(const AObj: AnsiString): Boolean` | Remove objeto + descendentes (OID `1.2.840.113556.1.4.805`) em operacao unica |
| `ModifyDN` | `function ModifyDN(obj, newRDN, newSuperior: AnsiString; DeleteoldRDN: Boolean): Boolean` | Renomeia/move objeto; `newSuperior` vazio mantem pai; `DeleteoldRDN` limpa RDN antigo |
| `Compare` | `function Compare(obj, AttributeValue: AnsiString): Boolean` | Compara `AttributeValue` (formato `nome=valor`) com atributo do objeto server-side |

### 4.6 Operacoes estendidas e senha AD

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `Extended` | `function Extended(const Name, Value: AnsiString): Boolean` | Envia operacao estendida LDAPv3 arbitraria; resultado em `ExtName`/`ExtValue` |
| `ChangePassword` | `function ChangePassword(const AUserDN, AOldPassword, ANewPassword: AnsiString): Boolean` | Troca senha AD via modify delete+add do `unicodePwd`; requer LDAPS ou StartTLS |
| `SetPassword` | `function SetPassword(const AUserDN, ANewPassword: AnsiString): Boolean` | Define senha AD directamente (requer `Reset Password` + LDAPS/StartTLS) |
| `ForcePasswordChange` | `function ForcePasswordChange(const AUserDN: AnsiString): Boolean` | Seta `pwdLastSet := 0` forcando troca na proxima autenticacao |
| `GetRootDSE` | `function GetRootDSE(const AAttributes: TStrings): Boolean` | Consulta RootDSE (base vazio) para `defaultNamingContext`, `schemaNamingContext`, `supportedControl`, `dnsHostName`, `serverName` |

### 4.7 Membership e LDAP Signing (Windows)

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `IsMemberOf` | `function IsMemberOf(const AUserDN, AGroupDN, ABase: AnsiString): Boolean` | Verifica pertencimento recursivo a grupo usando `LDAP_MATCHING_RULE_IN_CHAIN` (OID `1.2.840.113556.1.4.1941`) server-side |
| `SignLDAPMessage` (privado) | `function SignLDAPMessage(const AMsg: AnsiString): AnsiString` | **Windows:** assina PDU via SSPI `MakeSignature` (HMAC-MD5); **POSIX:** no-op pass-through |
| `VerifyLDAPMessage` (privado) | `function VerifyLDAPMessage(const ASignedMsg: AnsiString; out APlain: AnsiString): Boolean` | **Windows:** valida assinatura via `VerifySignature`; **POSIX:** `True` + `APlain := ASignedMsg` |

### 4.8 Class functions - Status de conta e FileTime

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `IsAccountLocked` | `class function IsAccountLocked(AUac: Integer): Boolean` | Testa bit `UAC_LOCKOUT` ($10) em `userAccountControl` |
| `IsAccountDisabled` | `class function IsAccountDisabled(AUac: Integer): Boolean` | Testa bit `UAC_ACCOUNTDISABLE` ($02) |
| `IsPasswordExpired` | `class function IsPasswordExpired(AUac: Integer): Boolean` | Testa bit `UAC_PASSWORD_EXPIRED` ($800000) |
| `FileTimeToDateTime` | `class function FileTimeToDateTime(AFileTime: Int64): TDateTime` | Converte FileTime AD (100ns desde 1601-01-01) para `TDateTime` Delphi |
| `DateTimeToFileTime` | `class function DateTimeToFileTime(ADateTime: TDateTime): Int64` | Converte `TDateTime` para FileTime 64-bit AD |

### 4.9 Class functions - Escaping RFC

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `EscapeFilterValue` | `class function EscapeFilterValue(const AValue: AnsiString): AnsiString` | RFC 4515: escapa `\`, `*`, `(`, `)`, `NUL` em valores de filtro |
| `EscapeDNComponent` | `class function EscapeDNComponent(const AValue: AnsiString): AnsiString` | RFC 4514: escapa `,`, `+`, `"`, `\`, `<`, `>`, `;`, `=`, `#` em componentes DN |
| `GUIDToLDAPEscape` | `class function GUIDToLDAPEscape(const AGUID: TGUID): AnsiString` | Converte GUID para sequencia `\XX\XX...` usavel em filtros |
| `SIDToLDAPEscape` | `class function SIDToLDAPEscape(const ASIDBytes: AnsiString): AnsiString` | Converte bytes raw de SID para sequencia hexadecimal `\XX` |

### 4.10 Properties publicas

| Property | Tipo | Acesso | Descricao |
| --- | --- | --- | --- |
| `Version` | `Integer` | R/W | Versao do protocolo LDAP (2 ou 3; default 3) |
| `ResultCode` | `Integer` | R | Codigo LDAP da ultima operacao (0 = success) |
| `ResultString` | `AnsiString` | R | Descricao textual do ultimo `ResultCode` |
| `FullResult` | `AnsiString` | R | PDU ASN.1 BER completo da ultima resposta (debug) |
| `AutoTLS` | `Boolean` | R/W | Se `True`, faz StartTLS automatico no `Login` |
| `FullSSL` | `Boolean` | R/W | Se `True`, conecta directamente via LDAPS (porta 636) |
| `Seq` | `Integer` | R | Sequencia de comando LDAP (incrementada por operacao) |
| `SearchScope` | `TLDAPSearchScope` | R/W | `SS_BaseObject`, `SS_SingleLevel` ou `SS_WholeSubtree` |
| `SearchAliases` | `TLDAPSearchAliases` | R/W | `SA_NeverDeref`, `SA_InSearching`, `SA_FindingBaseObj`, `SA_Always` |
| `SearchSizeLimit` | `Integer` | R/W | Limite de resultados por busca (0 = sem limite) |
| `SearchTimeLimit` | `Integer` | R/W | Timeout da busca em segundos (0 = sem limite) |
| `SearchPageSize` | `Integer` | R/W | Tamanho de pagina (0 = sem paginacao) |
| `SearchCookie` | `AnsiString` | R/W | Cookie de paginacao (vazio na primeira chamada) |
| `SearchResult` | `TLDAPResultList` | R | Resultado da ultima busca (ver [TLDAPResultList.md](TLDAPResultList.md)) |
| `Referals` | `TStringList` | R | URLs de referenciamento retornados pelo servidor |
| `ExtName` | `AnsiString` | R | Nome do resultado de `Extended` |
| `ExtValue` | `AnsiString` | R | Valor do resultado de `Extended` |
| `Sock` | `TTCPBlockSocket` | R | Socket TCP subjacente (ver [TTCPBlockSocket.md](TTCPBlockSocket.md)) |
| `DirSyncCookie` | `AnsiString` | R/W | Cookie incremental DirSync (persistir entre execucoes) |
| `DirSyncFlags` | `Integer` | R/W | Flags DirSync (`LDAP_DIRSYNC_INCREMENTAL_VALUES`, `ANCESTORS_FIRST`, `OBJECT_SECURITY`) |
| `DirSyncMaxBytes` | `Integer` | R/W | Tamanho maximo de resposta DirSync (default `1048576`) |
| `DirSyncResult` | `AnsiString` | R | Payload raw da ultima resposta DirSync |
| `SigningActive` | `Boolean` | R | `True` apos bind GSSAPI com LDAP Signing ativo (Windows) |

---

## 5. Aplicabilidades

1. **Autenticacao corporativa contra Active Directory** — `TActiveDirectoryService.Authenticate` invoca `Login` + `Bind` (bind-then-search) usando as credenciais do usuario; para SSO corporativo, `BindGSSAPIWithCBT` habilita Kerberos+CBT sobre LDAPS.
2. **Sincronizacao incremental de diretorio (M01 Seguranca)** — `SearchDirSync` com persistencia de `DirSyncCookie` em `dbo.Ldap_Sync_State` detecta alteracoes em usuarios/grupos desde a ultima execucao, alimentando tabelas locais via `ActiveDirectoryORM`.
3. **OBAC (Object-Based Access Control)** — `IsMemberOf` com `LDAP_MATCHING_RULE_IN_CHAIN` verifica pertencimento recursivo a grupos AD server-side, alimentando `Seguranca.Services.OBACService`.
4. **Gestao de contas (self-service / admin)** — `ChangePassword`, `SetPassword`, `ForcePasswordChange` + class functions `IsAccountLocked` / `IsPasswordExpired` para fluxos de desbloqueio e reset.
5. **Inventario / descoberta de diretorio** — `SearchAllPages` com `SS_WholeSubtree` percorre arvore AD sem limite de pagina; `SearchWithServerSort` ordena resultados server-side; `SearchShowDeleted` lista tombstones para auditoria.
6. **Seguranca de filtros** — `EscapeFilterValue` + `EscapeDNComponent` previnem LDAP injection ao compor filtros dinamicos a partir de entrada de usuario.

---

## 6. Exemplos de uso

### 6.1 Bind Kerberos com CBT sobre LDAPS (Windows)

```pascal
uses
  SysUtils, Classes,
  ldapsend, blcksock, ssl_openssl3;

var
  LLDAP: TLDAPSend;
  LCertHash: AnsiString;
begin
  LLDAP := TLDAPSend.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.TargetPort := '636';
    LLDAP.FullSSL    := True;
    LLDAP.Timeout    := 15000;
    LLDAP.Sock.SNIHost    := 'dc01.empresa.local';
    LLDAP.Sock.VerifyCert := True;

    if not LLDAP.Login then
      raise Exception.Create('LDAPS falhou: ' + string(LLDAP.ResultString));

    LCertHash := (LLDAP.Sock.SSL as TSSLOpenSSL).GetPeerCertSHA256Hash;
    if not LLDAP.BindGSSAPIWithCBT('ldap/dc01.empresa.local', LCertHash) then
      raise Exception.Create('Bind Kerberos+CBT: ' + string(LLDAP.ResultString));

    Writeln('Bind OK; signing=', LLDAP.SigningActive);
  finally
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.2 DirSync incremental + verificacao de membership

```pascal
uses SysUtils, Classes, ldapsend, ssl_openssl3;

var
  LLDAP: TLDAPSend;
  LAttrs: TStringList;
  I: Integer;
begin
  LLDAP := TLDAPSend.Create;
  LAttrs := TStringList.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL    := True;
    LLDAP.Sock.VerifyCert := True;

    if LLDAP.Login and LLDAP.BindGSSAPI('ldap/dc01.empresa.local') then
    begin
      LAttrs.Add('sAMAccountName');
      LAttrs.Add('userAccountControl');
      LAttrs.Add('pwdLastSet');

      LLDAP.DirSyncFlags := LDAP_DIRSYNC_INCREMENTAL_VALUES;
      LLDAP.DirSyncCookie := LoadCookie;

      if LLDAP.SearchDirSync('DC=empresa,DC=local',
                              '(objectClass=user)',
                              SS_WholeSubtree, LAttrs) then
      begin
        SaveCookie(LLDAP.DirSyncCookie);
        for I := 0 to LLDAP.SearchResult.Count - 1 do
          ProcessarAlteracao(LLDAP.SearchResult[I]);
      end;

      if LLDAP.IsMemberOf(
           'CN=Joao,OU=Users,DC=empresa,DC=local',
           'CN=Admins,OU=Groups,DC=empresa,DC=local',
           'DC=empresa,DC=local') then
        Writeln('OBAC: Joao in Admins');
    end;
  finally
    LAttrs.Free;
    LLDAP.Logout;
    LLDAP.Free;
  end;
end;
```

### 6.3 Paginacao + escaping seguro + status de conta

```pascal
uses SysUtils, Classes, ldapsend, ssl_openssl3;

var
  LLDAP: TLDAPSend;
  LAttrs: TStringList;
  LAll: TLDAPResultList;
  LFilter: AnsiString;
  LUac: Integer;
begin
  LLDAP := TLDAPSend.Create;
  LAttrs := TStringList.Create;
  LAll := TLDAPResultList.Create;
  try
    LLDAP.TargetHost := 'dc01.empresa.local';
    LLDAP.FullSSL    := True;
    LLDAP.Login;
    LLDAP.BindGSSAPI('ldap/dc01.empresa.local');

    LFilter := '(sAMAccountName=' +
               TLDAPSend.EscapeFilterValue(EditLogin.Text) + ')';
    LAttrs.Add('userAccountControl');

    LLDAP.SearchAllPages('DC=empresa,DC=local', LFilter,
                         SS_WholeSubtree, LAttrs, 500, LAll);

    if LAll.Count > 0 then
    begin
      LUac := StrToIntDef(LAll[0].Attributes.Get('userAccountControl'), 0);
      if TLDAPSend.IsAccountLocked(LUac)   then Writeln('Bloqueada');
      if TLDAPSend.IsAccountDisabled(LUac) then Writeln('Desabilitada');
      if TLDAPSend.IsPasswordExpired(LUac) then Writeln('Senha expirada');
    end;
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

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| [TSynaClient](TTCPBlockSocket.md) | Heranca | Fornece `TargetHost`, `TargetPort`, `IPInterface`, `Timeout`, `UserName`, `Password`, `OAuth2Token` |
| [TTCPBlockSocket](TTCPBlockSocket.md) | Composicao | Socket TCP subjacente (property `Sock`); carrega plugin SSL via `SSLImplementation` |
| [TCustomSSL](TCustomSSL.md) | Dependencia (via Sock) | Plugin SSL abstrato; instancia concreta determina LDAPS / StartTLS |
| [TLDAPAttribute](TLDAPAttribute.md) | Composicao | Atributo individual de resultado ou parametro de `Modify`/`Add` |
| [TLDAPAttributeList](TLDAPAttributeList.md) | Composicao | Lista de atributos por objeto LDAP |
| [TLDAPResult](TLDAPResult.md) | Composicao | Objeto LDAP retornado (DN + atributos) |
| [TLDAPResultList](TLDAPResultList.md) | Composicao | Property `SearchResult` acumula resultados |
| [Asn1Util](Asn1Util.md) | Dependencia | Codifica/decodifica todas as PDUs LDAP em ASN.1 BER |
| `synautil` / `synacode` | Dependencia | Base64, MD5, HMAC-MD5, utilitarios de string |
| `secur32.dll` (Windows) | Dependencia runtime | SSPI para GSSAPI/Kerberos + LDAP Signing (carregada dinamicamente) |
| `ssl_openssl.pas` / `ssl_openssl3.pas` / `ssl_openssl4.pas` | Plugin SSL | Implementacoes concretas de `TCustomSSL` para LDAPS/StartTLS |
| `TActiveDirectoryService` (ActiveDirectoryORM) | Consumidor | Encapsula `TLDAPSend` no ORM publico via `TLDAPConfig` + `IActiveDirectoryService` |
| `Seguranca.Services.OBACService` | Consumidor | Consome `IsMemberOf` para pertencimento recursivo a grupos |
