{ =============================================================================
  Synapse.Version.inc -- Tags de versionamento para compilacao condicional
  Package: Ararat Synapse (CSL fork)

  Contem APENAS diretivas {$DEFINE} -- sem codigo Pascal.
  Os valores numericos e strings de versao ficam no cabecalho de cada unit
  (linha "| Project : Ararat Synapse (CSL fork) | AAA.BBB.CCC |") e no
  VERSION.md do package.

  Versao : 41.3.0
  Autor  : CSL Softwares
  Data   : 22/04/2026

  Uso:
    Em qualquer unit do package -- {$I Synapse.Version.inc} para importar as tags.
    Depois -- {$IF DEFINED(SYNAPSE_V41_OR_HIGHER)} ... {$IFEND}

  Padrao: mesmo formato adoptado em ORM.Version.inc (ActiveDirectoryORM)
  e em projects/modules/ProvidersORM/ORM.Version.inc.
  ============================================================================= }

{ -- Tags de versao MAJOR do package -- }
{$DEFINE SYNAPSE_MAJOR_41}         { Versao principal actual do package: 41.x }
{$DEFINE SYNAPSE_V41_OR_HIGHER}    { Verdadeiro para MAJOR >= 41 }
{$DEFINE SYNAPSE_V40_OR_HIGHER}    { Verdadeiro para MAJOR >= 40 (retrocompat) }

{ -- Tags de versao MINOR (cumulativas) -- }
{$DEFINE SYNAPSE_V41_3_OR_HIGHER}  { Verdadeiro para 41.3+ (AddRaw bypassa CP1252+UnquoteStr, parser usa AddRaw, Put defensivo, Clear override, RawTo*Time defensive) }
{$DEFINE SYNAPSE_V41_2_OR_HIGHER}  { Verdadeiro para 41.2+ (TLDAPValueType + TLDAPAttributeValue + fix EEncodingError em TLDAPAttribute.Put) }
{$DEFINE SYNAPSE_V41_1_OR_HIGHER}  { Verdadeiro para 41.1+ (OpenSSL 4.0 + DLL path helper + tri-plataforma POSIX) }
{$DEFINE SYNAPSE_V41_0_OR_HIGHER}  { Verdadeiro para 41.0+ (baseline upstream Gebauer 1999-2023) }

{ -- Fork CSL -- camadas de modificacao cumulativas -- }
{$DEFINE SYNAPSE_CSL_FORK}         { Este e o fork CSL (nao upstream Gebauer puro) }
{$DEFINE SYNAPSE_CSL_V2026_04_22B} { Fork V41.3: AddRaw + parser usa AddRaw + Put defensivo (V1.7.2 do ORM) }
{$DEFINE SYNAPSE_CSL_V2026_04_22}  { Fork V41.2: tipagem automatica de atributos LDAP (ldapsend 001.007.004) }
{$DEFINE SYNAPSE_CSL_V2026_04_21}  { Fork anterior: OpenSSL 4.0 + path helper + ldapsend POSIX }
{$DEFINE SYNAPSE_CSL_V2026_04_13}  { Fork historico: GSSAPI+CBT + controles AD + LDAP Signing }

{ -- Tags de estabilidade -- }
{$DEFINE SYNAPSE_STABLE}           { Release estavel (remover em alpha/beta/rc) }
{$UNDEF  SYNAPSE_PRERELEASE}       { Sem sufixo de pre-lancamento }

{ -- Tags de features condicionais -- }
{$DEFINE SYNAPSE_DUAL_OPENSSL}     { Suporte dual OpenSSL 3.x (ssl_openssl3) + 4.0 (ssl_openssl4) }
{$DEFINE SYNAPSE_OPENSSL_PATHS}    { Helper TOpenSSLPaths.Apply(N) em ssl_openssl_paths.pas }
{$DEFINE SYNAPSE_LDAP_GSSAPI_CBT}  { Bind SASL GSSAPI + Channel Binding Token (RFC 5929) -- Windows }
{$DEFINE SYNAPSE_LDAP_SIGNING}     { LDAP Signing RFC 4757 (HMAC-MD5 em PDUs) -- Windows }
{$DEFINE SYNAPSE_LDAP_AD_CONTROLS} { 8 controles AD (DirSync, SDFlags, ExtendedDN, ShowDeleted, ShowRecycled, ServerSort, Permissive Modify, TreeDelete) }
{$DEFINE SYNAPSE_FILETIME_HELPERS} { synautil FileTimeToDateTime/DateTimeToFileTime (AD) }
{$DEFINE SYNAPSE_PEER_CERT_SHA256} { blcksock.GetPeerCertSHA256Hash (CBT RFC 5929) }

{ -- Tags de tri-plataforma (V1.7.0 do ActiveDirectoryORM / V41.1 do package) -- }
{$DEFINE SYNAPSE_POSIX_COMPATIBLE} { ldapsend.pas compila em POSIX (FPC Linux/macOS/BSD + Delphi LINUX64/macOS64) }
{$DEFINE SYNAPSE_SSPI_GUARDED}     { 6 blocos SSPI envolvidos em {$IFDEF MSWINDOWS} + 4 stubs POSIX }
{$UNDEF  SYNAPSE_GSSAPI_POSIX_REAL}{ Port real libgssapi_krb5 agendado para V2.0.0 (ainda nao entregue) }

{ -- Tags de tipagem automatica de atributos (V1.7.1 do ActiveDirectoryORM / V41.2 do package) -- }
{$DEFINE SYNAPSE_LDAP_TYPED_VALUES}{ Enum TLDAPValueType + mapa LDAP_KNOWN_ATTRIBUTE_TYPES em ldapsend 001.007.004 }
{$DEFINE SYNAPSE_LDAP_ATTR_VALUE_API} { Record TLDAPAttributeValue (AsString/AsInteger/AsFloat/AsBoolean/AsDateTime/AsBinary/AsHex/AsSid/AsGuid/AsVariant) }
{$DEFINE SYNAPSE_LDAP_RAW_VALUES}  { TLDAPAttribute.FRawValues preserva bytes crus do socket (fix EEncodingError Put) }
{$DEFINE SYNAPSE_LDAP_SAFE_UTF8}   { SafeUtf8Decode: UTF-8 com fallback Latin-1 nunca-lanca }

{ -- Tags V41.3 (V1.7.2 do ORM) -- AddRaw + Put defensivo + Clear -- }
{$DEFINE SYNAPSE_LDAP_RAW_BYTES_PRESERVED} { TLDAPAttribute.AddRaw + parser usa AddRaw -- preserva 100% bytes binarios (fix bytes 0x22 / 0x80-0xFF) }
{$DEFINE SYNAPSE_LDAP_PUT_DEFENSIVE}       { Put salta UnquoteStr quando FValueType in [vtGUID, vtSID, vtOctetString, vtBitString] }
{$DEFINE SYNAPSE_LDAP_GET_GUARDED}         { TLDAPAttribute.Get com try/except + fallback hex (nunca aborta iteracao) }
{$DEFINE SYNAPSE_LDAP_CLEAR_OVERRIDE}      { TLDAPAttribute.Clear override resetando FRawValues em sincronia com TStringList }

{ -- Tags de compatibilidade com upstream -- }
{$DEFINE SYNAPSE_UPSTREAM_41}      { Baseado em upstream Gebauer release 41 }
