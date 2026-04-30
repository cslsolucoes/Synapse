# OIDs ICP-Brasil DOC-ICP-04

Constantes de OIDs definidas no DOC-ICP-04 do ITI (Instituto Nacional de
Tecnologia da Informacao). Identificam campos especificos do certificado
digital brasileiro presentes no `subjectAltName.otherName`.

## Tabela de OIDs

| OID | Constante (`ssl_openssl_icpbrasil_oids`) | Significado | Formato (PrintableString) |
| --- | --- | --- | --- |
| `2.16.76.1.3.1` | `OID_ICPBR_E_CPF_DATA` | e-CPF: dados do titular PF | `DDMMYYYY` (8) + CPF (11) + NIS (11) + RG (15) + emissor (6) |
| `2.16.76.1.3.4` | `OID_ICPBR_E_CNPJ_RESPONSAVEL` | e-CNPJ: dados do PF responsavel | mesmo formato de `OID_ICPBR_E_CPF_DATA` |
| `2.16.76.1.3.5` | `OID_ICPBR_E_CPF_TITULO` | e-CPF: titulo de eleitor | numero/zona/secao/municipio/UF |
| `2.16.76.1.3.6` | `OID_ICPBR_E_CPF_INSS` | e-CPF: PIS/PASEP | `<11 digitos>` |
| `2.16.76.1.3.7` | `OID_ICPBR_E_CNPJ_DATA` | e-CNPJ: CNPJ da empresa | `<14 digitos>` |
| `2.16.76.1.3.8` | `OID_ICPBR_E_CPF_RG` | e-CPF: RG e emissor | RG/emissor/UF |

## Helpers

```pascal
function IsOidIcpBrasilPJ(const AOID: string): Boolean;  // true para OIDs 2.16.76.1.3.{4,7}
function IsOidIcpBrasilPF(const AOID: string): Boolean;  // true para OIDs 2.16.76.1.3.{1,5,6,8}
function OID_ICPBR_ROOT_PREFIX: string;                  // '2.16.76.1.3.'
```

## Referencias

- [Instituto Nacional de Tecnologia da Informacao (ITI)](https://www.gov.br/iti/pt-br)
- DOC-ICP-04 - Politicas de Certificacao Digital ICP-Brasil
- [RFC 5280](https://datatracker.ietf.org/doc/html/rfc5280) - Internet X.509 Public Key Infrastructure Certificate
