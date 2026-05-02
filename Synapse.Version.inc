{ =============================================================================
  Synapse.Version.inc -- Tags de versionamento para compilacao condicional
  Package: Ararat Synapse (CSL fork)

  Contem APENAS diretivas {$DEFINE} -- sem codigo Pascal.
  Os valores numericos e strings de versao ficam no cabecalho de cada unit
  (linha "| Project : Ararat Synapse (CSL fork) | AAA.BBB.CCC |") e no
  VERSION.md do package.

  Versao : 42.1.0
  Autor  : CSL Softwares
  Data   : 01/05/2026

  Uso:
    Em qualquer unit do package -- {$I Synapse.Version.inc} para importar as tags.
    Depois -- {$IF DEFINED(SYNAPSE_V41_OR_HIGHER)} ... {$IFEND}

  Padrao: mesmo formato adoptado em ORM.Version.inc (ActiveDirectoryORM)
  e em projects/modules/ProvidersORM/ORM.Version.inc.
  ============================================================================= }

{ -- Tags de versao MAJOR do package -- }
{$DEFINE SYNAPSE_MAJOR_42}         { Versao principal actual do package: 42.x (S13a/S13b/S14) }
{$DEFINE SYNAPSE_V42_OR_HIGHER}    { Verdadeiro para MAJOR >= 42 }
{$DEFINE SYNAPSE_MAJOR_41}         { Versao principal anterior: 41.x }
{$DEFINE SYNAPSE_V41_OR_HIGHER}    { Verdadeiro para MAJOR >= 41 }
{$DEFINE SYNAPSE_V40_OR_HIGHER}    { Verdadeiro para MAJOR >= 40 (retrocompat) }

