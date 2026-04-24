# TSynaOption / blcksock.pas

**Unit:** `blcksock.pas` | **Versao:** 009.011.001 (CSL fork) | **Tipo:** Classe auxiliar | **Origem:** Upstream Synapse

---

## 1. O que e?

`TSynaOption` e uma classe auxiliar usada internamente pela hierarquia `TBlockSocket` para armazenar **opcoes de socket delayadas** — opcoes (`setsockopt`) que o consumidor configurou antes do socket nativo ser criado. Quando `CreateSocket` executa, o `TBlockSocket` percorre a lista de `TSynaOption` pendentes (`FDelayedOptions: TOptionList`) e aplica cada uma via `setsockopt` / `ioctl`.

Esse padrao existe porque muitas properties (`TTL`, `SizeRecvBuffer`, `SizeSendBuffer`, `NonBlockMode`, `Linger`, etc.) sao atribuidas pelo consumidor antes do `Connect`/`Bind` — nesse momento ainda nao ha socket nativo para aplicar a opcao. O `TSynaOption` atua como fila de intencoes a serem materializadas posteriormente.

Embora `TSynaOption` seja publica, raramente e instanciada directamente pelo consumidor: ela e manipulada exclusivamente pelas properties de `TBlockSocket` (`SetTTL`, `SetLinger`, `SetNonBlockMode`, etc.) que criam a opcao e a adicionam a lista.

---

## 2. Caracteristicas

* Classe auxiliar usada internamente por `TBlockSocket`.
* Representa uma intencao de `setsockopt` que sera aplicada na criacao do socket.
* Herda directamente de `TObject`; tres campos publicos simples: `Option`, `Enabled`, `Value`.
* Armazenada em `TOptionList` (que e `TList<TSynaOption>` em POSIX ou `TList` em outras plataformas).
* Aplicada via `TBlockSocket.SetDelayedOption` / `DelayedOption` / `ProcessDelayedOptions`.

---

## 3. Engine

| Diretiva / Runtime | Efeito |
| --- | --- |
| `{$IFDEF FPC}` + `{$MODE DELPHI}` | Compatibilidade FPC |
| `{$IFDEF POSIX}` | `TOptionList = TList<TSynaOption>` (generico) |
| `{$ELSE}` | `TOptionList = TList` |
| `TObject` | Classe base |

---

## 4. Funcionalidades

### 4.1 Tipo enum auxiliar

```pascal
TSynaOptionType = (
  SOT_Linger,       // SO_LINGER (Enabled + Value=segundos)
  SOT_RecvBuff,     // SO_RCVBUF
  SOT_SendBuff,     // SO_SNDBUF
  SOT_NonBlock,     // FIONBIO (Enabled)
  SOT_RecvTimeout,  // SO_RCVTIMEO
  SOT_SendTimeout,  // SO_SNDTIMEO
  SOT_Reuse,        // SO_REUSEADDR (Enabled)
  SOT_TTL,          // IP_TTL
  SOT_Broadcast,    // SO_BROADCAST (Enabled)
  SOT_MulticastTTL, // IP_MULTICAST_TTL
  SOT_MulticastLoop // IP_MULTICAST_LOOP (Enabled)
);
```

### 4.2 Campos publicos

| Campo | Tipo | Descricao |
| --- | --- | --- |
| `Option` | `TSynaOptionType` | Qual opcao sera aplicada |
| `Enabled` | `Boolean` | Ativada / desativada (para opcoes booleanas) |
| `Value` | `Integer` | Valor numerico (bytes, segundos, TTL) |

### 4.3 Metodos internos de `TBlockSocket` que manipulam a lista

| Metodo | Descricao |
| --- | --- |
| `SetDelayedOption(const Value: TSynaOption)` | Armazena opcao ate criacao do socket, entao aplica |
| `DelayedOption(const Value: TSynaOption)` | Apenas enfileira |
| `ProcessDelayedOptions` | Chamado apos `CreateSocket` — percorre `FDelayedOptions` e aplica via `setsockopt` |

---

## 5. Aplicabilidades

1. **Padrao interno** — permite ao consumidor configurar properties antes de `Connect`, sem socket nativo.
2. **Reaplicacao apos re-criacao** — `FDelayedOptions` sobrevive a `CloseSocket`; nova criacao reaplica tudo.
3. **Debugging** — inspeccionar `FDelayedOptions` durante debug revela quais opcoes estao pendentes.
4. **Extensao custom** — novas properties podem usar o mesmo mecanismo para deferir configuracao.

---

## 6. Exemplos de uso

### 6.1 Atribuicao normal (TSynaOption criado automaticamente)

```pascal
uses blcksock;

var
  LSock: TTCPBlockSocket;
begin
  LSock := TTCPBlockSocket.Create;
  try
    // Cada atribuicao abaixo cria TSynaOption e guarda em FDelayedOptions;
    // todas serao aplicadas quando Connect criar o socket nativo.
    LSock.SizeRecvBuffer := 65536;
    LSock.SizeSendBuffer := 65536;
    LSock.TTL            := 64;
    LSock.NonBlockMode   := True;

    LSock.Connect('dc01.empresa.local', '389');
  finally
    LSock.Free;
  end;
end;
```

### 6.2 Uso directo de TSynaOption (normalmente NAO recomendado — apenas didatico)

```pascal
uses blcksock;

var
  LSock: TTCPBlockSocket;
  LOpt: TSynaOption;
begin
  LSock := TTCPBlockSocket.Create;
  try
    LOpt := TSynaOption.Create;
    LOpt.Option  := SOT_Linger;
    LOpt.Enabled := True;
    LOpt.Value   := 2;  // 2 seg
    // Em producao usar SetLinger(True, 2) — este exemplo expoe apenas a forma interna
  finally
    LSock.Free;
  end;
end;
```

---

## 7. Relacionamentos

| Classe/Unit | Tipo | Descricao |
| --- | --- | --- |
| `TObject` | Heranca | Base Delphi |
| [TBlockSocket](TBlockSocket.md) | Uso exclusivo | `FDelayedOptions: TOptionList` armazena instancias |
| `TOptionList` (`TList<TSynaOption>` ou `TList`) | Container | Lista de opcoes pendentes |
| `TSynaOptionType` | Enum auxiliar | Enumeracao dos tipos |
