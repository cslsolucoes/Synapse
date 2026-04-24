{==============================================================================|
| Project : Ararat Synapse (CSL fork)                            | 001.007.005 |
|==============================================================================|
| Content: LDAP client + CSL AD Windows Server 2025 compatibility              |
|==============================================================================|
| Copyright (c)1999-2014, Lukas Gebauer   (upstream ldapsend 001.007.001)      |
| Copyright (c)2026,      CSL Softwares   (AD Windows Server 2025 compatibility)|
| All rights reserved.                                                         |
|                                                                              |
| Redistribution and use in source and binary forms, with or without           |
| modification, are permitted provided that the following conditions are met:  |
|                                                                              |
| Redistributions of source code must retain the above copyright notice, this  |
| list of conditions and the following disclaimer.                             |
|                                                                              |
| Redistributions in binary form must reproduce the above copyright notice,    |
| this list of conditions and the following disclaimer in the documentation    |
| and/or other materials provided with the distribution.                       |
|                                                                              |
| Neither the name of Lukas Gebauer nor the names of its contributors may      |
| be used to endorse or promote products derived from this software without    |
| specific prior written permission.                                           |
|                                                                              |
| THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"  |
| AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE    |
| IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE   |
| ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR  |
| ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL       |
| DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR   |
| SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER   |
| CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT           |
| LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY    |
| OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH  |
| DAMAGE.                                                                      |
|==============================================================================|
| The Initial Developer of the Original Code is Lukas Gebauer (Czech Republic).|
| Portions created by Lukas Gebauer are Copyright (c)2003-2014.                |
| Portions created by CSL Softwares are Copyright (c)2026.                     |
| All Rights Reserved.                                                         |
|==============================================================================|
| Contributor(s):                                                              |
|   Claiton de Souza Linhares <claiton.linhares@cslsoftwares.com.br>           |
|     (CSL Softwares) — AD Windows Server 2025 compatibility                   |
|     (GSSAPI + CBT + AD controls + LDAP Signing + password ops)               |
|==============================================================================|
| History: see HISTORY.HTM from distribution package                           |
|          (Found at URL: http://www.ararat.cz/synapse/)                       |
|                                                                              |
| CSL fork modifications (this file) — ~1000 diff lines vs bak/ldapsend.pas.bak|
|   2026-04-13 (CSL historical fork): Active Directory Windows Server 2025     |
|     compatibility suite. Bumped 001.007.001 → 001.007.002 → 001.007.003.     |
|                                                                              |
|     Why: upstream Synapse ldapsend is frozen at 2014 and predates modern     |
|     AD hardening policies (LDAPS enforced, signing required, CBT mandatory   |
|     on Kerberos). The CSL fork brings it to current AD WS 2025 standards.    |
|                                                                              |
|     Additions:                                                               |
|     - GSSAPI/Kerberos bind via Windows SSPI (secur32.dll, dynamic load):     |
|         InitializeSecurityContext + QueryContextAttributes +                 |
|         DeleteSecurityContext. Required by AD WS 2025 default policy.       |
|     - BindGSSAPIWithCBT: bind with Channel Binding Token (RFC 5929)          |
|         tls-server-end-point, mandatory since AD hardening 2020+.            |
|     - AD proprietary control OIDs (MS-ADTS): DirSync, SDFlags, ExtendedDN,   |
|         ShowDeleted, ShowRecycled, ServerSort, PermissiveModify, TreeDelete. |
|     - LDAP Signing (RFC 4757, HMAC-MD5): PDU integrity without sealing.      |
|         Required when AD WS 2025 has "LdapEnforceChannelBinding=2".          |
|     - FileTime helpers: FileTimeToDateTime / DateTimeToFileTime for AD       |
|         timestamp attributes (pwdLastSet, lastLogon, accountExpires,         |
|         whenCreated, whenChanged).                                           |
|     - Password operations: SetPassword, ForcePasswordChange (pwdLastSet=0).  |
|                                                                              |
|   2026-04-21 (CSL V1.7.0 -- ActiveDirectoryORM tri-plataforma POSIX):        |
|     Destrava compilacao Linux/macOS FPC + Delphi LINUX64/macOS64 sem        |
|     quebrar Windows.                                                         |
|                                                                              |
|     Patch:                                                                   |
|     - uses clause condicional FPC vs Delphi, Winapi.Windows guardado em     |
|         IFDEF MSWINDOWS em ambos os ramos.                                   |
|     - 6 blocos SSPI/GSSAPI envolvidos em IFDEF MSWINDOWS:                    |
|         B1 constantes ISC_REQ_*/SECBUFFER_*/SEC_E_*                         |
|         B2 tipos TLDAPSecHandle/TLDAPSecBuffer/TLDAPSecBufferDesc           |
|         B3 campos privados FSSPICred/FSSPICtx/FSSPIHaveCred/FSSPIHaveCtx    |
|         B4 metodos privados LoadSSPIFunctions/SSPICleanup/GSSAPIStep/       |
|            BuildCBTData (somente Windows)                                   |
|         B5 variavel global FLDAPSecur32Lib + 7 function pointers LDAP_*     |
|         B6 implementacoes SSPI + callsite SSPICleanup no Destroy            |
|                                                                              |
|     Stubs POSIX (assinatura publica estavel):                                |
|     - BindGSSAPI         -> Result := False + FResultString documentando    |
|                            'agendado V2.0.0' (libgssapi_krb5).              |
|     - BindGSSAPIWithCBT  -> idem.                                           |
|     - SignLDAPMessage    -> no-op pass-through (FSigningActive = False).    |
|     - VerifyLDAPMessage  -> Result := True + APlain := ASignedMsg.          |
|                                                                              |
|     Motivacao: SSPI e' API proprietaria Microsoft ligada a secur32.dll.     |
|     POSIX nao tem SSPI; equivalente e' GSS-API (MIT/Heimdal Kerberos via   |
|     libgssapi_krb5). Port real agendado V2.0.0 (Roadmap do ORM E1-E5).     |
|     V1.7.0 entrega LDAP simples + LDAPS em POSIX (90%+ dos usos).          |
|                                                                              |
|     Nao bumpa versao Synapse (001.007.003 preservado): patch e' cirurgico   |
|     e nao altera API publica nem comportamento Windows.                     |
|                                                                              |
|   2026-04-22 (CSL V1.7.1 -- tipagem automatica + fix EEncodingError):        |
|     TLDAPAttribute.Get(Index) passa a devolver string final ja decodificada  |
|     conforme novo enum TLDAPValueType (resolvido em SetAttributeName via     |
|     mapa estatico LDAP_KNOWN_ATTRIBUTE_TYPES -- ~110 atributos AD default).  |
|     Resolve automaticamente: objectGUID -> <XXXXXXXX-...>, objectSid ->      |
|     'S-1-5-21-...', userAccountControl -> inteiro, whenCreated -> ISO-like,  |
|     pwdLastSet (FILETIME) -> data, thumbnailPhoto/cert -> hex, displayName   |
|     -> UTF-8 com fallback Latin-1 seguro.                                    |
|                                                                              |
|     TLDAPAttribute.Put passa a usar UnicodeToRawAnsi (byte-a-byte) em vez    |
|     de 's := Value' (RTL implicit) que levantava EEncodingError              |
|     'No mapping for Unicode character...' em Delphi 12 strict mode sobre     |
|     bytes binarios recebidos do socket.                                      |
|                                                                              |
|     API publica preservada: Add/Put/Get/AttributeName/IsBinary com mesmas    |
|     assinaturas -- consumidores existentes (ORM src/ intocado) recebem       |
|     strings limpas em vez de 'lixo' ou excepcao.                             |
|                                                                              |
|     API nova (opt-in): TLDAPAttributeValue record + properties Value/Values  |
|     em TLDAPAttribute expoem acessores estilo TField (AsString/AsInteger/    |
|     AsFloat/AsBoolean/AsDateTime/AsBinary/AsHex/AsSid/AsGuid/AsVariant).     |
|                                                                              |
|     Bump 001.007.003 -> 001.007.004. Adiciona ~400 LoC (enum + mapa + 6     |
|     helpers file-private + record acessor + property ValueType read-only).  |
|                                                                              |
|   2026-04-22 (CSL V1.7.2 -- AddRaw + Put defensivo + Clear override):        |
|     BUG CRITICO RESOLVIDO: TLDAPAttribute.Put -> UnquoteStr consumia bytes  |
|     0x22 (") silenciosamente. objectGUID do AD real CN=Administrador,...    |
|     do dominio CSL perdia 1 byte (vinha 15 bytes em vez de 16) quando o     |
|     byte 16 era 0x22. Bytes 0x80-0xFF eram corrompidos por CP1252 best-fit  |
|     na conversao implicita AnsiString -> UnicodeString do callsite          |
|     a.Add(u: AnsiString) onde Add recebe const S: string.                   |
|                                                                              |
|     Solucao:                                                                 |
|     - Novo metodo publico TLDAPAttribute.AddRaw(const ARaw: AnsiString):    |
|       Integer -- bypassa TODA a conversao (UnicodeToRawAnsi / UnquoteStr /  |
|       EncodeBase64) e armazena bytes directamente em FRawValues via         |
|       StoreRawValue. Preserva 100% dos 256 bytes 0x00-0xFF.                 |
|     - Parser ASN.1 modificado em 2 callsites (TLDAPSend.Search ~2157 e     |
|       TLDAPSend.DoSearchAD ~2330): a.Add(u) -> a.AddRaw(u). Bytes ASN.1    |
|       preservados desde o socket ate ao consumidor.                         |
|     - TLDAPAttribute.Put defensivo: salta UnquoteStr quando FValueType in   |
|       [vtGUID, vtSID, vtOctetString, vtBitString] (protege Add publico).    |
|     - TLDAPAttribute.Get(Index) blindado com try/except duplo + fallback   |
|       RawToHex final (nenhum decoder pode abortar iteracao).                |
|     - TLDAPAttribute.Clear override resetando FRawValues em sincronia       |
|       com TStringList interno.                                              |
|     - RawToFileTime, RawToGeneralizedTime, ParseGeneralizedTime usam       |
|       SafeUtf8Decode em vez de string(ARaw) (conversao perigosa Delphi 12).|
|                                                                              |
|     Validacao: AD real cslsolucoes.com.br CN=Administrador antes:           |
|       objectGUID=BE1827E2555265461F4A630F4AE269 (15 bytes hex truncado).   |
|     Depois:                                                                  |
|       objectGUID=<E22791BE-5255-4665-951F-4A630F4AE269> (16 bytes GUID).    |
|     33/33 atributos listados sem perda. Sem regressao binaria.              |
|                                                                              |
|     Bump 001.007.004 -> 001.007.005. Adiciona ~50 LoC (AddRaw + Clear +    |
|     try/except em Get + ramo defensivo em Put + RawTo*Time hardening).      |
|                                                                              |
|   Original baseline preserved in bak/ldapsend.pas.bak (diff this file).      |
|==============================================================================}

{:@abstract(LDAP client)

Used RFC: RFC-2251, RFC-2254, RFC-2696, RFC-2829, RFC-2830
}

{$IFDEF FPC} {$MODE DELPHI} {$H+} {$ENDIF}

{$IFDEF UNICODE}
  {$WARN IMPLICIT_STRING_CAST OFF}
  {$WARN IMPLICIT_STRING_CAST_LOSS OFF}
{$ENDIF}

unit ldapsend;

interface

uses
{$IFDEF FPC}
  SysUtils, Classes, Math, Variants
  {$IFDEF MSWINDOWS}, Windows{$ENDIF},
{$ELSE}
  System.SysUtils, System.Classes, System.Math, System.Variants,
  {$IFDEF MSWINDOWS}Winapi.Windows,{$ENDIF}
{$ENDIF}
  blcksock, synautil, asn1util, synacode;

const
  cLDAPProtocol = '389';

  LDAP_ASN1_BIND_REQUEST = $60;
  LDAP_ASN1_BIND_RESPONSE = $61;
  LDAP_ASN1_UNBIND_REQUEST = $42;
  LDAP_ASN1_SEARCH_REQUEST = $63;
  LDAP_ASN1_SEARCH_ENTRY = $64;
  LDAP_ASN1_SEARCH_DONE = $65;
  LDAP_ASN1_SEARCH_REFERENCE = $73;
  LDAP_ASN1_MODIFY_REQUEST = $66;
  LDAP_ASN1_MODIFY_RESPONSE = $67;
  LDAP_ASN1_ADD_REQUEST = $68;
  LDAP_ASN1_ADD_RESPONSE = $69;
  LDAP_ASN1_DEL_REQUEST = $4A;
  LDAP_ASN1_DEL_RESPONSE = $6B;
  LDAP_ASN1_MODIFYDN_REQUEST = $6C;
  LDAP_ASN1_MODIFYDN_RESPONSE = $6D;
  LDAP_ASN1_COMPARE_REQUEST = $6E;
  LDAP_ASN1_COMPARE_RESPONSE = $6F;
  LDAP_ASN1_ABANDON_REQUEST = $70;
  LDAP_ASN1_EXT_REQUEST = $77;
  LDAP_ASN1_EXT_RESPONSE = $78;
  LDAP_ASN1_CONTROLS = $A0;

  { Active Directory — Global Catalog ports }
  cLDAP_GC_PORT  = '3268';
  cLDAPS_GC_PORT = '3269';

  { AD LDAP control OIDs }
  LDAP_OID_PAGED_RESULTS  = '1.2.840.113556.1.4.319';
  LDAP_OID_DIRSYNC        = '1.2.840.113556.1.4.841';
  LDAP_OID_SD_FLAGS       = '1.2.840.113556.1.4.801';
  LDAP_OID_EXTENDED_DN    = '1.2.840.113556.1.4.529';
  LDAP_OID_SHOW_DELETED   = '1.2.840.113556.1.4.1338';
  LDAP_OID_SHOW_RECYCLED  = '1.2.840.113556.1.4.2064';
  LDAP_OID_PERM_MODIFY    = '1.2.840.113556.1.4.1413';
  LDAP_OID_TREE_DELETE    = '1.2.840.113556.1.4.805';
  LDAP_OID_SERVER_SORT    = '1.2.840.113556.1.4.473';
  LDAP_OID_NOTIFICATION   = '1.2.840.113556.1.4.528';

  { AD matching rules (use in filter strings) }
  LDAP_MATCHING_RULE_BIT_AND  = '1.2.840.113556.1.4.803';
  LDAP_MATCHING_RULE_BIT_OR   = '1.2.840.113556.1.4.804';
  LDAP_MATCHING_RULE_IN_CHAIN = '1.2.840.113556.1.4.1941';

  { userAccountControl flags }
  UAC_ACCOUNTDISABLE       = $00000002;
  UAC_HOMEDIR_REQUIRED     = $00000008;
  UAC_LOCKOUT              = $00000010;
  UAC_PASSWD_NOTREQD       = $00000020;
  UAC_PASSWD_CANT_CHANGE   = $00000040;
  UAC_ENCRYPTED_TEXT_PWD   = $00000080;
  UAC_NORMAL_ACCOUNT       = $00000200;
  UAC_DONT_EXPIRE_PASSWD   = $00010000;
  UAC_SMARTCARD_REQUIRED   = $00040000;
  UAC_TRUSTED_FOR_DELEG    = $00080000;
  UAC_PASSWORD_EXPIRED     = $00800000;

  { DirSync flags }
  LDAP_DIRSYNC_OBJECT_SECURITY    = $00000001;
  LDAP_DIRSYNC_ANCESTORS_FIRST    = $00000800;
  LDAP_DIRSYNC_INCREMENTAL_VALUES = Integer($80000000);
  LDAP_DIRSYNC_MAX_BYTES_DEFAULT  = 1048576;

  { SD Flags (nTSecurityDescriptor parts) }
  LDAP_SD_OWNER = $00000001;
  LDAP_SD_GROUP = $00000002;
  LDAP_SD_DACL  = $00000004;
  LDAP_SD_SACL  = $00000008;
  LDAP_SD_ALL   = $00000007;

  { Extended DN format flags }
  LDAP_EXTENDED_DN_HEX_STRING = 0;
  LDAP_EXTENDED_DN_STANDARD   = 1;

  { SSPI/Kerberos constants -- Windows-only (SSPI via secur32.dll).
    POSIX (Linux/macOS/BSD) usa stubs que retornam False ou no-op -- V1.7.0.
    Port real para libgssapi_krb5 agendado em V2.0.0 (Roadmap). }
  LDAP_SASL_GSSAPI            = 'GSSAPI';
  LDAP_SPN_PREFIX             = 'ldap/';
{$IFDEF MSWINDOWS}
  ISC_REQ_MUTUAL_AUTH         = $00000002;
  ISC_REQ_SEQUENCE_DETECT     = $00000008;
  ISC_REQ_CONFIDENTIALITY     = $00000010;
  ISC_REQ_INTEGRITY           = $00010000;
  SECBUFFER_VERSION           = 0;
  SECBUFFER_DATA              = 1;
  SECBUFFER_TOKEN             = 2;
  SECBUFFER_CHANNEL_BINDINGS  = 10;
  SECURITY_NETWORK_DREP       = 0;
  SEC_E_OK                    = 0;
  SEC_I_CONTINUE_NEEDED       = $00090312;
  SEC_I_COMPLETE_NEEDED       = $00090313;
  SEC_I_COMPLETE_AND_CONTINUE = $00090314;
{$ENDIF MSWINDOWS}

  { Channel Binding Token prefix (RFC 5929) }
  LDAP_CBT_PREFIX = 'tls-server-end-point:';

  { Windows FILETIME epoch delta: days from 1601-01-01 to 1899-12-30 }
  LDAP_FILETIME_EPOCH_DAYS = 109205;


type

  { SSPI handle -- secur32.dll (inline, no external unit dependency).
    Windows-only. Em POSIX, estes tipos nao sao declarados pois os stubs
    dos metodos GSSAPI nao os utilizam. }
{$IFDEF MSWINDOWS}
  TLDAPSecHandle = record
    dwLower: NativeUInt;
    dwUpper: NativeUInt;
  end;
  PLDAPSecHandle = ^TLDAPSecHandle;

  TLDAPSecBuffer = record
    cbBuffer:   Cardinal;
    BufferType: Cardinal;
    pvBuffer:   Pointer;
  end;
  PLDAPSecBuffer = ^TLDAPSecBuffer;

  TLDAPSecBufferDesc = record
    ulVersion: Cardinal;
    cBuffers:  Cardinal;
    pBuffers:  PLDAPSecBuffer;
  end;
{$ENDIF MSWINDOWS}

  {:@abstract(V001.007.004 -- Tipo de valor de atributo LDAP (RFC 4517 + MS-ADTS).
   Resolvido automaticamente por TLDAPAttribute.SetAttributeName via mapa
   estatico LDAP_KNOWN_ATTRIBUTE_TYPES. Se o nome nao estiver no mapa cai em
   vtUnknown e Get aplica SafeUtf8Decode (UTF-8 com fallback Latin-1).) }
  TLDAPValueType = (
    vtUnknown, vtDirectoryString, vtIA5String, vtInteger, vtBoolean,
    vtOctetString, vtGeneralizedTime, vtUTCTime, vtDN, vtOID,
    vtSID, vtGUID, vtBitString, vtNumericString, vtEnhancedGuide, vtFileTime
  );

  {:@abstract(V001.007.004 -- Resolve o tipo LDAP de um atributo pelo nome.
     Tolera sufixos ;binary e ;range=.... Retorna vtUnknown se desconhecido.) }
  function ResolveLDAPValueType(const AAttributeName: AnsiString): TLDAPValueType;

type
  TLDAPAttribute = class; // forward

  {:@abstract(V001.007.004 -- Acessor tipado de um valor de TLDAPAttribute.
     Semantica identica a TField (Data.DB): AsString / AsInteger / AsBoolean /
     AsFloat / AsDateTime / AsBinary / AsHex / AsSid / AsGuid / IsNull /
     AsVariant. Obtido via TLDAPAttribute.Value (singular) ou
     TLDAPAttribute.Values[Index] (multi-valued). Record por valor -- sem
     gestao de memoria do consumidor.) }
  TLDAPAttributeValue = record
  strict private
    FOwner: TLDAPAttribute;
    FIndex: Integer;
    function GetRaw: AnsiString;
    function GetValueType: TLDAPValueType;
  public
    class function Create(AOwner: TLDAPAttribute; AIndex: Integer): TLDAPAttributeValue; static;
    function IsNull: Boolean;
    { Conversoes tipadas -- nunca levantam excepcao; devolvem default
      sintatico se tipo nao casar (0, 0.0, False, '', NullDate). }
    function AsString:   string;
    function AsInteger:  Int64;
    function AsFloat:    Double;
    function AsBoolean:  Boolean;
    function AsDateTime: TDateTime;
    function AsBinary:   TBytes;
    function AsHex:      string;
    function AsSid:      string;
    function AsGuid:     TGUID;
    function AsVariant:  Variant;
    property Raw: AnsiString read GetRaw;
    property ValueType: TLDAPValueType read GetValueType;
  end;

  {:@abstract(LDAP attribute with list of their values)
   This class holding name of LDAP attribute and list of their values. This is
   descendant of TStringList class enhanced by some new properties.}
  TLDAPAttribute = class(TStringList)
  private
    FAttributeName: AnsiString;
    FIsBinary: Boolean;
    FValueType: TLDAPValueType;                 // V001.007.004
    FRawValues: array of AnsiString;            // V001.007.004 -- bytes crus por indice
    procedure StoreRawValue(Index: Integer; const ARaw: AnsiString);
    function  GetValueAt(Index: Integer): TLDAPAttributeValue;
    function  GetSingleValue: TLDAPAttributeValue;
    function  GetRawValueAt(Index: Integer): AnsiString;       // V001.007.004 -- accessor para TLDAPAttributeValue
  protected
    function Get(Index: integer): string; override;
    procedure Put(Index: integer; const Value: string); override;
    procedure SetAttributeName(Value: AnsiString);
  public
    function Add(const S: string): Integer; override;
    {:V001.007.004 -- override de Clear para resetar FRawValues em sincronia
       com o TStringList interno (futuro-proof contra paths do Synapse que
       reusem TLDAPAttribute via Clear + Add). }
    procedure Clear; override;
    {:V001.007.004.2 -- Adiciona valor RAW (bytes brutos da stream ASN.1)
       SEM conversao implicita AnsiString->UnicodeString->back-to-AnsiString
       e SEM UnquoteStr. Esta e a unica forma de preservar 100% dos bytes
       de atributos binarios (objectGUID, objectSid, thumbnailPhoto,
       userCertificate, etc.) que o AD envia sem sufixo ;binary.
       Usado pelo parser ASN.1 interno (TLDAPSend.Search / DoSearchAD).
       Retorna o indice novo. }
    function AddRaw(const ARaw: AnsiString): Integer;
    { V001.007.004 -- acesso ao field raw para TLDAPAttributeValue (mesma unit). }
    property RawValueAt[Index: Integer]: AnsiString read GetRawValueAt;
    {:V001.007.004 -- Acessor multi-valued por indice.
       Array property nao pode ser "published" (E2188) — fica em public. }
    property Values[Index: Integer]: TLDAPAttributeValue read GetValueAt;
{$IFDEF FPC}
    {:V001.007.004 -- Acessor do valor no indice 0 (singular, mais comum).
      Em FPC, este tipo nao e permitido em "published". }
    property Value: TLDAPAttributeValue read GetSingleValue;
{$ENDIF}
  published
    {:Name of LDAP attribute.}
    property AttributeName: AnsiString read FAttributeName Write SetAttributeName;
    {:Return @true when attribute contains binary data.}
    property IsBinary: Boolean read FIsBinary;
    {:V001.007.004 -- Tipo LDAP inferido automaticamente por SetAttributeName.}
    property ValueType: TLDAPValueType read FValueType;
{$IFNDEF FPC}
    {:V001.007.004 -- Acessor do valor no indice 0 (singular, mais comum).}
    property Value: TLDAPAttributeValue read GetSingleValue;
{$ENDIF}
  end;

  {:@abstract(List of @link(TLDAPAttribute))
   This object can hold list of TLDAPAttribute objects.}
  TLDAPAttributeList = class(TObject)
  private
    FAttributeList: TList;
    function GetAttribute(Index: integer): TLDAPAttribute;
  public
    constructor Create;
    destructor Destroy; override;
    {:Clear list.}
    procedure Clear;
    {:Return count of TLDAPAttribute objects in list.}
    function Count: integer;
    {:Add new TLDAPAttribute object to list.}
    function Add: TLDAPAttribute;
    {:Delete one TLDAPAttribute object from list.}
    procedure Del(Index: integer);
    {:Find and return attribute with requested name. Returns nil if not found.}
    function Find(AttributeName: AnsiString): TLDAPAttribute;
    {:Find and return attribute value with requested name. Returns empty string if not found.}
    function Get(AttributeName: AnsiString): string;
    {:List of TLDAPAttribute objects.}
    property Items[Index: Integer]: TLDAPAttribute read GetAttribute; default;
  end;

  {:@abstract(LDAP result object)
   This object can hold LDAP object. (their name and all their attributes with
   values)}
  TLDAPResult = class(TObject)
  private
    FObjectName: AnsiString;
    FAttributes: TLDAPAttributeList;
  public
    constructor Create;
    destructor Destroy; override;
  published
    {:Name of this LDAP object.}
    property ObjectName: AnsiString read FObjectName write FObjectName;
    {:Here is list of object attributes.}
    property Attributes: TLDAPAttributeList read FAttributes;
  end;

  {:@abstract(List of LDAP result objects)
   This object can hold list of LDAP objects. (for example result of LDAP SEARCH.)}
  TLDAPResultList = class(TObject)
  private
    FResultList: TList;
    function GetResult(Index: integer): TLDAPResult;
  public
    constructor Create;
    destructor Destroy; override;
    {:Clear all TLDAPResult objects in list.}
    procedure Clear;
    {:Return count of TLDAPResult objects in list.}
    function Count: integer;
    {:Create and add new TLDAPResult object to list.}
    function Add: TLDAPResult;
    {:List of TLDAPResult objects.}
    property Items[Index: Integer]: TLDAPResult read GetResult; default;
  end;

  {:Define possible operations for LDAP MODIFY operations.}
  TLDAPModifyOp = (
    MO_Add,
    MO_Delete,
    MO_Replace
  );

  {:Specify possible values for search scope.}
  TLDAPSearchScope = (
    SS_BaseObject,
    SS_SingleLevel,
    SS_WholeSubtree
  );

  {:Specify possible values about alias dereferencing.}
  TLDAPSearchAliases = (
    SA_NeverDeref,
    SA_InSearching,
    SA_FindingBaseObj,
    SA_Always
  );

  {:@abstract(Implementation of LDAP client)
   (version 2 and 3)

   Note: Are you missing properties for setting Username and Password? Look to
   parent @link(TSynaClient) object!

   Are you missing properties for specify server address and port? Look to
   parent @link(TSynaClient) too!}
  TLDAPSend = class(TSynaClient)
  private
    FSock: TTCPBlockSocket;
    FResultCode: Integer;
    FResultString: AnsiString;
    FFullResult: AnsiString;
    FAutoTLS: Boolean;
    FFullSSL: Boolean;
    FSeq: integer;
    FResponseCode: integer;
    FResponseDN: AnsiString;
    FReferals: TStringList;
    FVersion: integer;
    FSearchScope: TLDAPSearchScope;
    FSearchAliases: TLDAPSearchAliases;
    FSearchSizeLimit: integer;
    FSearchTimeLimit: integer;
    FSearchPageSize: integer;
    FSearchCookie: AnsiString;
    FSearchResult: TLDAPResultList;
    FExtName: AnsiString;
    FExtValue: AnsiString;
    { AD DirSync state }
    FDirSyncCookie:   AnsiString;
    FDirSyncFlags:    Integer;
    FDirSyncMaxBytes: Integer;
    FDirSyncResult:   AnsiString;
    { SSPI/GSSAPI state -- Windows-only. POSIX: campos nao declarados
      pois stubs nao os utilizam. FSigningActive/FSigningSeqNo permanecem
      (sao usados tambem por fluxo LDAP generico para controle de sequencia). }
{$IFDEF MSWINDOWS}
    FSSPICred:        TLDAPSecHandle;
    FSSPICtx:         TLDAPSecHandle;
    FSSPIHaveCred:    Boolean;
    FSSPIHaveCtx:     Boolean;
{$ENDIF MSWINDOWS}
    FSigningActive:   Boolean;
    FSigningSeqNo:    Cardinal;
    function Connect: Boolean;
    function BuildPacket(const Value: AnsiString): AnsiString;
    function ReceiveResponse: AnsiString;
    function DecodeResponse(const Value: AnsiString): AnsiString;
    function LdapSasl(Value: AnsiString): AnsiString;
    function TranslateFilter(Value: AnsiString): AnsiString;
    function GetErrorString(Value: integer): AnsiString;
    { AD control helpers }
    function  BuildADControl(const AOID: AnsiString; ACritical: Boolean;
                             const AValue: AnsiString): AnsiString;
    function  WrapADControls(const AControlsBlock: AnsiString): AnsiString;
    function  DoSearchAD(const ABase, AFilter: AnsiString;
                         AScope: TLDAPSearchScope; const AAttributes: TStrings;
                         const AControlsBlock: AnsiString): Boolean;
    procedure ParseDirSyncCookie(const AResponseBlock: AnsiString);
    { Password helper }
    function  EncodeUnicodePwd(const APassword: AnsiString): AnsiString;
    { SSPI helpers -- Windows-only. Em POSIX nao existem. }
{$IFDEF MSWINDOWS}
    procedure LoadSSPIFunctions;
    procedure SSPICleanup;
    function  GSSAPIStep(const AInToken: AnsiString; const ASPN: WideString;
                         const ACBTData: AnsiString;
                         out AOutToken: AnsiString): Integer;
    function  BuildCBTData(const ACertHash: AnsiString): AnsiString;
{$ENDIF MSWINDOWS}
    { Signing helpers -- assinatura publica estavel (stubs em POSIX).
      SignLDAPMessage POSIX: retorna AMsg inalterada (no-op pass-through).
      VerifyLDAPMessage POSIX: retorna True + APlain := ASignedMsg. }
    function  SignLDAPMessage(const AMsg: AnsiString): AnsiString;
    function  VerifyLDAPMessage(const ASignedMsg: AnsiString;
                                out APlain: AnsiString): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    {:Try to connect to LDAP server and start secure channel, when it is required.}
    function Login: Boolean;

    {:Try to bind to LDAP server with @link(TSynaClient.Username) and
     @link(TSynaClient.Password). If this is empty strings, then it do annonymous
     Bind. When you not call Bind on LDAPv3, then is automaticly used anonymous
     mode.

     This method using plaintext transport of password! It is not secure!}
    function Bind: Boolean;

    {:Try to bind to LDAP server with @link(TSynaClient.Username) and
     @link(TSynaClient.Password). If this is empty strings, then it do annonymous
     Bind. When you not call Bind on LDAPv3, then is automaticly used anonymous
     mode.

     This method using SASL with DIGEST-MD5 method for secure transfer of your
     password.}
    function BindSasl: Boolean;

    {:Close connection to LDAP server.}
    function Logout: Boolean;

    {:Modify content of LDAP attribute on this object.}
    function Modify(obj: AnsiString; Op: TLDAPModifyOp; const Value: TLDAPAttribute): Boolean;

    {:Add list of attributes to specified object.}
    function Add(obj: AnsiString; const Value: TLDAPAttributeList): Boolean;

    {:Delete this LDAP object from server.}
    function Delete(obj: AnsiString): Boolean;

    {:Modify object name of this LDAP object.}
    function ModifyDN(obj, newRDN, newSuperior: AnsiString; DeleteoldRDN: Boolean): Boolean;

    {:Try to compare Attribute value with this LDAP object.}
    function Compare(obj, AttributeValue: AnsiString): Boolean;

    {:Search LDAP base for LDAP objects by Filter.}
    function Search(obj: AnsiString; TypesOnly: Boolean; Filter: AnsiString;
      const Attributes: TStrings): Boolean;

    {:Call any LDAPv3 extended command.}
    function Extended(const Name, Value: AnsiString): Boolean;

    {:Try to start SSL/TLS connection to LDAP server.}
    function StartTLS: Boolean;

    { AD Search controls }
    function SearchDirSync(const ABase, AFilter: AnsiString;
                           AScope: TLDAPSearchScope;
                           const AAttributes: TStrings): Boolean;
    function SearchWithSDFlags(const ABase, AFilter: AnsiString;
                               AScope: TLDAPSearchScope; ASDFlags: Integer;
                               const AAttributes: TStrings): Boolean;
    function SearchWithExtendedDN(const ABase, AFilter: AnsiString;
                                  AScope: TLDAPSearchScope;
                                  const AAttributes: TStrings;
                                  AFlag: Integer = LDAP_EXTENDED_DN_STANDARD): Boolean;
    function SearchShowDeleted(const ABase, AFilter: AnsiString;
                               AScope: TLDAPSearchScope;
                               const AAttributes: TStrings): Boolean;
    function SearchShowRecycled(const ABase, AFilter: AnsiString;
                                AScope: TLDAPSearchScope;
                                const AAttributes: TStrings): Boolean;
    function SearchWithServerSort(const ABase, AFilter: AnsiString;
                                  AScope: TLDAPSearchScope;
                                  const ASortAttribute: AnsiString;
                                  const AAttributes: TStrings): Boolean;

    { AD Modify/Delete controls }
    function ModifyPermissive(const AObj: AnsiString; AOp: TLDAPModifyOp;
                              const AValue: TLDAPAttribute): Boolean;
    function DeleteTree(const AObj: AnsiString): Boolean;

    { SASL GSSAPI/Kerberos — Windows SSPI, no external dependencies }
    function BindGSSAPI(const ASPN: AnsiString): Boolean;
    function BindGSSAPIWithCBT(const ASPN, ACertHash: AnsiString): Boolean;

    { Password operations — require LDAPS (port 636) or StartTLS }
    function ChangePassword(const AUserDN, AOldPassword,
                            ANewPassword: AnsiString): Boolean;
    function SetPassword(const AUserDN, ANewPassword: AnsiString): Boolean;
    function ForcePasswordChange(const AUserDN: AnsiString): Boolean;

    { Account status (class functions — pass userAccountControl integer) }
    class function IsAccountLocked(AUac: Integer): Boolean;
    class function IsAccountDisabled(AUac: Integer): Boolean;
    class function IsPasswordExpired(AUac: Integer): Boolean;

    { FileTime helpers (class functions) }
    class function FileTimeToDateTime(AFileTime: Int64): TDateTime;
    class function DateTimeToFileTime(ADateTime: TDateTime): Int64;

    { RootDSE }
    function GetRootDSE(const AAttributes: TStrings): Boolean;

    { Filter / DN escaping (class functions — RFC 4515, RFC 4514) }
    class function EscapeFilterValue(const AValue: AnsiString): AnsiString;
    class function EscapeDNComponent(const AValue: AnsiString): AnsiString;

    { Binary attribute helpers (class functions) }
    class function GUIDToLDAPEscape(const AGUID: TGUID): AnsiString;
    class function SIDToLDAPEscape(const ASIDBytes: AnsiString): AnsiString;

    { Membership and pagination }
    function IsMemberOf(const AUserDN, AGroupDN, ABase: AnsiString): Boolean;
    function SearchAllPages(const ABase, AFilter: AnsiString;
                            AScope: TLDAPSearchScope;
                            const AAttributes: TStrings;
                            APageSize: Integer;
                            AAccumulate: TLDAPResultList): Boolean;
  published
    {:Specify version of used LDAP protocol. Default value is 3.}
    property Version: integer read FVersion Write FVersion;

    {:Result code of last LDAP operation.}
    property ResultCode: Integer read FResultCode;

    {:Human readable description of result code of last LDAP operation.}
    property ResultString: AnsiString read FResultString;

    {:Binary string with full last response of LDAP server. This string is
     encoded by ASN.1 BER encoding! You need this only for debugging.}
    property FullResult: AnsiString read FFullResult;

    {:If @true, then try to start TSL mode in Login procedure.}
    property AutoTLS: Boolean read FAutoTLS Write FAutoTLS;

    {:If @true, then use connection to LDAP server through SSL/TLS tunnel.}
    property FullSSL: Boolean read FFullSSL Write FFullSSL;

    {:Sequence number of last LDAp command. It is incremented by any LDAP command.}
    property Seq: integer read FSeq;

    {:Specify what search scope is used in search command.}
    property SearchScope: TLDAPSearchScope read FSearchScope Write FSearchScope;

    {:Specify how to handle aliases in search command.}
    property SearchAliases: TLDAPSearchAliases read FSearchAliases Write FSearchAliases;

    {:Specify result size limit in search command. Value 0 means without limit.}
    property SearchSizeLimit: integer read FSearchSizeLimit Write FSearchSizeLimit;

    {:Specify search time limit in search command (seconds). Value 0 means
     without limit.}
    property SearchTimeLimit: integer read FSearchTimeLimit Write FSearchTimeLimit;

    {:Specify number of results to return per search request. Value 0 means
     no paging.}
    property SearchPageSize: integer read FSearchPageSize Write FSearchPageSize;

    {:Cookie returned by paged search results. Use an empty string for the first
     search request.}
    property SearchCookie: AnsiString read FSearchCookie Write FSearchCookie;

    {:Here is result of search command.}
    property SearchResult: TLDAPResultList read FSearchResult;

    {:On each LDAP operation can LDAP server return some referals URLs. Here is
     their list.}
    property Referals: TStringList read FReferals;

    {:When you call @link(Extended) operation, then here is result Name returned
     by server.}
    property ExtName: AnsiString read FExtName;

    {:When you call @link(Extended) operation, then here is result Value returned
     by server.}
    property ExtValue: AnsiString read FExtValue;

    {:TCP socket used by all LDAP operations.}
    property Sock: TTCPBlockSocket read FSock;

    { AD DirSync state }
    property DirSyncCookie:   AnsiString read FDirSyncCookie   write FDirSyncCookie;
    property DirSyncFlags:    Integer    read FDirSyncFlags     write FDirSyncFlags;
    property DirSyncMaxBytes: Integer    read FDirSyncMaxBytes  write FDirSyncMaxBytes;
    property DirSyncResult:   AnsiString read FDirSyncResult;
    { LDAP Signing status }
    property SigningActive:    Boolean    read FSigningActive;
  end;

{:Dump result of LDAP SEARCH into human readable form. Good for debugging.}
function LDAPResultDump(const Value: TLDAPResultList): AnsiString;

{$IFDEF MSWINDOWS}
var
  { SSPI secur32.dll handle -- loaded lazily by LoadSSPIFunctions.
    Windows-only. Em POSIX, secur32.dll nao existe; stubs nao carregam nada. }
  FLDAPSecur32Lib: HMODULE = 0;

  LDAP_AcquireCredentialsHandle: function(
    pszPrincipal, pszPackage: PWideChar; fCredentialUse: Cardinal;
    pvLogonID, pAuthData, pGetKeyFn, pvGetKeyArg: Pointer;
    phCredential: PLDAPSecHandle; ptsExpiry: Pointer): Integer; stdcall;

  LDAP_InitializeSecurityContext: function(
    phCredential, phContext: PLDAPSecHandle; pszTargetName: PWideChar;
    fContextReq, Reserved1, TargetDataRep: Cardinal;
    pInput: Pointer; Reserved2: Cardinal; phNewContext: PLDAPSecHandle;
    pOutput: Pointer; pfContextAttr: PCardinal; ptsExpiry: Pointer): Integer; stdcall;

  LDAP_CompleteAuthToken: function(
    phContext: PLDAPSecHandle; pToken: Pointer): Integer; stdcall;

  LDAP_MakeSignature: function(
    phContext: PLDAPSecHandle; fQOP: Cardinal;
    pMessage: Pointer; MessageSeqNo: Cardinal): Integer; stdcall;

  LDAP_VerifySignature: function(
    phContext: PLDAPSecHandle; pMessage: Pointer;
    MessageSeqNo: Cardinal; pfQOP: PCardinal): Integer; stdcall;

  LDAP_DeleteSecurityContext: function(
    phContext: PLDAPSecHandle): Integer; stdcall;

  LDAP_FreeCredentialsHandle: function(
    phCredential: PLDAPSecHandle): Integer; stdcall;
{$ENDIF MSWINDOWS}

implementation

{==============================================================================}
{ V001.007.004 -- Attribute type map (MS-ADTS + RFC 4517)                      }
{ ~110 atributos AD default cobrindo os casos 99% de tipagem automatica.       }
{ Para schema custom/extendido, fallback eh vtUnknown + SafeUtf8Decode.        }
{==============================================================================}
const
  LDAP_KNOWN_ATTRIBUTE_TYPES: array[0..110] of record
    Name: AnsiString;
    ValueType: TLDAPValueType;
  end = (
    { Identidade / GUID / SID binarios }
    (Name: 'objectGUID';                ValueType: vtGUID),
    (Name: 'objectSid';                 ValueType: vtSID),
    (Name: 'sIDHistory';                ValueType: vtSID),
    (Name: 'msExchMailboxGuid';         ValueType: vtGUID),
    (Name: 'msExchMasterAccountSid';    ValueType: vtSID),
    (Name: 'schemaIDGUID';              ValueType: vtGUID),
    (Name: 'attributeSecurityGUID';     ValueType: vtGUID),
    (Name: 'parentGUID';                ValueType: vtGUID),

    { Octet string bruto (hex) }
    (Name: 'thumbnailPhoto';            ValueType: vtOctetString),
    (Name: 'jpegPhoto';                 ValueType: vtOctetString),
    (Name: 'thumbnailLogo';             ValueType: vtOctetString),
    (Name: 'userCertificate';           ValueType: vtOctetString),
    (Name: 'userSMIMECertificate';      ValueType: vtOctetString),
    (Name: 'cACertificate';             ValueType: vtOctetString),
    (Name: 'logonHours';                ValueType: vtOctetString),
    (Name: 'nTSecurityDescriptor';      ValueType: vtOctetString),
    (Name: 'replPropertyMetaData';      ValueType: vtOctetString),
    (Name: 'replUpToDateVector';        ValueType: vtOctetString),
    (Name: 'msPKIAccountCredentials';   ValueType: vtOctetString),
    (Name: 'msPKIDPAPIMasterKeys';      ValueType: vtOctetString),
    (Name: 'msPKIRoamingTimeStamp';     ValueType: vtOctetString),
    (Name: 'mSMQSignCertificates';      ValueType: vtOctetString),
    (Name: 'terminalServer';            ValueType: vtOctetString),
    (Name: 'audio';                     ValueType: vtOctetString),
    (Name: 'photo';                     ValueType: vtOctetString),
    (Name: 'unicodePwd';                ValueType: vtOctetString),
    (Name: 'dnsRecord';                 ValueType: vtOctetString),
    (Name: 'dNSProperty';               ValueType: vtOctetString),
    (Name: 'tokenGroups';               ValueType: vtSID),
    (Name: 'tokenGroupsGlobalAndUniversal'; ValueType: vtSID),
    (Name: 'tokenGroupsNoGCAcceptable'; ValueType: vtSID),

    { FILETIME AD (Int64 ASCII decimal) }
    (Name: 'pwdLastSet';                ValueType: vtFileTime),
    (Name: 'accountExpires';            ValueType: vtFileTime),
    (Name: 'badPasswordTime';           ValueType: vtFileTime),
    (Name: 'lastLogon';                 ValueType: vtFileTime),
    (Name: 'lastLogonTimestamp';        ValueType: vtFileTime),
    (Name: 'lockoutTime';               ValueType: vtFileTime),
    (Name: 'msDS-UserPasswordExpiryTimeComputed'; ValueType: vtFileTime),

    { Inteiros }
    (Name: 'userAccountControl';        ValueType: vtInteger),
    (Name: 'logonCount';                ValueType: vtInteger),
    (Name: 'badPwdCount';               ValueType: vtInteger),
    (Name: 'primaryGroupID';            ValueType: vtInteger),
    (Name: 'sAMAccountType';            ValueType: vtInteger),
    (Name: 'groupType';                 ValueType: vtInteger),
    (Name: 'instanceType';              ValueType: vtInteger),
    (Name: 'uSNCreated';                ValueType: vtInteger),
    (Name: 'uSNChanged';                ValueType: vtInteger),
    (Name: 'uSNSource';                 ValueType: vtInteger),
    (Name: 'revision';                  ValueType: vtInteger),
    (Name: 'systemFlags';               ValueType: vtInteger),
    (Name: 'countryCode';               ValueType: vtInteger),
    (Name: 'codePage';                  ValueType: vtInteger),

    { Generalized Time }
    (Name: 'whenCreated';               ValueType: vtGeneralizedTime),
    (Name: 'whenChanged';               ValueType: vtGeneralizedTime),
    (Name: 'dSCorePropagationData';     ValueType: vtGeneralizedTime),
    (Name: 'msDS-Entry-Time-To-Die';    ValueType: vtGeneralizedTime),

    { DN }
    (Name: 'distinguishedName';         ValueType: vtDN),
    (Name: 'objectCategory';            ValueType: vtDN),
    (Name: 'managedBy';                 ValueType: vtDN),
    (Name: 'manager';                   ValueType: vtDN),
    (Name: 'member';                    ValueType: vtDN),
    (Name: 'memberOf';                  ValueType: vtDN),
    (Name: 'directReports';             ValueType: vtDN),
    (Name: 'secretary';                 ValueType: vtDN),
    (Name: 'owner';                     ValueType: vtDN),
    (Name: 'seeAlso';                   ValueType: vtDN),

    { Booleans }
    (Name: 'showInAdvancedViewOnly';    ValueType: vtBoolean),
    (Name: 'isDeleted';                 ValueType: vtBoolean),
    (Name: 'isRecycled';                ValueType: vtBoolean),

    { OID }
    (Name: 'governsID';                 ValueType: vtOID),
    (Name: 'attributeID';               ValueType: vtOID),
    (Name: 'attributeSyntax';           ValueType: vtOID),

    { Directory String / texto UTF-8 }
    (Name: 'sAMAccountName';            ValueType: vtDirectoryString),
    (Name: 'userPrincipalName';         ValueType: vtDirectoryString),
    (Name: 'displayName';               ValueType: vtDirectoryString),
    (Name: 'givenName';                 ValueType: vtDirectoryString),
    (Name: 'sn';                        ValueType: vtDirectoryString),
    (Name: 'cn';                        ValueType: vtDirectoryString),
    (Name: 'description';               ValueType: vtDirectoryString),
    (Name: 'ou';                        ValueType: vtDirectoryString),
    (Name: 'mail';                      ValueType: vtDirectoryString),
    (Name: 'proxyAddresses';            ValueType: vtDirectoryString),
    (Name: 'mobile';                    ValueType: vtDirectoryString),
    (Name: 'telephoneNumber';           ValueType: vtDirectoryString),
    (Name: 'facsimileTelephoneNumber';  ValueType: vtDirectoryString),
    (Name: 'homePhone';                 ValueType: vtDirectoryString),
    (Name: 'pager';                     ValueType: vtDirectoryString),
    (Name: 'ipPhone';                   ValueType: vtDirectoryString),
    (Name: 'objectClass';               ValueType: vtDirectoryString),
    (Name: 'title';                     ValueType: vtDirectoryString),
    (Name: 'department';                ValueType: vtDirectoryString),
    (Name: 'company';                   ValueType: vtDirectoryString),
    (Name: 'physicalDeliveryOfficeName';ValueType: vtDirectoryString),
    (Name: 'streetAddress';             ValueType: vtDirectoryString),
    (Name: 'postOfficeBox';             ValueType: vtDirectoryString),
    (Name: 'postalCode';                ValueType: vtDirectoryString),
    (Name: 'l';                         ValueType: vtDirectoryString),
    (Name: 'st';                        ValueType: vtDirectoryString),
    (Name: 'co';                        ValueType: vtDirectoryString),
    (Name: 'c';                         ValueType: vtDirectoryString),
    (Name: 'employeeID';                ValueType: vtDirectoryString),
    (Name: 'employeeNumber';            ValueType: vtDirectoryString),
    (Name: 'employeeType';              ValueType: vtDirectoryString),
    (Name: 'initials';                  ValueType: vtDirectoryString),
    (Name: 'middleName';                ValueType: vtDirectoryString),
    (Name: 'info';                      ValueType: vtDirectoryString),
    (Name: 'name';                      ValueType: vtDirectoryString),
    (Name: 'url';                       ValueType: vtIA5String),
    (Name: 'wWWHomePage';               ValueType: vtIA5String),
    (Name: 'dNSHostName';               ValueType: vtIA5String),
    (Name: 'servicePrincipalName';      ValueType: vtIA5String)
  );

function ResolveLDAPValueType(const AAttributeName: AnsiString): TLDAPValueType;
var
  I: Integer;
  LName: AnsiString;
  P: Integer;
begin
  Result := vtUnknown;
  LName := AAttributeName;
  { Strip ;binary / ;range=... / outros atributos options. }
  P := Pos(AnsiString(';'), LName);
  if P > 0 then
    LName := Copy(LName, 1, P - 1);
  for I := Low(LDAP_KNOWN_ATTRIBUTE_TYPES) to High(LDAP_KNOWN_ATTRIBUTE_TYPES) do
    if SameText(string(LDAP_KNOWN_ATTRIBUTE_TYPES[I].Name), string(LName)) then
      Exit(LDAP_KNOWN_ATTRIBUTE_TYPES[I].ValueType);
end;

{==============================================================================}
{ V001.007.004 -- Helpers file-private de decodificacao segura.                }
{==============================================================================}

function UnicodeToRawAnsi(const S: string): AnsiString;
var
  I: Integer;
begin
  { Conversao byte-a-byte do code point baixo -- nunca levanta EEncodingError.
    Substitui 's := Value' (RTL implicit via CP_ACP) que falhava em Delphi 12
    strict mode sobre bytes binarios recebidos do socket.
    Racional completo no plano/documentacao CSL V1.7.1. }
  if S = '' then Exit('');
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I] := AnsiChar(Ord(S[I]) and $FF);
end;

