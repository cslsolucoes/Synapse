# Changelog - Ararat Synapse (fork)

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versionamento: ver `VERSION.md`.

## [41.4] - 2026-04-30

### Added

- `ssl_openssl_x509_ext.pas` - cross-platform X509 PFX companion unit
  (Windows + FPC Linux + macOS via DynLibs IFDEF).
  - `TX509Ext.X509GetNotBefore` / `X509GetNotAfter` (ASN1_TIME accessors)
  - `TX509Ext.X509ASN1TimeToDateTimeUTC` (ASN1_TIME -> TDateTime UTC)
  - `TX509Ext.X509GetSubjectCN` / `X509GetIssuerCN` (NID_commonName helpers)
  - `TX509Ext.X509GetAllExtensions: TX509ExtensionArray`
  - `TX509Ext.PKCS12ReadFromBytes` (managed PFX wrapper)
  - Self-loads libcrypto-3 in own handle (no modification of `ssl_openssl3_lib.pas`).
- ICP-Brasil DOC-ICP-04 tropicalization (5 units):
  - `ssl_openssl_icpbrasil_oids.pas` - OID constants (functions, due to `WRITEABLECONST OFF`).
  - `ssl_openssl_icpbrasil_types.pas` - `TIcpBrasilCertificado` record + 3 exceptions.
  - `ssl_openssl_icpbrasil_subject.pas` - Subject CN parser + CNPJ/CPF mod-11 validators.
  - `ssl_openssl_icpbrasil_othername.pas` - ASN.1 OtherName parsers.
  - `ssl_openssl_icpbrasil.pas` - public reader `TIcpBrasilCertificadoReader.LerDoPfx`.
- `tests-extra/` - DUnitX suite (38 tests, 100% synthetic vectors).

### Changed

- `synapse.dpk` lists 6 new units; description bumped to v41.4.
- `laz_synapse.lpk` lists 6 new units (Files Count 42 -> 48).
- `VERSION.md` bumped 41.3 -> 41.4.

### Notes

- Zero modification of existing `ssl_openssl{3,4}_lib.pas` files.
  Mitigates upstream rebase risk - all v41.4 extensions in new files.
- Cross-platform via `{$IFDEF MSWINDOWS} ... {$ELSE FPC DynLibs} ... {$ENDIF}`.
- DOC-ICP-04 reference: <https://www.gov.br/iti/pt-br>.
- Fork extensions in v41.4 contributed by CSL Tech Solutions.

## [41.3] - 2026-04-22

### Changed

- AddRaw method preserves 100% binary bytes when writing LDAP attributes.

## [41.2] - earlier

### Added

- Automatic LDAP attribute typing.

## [41.1] - earlier

### Added

- OpenSSL 4.0 support (`ssl_openssl4*.pas`).
- DLL path resolution helper (`ssl_openssl_paths.pas`).
- AD WS 2025 compatibility (LDAPS + CBT + tri-platform POSIX).

## [41.0] - 2023

### Initial

- Forked from Synapse upstream (copyright 1999-2023, Lukas Gebauer).
