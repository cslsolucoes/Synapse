# TPGMMessageBlockSocket / blcksock.pas

**Unit:** `blcksock.pas` | **Versao:** 009.011.001 (CSL fork) | **Tipo:** Classe concreta | **Origem:** Upstream Synapse

---

## 1. O que e?

`TPGMMessageBlockSocket` e um socket para PGM (Pragmatic General Multicast, RFC 3208) em modo message — um protocolo de multicast confiavel onde cada datagrama e entregue com garantia aos receptores multicast. Herda directamente de `TBlockSocket`, retornando `SOCK_RDM` (Reliable Datagram) + `IPPROTO_RM`.

PGM e suportado nativamente apenas em Windows (via kernel driver) e requer instalacao do componente `MSMQ` / `Reliable Multicast Protocol`. Em Linux/macOS/BSD a opcao nao existe nativamente.

No contexto ActiveDirectoryORM, PGM nao e utilizado.

---

## 2. Caracteristicas

* Multicast confiavel (RFC 3208).
* Modo message (cada `Send` = um datagrama; `Recv` retorna um datagrama completo).
* Suporte apenas em Windows com Reliable Multicast Protocol instalado.
* Cross-platform **falha graciosamente** em OS sem suporte.

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| [TBlockSocket](TBlockSocket.md) | Heranca directa |
| Windows Reliable Multicast Protocol | Requerido em runtime |

---

## 4. Funcionalidades

### 4.1 Identificacao do socket

| Metodo | Assinatura | Descricao |
| --- | --- | --- |
| `GetSocketType` | `function GetSocketType: integer; override` | `SOCK_RDM` |
| `GetSocketProtocol` | `function GetSocketProtocol: integer; override` | `IPPROTO_RM` |

### 4.2 Metodos herdados

Todo I/O de `TBlockSocket` (`SendBuffer`, `RecvBuffer`, `Connect`, `Bind`, `Listen`) e aplicavel com semantica PGM.

---

## 5. Aplicabilidades

1. **Mercado financeiro** — distribuir cotacoes em tempo real com entrega garantida a N receptores.
2. **Broadcast confiavel em LAN Windows** — ambientes corporativos onde o protocolo ja esta instalado.
3. **Substituicao de UDP multicast** quando perdas de pacote sao inaceitaveis.
4. **Legado** — suporte a aplicacoes antigas Windows-only.

---

## 6. Exemplos de uso

### 6.1 Detectar suporte PGM no sistema

```pascal
uses SysUtils, blcksock;

var
  LSock: TPGMMessageBlockSocket;
begin
  LSock := TPGMMessageBlockSocket.Create;
  try
    LSock.CreateSocket;
    if LSock.LastError <> 0 then
      Writeln('PGM nao suportado neste sistema: ', LSock.GetErrorDescEx)
    else
      Writeln('PGM disponivel');
  finally
    LSock.Free;
  end;
end;
```

### 6.2 Recepcao em grupo multicast (esqueleto)

```pascal
uses SysUtils, blcksock;

var
  LSock: TPGMMessageBlockSocket;
  LMsg: AnsiString;
begin
  LSock := TPGMMessageBlockSocket.Create;
  try
    LSock.Bind('239.5.6.7', '4004');
    LSock.Listen;
    while True do
    begin
      LMsg := LSock.RecvPacket(5000);
      if LMsg <> '' then
        Writeln('Mensagem: ', LMsg);
    end;
  finally
    LSock.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| [TBlockSocket](TBlockSocket.md) | Heranca directa | |
| [TPGMStreamBlockSocket](TPGMStreamBlockSocket.md) | Irmao | Modo stream (same protocol, TCP-like bytes) |
