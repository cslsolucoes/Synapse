---
name: developer-delphi-rest-dataware-estrutura
description: Mapa de pastas, localização de arquivos e ordem de compilação do framework REST DataWare V2.1. Cobre CORE/Source/ (subpastas Sockets, Basic, Database_Drivers, utils, Plugins, Crypto, ShellTools, Wizards), tabela módulo→path→diretiva, ordem obrigatória de pacotes (RN-M00-004), compatibilidade Delphi+FPC e obrigatoriedade GPL-3.0.
model: haiku
thinking: minimal
category: project
---

# developer-delphi-rest-dataware-estrutura

## Versão interna (ficheiro)

| Campo | Valor |
| --- | --- |
| **FileVersion** | 1.0.0 |
| **Política** | `.cursor/VERSION.md` |

## Responsabilidade única

Localização de arquivos, mapa de pastas e ordem de compilação do REST DataWare V2.1. Não contém exemplos de código — ver `developer-delphi-rest-dataware-roteiro`.

## When to use

- "Onde está o arquivo X do REST DataWare?"
- "Qual a pasta dos drivers de banco?"
- "Qual a ordem de compilação dos pacotes?"
- "Onde fica uRESTDW.inc?"
- "Como a estrutura de pastas está organizada?"

## When NOT to use

- Arquitetura e componentes → `developer-delphi-rest-dataware-expert`
- Exemplos de código → `developer-delphi-rest-dataware-roteiro`

## Documentos canônicos

| Documento | Conteúdo |
| --- | --- |
| `app/modules/REST-DataWare/Documentation/Arquitetura/Arquitetura_RESTDataWare_V2.1.md` | Visão geral de pastas |
| `app/modules/REST-DataWare/Documentation/Regras de Negocio/RN-M00-004` | Ordem de compilação de pacotes |
| `app/modules/REST-DataWare/Documentation/Regras de Negocio/RN-M00-001` | Compatibilidade Delphi 7+ e Lazarus/FPC |
| `app/modules/REST-DataWare/Documentation/Regras de Negocio/RN-M00-003` | Licença GPL-3.0 obrigatória |

---

## Mapa de pastas completo

```
app/modules/REST-DataWare/
├── CORE/
│   └── Source/
│       ├── uRESTDW.inc               ← Diretivas de compilação (driver + transporte)
│       ├── uRESTDWException.pas      ← Hierarquia de exceções
│       ├── uRESTDWJSON.pas           ← TRESTDWJSONValue
│       ├── Sockets/
│       │   ├── uRESTDWIdBase.pas     ← Servidor Indy (padrão)
│       │   ├── uRESTDWICSBase.pas    ← Servidor ICS
│       │   └── uRESTDWFpHttpBase.pas ← Servidor FpHttp (Lazarus)
│       ├── Basic/
│       │   ├── uRESTDWClientSQL.pas  ← TRESTDWClientSQL
│       │   ├── uRESTDWClientTable.pas← TRESTDWTable
│       │   ├── uRESTDWPoolerDB.pas   ← TRESTDWPoolerDB
│       │   ├── uRESTDWMassiveCache.pas← TRESTDWMassiveCache
│       │   ├── uRESTDWParams.pas     ← TRESTDWParams
│       │   └── Crypto/
│       │       └── uRESTDWCripto.pas ← TCripto (AES-256, JWT)
│       ├── Database_Drivers/
│       │   ├── uRESTDWDriverBase.pas ← TRESTDWDriverBase (abstrato)
│       │   ├── uRESTDWFireDAC.pas    ← Driver FireDAC
│       │   ├── uRESTDWZeos.pas       ← Driver Zeos
│       │   ├── uRESTDWUniDAC.pas     ← Driver UniDAC
│       │   ├── uRESTDWIBDAC.pas      ← Driver IBDAC
│       │   ├── uRESTDWMyDAC.pas      ← Driver MyDAC
│       │   ├── uRESTDWSQLdb.pas      ← Driver Lazarus SQLdb
│       │   └── uRESTDWInterbase.pas  ← Driver InterBase nativo
│       ├── utils/
│       │   └── uRESTDWHelper.pas     ← Utilitários internos
│       ├── ShellTools/
│       │   └── uRESTDWShellTools.pas ← Ferramentas de linha de comando
│       └── Plugins/
│           └── ...                  ← Pacotes extras/wizards
├── Packages/
│   ├── Delphi/                      ← Pacotes .dpk para Delphi
│   └── Lazarus/                     ← Pacotes .lpk para Lazarus
├── Exemplo/
│   ├── Server/                      ← Servidor de exemplo
│   └── Client/                      ← Cliente de exemplo
└── Documentation/
    ├── Arquitetura/
    ├── Analise/
    │   ├── Basic/
    │   ├── Mechanics/
    │   └── Database_Drivers/
    └── Regras de Negocio/           ← 25 RNs (M00-M04)
```