{ -- Tags de versao MINOR (cumulativas) -- }
{$DEFINE SYNAPSE_V42_1_OR_HIGHER}  { Verdadeiro para 42.1+ (S14 fiscal helpers: IsCertificadoNFe/ESocial/Serpro/Sefaz/EFDReinf) }
{$DEFINE SYNAPSE_V42_0_OR_HIGHER}  { Verdadeiro para 42.0+ (S13a Windows Store + A3 detection via WinCrypt CRYPT_IMPL_HARDWARE) }
{$DEFINE SYNAPSE_V41_9_OR_HIGHER}  { Verdadeiro para 41.9+ (S12 PKCS#7/CAdES + RFC 3161 TSP: TPkcs7Signer + TTspClient) }
{$DEFINE SYNAPSE_V41_8_OR_HIGHER}  { Verdadeiro para 41.8+ (S11 subject enrichment: SAN/KU/EKU/OAB parsers em ssl_openssl_icpbrasil_san.pas) }
{$DEFINE SYNAPSE_V41_7_OR_HIGHER}  { Verdadeiro para 41.7+ (S10 revogacao: bindings CRL+OCSP, parsers AIA+CDP, TIcpBrasilCrlClient com cache, TIcpBrasilOcspClient via httpsend, integracao em LerDoPfx com TRevogacaoMode) }
{$DEFINE SYNAPSE_V41_6_OR_HIGHER}  { Verdadeiro para 41.6+ (S9 chain validation: TX509ChainVerifier offline, Certificate Policies parser, AC-Raiz V1..V10 detection, LerDoPfx com options para chain+policy) }
{$DEFINE SYNAPSE_V41_5_OR_HIGHER}  { Verdadeiro para 41.5+ (S8 quick wins ICP-Brasil: OID .3 fallback, NumeroSerie, Thumbprint, Certificadora, .5/.6/.8 consumidos, MatchCnpjRaiz, EstaValidoEm) }
{$DEFINE SYNAPSE_V41_4_OR_HIGHER}  { Verdadeiro para 41.4+ (IcpBrasil reader S1-S6: ssl_openssl_x509_ext + ssl_openssl_icpbrasil*) }
{$DEFINE SYNAPSE_V41_3_OR_HIGHER}  { Verdadeiro para 41.3+ (AddRaw bypassa CP1252+UnquoteStr, parser usa AddRaw, Put defensivo, Clear override, RawTo*Time defensive) }
{$DEFINE SYNAPSE_V41_2_OR_HIGHER}  { Verdadeiro para 41.2+ (TLDAPValueType + TLDAPAttributeValue + fix EEncodingError em TLDAPAttribute.Put) }
{$DEFINE SYNAPSE_V41_1_OR_HIGHER}  { Verdadeiro para 41.1+ (OpenSSL 4.0 + DLL path helper + tri-plataforma POSIX) }
{$DEFINE SYNAPSE_V41_0_OR_HIGHER}  { Verdadeiro para 41.0+ (baseline upstream Gebauer 1999-2023) }

{ -- Fork CSL -- camadas de modificacao cumulativas -- }
{$DEFINE SYNAPSE_CSL_FORK}         { Este e o fork CSL (nao upstream Gebauer puro) }
{$DEFINE SYNAPSE_CSL_ICPBR_S14}    { Fork V42.1: S14 fiscal helpers (NFe/ESocial/Serpro/Sefaz/EFD-Reinf) }
{$DEFINE SYNAPSE_CSL_ICPBR_S13B}   { Fork V42.0: S13b PKCS#11 cross-platform loader (Cryptoki v3) }
{$DEFINE SYNAPSE_CSL_ICPBR_S13A}   { Fork V42.0: S13a Windows Store enumeration + A3 detection (LGPL portions ACBr) }
{$DEFINE SYNAPSE_CSL_ICPBR_S12}    { Fork V41.9: S12 PKCS#7/CAdES signer + RFC 3161 TSP client }
{$DEFINE SYNAPSE_CSL_ICPBR_S11}    { Fork V41.8: S11 subject enrichment (SAN/KU/EKU/OAB) }
{$DEFINE SYNAPSE_CSL_ICPBR_S10}    { Fork V41.7: S10 revogacao programatica (CRL + OCSP + AIA + CDP) }
{$DEFINE SYNAPSE_CSL_ICPBR_S9}     { Fork V41.6: S9 chain validation + Certificate Policies parser + bundle AC-Raiz ICP-Brasil v1..v10 }
{$DEFINE SYNAPSE_CSL_ICPBR_S8}     { Fork V41.5: S8 quick wins (campo expandido + OID .3 fallback) }
{$DEFINE SYNAPSE_CSL_ICPBR_S1_S6}  { Fork V41.4: leitor ICP-Brasil PFX (LerDoPfx + 6 units) }
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

{ -- Tags V41.4 (S1-S6) -- Leitor PFX ICP-Brasil -- }
{$DEFINE SYNAPSE_ICPBR_PFX_READER}         { TIcpBrasilCertificadoReader.LerDoPfx (PKCS12 + Subject + OtherName decode) }
{$DEFINE SYNAPSE_X509_EXT_HELPERS}         { ssl_openssl_x509_ext: NotBefore/NotAfter/AllExtensions/PKCS12ReadFromBytes }

{ -- Tags V41.5 (S8) -- Quick wins ICP-Brasil -- }
{$DEFINE SYNAPSE_ICPBR_OID_3_FALLBACK}     { OID 2.16.76.1.3.3 legacy CNPJ fallback (compat e-CNPJ A1 antigos) }
{$DEFINE SYNAPSE_ICPBR_RICH_RECORD}        { TIcpBrasilCertificado expandido: NumeroSerie/Thumbprint/Certificadora/DERBase64/Versao + 3 OIDs adicionais (.5/.6/.8) }
{$DEFINE SYNAPSE_ICPBR_FISCAL_HELPERS}     { MatchCnpjRaiz (8 digitos) + EstaValidoEm/EstaValido/DiasParaExpirar }
{$DEFINE SYNAPSE_X509_HELPERS_THUMBPRINT}  { TX509Ext.X509GetSerialNumber*/Thumbprint*/DER*/Version }

{ -- Tags V41.6 (S9) -- Chain validation + Policy + AC-Raiz bundle -- }
{$DEFINE SYNAPSE_X509_CHAIN_VERIFY}        { ssl_openssl_chain_verify: TX509ChainVerifier (X509_STORE_*, X509_verify_cert, PEM_read_bio_X509) }
{$DEFINE SYNAPSE_ICPBR_POLICY_PARSER}      { ssl_openssl_icpbrasil_policy: parser ext 2.5.29.32 + IsIcpBrasilPolicyOid + AcRaiz V1..V10 detection }
{$DEFINE SYNAPSE_ICPBR_LER_DO_PFX_OPT}     { LerDoPfx overload com TLerDoPfxOptions (VerificarChain + AcRaizBundlePath + VerificarPolicy) }
{$DEFINE SYNAPSE_ICPBR_AC_RAIZ_BUNDLE}     { Suporte a bundle PEM AC-Raiz ICP-Brasil v1..v10 (script bundles/AC-Raiz-ICP-Brasil-fetch.ps1) }

{ -- Tags V41.7 (S10) -- Revogacao programatica (CRL + OCSP + AIA + CDP) -- }
{$DEFINE SYNAPSE_X509_CRL_BINDINGS}        { ssl_openssl_chain_verify estendido: LoadCrl* + IsRevogadoNaCRL + VerifyCrlSignature }
{$DEFINE SYNAPSE_ICPBR_OCSP_CLIENT}        { ssl_openssl_icpbrasil_ocsp: TIcpBrasilOcspClient via httpsend POST }
{$DEFINE SYNAPSE_ICPBR_CRL_CLIENT}         { ssl_openssl_icpbrasil_crl: TIcpBrasilCrlClient com cache + nextUpdate TTL }
{$DEFINE SYNAPSE_ICPBR_AIA_CDP_PARSER}     { ssl_openssl_icpbrasil_extparsers: ParseAIA + ParseCDP (RFC 5280 §4.2.2.1 + §4.2.1.13) }
{$DEFINE SYNAPSE_ICPBR_REVOCATION_MODE}    { TRevogacaoMode + integracao em LerDoPfx options }

{ -- Tags de compatibilidade com upstream -- }
{$DEFINE SYNAPSE_UPSTREAM_41}      { Baseado em upstream Gebauer release 41 }