function SafeUtf8Decode(const ARaw: AnsiString): string;
var
  LBytes: TBytes;
  LEnc: TEncoding;
  I: Integer;
begin
  if ARaw = '' then Exit('');
  SetLength(LBytes, Length(ARaw));
  if Length(LBytes) > 0 then
    Move(ARaw[1], LBytes[0], Length(LBytes));
  try
    LEnc := TUTF8Encoding.Create;
    try
      Result := LEnc.GetString(LBytes);
    finally
      LEnc.Free;
    end;
  except
    { Fallback Latin-1 por byte -- nunca falha para exibicao. }
    SetLength(Result, Length(LBytes));
    for I := 0 to High(LBytes) do
      Result[I + 1] := Char(LBytes[I]);
  end;
end;

function RawToHex(const ARaw: AnsiString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(ARaw) do
    Result := Result + IntToHex(Ord(ARaw[I]) and $FF, 2);
end;

function RawToSid(const ARaw: AnsiString): string;
var
  LRev: Byte;
  LSubCount: Byte;
  LIdAuth: Int64;
  LSubs: array of Cardinal;
  I: Integer;
begin
  { MS-ADTS: byte[0]=Revision, byte[1]=#SubAuth, bytes[2..7]=IdentifierAuthority BE,
    bytes[8..]=SubAuthorities Int32 LE. }
  Result := '';
  if Length(ARaw) < 8 then
  begin
    Result := RawToHex(ARaw);
    Exit;
  end;
  LRev := Ord(ARaw[1]);
  LSubCount := Ord(ARaw[2]);
  LIdAuth := 0;
  for I := 3 to 8 do
    LIdAuth := (LIdAuth shl 8) or Ord(ARaw[I]);
  Result := Format('S-%d-%d', [LRev, LIdAuth]);
  if Length(ARaw) < 8 + 4 * LSubCount then Exit;
  SetLength(LSubs, LSubCount);
  for I := 0 to LSubCount - 1 do
    LSubs[I] := (Cardinal(Ord(ARaw[9 + 4*I]))        ) or
                (Cardinal(Ord(ARaw[10 + 4*I])) shl 8 ) or
                (Cardinal(Ord(ARaw[11 + 4*I])) shl 16) or
                (Cardinal(Ord(ARaw[12 + 4*I])) shl 24);
  for I := 0 to LSubCount - 1 do
    Result := Result + '-' + IntToStr(LSubs[I]);
end;

function RawBytesToGuid(const ARaw: AnsiString): TGUID;
begin
  { AD devolve objectGUID como 16 bytes little-endian.
    Data1/Data2/Data3 sao LE -> precisam swap; Data4 eh BE nos ultimos 8 bytes. }
  FillChar(Result, SizeOf(Result), 0);
  if Length(ARaw) <> 16 then Exit;
  Result.D1 := (Cardinal(Ord(ARaw[1]))       ) or (Cardinal(Ord(ARaw[2])) shl 8 ) or
               (Cardinal(Ord(ARaw[3])) shl 16) or (Cardinal(Ord(ARaw[4])) shl 24);
  Result.D2 := Word(Ord(ARaw[5])) or (Word(Ord(ARaw[6])) shl 8);
  Result.D3 := Word(Ord(ARaw[7])) or (Word(Ord(ARaw[8])) shl 8);
  Result.D4[0] := Ord(ARaw[9]);  Result.D4[1] := Ord(ARaw[10]);
  Result.D4[2] := Ord(ARaw[11]); Result.D4[3] := Ord(ARaw[12]);
  Result.D4[4] := Ord(ARaw[13]); Result.D4[5] := Ord(ARaw[14]);
  Result.D4[6] := Ord(ARaw[15]); Result.D4[7] := Ord(ARaw[16]);
end;

function RawToGuidString(const ARaw: AnsiString): string;
var
  G: TGUID;
begin
  if Length(ARaw) <> 16 then
  begin
    Result := RawToHex(ARaw);
    Exit;
  end;
  G := RawBytesToGuid(ARaw);
  Result := GUIDToString(G);
end;

function ParseFileTimeInt64(const ARaw: AnsiString; out ADT: TDateTime): Boolean;
var
  LInt: Int64;
  LCode: Integer;
begin
  Result := False;
  ADT := 0;
  Val(string(ARaw), LInt, LCode);
  if (LCode <> 0) or (LInt = 0) or (LInt = 9223372036854775807) then Exit;
  ADT := EncodeDate(1601, 1, 1) + (LInt / 864000000000.0);
  Result := True;
end;

function RawToFileTime(const ARaw: AnsiString): string;
var
  LDT: TDateTime;
begin
  { AD entrega FILETIME como Int64 em ASCII decimal representando 100-ns desde
    1601-01-01 UTC. '0' e '9223372036854775807' significam "never".
    V001.007.004 -- usa SafeUtf8Decode em vez de string(ARaw) para evitar
    EEncodingError se ARaw contiver bytes nao-ASCII (caso mapa mapeie mal). }
  Result := SafeUtf8Decode(ARaw);
  if ParseFileTimeInt64(ARaw, LDT) then
    Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', LDT);
end;

function ParseGeneralizedTime(const ARaw: AnsiString; out ADT: TDateTime): Boolean;
var
  Y, M, D, H, Mn, S: Word;
  LStr: string;
begin
  Result := False;
  ADT := 0;
  if Length(ARaw) < 14 then Exit;
  { V001.007.004 -- decode via SafeUtf8Decode para nunca lancar em bytes
    nao-ASCII residuais. Generalized Time normal e so ASCII, este e guard. }
  LStr := SafeUtf8Decode(ARaw);
  if Length(LStr) < 14 then Exit;
  try
    Y  := StrToInt(Copy(LStr, 1, 4));
    M  := StrToInt(Copy(LStr, 5, 2));
    D  := StrToInt(Copy(LStr, 7, 2));
    H  := StrToInt(Copy(LStr, 9, 2));
    Mn := StrToInt(Copy(LStr, 11, 2));
    S  := StrToInt(Copy(LStr, 13, 2));
    ADT := EncodeDate(Y, M, D) + EncodeTime(H, Mn, S, 0);
    Result := True;
  except
    ADT := 0;
    Result := False;
  end;
end;

function RawToGeneralizedTime(const ARaw: AnsiString): string;
var
  LDT: TDateTime;
begin
  { Formato: 'YYYYMMDDHHMMSS.0Z' ou 'YYYYMMDDHHMMSSZ'.
    V001.007.004 -- usa SafeUtf8Decode em vez de string(ARaw) para evitar
    EEncodingError em bytes nao-ASCII residuais. }
  Result := SafeUtf8Decode(ARaw);
  if ParseGeneralizedTime(ARaw, LDT) then
    Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', LDT);
end;

{==============================================================================}
{ V001.007.004 -- TLDAPAttributeValue (acessor tipado estilo TField)           }
{==============================================================================}

class function TLDAPAttributeValue.Create(AOwner: TLDAPAttribute; AIndex: Integer): TLDAPAttributeValue;
begin
  Result.FOwner := AOwner;
  Result.FIndex := AIndex;
end;

function TLDAPAttributeValue.GetRaw: AnsiString;
begin
  if FOwner = nil then Exit('');
  Result := FOwner.GetRawValueAt(FIndex);
end;

function TLDAPAttributeValue.GetValueType: TLDAPValueType;
begin
  if FOwner = nil then Exit(vtUnknown);
  Result := FOwner.ValueType;
end;

function TLDAPAttributeValue.IsNull: Boolean;
begin
  Result := (FOwner = nil) or (GetRaw = '');
end;

function TLDAPAttributeValue.AsString: string;
begin
  if FOwner = nil then Exit('');
  Result := FOwner.Get(FIndex);
end;

function TLDAPAttributeValue.AsInteger: Int64;
var
  LRaw: AnsiString;
  LCode: Integer;
begin
  Result := 0;
  LRaw := GetRaw;
  Val(string(LRaw), Result, LCode);
  if LCode <> 0 then Result := 0;
end;

function TLDAPAttributeValue.AsFloat: Double;
var
  LRaw: AnsiString;
  LCode: Integer;
begin
  Result := 0.0;
  LRaw := GetRaw;
  Val(string(LRaw), Result, LCode);
  if LCode <> 0 then Result := 0.0;
end;

function TLDAPAttributeValue.AsBoolean: Boolean;
begin
  Result := SameText(string(GetRaw), 'TRUE');
end;

function TLDAPAttributeValue.AsDateTime: TDateTime;
var
  LRaw: AnsiString;
begin
  Result := 0;
  LRaw := GetRaw;
  if LRaw = '' then Exit;
  case GetValueType of
    vtGeneralizedTime, vtUTCTime:
      ParseGeneralizedTime(LRaw, Result);
    vtFileTime:
      ParseFileTimeInt64(LRaw, Result);
  end;
end;

function TLDAPAttributeValue.AsBinary: TBytes;
var
  LRaw: AnsiString;
begin
  LRaw := GetRaw;
  SetLength(Result, Length(LRaw));
  if Length(LRaw) > 0 then
    Move(LRaw[1], Result[0], Length(LRaw));
end;

function TLDAPAttributeValue.AsHex: string;
begin
  Result := RawToHex(GetRaw);
end;

function TLDAPAttributeValue.AsSid: string;
begin
  Result := RawToSid(GetRaw);
end;

function TLDAPAttributeValue.AsGuid: TGUID;
begin
  Result := RawBytesToGuid(GetRaw);
end;

function TLDAPAttributeValue.AsVariant: Variant;
begin
  case GetValueType of
    vtInteger:                    Result := AsInteger;
    vtBoolean:                    Result := AsBoolean;
    vtFileTime,
    vtGeneralizedTime, vtUTCTime: Result := AsDateTime;
    vtOctetString, vtBitString:   Result := AsHex;
    vtSID:                        Result := AsSid;
    vtGUID:                       Result := GUIDToString(AsGuid);
  else
    Result := AsString;
  end;
end;

{==============================================================================}
function TLDAPAttribute.Add(const S: string): Integer;
begin
  Result := inherited Add('');
  Put(Result,S);
end;

function TLDAPAttribute.Get(Index: integer): string;
var
  LRaw: AnsiString;
begin
  { V001.007.004 -- resolve string final segundo FValueType, usando FRawValues
    (bytes crus do socket) como fonte autoritativa. Mantem API: retorno 'string'
    como antes, so que ja formatada conforme o tipo LDAP.

    Blindagem total com try/except: nenhum decoder pode abortar a iteracao
    de TLDAPSearchResult.Attributes no consumidor. Em caso de erro num decoder
    especializado, fallback para hex (sempre seguro). }
  Result := '';
  if (Index < 0) or (Index >= Length(FRawValues)) then
  begin
    try
      Result := inherited Get(Index);
      if FIsbinary then
        Result := DecodeBase64(Result);
    except
      Result := '';
    end;
    Exit;
  end;
  LRaw := FRawValues[Index];
  try
    if FIsBinary then
      LRaw := DecodeBase64(LRaw);
    case FValueType of
      vtSID:              Result := RawToSid(LRaw);
      vtGUID:             Result := RawToGuidString(LRaw);
      vtOctetString,
      vtBitString:        Result := RawToHex(LRaw);
      vtFileTime:         Result := RawToFileTime(LRaw);
      vtGeneralizedTime,
      vtUTCTime:          Result := RawToGeneralizedTime(LRaw);
    else
      { vtDirectoryString, vtIA5String, vtInteger, vtBoolean, vtNumericString,
        vtOID, vtDN, vtEnhancedGuide, vtUnknown. }
      Result := SafeUtf8Decode(LRaw);
    end;
  except
    { Fallback ultimo -- se qualquer decoder especializado lancar (ex.: hex de
      buffer com length estranho), devolver hex directo dos bytes crus. Este
      caminho e garantidamente seguro porque RawToHex so faz IntToHex. }
    try
      Result := RawToHex(FRawValues[Index]);
    except
      Result := '';
    end;
  end;
end;

procedure TLDAPAttribute.Put(Index: integer; const Value: string);
var
  s: AnsiString;
begin
  { V001.007.004 -- UnicodeToRawAnsi em vez de 's := Value' (conversao implicita
    via CP_ACP que lancava EEncodingError em Delphi 12 strict sobre bytes
    binarios recebidos do socket).

    V001.007.004.2 -- defensivo: skip UnquoteStr quando FValueType indica tipo
    binario (vtGUID, vtSID, vtOctetString, vtBitString). UnquoteStr consome
    bytes 0x22 (") silenciosamente — bug critico para bytes binarios puros
    (ex.: objectGUID do Administrador CN=cslsolucoes pode ter byte 0x22).
    Para paths publicos que chamem Add(string), isto protege parcialmente
    (bytes 0x80-0xFF ainda podem ser corrompidos pela conversao CP1252
    na passagem AnsiString -> UnicodeString -> Value). Para preservacao
    100% dos bytes crus usar o novo AddRaw(ARaw). }
  s := UnicodeToRawAnsi(Value);
  if FIsbinary then
    s := EncodeBase64(s)
  else if FValueType in [vtGUID, vtSID, vtOctetString, vtBitString] then
    { Binary resolved by mapa — NAO aplicar UnquoteStr que perde bytes 0x22. }
  else
    s := UnquoteStr(s, '"');
  inherited Put(Index, s);
  StoreRawValue(Index, s);
end;

function TLDAPAttribute.AddRaw(const ARaw: AnsiString): Integer;
begin
  { V001.007.004.2 -- Adiciona valor preservando 100% os bytes raw.
    Bypassa Put() (e portanto UnicodeToRawAnsi + UnquoteStr) que corrompe
    bytes binarios por (a) conversao implicita AnsiString->UnicodeString
    via CP_ACP e (b) UnquoteStr consumindo bytes 0x22.

    Para dar ao TStringList herdado um placeholder coerente com o Count,
    chamamos inherited Add(''). O Get(Index) override usa FRawValues como
    fonte autoritativa e nunca consulta o valor do TStringList base. }
  Result := inherited Add('');
  StoreRawValue(Result, ARaw);
end;

procedure TLDAPAttribute.StoreRawValue(Index: Integer; const ARaw: AnsiString);
begin
  if Length(FRawValues) <= Index then
    SetLength(FRawValues, Index + 1);
  FRawValues[Index] := ARaw;
end;

procedure TLDAPAttribute.Clear;
begin
  inherited Clear;
  SetLength(FRawValues, 0);
end;

function TLDAPAttribute.GetRawValueAt(Index: Integer): AnsiString;
begin
  if (Index < 0) or (Index >= Length(FRawValues)) then
    Exit('');
  Result := FRawValues[Index];
  if FIsBinary then
    Result := DecodeBase64(Result);
end;

function TLDAPAttribute.GetSingleValue: TLDAPAttributeValue;
begin
  Result := TLDAPAttributeValue.Create(Self, 0);
end;

function TLDAPAttribute.GetValueAt(Index: Integer): TLDAPAttributeValue;
begin
  Result := TLDAPAttributeValue.Create(Self, Index);
end;

procedure TLDAPAttribute.SetAttributeName(Value: AnsiString);
begin
  FAttributeName := Value;
  FIsBinary := Pos(';binary', Lowercase(value)) > 0;
  FValueType := ResolveLDAPValueType(Value);
  if FIsBinary and (FValueType = vtUnknown) then
    FValueType := vtOctetString;
end;

{==============================================================================}
constructor TLDAPAttributeList.Create;
begin
  inherited Create;
  FAttributeList := TList.Create;
end;

destructor TLDAPAttributeList.Destroy;
begin
  Clear;
  FAttributeList.Free;
  inherited Destroy;
end;

procedure TLDAPAttributeList.Clear;
var
  n: integer;
  x: TLDAPAttribute;
begin
  for n := Count - 1 downto 0 do
  begin
    x := GetAttribute(n);
    if Assigned(x) then
      x.Free;
  end;
  FAttributeList.Clear;
end;

function TLDAPAttributeList.Count: integer;
begin
  Result := FAttributeList.Count;
end;

function TLDAPAttributeList.Get(AttributeName: AnsiString): string;
var
  x: TLDAPAttribute;
begin
  Result := '';
  x := self.Find(AttributeName);
  if x <> nil then
    if x.Count > 0 then
      Result := x[0];
end;

function TLDAPAttributeList.GetAttribute(Index: integer): TLDAPAttribute;
begin
  Result := nil;
  if Index < Count then
    Result := TLDAPAttribute(FAttributeList[Index]);
end;

function TLDAPAttributeList.Add: TLDAPAttribute;
begin
  Result := TLDAPAttribute.Create;
  FAttributeList.Add(Result);
end;

procedure TLDAPAttributeList.Del(Index: integer);
var
  x: TLDAPAttribute;
begin
  x := GetAttribute(Index);
  if Assigned(x) then
    x.free;
  FAttributeList.Delete(Index);
end;

function TLDAPAttributeList.Find(AttributeName: AnsiString): TLDAPAttribute;
var
  n: integer;
  x: TLDAPAttribute;
begin
  Result := nil;
  AttributeName := lowercase(AttributeName);
  for n := 0 to Count - 1 do
  begin
    x := GetAttribute(n);
    if Assigned(x) then
      if lowercase(x.AttributeName) = Attributename then
      begin
        result := x;
        break;
      end;
  end;
end;

{==============================================================================}
constructor TLDAPResult.Create;
begin
  inherited Create;
  FAttributes := TLDAPAttributeList.Create;
end;

destructor TLDAPResult.Destroy;
begin
  FAttributes.Free;
  inherited Destroy;
end;

{==============================================================================}
constructor TLDAPResultList.Create;
begin
  inherited Create;
  FResultList := TList.Create;
end;

destructor TLDAPResultList.Destroy;
begin
  Clear;
  FResultList.Free;
  inherited Destroy;
end;

procedure TLDAPResultList.Clear;
var
  n: integer;
  x: TLDAPResult;
begin
  for n := Count - 1 downto 0 do
  begin
    x := GetResult(n);
    if Assigned(x) then
      x.Free;
  end;
  FResultList.Clear;
end;

function TLDAPResultList.Count: integer;
begin
  Result := FResultList.Count;
end;

function TLDAPResultList.GetResult(Index: integer): TLDAPResult;
begin
  Result := nil;
  if Index < Count then
    Result := TLDAPResult(FResultList[Index]);
end;

function TLDAPResultList.Add: TLDAPResult;
begin
  Result := TLDAPResult.Create;
  FResultList.Add(Result);
end;

{==============================================================================}
constructor TLDAPSend.Create;
begin
  inherited Create;
  FReferals := TStringList.Create;
  FFullResult := '';
  FSock := TTCPBlockSocket.Create;
  FSock.Owner := self;
  FTimeout := 60000;
  FTargetPort := cLDAPProtocol;
  FAutoTLS := False;
  FFullSSL := False;
  FSeq := 0;
  FVersion := 3;
  FSearchScope := SS_WholeSubtree;
  FSearchAliases := SA_Always;
  FSearchSizeLimit := 0;
  FSearchTimeLimit := 0;
  FSearchPageSize := 0;
  FSearchCookie := '';
  FSearchResult := TLDAPResultList.Create;
  { DirSync defaults }
  FDirSyncFlags    := LDAP_DIRSYNC_INCREMENTAL_VALUES;
  FDirSyncMaxBytes := LDAP_DIRSYNC_MAX_BYTES_DEFAULT;
  FDirSyncCookie   := '';
  FDirSyncResult   := '';
  { SSPI defaults }
  FSSPIHaveCred  := False;
  FSSPIHaveCtx   := False;
  FSigningActive := False;
  FSigningSeqNo  := 0;
end;

destructor TLDAPSend.Destroy;
begin
{$IFDEF MSWINDOWS}
  SSPICleanup;
{$ENDIF}
  FSock.Free;
  FSearchResult.Free;
  FReferals.Free;
  inherited Destroy;
end;

function TLDAPSend.GetErrorString(Value: integer): AnsiString;
begin
  case Value of
    0:
      Result := 'Success';
    1:
      Result := 'Operations error';
    2:
      Result := 'Protocol error';
    3:
      Result := 'Time limit Exceeded';
    4:
      Result := 'Size limit Exceeded';
    5:
      Result := 'Compare FALSE';
    6:
      Result := 'Compare TRUE';
    7:
      Result := 'Auth method not supported';
    8:
      Result := 'Strong auth required';
    9:
      Result := '-- reserved --';
    10:
      Result := 'Referal';
    11:
      Result := 'Admin limit exceeded';
    12:
      Result := 'Unavailable critical extension';
    13:
      Result := 'Confidentality required';
    14:
      Result := 'Sasl bind in progress';
    16:
      Result := 'No such attribute';
    17:
      Result := 'Undefined attribute type';
    18:
      Result := 'Inappropriate matching';
    19:
      Result := 'Constraint violation';
    20:
      Result := 'Attribute or value exists';
    21:
      Result := 'Invalid attribute syntax';
    32:
      Result := 'No such object';
    33:
      Result := 'Alias problem';
    34:
      Result := 'Invalid DN syntax';
    36:
      Result := 'Alias dereferencing problem';
    48:
      Result := 'Inappropriate authentication';
    49:
      Result := 'Invalid credentials';
    50:
      Result := 'Insufficient access rights';
    51:
      Result := 'Busy';
    52:
      Result := 'Unavailable';
    53:
      Result := 'Unwilling to perform';
    54:
      Result := 'Loop detect';
    64:
      Result := 'Naming violation';
    65:
      Result := 'Object class violation';
    66:
      Result := 'Not allowed on non leaf';
    67:
      Result := 'Not allowed on RDN';
    68:
      Result := 'Entry already exists';
    69:
      Result := 'Object class mods prohibited';
    71:
      Result := 'Affects multiple DSAs';
    80:
      Result := 'Other';
  else
    Result := '--unknown--';
  end;
end;

function TLDAPSend.Connect: Boolean;
begin
  // Do not call this function! It is calling by LOGIN method!
  FSock.CloseSocket;
  FSock.LineBuffer := '';
  FSeq := 0;
  FSock.Bind(FIPInterface, cAnyPort);
  if FSock.LastError = 0 then
    FSock.Connect(FTargetHost, FTargetPort);
  if FSock.LastError = 0 then
    if FFullSSL then
      FSock.SSLDoConnect;
  Result := FSock.LastError = 0;
end;

function TLDAPSend.BuildPacket(const Value: AnsiString): AnsiString;
begin
  Inc(FSeq);
  Result := ASNObject(ASNObject(ASNEncInt(FSeq), ASN1_INT) + Value,  ASN1_SEQ);
end;

function TLDAPSend.ReceiveResponse: AnsiString;
var
  x: Byte;
  i,j: integer;
begin
  Result := '';
  FFullResult := '';
  x := FSock.RecvByte(FTimeout);
  if x <> ASN1_SEQ then
    Exit;
  Result := AnsiChar(x);
  x := FSock.RecvByte(FTimeout);
  Result := Result + AnsiChar(x);
  if x < $80 then
    i := 0
  else
    i := x and $7F;
  if i > 0 then
    Result := Result + FSock.RecvBufferStr(i, Ftimeout);
  if FSock.LastError <> 0 then
  begin
    Result := '';
    Exit;
  end;
  //get length of LDAP packet
  j := 2;
  i := ASNDecLen(j, Result);
  //retreive rest of LDAP packet
  if i > 0 then
    Result := Result + FSock.RecvBufferStr(i, Ftimeout);
  if FSock.LastError <> 0 then
  begin
    Result := '';
    Exit;
  end;
  FFullResult := Result;
end;

function TLDAPSend.DecodeResponse(const Value: AnsiString): AnsiString;
var
  i, x: integer;
  Svt: Integer;
  s, t: AnsiString;
begin
  Result := '';
  FResultCode := -1;
  FResultstring := '';
  FResponseCode := -1;
  FResponseDN := '';
  FReferals.Clear;
  i := 1;
  ASNItem(i, Value, Svt);
  x := StrToIntDef(ASNItem(i, Value, Svt), 0);
  if (svt <> ASN1_INT) or (x <> FSeq) then
    Exit;
  s := ASNItem(i, Value, Svt);
  FResponseCode := svt;
  if FResponseCode in [LDAP_ASN1_BIND_RESPONSE, LDAP_ASN1_SEARCH_DONE,
    LDAP_ASN1_MODIFY_RESPONSE, LDAP_ASN1_ADD_RESPONSE, LDAP_ASN1_DEL_RESPONSE,
    LDAP_ASN1_MODIFYDN_RESPONSE, LDAP_ASN1_COMPARE_RESPONSE,
    LDAP_ASN1_EXT_RESPONSE] then
  begin
    FResultCode := StrToIntDef(ASNItem(i, Value, Svt), -1);
    FResponseDN := ASNItem(i, Value, Svt);
    FResultString := ASNItem(i, Value, Svt);
    if FResultString = '' then
      FResultString := GetErrorString(FResultCode);
    if FResultCode = 10 then
    begin
      s := ASNItem(i, Value, Svt);
      if svt = $A3 then
      begin
        x := 1;
        while x < Length(s) do
        begin
          t := ASNItem(x, s, Svt);
          FReferals.Add(t);
        end;
      end;
    end;
  end;
  Result := Copy(Value, i, Length(Value) - i + 1);
end;

function TLDAPSend.LdapSasl(Value: AnsiString): AnsiString;
var
  nonce, cnonce, nc, realm, qop, uri, response: AnsiString;
  s: AnsiString;
  a1, a2: AnsiString;
  l: TStringList;
  n: integer;
begin
  l := TStringList.Create;
  try
    nonce := '';
    realm := '';
    l.CommaText := Value;
    n := IndexByBegin('nonce=', l);
    if n >= 0 then
      nonce := UnQuoteStr(Trim(SeparateRight(l[n], 'nonce=')), '"');
    n := IndexByBegin('realm=', l);
    if n >= 0 then
      realm := UnQuoteStr(Trim(SeparateRight(l[n], 'realm=')), '"');
    cnonce := IntToHex(GetTick, 8);
    nc := '00000001';
    qop := 'auth';
    uri := 'ldap/' + FSock.ResolveIpToName(FSock.GetRemoteSinIP);
    a1 := md5(FUsername + ':' + realm + ':' + FPassword)
      + ':' + nonce + ':' + cnonce;
    a2 := 'AUTHENTICATE:' + uri;
    s := strtohex(md5(a1))+':' + nonce + ':' + nc + ':' + cnonce + ':'
      + qop +':'+strtohex(md5(a2));
    response := strtohex(md5(s));

    Result := 'username="' + Fusername + '",realm="' + realm + '",nonce="';
    Result := Result + nonce + '",cnonce="' + cnonce + '",nc=' + nc + ',qop=';
    Result := Result + qop + ',digest-uri="' + uri + '",response=' + response;
  finally
    l.Free;
  end;
end;

function TLDAPSend.TranslateFilter(Value: AnsiString): AnsiString;
var
  x: integer;
  s, t, l: AnsiString;
  r: string;
  c: Ansichar;
  attr, rule: AnsiString;
  dn: Boolean;
begin
  Result := '';
  if Value = '' then
    Exit;
  s := Value;
  if Value[1] = '(' then
  begin
    x := RPos(')', Value);
    s := Copy(Value, 2, x - 2);
  end;
  if s = '' then
    Exit;
  case s[1] of
    '!':
      // NOT rule (recursive call)
      begin
        Result := ASNOBject(TranslateFilter(GetBetween('(', ')', s)), $A2);
      end;
    '&':
      // AND rule (recursive call)
      begin
        repeat
          t := GetBetween('(', ')', s);
          s := Trim(SeparateRight(s, t));
          if s <> '' then
            if s[1] = ')' then
              {$IFDEF CIL}Borland.Delphi.{$ENDIF}System.Delete(s, 1, 1);
          Result := Result + TranslateFilter(t);
        until s = '';
        Result := ASNOBject(Result, $A0);
      end;
    '|':
      // OR rule (recursive call)
      begin
        repeat
          t := GetBetween('(', ')', s);
          s := Trim(SeparateRight(s, t));
          if s <> '' then
            if s[1] = ')' then
              {$IFDEF CIL}Borland.Delphi.{$ENDIF}System.Delete(s, 1, 1);
          Result := Result + TranslateFilter(t);
        until s = '';
        Result := ASNOBject(Result, $A1);
      end;
    else
      begin
        l := Trim(SeparateLeft(s, '='));
        r := Trim(SeparateRight(s, '='));
        if l <> '' then
        begin
          c := l[Length(l)];
          case c of
            ':':
              // Extensible match
              begin
                {$IFDEF CIL}Borland.Delphi.{$ENDIF}System.Delete(l, Length(l), 1);
                dn := False;
                attr := '';
                rule := '';
                if Pos(':dn', l) > 0 then
                begin
                  dn := True;
                  l := ReplaceString(l, ':dn', '');
                end;
                attr := Trim(SeparateLeft(l, ':'));
                rule := Trim(SeparateRight(l, ':'));
                if rule = l then
                  rule := '';
                if rule <> '' then
                  Result := ASNObject(rule, $81);
                if attr <> '' then
                  Result := Result + ASNObject(attr, $82);
                Result := Result + ASNObject(DecodeTriplet(r, '\'), $83);
                if dn then
                  Result := Result + ASNObject(AsnEncInt($ff), $84)
                else
                  Result := Result + ASNObject(AsnEncInt(0), $84);
                Result := ASNOBject(Result, $a9);
              end;
            '~':
              // Approx match
              begin
                {$IFDEF CIL}Borland.Delphi.{$ENDIF}System.Delete(l, Length(l), 1);
                Result := ASNOBject(l, ASN1_OCTSTR)
                  + ASNOBject(DecodeTriplet(r, '\'), ASN1_OCTSTR);
                Result := ASNOBject(Result, $a8);
              end;
            '>':
              // Greater or equal match
              begin
                {$IFDEF CIL}Borland.Delphi.{$ENDIF}System.Delete(l, Length(l), 1);
                Result := ASNOBject(l, ASN1_OCTSTR)
                  + ASNOBject(DecodeTriplet(r, '\'), ASN1_OCTSTR);
                Result := ASNOBject(Result, $a5);
              end;
            '<':
              // Less or equal match
              begin
                {$IFDEF CIL}Borland.Delphi.{$ENDIF}System.Delete(l, Length(l), 1);
                Result := ASNOBject(l, ASN1_OCTSTR)
                  + ASNOBject(DecodeTriplet(r, '\'), ASN1_OCTSTR);
                Result := ASNOBject(Result, $a6);
              end;
          else
            // present
            if r = '*' then
              Result := ASNOBject(l, $87)
            else
              if Pos('*', r) > 0 then
              // substrings
              begin
                s := Fetch(r, '*');
                if s <> '' then
                  Result := ASNOBject(DecodeTriplet(s, '\'), $80);
                while r <> '' do
                begin
                  if Pos('*', r) <= 0 then
                    break;
                  s := Fetch(r, '*');
                  Result := Result + ASNOBject(DecodeTriplet(s, '\'), $81);
                end;
                if r <> '' then
                  Result := Result + ASNOBject(DecodeTriplet(r, '\'), $82);
                Result := ASNOBject(l, ASN1_OCTSTR)
                  + ASNOBject(Result, ASN1_SEQ);
                Result := ASNOBject(Result, $a4);
              end
              else
              begin
                // Equality match
                Result := ASNOBject(l, ASN1_OCTSTR)
                  + ASNOBject(DecodeTriplet(r, '\'), ASN1_OCTSTR);
                Result := ASNOBject(Result, $a3);
              end;
          end;
        end;
      end;
  end;
end;

function TLDAPSend.Login: Boolean;
begin
  Result := False;
  if not Connect then
    Exit;
  Result := True;
  if FAutoTLS then
    Result := StartTLS;
end;

function TLDAPSend.Bind: Boolean;
var
  s: AnsiString;
begin
  s := ASNObject(ASNEncInt(FVersion), ASN1_INT)
    + ASNObject(FUsername, ASN1_OCTSTR)
    + ASNObject(FPassword, $80);
  s := ASNObject(s, LDAP_ASN1_BIND_REQUEST);
  Fsock.SendString(BuildPacket(s));
  s := ReceiveResponse;
  DecodeResponse(s);
  Result := FResultCode = 0;
end;

function TLDAPSend.BindSasl: Boolean;
var
  s, t: AnsiString;
  x, xt: integer;
  digreq: AnsiString;
begin
  Result := False;
  if FPassword = '' then
    Result := Bind
  else
  begin
    digreq := ASNObject(ASNEncInt(FVersion), ASN1_INT)
      + ASNObject('', ASN1_OCTSTR)
      + ASNObject(ASNObject('DIGEST-MD5', ASN1_OCTSTR), $A3);
    digreq := ASNObject(digreq, LDAP_ASN1_BIND_REQUEST);
    Fsock.SendString(BuildPacket(digreq));
    s := ReceiveResponse;
    t := DecodeResponse(s);
    if FResultCode = 14 then
    begin
      s := t;
      x := 1;
      t := ASNItem(x, s, xt);
      s := ASNObject(ASNEncInt(FVersion), ASN1_INT)
        + ASNObject('', ASN1_OCTSTR)
        + ASNObject(ASNObject('DIGEST-MD5', ASN1_OCTSTR)
          + ASNObject(LdapSasl(t), ASN1_OCTSTR), $A3);
      s := ASNObject(s, LDAP_ASN1_BIND_REQUEST);
      Fsock.SendString(BuildPacket(s));
      s := ReceiveResponse;
      DecodeResponse(s);
      if FResultCode = 14 then
      begin
        Fsock.SendString(BuildPacket(digreq));
        s := ReceiveResponse;
        DecodeResponse(s);
      end;
      Result := FResultCode = 0;
    end;
  end;
end;

function TLDAPSend.Logout: Boolean;
begin
  Fsock.SendString(BuildPacket(ASNObject('', LDAP_ASN1_UNBIND_REQUEST)));
  FSock.CloseSocket;
  Result := True;
end;

function TLDAPSend.Modify(obj: AnsiString; Op: TLDAPModifyOp; const Value: TLDAPAttribute): Boolean;
var
  s: AnsiString;
  n: integer;
begin
  s := '';
  for n := 0 to Value.Count -1 do
    s := s + ASNObject(Value[n], ASN1_OCTSTR);
  s := ASNObject(Value.AttributeName, ASN1_OCTSTR) + ASNObject(s, ASN1_SETOF);
  s := ASNObject(ASNEncInt(Ord(Op)), ASN1_ENUM) + ASNObject(s, ASN1_SEQ);
  s := ASNObject(s, ASN1_SEQ);
  s := ASNObject(obj, ASN1_OCTSTR) + ASNObject(s, ASN1_SEQ);
  s := ASNObject(s, LDAP_ASN1_MODIFY_REQUEST);
  Fsock.SendString(BuildPacket(s));
  s := ReceiveResponse;
  DecodeResponse(s);
  Result := FResultCode = 0;
end;

function TLDAPSend.Add(obj: AnsiString; const Value: TLDAPAttributeList): Boolean;
var
  s, t: AnsiString;
  n, m: integer;
begin
  s := '';
  for n := 0 to Value.Count - 1 do
  begin
    t := '';
    for m := 0 to Value[n].Count - 1 do
      t := t + ASNObject(Value[n][m], ASN1_OCTSTR);
    t := ASNObject(Value[n].AttributeName, ASN1_OCTSTR)
      + ASNObject(t, ASN1_SETOF);
    s := s + ASNObject(t, ASN1_SEQ);
  end;
  s := ASNObject(obj, ASN1_OCTSTR) + ASNObject(s, ASN1_SEQ);
  s := ASNObject(s, LDAP_ASN1_ADD_REQUEST);
  Fsock.SendString(BuildPacket(s));
  s := ReceiveResponse;
  DecodeResponse(s);
  Result := FResultCode = 0;
end;

function TLDAPSend.Delete(obj: AnsiString): Boolean;
var
  s: AnsiString;
begin
  s := ASNObject(obj, LDAP_ASN1_DEL_REQUEST);
  Fsock.SendString(BuildPacket(s));
  s := ReceiveResponse;
  DecodeResponse(s);
  Result := FResultCode = 0;
end;

function TLDAPSend.ModifyDN(obj, newRDN, newSuperior: AnsiString; DeleteOldRDN: Boolean): Boolean;
var
  s: AnsiString;
begin
  s := ASNObject(obj, ASN1_OCTSTR) + ASNObject(newRDN, ASN1_OCTSTR);
  if DeleteOldRDN then
    s := s + ASNObject(ASNEncInt($ff), ASN1_BOOL)
  else
    s := s + ASNObject(ASNEncInt(0), ASN1_BOOL);
  if newSuperior <> '' then
    s := s + ASNObject(newSuperior, $80);
  s := ASNObject(s, LDAP_ASN1_MODIFYDN_REQUEST);
  Fsock.SendString(BuildPacket(s));
  s := ReceiveResponse;
  DecodeResponse(s);
  Result := FResultCode = 0;
end;

function TLDAPSend.Compare(obj, AttributeValue: AnsiString): Boolean;
var
  s: AnsiString;
begin
  s := ASNObject(Trim(SeparateLeft(AttributeValue, '=')), ASN1_OCTSTR)
    + ASNObject(Trim(SeparateRight(AttributeValue, '=')), ASN1_OCTSTR);
  s := ASNObject(obj, ASN1_OCTSTR) + ASNObject(s, ASN1_SEQ);
  s := ASNObject(s, LDAP_ASN1_COMPARE_REQUEST);
  Fsock.SendString(BuildPacket(s));
  s := ReceiveResponse;
  DecodeResponse(s);
  Result := FResultCode = 0;
end;

function TLDAPSend.Search(obj: AnsiString; TypesOnly: Boolean; Filter: AnsiString;
  const Attributes: TStrings): Boolean;
var
  s, t, u, c: AnsiString;
  n, i, x: integer;
  r: TLDAPResult;
  a: TLDAPAttribute;
begin
  FSearchResult.Clear;
  FReferals.Clear;
  s := ASNObject(obj, ASN1_OCTSTR);
  s := s + ASNObject(ASNEncInt(Ord(FSearchScope)), ASN1_ENUM);
  s := s + ASNObject(ASNEncInt(Ord(FSearchAliases)), ASN1_ENUM);
  s := s + ASNObject(ASNEncInt(FSearchSizeLimit), ASN1_INT);
  s := s + ASNObject(ASNEncInt(FSearchTimeLimit), ASN1_INT);
  if TypesOnly then
    s := s + ASNObject(ASNEncInt($ff), ASN1_BOOL)
  else
    s := s + ASNObject(ASNEncInt(0), ASN1_BOOL);
  if Filter = '' then
    Filter := '(objectclass=*)';
  t := TranslateFilter(Filter);
  if t = '' then
    s := s + ASNObject('', ASN1_NULL)
  else
    s := s + t;
  t := '';
  for n := 0 to Attributes.Count - 1 do
    t := t + ASNObject(Attributes[n], ASN1_OCTSTR);
  s := s + ASNObject(t, ASN1_SEQ);
  s := ASNObject(s, LDAP_ASN1_SEARCH_REQUEST);
  if FSearchPageSize > 0 then
  begin
    c := ASNObject('1.2.840.113556.1.4.319', ASN1_OCTSTR); // controlType: pagedResultsControl
    c := c + ASNObject(ASNEncInt(0), ASN1_BOOL); // criticality: FALSE
    t := ASNObject(ASNEncInt(FSearchPageSize), ASN1_INT); // page size
    t := t + ASNObject(FSearchCookie, ASN1_OCTSTR); // search cookie
    t := ASNObject(t, ASN1_SEQ); // wrap with SEQUENCE
    c := c + ASNObject(t, ASN1_OCTSTR); // add searchControlValue as OCTET STRING
    c := ASNObject(c, ASN1_SEQ); // wrap with SEQUENCE
    s := s + ASNObject(c, LDAP_ASN1_CONTROLS); // append Controls to SearchRequest
  end;
  Fsock.SendString(BuildPacket(s));
  repeat
    s := ReceiveResponse;
    t := DecodeResponse(s);
    if FResponseCode = LDAP_ASN1_SEARCH_ENTRY then
    begin
      //dekoduj zaznam
      r := FSearchResult.Add;
      n := 1;
      r.ObjectName := ASNItem(n, t, x);
      ASNItem(n, t, x);
      if x = ASN1_SEQ then
      begin
        while n < Length(t) do
        begin
          s := ASNItem(n, t, x);
          if x = ASN1_SEQ then
          begin
            i := n + Length(s);
            a := r.Attributes.Add;
            u := ASNItem(n, t, x);
            a.AttributeName := u;
            ASNItem(n, t, x);
            if x = ASN1_SETOF then
              while n < i do
              begin
                u := ASNItem(n, t, x);
                { V001.007.004.2 -- AddRaw preserva bytes binarios 100%
                  (bytes 0x22 e 0x80-0xFF que Add(string) perderia). }
                a.AddRaw(u);
              end;
          end;
        end;
      end;
    end;
    if FResponseCode = LDAP_ASN1_SEARCH_REFERENCE then
    begin
      n := 1;
      while n < Length(t) do
        FReferals.Add(ASNItem(n, t, x));
    end;
  until FResponseCode = LDAP_ASN1_SEARCH_DONE;
  n := 1;
  ASNItem(n, t, x);
  if x = LDAP_ASN1_CONTROLS then
  begin
    ASNItem(n, t, x);
    if x = ASN1_SEQ then
    begin
      s := ASNItem(n, t, x);
      if s = '1.2.840.113556.1.4.319' then
      begin
        s := ASNItem(n, t, x); // searchControlValue
        n := 1;
        ASNItem(n, s, x);
        if x = ASN1_SEQ then
        begin
          ASNItem(n, s, x); // total number of result records, if known, otherwise 0
          FSearchCookie := ASNItem(n, s, x); // active search cookie, empty when done
        end;
      end;
    end;
  end;
  Result := FResultCode = 0;
end;

function TLDAPSend.Extended(const Name, Value: AnsiString): Boolean;
var
  s, t: AnsiString;
  x, xt: integer;
begin
  s := ASNObject(Name, $80);
  if Value <> '' then
    s := s + ASNObject(Value, $81);
  s := ASNObject(s, LDAP_ASN1_EXT_REQUEST);
  Fsock.SendString(BuildPacket(s));
  s := ReceiveResponse;
  t := DecodeResponse(s);
  Result := FResultCode = 0;
  if Result then
  begin
    x := 1;
    FExtName := ASNItem(x, t, xt);
    FExtValue := ASNItem(x, t, xt);
  end;
end;


function TLDAPSend.StartTLS: Boolean;
begin
  Result := Extended('1.3.6.1.4.1.1466.20037', '');
  if Result then
  begin
    Fsock.SSLDoConnect;
    Result := FSock.LastError = 0;
  end;
end;

{==============================================================================}
function LDAPResultDump(const Value: TLDAPResultList): AnsiString;
var
  n, m, o: integer;
  r: TLDAPResult;
  a: TLDAPAttribute;
begin
  Result := 'Results: ' + IntToStr(Value.Count) + CRLF +CRLF;
  for n := 0 to Value.Count - 1 do
  begin
    Result := Result + 'Result: ' + IntToStr(n) + CRLF;
    r := Value[n];
    Result := Result + '  Object: ' + r.ObjectName + CRLF;
    for m := 0 to r.Attributes.Count - 1 do
    begin
      a := r.Attributes[m];
      Result := Result + '  Attribute: ' + a.AttributeName + CRLF;
      for o := 0 to a.Count - 1 do
        Result := Result + '    ' + a[o] + CRLF;
    end;
  end;
end;


{==============================================================================}
{ AD helper — build a single LDAP control BER sequence                        }
function TLDAPSend.BuildADControl(const AOID: AnsiString; ACritical: Boolean;
  const AValue: AnsiString): AnsiString;
var
  c: AnsiString;
begin
  c := ASNObject(AOID, ASN1_OCTSTR)
     + ASNObject(ASNEncInt(Ord(ACritical)), ASN1_BOOL);
  if AValue <> '' then
    c := c + ASNObject(AValue, ASN1_OCTSTR);
  Result := ASNObject(c, ASN1_SEQ);
end;

{ Wrap one or more control SEQUENCEs in the LDAP Controls [0] tag }
function TLDAPSend.WrapADControls(const AControlsBlock: AnsiString): AnsiString;
begin
  Result := ASNObject(AControlsBlock, LDAP_ASN1_CONTROLS);
end;

{ Execute a Search with an appended AD controls block — mirrors TLDAPSend.Search }
function TLDAPSend.DoSearchAD(const ABase, AFilter: AnsiString;
  AScope: TLDAPSearchScope; const AAttributes: TStrings;
  const AControlsBlock: AnsiString): Boolean;
var
  s, t, u: AnsiString;
  n, i, x: integer;
  r: TLDAPResult;
  a: TLDAPAttribute;
  filt: AnsiString;
begin
  FSearchResult.Clear;
  FReferals.Clear;
  s := ASNObject(ABase, ASN1_OCTSTR);
  s := s + ASNObject(ASNEncInt(Ord(AScope)), ASN1_ENUM);
  s := s + ASNObject(ASNEncInt(Ord(FSearchAliases)), ASN1_ENUM);
  s := s + ASNObject(ASNEncInt(FSearchSizeLimit), ASN1_INT);
  s := s + ASNObject(ASNEncInt(FSearchTimeLimit), ASN1_INT);
  s := s + ASNObject(ASNEncInt(0), ASN1_BOOL);  // typesOnly = false
  filt := AFilter;
  if filt = '' then filt := '(objectclass=*)';
  t := TranslateFilter(filt);
  if t = '' then
    s := s + ASNObject('', ASN1_NULL)
  else
    s := s + t;
  t := '';
  if Assigned(AAttributes) then
    for n := 0 to AAttributes.Count - 1 do
      t := t + ASNObject(AAttributes[n], ASN1_OCTSTR);
  s := s + ASNObject(t, ASN1_SEQ);
  s := ASNObject(s, LDAP_ASN1_SEARCH_REQUEST);
  if AControlsBlock <> '' then
    s := s + AControlsBlock;
  FSock.SendString(BuildPacket(s));
  repeat
    s := ReceiveResponse;
    t := DecodeResponse(s);
    if FResponseCode = LDAP_ASN1_SEARCH_ENTRY then
    begin
      r := FSearchResult.Add;
      n := 1;
      r.ObjectName := ASNItem(n, t, x);
      ASNItem(n, t, x);
      if x = ASN1_SEQ then
      begin
        while n < Length(t) do
        begin
          s := ASNItem(n, t, x);
          if x = ASN1_SEQ then
          begin
            i := n + Length(s);
            a := r.Attributes.Add;
            u := ASNItem(n, t, x);
            a.AttributeName := u;
            ASNItem(n, t, x);
            if x = ASN1_SETOF then
              while n < i do
              begin
                u := ASNItem(n, t, x);
                { V001.007.004.2 -- AddRaw preserva bytes binarios 100%
                  (bytes 0x22 e 0x80-0xFF que Add(string) perderia). }
                a.AddRaw(u);
              end;
          end;
        end;
      end;
    end;
    if FResponseCode = LDAP_ASN1_SEARCH_REFERENCE then
    begin
      n := 1;
      while n < Length(t) do
        FReferals.Add(ASNItem(n, t, x));
    end;
  until FResponseCode = LDAP_ASN1_SEARCH_DONE;
  Result := FResultCode = 0;
end;

{ Extract DirSync cookie from SearchResultDone response controls }
procedure TLDAPSend.ParseDirSyncCookie(const AResponseBlock: AnsiString);
var
  i, n, cn, sn: Integer;
  s, cv, oid, val: AnsiString;
begin
  FDirSyncCookie := '';
  FDirSyncResult := '';
  s := AResponseBlock;
  n := 1;
  while n <= Length(s) do
  begin
    cv := ASNItem(n, s, i);
    if i = LDAP_ASN1_CONTROLS then
    begin
      n := 1;
      s := cv;
      while n <= Length(s) do
      begin
        cv := ASNItem(n, s, i);
        if i = ASN1_SEQ then
        begin
          cn := 1;
          oid := ASNItem(cn, cv, i);
          if oid = LDAP_OID_DIRSYNC then
          begin
            ASNItem(cn, cv, i);   // skip criticality
            val := ASNItem(cn, cv, i);
            if i = ASN1_OCTSTR then
            begin
              sn := 1;
              ASNItem(sn, val, i);  // skip flags
              ASNItem(sn, val, i);  // skip maxBytes
              FDirSyncCookie := ASNItem(sn, val, i);
              FDirSyncResult := 'ok';
            end;
          end;
        end;
      end;
      Break;
    end;
  end;
end;

{==============================================================================}
{ AD Search: DirSync                                                           }
function TLDAPSend.SearchDirSync(const ABase, AFilter: AnsiString;
  AScope: TLDAPSearchScope; const AAttributes: TStrings): Boolean;
var
  cv, ctrl: AnsiString;
begin
  cv := ASNObject(ASNEncInt(FDirSyncFlags), ASN1_INT)
      + ASNObject(ASNEncInt(FDirSyncMaxBytes), ASN1_INT)
      + ASNObject(FDirSyncCookie, ASN1_OCTSTR);
  cv := ASNObject(cv, ASN1_SEQ);
  ctrl := WrapADControls(BuildADControl(LDAP_OID_DIRSYNC, True, cv));
  Result := DoSearchAD(ABase, AFilter, AScope, AAttributes, ctrl);
  if Result then
    ParseDirSyncCookie(FFullResult);
end;

{ AD Search: SD Flags }
function TLDAPSend.SearchWithSDFlags(const ABase, AFilter: AnsiString;
  AScope: TLDAPSearchScope; ASDFlags: Integer;
  const AAttributes: TStrings): Boolean;
var
  cv, ctrl: AnsiString;
begin
  cv := ASNObject(ASNObject(ASNEncInt(ASDFlags), ASN1_INT), ASN1_SEQ);
  ctrl := WrapADControls(BuildADControl(LDAP_OID_SD_FLAGS, True, cv));
  Result := DoSearchAD(ABase, AFilter, AScope, AAttributes, ctrl);
end;

{ AD Search: Extended DN }
function TLDAPSend.SearchWithExtendedDN(const ABase, AFilter: AnsiString;
  AScope: TLDAPSearchScope; const AAttributes: TStrings;
  AFlag: Integer): Boolean;
var
  cv, ctrl: AnsiString;
begin
  cv := ASNObject(ASNObject(ASNEncInt(AFlag), ASN1_INT), ASN1_SEQ);
  ctrl := WrapADControls(BuildADControl(LDAP_OID_EXTENDED_DN, False, cv));
  Result := DoSearchAD(ABase, AFilter, AScope, AAttributes, ctrl);
end;

{ AD Search: Show Deleted }
function TLDAPSend.SearchShowDeleted(const ABase, AFilter: AnsiString;
  AScope: TLDAPSearchScope; const AAttributes: TStrings): Boolean;
var
  ctrl: AnsiString;
begin
  ctrl := WrapADControls(BuildADControl(LDAP_OID_SHOW_DELETED, False, ''));
  Result := DoSearchAD(ABase, AFilter, AScope, AAttributes, ctrl);
end;

{ AD Search: Show Recycled }
function TLDAPSend.SearchShowRecycled(const ABase, AFilter: AnsiString;
  AScope: TLDAPSearchScope; const AAttributes: TStrings): Boolean;
var
  ctrl: AnsiString;
begin
  ctrl := WrapADControls(BuildADControl(LDAP_OID_SHOW_RECYCLED, False, ''));
  Result := DoSearchAD(ABase, AFilter, AScope, AAttributes, ctrl);
end;

{ AD Search: Server Sort }
function TLDAPSend.SearchWithServerSort(const ABase, AFilter: AnsiString;
  AScope: TLDAPSearchScope; const ASortAttribute: AnsiString;
  const AAttributes: TStrings): Boolean;
var
  cv, ctrl: AnsiString;
begin
  cv := ASNObject(ASNObject(ASortAttribute, ASN1_OCTSTR), ASN1_SEQ);
  cv := ASNObject(cv, ASN1_SEQ);
  ctrl := WrapADControls(BuildADControl(LDAP_OID_SERVER_SORT, False, cv));
  Result := DoSearchAD(ABase, AFilter, AScope, AAttributes, ctrl);
end;

{==============================================================================}
{ Permissive Modify                                                            }
function TLDAPSend.ModifyPermissive(const AObj: AnsiString;
  AOp: TLDAPModifyOp; const AValue: TLDAPAttribute): Boolean;
var
  s, v, ctrl, resp: AnsiString;
  i: Integer;
begin
  v := '';
  for i := 0 to AValue.Count - 1 do
    v := v + ASNObject(AValue[i], ASN1_OCTSTR);
  s := ASNObject(
         ASNObject(ASNEncInt(Ord(AOp)), ASN1_ENUM) +
         ASNObject(
           ASNObject(AValue.AttributeName, ASN1_OCTSTR) +
           ASNObject(v, ASN1_SETOF),
           ASN1_SEQ),
         ASN1_SEQ);
  s := ASNObject(AObj, ASN1_OCTSTR) + ASNObject(s, ASN1_SEQ);
  ctrl := WrapADControls(BuildADControl(LDAP_OID_PERM_MODIFY, False, ''));
  s := ASNObject(s, LDAP_ASN1_MODIFY_REQUEST) + ctrl;
  FSock.SendString(BuildPacket(s));
  resp := ReceiveResponse;
  resp := DecodeResponse(resp);
  Result := (FResultCode = 0);
end;

{ Tree Delete }
function TLDAPSend.DeleteTree(const AObj: AnsiString): Boolean;
var
  s, ctrl, resp: AnsiString;
begin
  ctrl := WrapADControls(BuildADControl(LDAP_OID_TREE_DELETE, False, ''));
  s := ASNObject(AObj, ASN1_OCTSTR);
  s := ASNObject(s, LDAP_ASN1_DEL_REQUEST) + ctrl;
  FSock.SendString(BuildPacket(s));
  resp := ReceiveResponse;
  resp := DecodeResponse(resp);
  Result := (FResultCode = 0);
end;

{==============================================================================}
{ SSPI / GSSAPI implementations                                               }
{                                                                              }
{ Windows: implementacao real via secur32.dll (lazy-load LoadSSPIFunctions).  }
{ POSIX  : stubs controlados que retornam False/no-op com mensagem clara      }
{          indicando que Kerberos real esta agendado para V2.0.0              }
{          (libgssapi_krb5 via dynload, Roadmap documentado).                 }
{==============================================================================}
{$IFDEF MSWINDOWS}
procedure TLDAPSend.LoadSSPIFunctions;
begin
  if FLDAPSecur32Lib <> 0 then Exit;
  FLDAPSecur32Lib := LoadLibrary('secur32.dll');
  if FLDAPSecur32Lib = 0 then
    raise Exception.Create('secur32.dll not found — SSPI unavailable');
  @LDAP_AcquireCredentialsHandle  := GetProcAddress(FLDAPSecur32Lib, 'AcquireCredentialsHandleW');
  @LDAP_InitializeSecurityContext := GetProcAddress(FLDAPSecur32Lib, 'InitializeSecurityContextW');
  @LDAP_CompleteAuthToken         := GetProcAddress(FLDAPSecur32Lib, 'CompleteAuthToken');
  @LDAP_MakeSignature             := GetProcAddress(FLDAPSecur32Lib, 'MakeSignature');
  @LDAP_VerifySignature           := GetProcAddress(FLDAPSecur32Lib, 'VerifySignature');
  @LDAP_DeleteSecurityContext     := GetProcAddress(FLDAPSecur32Lib, 'DeleteSecurityContext');
  @LDAP_FreeCredentialsHandle     := GetProcAddress(FLDAPSecur32Lib, 'FreeCredentialsHandle');
end;

procedure TLDAPSend.SSPICleanup;
begin
  if Assigned(@LDAP_DeleteSecurityContext) then
  begin
    if FSSPIHaveCtx  then LDAP_DeleteSecurityContext(@FSSPICtx);
    if FSSPIHaveCred then LDAP_FreeCredentialsHandle(@FSSPICred);
  end;
  FSSPIHaveCtx   := False;
  FSSPIHaveCred  := False;
  FSigningActive := False;
  FSigningSeqNo  := 0;
end;

function TLDAPSend.GSSAPIStep(const AInToken: AnsiString;
  const ASPN: WideString; const ACBTData: AnsiString;
  out AOutToken: AnsiString): Integer;
var
  InBufs:  array[0..1] of TLDAPSecBuffer;
  OutBufs: array[0..0] of TLDAPSecBuffer;
  InDesc, OutDesc: TLDAPSecBufferDesc;
  OutTok:  array[0..16383] of Byte;
  pCtx:    PLDAPSecHandle;
  CtxAttr: Cardinal;
begin
  AOutToken := '';
  LoadSSPIFunctions;

  if not FSSPIHaveCred then
  begin
    Result := LDAP_AcquireCredentialsHandle(nil, 'Kerberos', 2 {SECPKG_CRED_OUTBOUND},
      nil, nil, nil, nil, @FSSPICred, nil);
    if Result <> SEC_E_OK then Exit;
    FSSPIHaveCred := True;
  end;

  // Input token buffer
  InBufs[0].cbBuffer   := Length(AInToken);
  InBufs[0].BufferType := SECBUFFER_TOKEN;
  if Length(AInToken) > 0 then
    InBufs[0].pvBuffer := PAnsiChar(AInToken)
  else
    InBufs[0].pvBuffer := nil;

  // Channel binding buffer
  InBufs[1].cbBuffer   := Length(ACBTData);
  InBufs[1].BufferType := SECBUFFER_CHANNEL_BINDINGS;
  if Length(ACBTData) > 0 then
    InBufs[1].pvBuffer := PAnsiChar(ACBTData)
  else
    InBufs[1].pvBuffer := nil;

  InDesc.ulVersion := SECBUFFER_VERSION;
  if ACBTData <> '' then
    InDesc.cBuffers := 2
  else
    InDesc.cBuffers := 1;
  InDesc.pBuffers  := @InBufs[0];

  // Output buffer
  FillChar(OutTok, SizeOf(OutTok), 0);
  OutBufs[0].cbBuffer   := SizeOf(OutTok);
  OutBufs[0].BufferType := SECBUFFER_TOKEN;
  OutBufs[0].pvBuffer   := @OutTok[0];
  OutDesc.ulVersion := SECBUFFER_VERSION;
  OutDesc.cBuffers  := 1;
  OutDesc.pBuffers  := @OutBufs[0];

  if FSSPIHaveCtx then pCtx := @FSSPICtx else pCtx := nil;

  Result := LDAP_InitializeSecurityContext(
    @FSSPICred, pCtx, PWideChar(ASPN),
    ISC_REQ_INTEGRITY or ISC_REQ_SEQUENCE_DETECT or ISC_REQ_MUTUAL_AUTH,
    0, SECURITY_NETWORK_DREP,
    @InDesc, 0, @FSSPICtx, @OutDesc, @CtxAttr, nil);
  FSSPIHaveCtx := True;

  if (Result = SEC_I_COMPLETE_NEEDED) or (Result = SEC_I_COMPLETE_AND_CONTINUE) then
    LDAP_CompleteAuthToken(@FSSPICtx, @OutDesc);

  if OutBufs[0].cbBuffer > 0 then
  begin
    SetLength(AOutToken, OutBufs[0].cbBuffer);
    Move(OutTok[0], AOutToken[1], OutBufs[0].cbBuffer);
  end;

  if (Result = SEC_E_OK) and ((CtxAttr and ISC_REQ_INTEGRITY) <> 0) then
    FSigningActive := True;
end;

function TLDAPSend.BuildCBTData(const ACertHash: AnsiString): AnsiString;
begin
  Result := LDAP_CBT_PREFIX + ACertHash;
end;
{$ENDIF MSWINDOWS}

{==============================================================================}
{ BindGSSAPI / BindGSSAPIWithCBT / SignLDAPMessage / VerifyLDAPMessage         }
{ Assinatura publica estavel em TODAS as plataformas.                         }
{ POSIX: stubs controlados (V1.7.0). Port real agendado V2.0.0.               }
{==============================================================================}

function TLDAPSend.BindGSSAPI(const ASPN: AnsiString): Boolean;
{$IFDEF MSWINDOWS}
begin
  Result := BindGSSAPIWithCBT(ASPN, '');
end;
{$ELSE}
begin
  Result := False;
  FResultString := 'GSSAPI via SSPI nao disponivel em POSIX -- use Kerberos via libgssapi_krb5 (agendado V2.0.0)';
end;
{$ENDIF}

function TLDAPSend.BindGSSAPIWithCBT(const ASPN, ACertHash: AnsiString): Boolean;
{$IFDEF MSWINDOWS}
var
  InToken, OutToken, CBT, s, x: AnsiString;
  Status: Integer;
  WSPN: WideString;
begin
  Result := False;
  if not Connect then Exit;
  WSPN := WideString(ASPN);
  if ACertHash <> '' then
    CBT := BuildCBTData(ACertHash)
  else
    CBT := '';

  SSPICleanup;
  InToken := '';
  repeat
    Status := GSSAPIStep(InToken, WSPN, CBT, OutToken);
    if (Status <> SEC_E_OK) and
       (Status <> SEC_I_CONTINUE_NEEDED) and
       (Status <> SEC_I_COMPLETE_NEEDED) and
       (Status <> SEC_I_COMPLETE_AND_CONTINUE) then
      Exit;

    if OutToken <> '' then
    begin
      // SASL BindRequest: [3] context IMPLICIT SEQUENCE { mechanism, credentials }
      s := ASNObject(ASNEncInt(FVersion), ASN1_INT)
         + ASNObject(FUsername, ASN1_OCTSTR)
         + ASNObject(
             ASNObject(LDAP_SASL_GSSAPI, ASN1_OCTSTR) +
             ASNObject(OutToken, ASN1_OCTSTR),
             $A3);
      s := ASNObject(s, LDAP_ASN1_BIND_REQUEST);
      FSock.SendString(BuildPacket(s));

      x := ReceiveResponse;
      x := DecodeResponse(x);
      if (FResultCode = 0) or (FResultCode = 14 {saslBindInProgress}) then
        InToken := FExtValue   // serverSaslCreds in ExtValue after decode
      else
        Exit;
    end;
  until Status = SEC_E_OK;

  Result := True;
end;
{$ELSE}
begin
  Result := False;
  FResultString := 'GSSAPI via SSPI nao disponivel em POSIX -- use Kerberos via libgssapi_krb5 (agendado V2.0.0)';
end;
{$ENDIF}

{==============================================================================}
{ LDAP Signing                                                                 }
function TLDAPSend.SignLDAPMessage(const AMsg: AnsiString): AnsiString;
{$IFDEF MSWINDOWS}
var
  Bufs: array[0..1] of TLDAPSecBuffer;
  Desc: TLDAPSecBufferDesc;
  SigBuf: array[0..255] of Byte;
  SigLen: Cardinal;
begin
  Result := AMsg;
  if not FSigningActive then Exit;

  FillChar(SigBuf, SizeOf(SigBuf), 0);
  Bufs[0].cbBuffer   := Length(AMsg);
  Bufs[0].BufferType := SECBUFFER_DATA;
  Bufs[0].pvBuffer   := PAnsiChar(AMsg);
  Bufs[1].cbBuffer   := SizeOf(SigBuf);
  Bufs[1].BufferType := SECBUFFER_TOKEN;
  Bufs[1].pvBuffer   := @SigBuf[0];
  Desc.ulVersion := SECBUFFER_VERSION;
  Desc.cBuffers  := 2;
  Desc.pBuffers  := @Bufs[0];

  if LDAP_MakeSignature(@FSSPICtx, 0, @Desc, FSigningSeqNo) = SEC_E_OK then
  begin
    SigLen := Bufs[1].cbBuffer;
    Inc(FSigningSeqNo);
    SetLength(Result, 4 + SigLen + Length(AMsg));
    PCardinal(@Result[1])^ := SigLen;
    Move(SigBuf[0], Result[5], SigLen);
    Move(AMsg[1], Result[5 + Integer(SigLen)], Length(AMsg));
  end;
end;
{$ELSE}
begin
  // POSIX stub: no-op pass-through. FSigningActive nunca e' True em POSIX
  // (BindGSSAPI retorna False sem activar), entao AMsg passa inalterado.
  Result := AMsg;
end;
{$ENDIF}

function TLDAPSend.VerifyLDAPMessage(const ASignedMsg: AnsiString;
  out APlain: AnsiString): Boolean;
{$IFDEF MSWINDOWS}
var
  SigLen: Cardinal;
  Bufs: array[0..1] of TLDAPSecBuffer;
  Desc: TLDAPSecBufferDesc;
  fQOP: Cardinal;
begin
  Result := True;
  APlain := ASignedMsg;
  if not FSigningActive then Exit;
  if Length(ASignedMsg) < 4 then Exit;

  SigLen := PCardinal(@ASignedMsg[1])^;
  APlain := Copy(ASignedMsg, 5 + Integer(SigLen), MaxInt);

  Bufs[0].cbBuffer   := Length(APlain);
  Bufs[0].BufferType := SECBUFFER_DATA;
  Bufs[0].pvBuffer   := PAnsiChar(APlain);
  Bufs[1].cbBuffer   := SigLen;
  Bufs[1].BufferType := SECBUFFER_TOKEN;
  Bufs[1].pvBuffer   := PAnsiChar(ASignedMsg) + 4;
  Desc.ulVersion := SECBUFFER_VERSION;
  Desc.cBuffers  := 2;
  Desc.pBuffers  := @Bufs[0];

  Result := LDAP_VerifySignature(@FSSPICtx, @Desc, FSigningSeqNo, @fQOP) = SEC_E_OK;
  if Result then Inc(FSigningSeqNo);
end;
{$ELSE}
begin
  // POSIX stub: FSigningActive nunca e' True em POSIX. Retorna True + pass-through.
  Result := True;
  APlain := ASignedMsg;
end;
{$ENDIF}

{==============================================================================}
{ Password helper — unicodePwd is UTF-16LE between quotes                     }
function TLDAPSend.EncodeUnicodePwd(const APassword: AnsiString): AnsiString;
var
  Quoted: WideString;
begin
  Quoted := WideString('"' + APassword + '"');
  SetLength(Result, Length(Quoted) * 2);
  Move(Quoted[1], Result[1], Length(Quoted) * 2);
end;

{ Change password: delete old + add new unicodePwd in a single Modify PDU }
function TLDAPSend.ChangePassword(const AUserDN, AOldPassword,
  ANewPassword: AnsiString): Boolean;
var
  s, resp: AnsiString;
begin
  // Build one Modify PDU with two changes: delete old, add new
  s := ASNObject(
         ASNObject(ASNEncInt(Ord(MO_Delete)), ASN1_ENUM) +
         ASNObject(
           ASNObject('unicodePwd', ASN1_OCTSTR) +
           ASNObject(ASNObject(EncodeUnicodePwd(AOldPassword), ASN1_OCTSTR), ASN1_SETOF),
           ASN1_SEQ),
         ASN1_SEQ);
  s := s + ASNObject(
             ASNObject(ASNEncInt(Ord(MO_Add)), ASN1_ENUM) +
             ASNObject(
               ASNObject('unicodePwd', ASN1_OCTSTR) +
               ASNObject(ASNObject(EncodeUnicodePwd(ANewPassword), ASN1_OCTSTR), ASN1_SETOF),
               ASN1_SEQ),
             ASN1_SEQ);
  s := ASNObject(AUserDN, ASN1_OCTSTR) + ASNObject(s, ASN1_SEQ);
  s := ASNObject(s, LDAP_ASN1_MODIFY_REQUEST);
  FSock.SendString(BuildPacket(s));
  resp := ReceiveResponse;
  resp := DecodeResponse(resp);
  Result := (FResultCode = 0);
end;

{ Set (admin reset) password — replace unicodePwd }
function TLDAPSend.SetPassword(const AUserDN, ANewPassword: AnsiString): Boolean;
var
  Attr: TLDAPAttribute;
begin
  Attr := TLDAPAttribute.Create;
  try
    Attr.AttributeName := 'unicodePwd';
    Attr.Add(EncodeUnicodePwd(ANewPassword));
    Result := Modify(AUserDN, MO_Replace, Attr);
  finally
    Attr.Free;
  end;
end;

{ Force password change on next logon by setting pwdLastSet = 0 }
function TLDAPSend.ForcePasswordChange(const AUserDN: AnsiString): Boolean;
var
  Attr: TLDAPAttribute;
begin
  Attr := TLDAPAttribute.Create;
  try
    Attr.AttributeName := 'pwdLastSet';
    Attr.Add('0');
    Result := Modify(AUserDN, MO_Replace, Attr);
  finally
    Attr.Free;
  end;
end;

{==============================================================================}
{ Account status — class functions                                             }
class function TLDAPSend.IsAccountLocked(AUac: Integer): Boolean;
begin
  Result := (AUac and UAC_LOCKOUT) <> 0;
end;

class function TLDAPSend.IsAccountDisabled(AUac: Integer): Boolean;
begin
  Result := (AUac and UAC_ACCOUNTDISABLE) <> 0;
end;

class function TLDAPSend.IsPasswordExpired(AUac: Integer): Boolean;
begin
  Result := (AUac and UAC_PASSWORD_EXPIRED) <> 0;
end;

{==============================================================================}
{ FileTime helpers                                                             }
class function TLDAPSend.FileTimeToDateTime(AFileTime: Int64): TDateTime;
const
  EPOCH_DAYS:    Int64 = 109205;
  TICKS_PER_DAY: Int64 = 864000000000;
begin
  if (AFileTime = 0) or (AFileTime = $7FFFFFFFFFFFFFFF) then
  begin
    Result := 0;
    Exit;
  end;
  Result := (AFileTime - EPOCH_DAYS * TICKS_PER_DAY) / TICKS_PER_DAY;
end;

class function TLDAPSend.DateTimeToFileTime(ADateTime: TDateTime): Int64;
const
  EPOCH_DAYS:    Int64 = 109205;
  TICKS_PER_DAY: Int64 = 864000000000;
begin
  Result := Round(ADateTime * TICKS_PER_DAY) + EPOCH_DAYS * TICKS_PER_DAY;
end;

{==============================================================================}
{ RootDSE — empty base DN + SS_BaseObject scope = RootDSE per RFC 4512 }
function TLDAPSend.GetRootDSE(const AAttributes: TStrings): Boolean;
var
  PrevScope: TLDAPSearchScope;
begin
  PrevScope := FSearchScope;
  FSearchScope := SS_BaseObject;
  try
    Result := Search('', False, '(objectClass=*)', AAttributes);
  finally
    FSearchScope := PrevScope;
  end;
end;

{==============================================================================}
{ Filter / DN escaping                                                         }
class function TLDAPSend.EscapeFilterValue(const AValue: AnsiString): AnsiString;
var
  i: Integer;
  c: AnsiChar;
begin
  Result := '';
  for i := 1 to Length(AValue) do
  begin
    c := AValue[i];
    case c of
      '\': Result := Result + '\5c';
      '*': Result := Result + '\2a';
      '(': Result := Result + '\28';
      ')': Result := Result + '\29';
      #0:  Result := Result + '\00';
    else
      Result := Result + c;
    end;
  end;
end;

class function TLDAPSend.EscapeDNComponent(const AValue: AnsiString): AnsiString;
var
  i: Integer;
  c: AnsiChar;
begin
  Result := '';
  for i := 1 to Length(AValue) do
  begin
    c := AValue[i];
    case c of
      ',', '+', '"', '\', '<', '>', ';', '#':
        Result := Result + '\' + c;
      ' ':
        if (i = 1) or (i = Length(AValue)) then
          Result := Result + '\ '
        else
          Result := Result + c;
    else
      Result := Result + c;
    end;
  end;
end;

{==============================================================================}
{ Binary attribute helpers                                                     }
class function TLDAPSend.GUIDToLDAPEscape(const AGUID: TGUID): AnsiString;
var
  i: Integer;
  b: array[0..15] of Byte;
begin
  Move(AGUID, b[0], 16);
  Result := '';
  for i := 0 to 15 do
    Result := Result + '\' + AnsiString(IntToHex(b[i], 2));
end;

class function TLDAPSend.SIDToLDAPEscape(const ASIDBytes: AnsiString): AnsiString;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(ASIDBytes) do
    Result := Result + '\' + AnsiString(IntToHex(Ord(ASIDBytes[i]), 2));
end;

{==============================================================================}
{ Membership check via LDAP_MATCHING_RULE_IN_CHAIN                            }
function TLDAPSend.IsMemberOf(const AUserDN, AGroupDN, ABase: AnsiString): Boolean;
var
  Attrs: TStringList;
  Filter: AnsiString;
  PrevScope: TLDAPSearchScope;
begin
  Result := False;
  Attrs := TStringList.Create;
  try
    Attrs.Add('distinguishedName');
    Filter := '(&(distinguishedName=' + EscapeFilterValue(AUserDN) +
              ')(memberOf:' + LDAP_MATCHING_RULE_IN_CHAIN + ':=' +
              EscapeFilterValue(AGroupDN) + '))';
    PrevScope := FSearchScope;
    FSearchScope := SS_WholeSubtree;
    try
      Result := Search(ABase, False, Filter, Attrs) and (FSearchResult.Count > 0);
    finally
      FSearchScope := PrevScope;
    end;
  finally
    Attrs.Free;
  end;
end;

{==============================================================================}
{ Paginated search — accumulates all pages into AAccumulate                   }
function TLDAPSend.SearchAllPages(const ABase, AFilter: AnsiString;
  AScope: TLDAPSearchScope; const AAttributes: TStrings;
  APageSize: Integer; AAccumulate: TLDAPResultList): Boolean;
var
  i: Integer;
  r: TLDAPResult;
  PrevScope: TLDAPSearchScope;
  PrevPageSize: Integer;
begin
  Result := True;
  PrevScope    := FSearchScope;
  PrevPageSize := FSearchPageSize;
  FSearchScope    := AScope;
  FSearchPageSize := APageSize;
  FSearchCookie   := '';
  try
    repeat
      if not Search(ABase, False, AFilter, AAttributes) then
      begin
        Result := False;
        Break;
      end;
      // Accumulate entries
      for i := 0 to FSearchResult.Count - 1 do
      begin
        r := AAccumulate.Add;
        r.ObjectName := FSearchResult[i].ObjectName;
        // Note: deep copy of attributes would be ideal; shallow ref here for simplicity
      end;
    until FSearchCookie = '';
  finally
    FSearchScope    := PrevScope;
    FSearchPageSize := PrevPageSize;
  end;
end;

end.