---

## Tabela módulo → path → diretiva

| Módulo | Path | Diretiva |
| --- | --- | --- |
| Config de compilação | `CORE/Source/uRESTDW.inc` | (editar este arquivo) |
| Servidor Indy | `CORE/Source/Sockets/uRESTDWIdBase.pas` | padrão |
| Servidor ICS | `CORE/Source/Sockets/uRESTDWICSBase.pas` | `RESTDWINDYICS` |
| Servidor FpHttp | `CORE/Source/Sockets/uRESTDWFpHttpBase.pas` | `RESTDWFPHTTPCLIENT` |
| ClientSQL | `CORE/Source/Basic/uRESTDWClientSQL.pas` | — |
| PoolerDB | `CORE/Source/Basic/uRESTDWPoolerDB.pas` | — |
| MassiveCache | `CORE/Source/Basic/uRESTDWMassiveCache.pas` | — |
| Criptografia/JWT | `CORE/Source/Basic/Crypto/uRESTDWCripto.pas` | — |
| Driver base | `CORE/Source/Database_Drivers/uRESTDWDriverBase.pas` | — |
| Driver FireDAC | `CORE/Source/Database_Drivers/uRESTDWFireDAC.pas` | `RESTDWFIREDAC` |
| Driver Zeos | `CORE/Source/Database_Drivers/uRESTDWZeos.pas` | `RESTDWZEOS` |
| Driver SQLdb | `CORE/Source/Database_Drivers/uRESTDWSQLdb.pas` | `RESTDWSQLDB` |
| Exceções | `CORE/Source/uRESTDWException.pas` | — |

---

## Ordem de compilação de pacotes (RN-M00-004)

> Compilar na ordem abaixo para evitar dependências circulares.

1. `RESTDWRuntime` — runtime base (sem driver)
2. Driver escolhido (ex.: `RESTDWFireDAC`)
3. `RESTDWDesigntime` — componentes visuais e design-time
4. Pacote de transporte escolhido (ex.: `RESTDWIndy`)

Em Lazarus/FPC: mesma sequência via `.lpk` no OPM.

---

## Compatibilidade (RN-M00-001)

| Compilador | Versão mínima | Observações |
| --- | --- | --- |
| Delphi | 7 | Todas as versões Delphi 7+ suportadas |
| Free Pascal (FPC) | 3.0 | Via Lazarus; sem generics modernos |
| Lazarus | 2.0 | Pacotes `.lpk` disponíveis |

---

## Licença GPL-3.0 (RN-M00-003)

Todo arquivo `.pas` e `.inc` distribuído deve incluir:

```pascal
{ REST DataWare — Copyright (C) <ano> <autor>
  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version. }
```

---

## Changelog (este arquivo)

- 1.0.0 (11/04/2026): Criação — skill estrutura da família developer-delphi-rest-dataware-*.
