{
| Project   : Ararat Synapse                                     |  v41.4     |
|==============================================================================|
| Content: DUnitX suite for ICP-Brasil parsers + validators (synthetic vectors)|
|==============================================================================|
| Copyright (c)2026, contributors (fork extensions)                            |
| All rights reserved.                                                         |
|                                                                              |
| BSD 3-Clause License - see LICENSE for full text.                            |
|==============================================================================|
| Reference: .workspace/plans/pfx-cripto-synapse_v1.0.plan.md V2.1.0           |
|==============================================================================|
}

{:@abstract(DUnitX test suite for fork extensions parsers and validators.

Vectors are 100% synthetic - no real PII. Synthetic CNPJ/CPF have valid
mod-11 checksum but do not correspond to any real entity.

Reader integral tests (TIcpBrasilCertificadoReader.LerDoPfx) with real PFX
go in PLANO 2 (M08) using subset selected in Wave M0.
}
program ssl_openssl_icpbrasil_tests;

{$IFDEF FPC}{$MODE DELPHI}{$H+}{$ENDIF}
{$APPTYPE CONSOLE}

uses
  SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.TestRunner,
  ssl_openssl_icpbrasil_oids        in '..\ssl_openssl_icpbrasil_oids.pas',
  ssl_openssl_icpbrasil_types       in '..\ssl_openssl_icpbrasil_types.pas',
  ssl_openssl_icpbrasil_subject     in '..\ssl_openssl_icpbrasil_subject.pas',
  ssl_openssl_icpbrasil_othername   in '..\ssl_openssl_icpbrasil_othername.pas';

type
  [TestFixture]
  TTestSubjectParser = class
  public
    [Test] procedure ParseCN_eCNPJ_Standard;
    [Test] procedure ParseCN_eCNPJ_NameWithSpaces;
    [Test] procedure ParseCN_eCNPJ_NameWithColon;
    [Test] procedure ParseCN_eCPF_Standard;
    [Test] procedure ParseCN_NoColon_Fails;
    [Test] procedure ParseCN_EmptyString_Fails;
    [Test] procedure ParseCN_NonNumericDocument_Fails;
    [Test] procedure ParseCN_WrongDocumentLength_Fails;
  end;

  [TestFixture]
  TTestCnpjValidator = class
  public
    [Test] procedure CnpjValid_Synthetic1;
    [Test] procedure CnpjValid_Synthetic2;
    [Test] procedure CnpjValid_Formatted;
    [Test] procedure CnpjInvalid_AllZeros;
    [Test] procedure CnpjInvalid_AllOnes;
    [Test] procedure CnpjInvalid_WrongDV;
    [Test] procedure CnpjInvalid_LengthWrong;
    [Test] procedure CnpjInvalid_NonDigits;
  end;

  [TestFixture]
  TTestCpfValidator = class
  public
    [Test] procedure CpfValid_Synthetic1;
    [Test] procedure CpfValid_Synthetic2;
    [Test] procedure CpfValid_Formatted;
    [Test] procedure CpfInvalid_AllZeros;
    [Test] procedure CpfInvalid_RepeatedDigits;
    [Test] procedure CpfInvalid_WrongDV;
    [Test] procedure CpfInvalid_LengthWrong;
  end;

  [TestFixture]
  TTestFormatters = class
  public
    [Test] procedure FormatCnpj_FromRaw;
    [Test] procedure FormatCnpj_FromAlreadyFormatted;
    [Test] procedure FormatCnpj_WrongLength_ReturnsEmpty;
    [Test] procedure FormatCpf_FromRaw;
    [Test] procedure FormatCpf_WrongLength_ReturnsEmpty;
    [Test] procedure ClassifyByDigitCount;
  end;

  [TestFixture]
  TTestOidsHelpers = class
  public
    [Test] procedure OidsAreCorrect;
    [Test] procedure IsOidPJ_Recognizes;
    [Test] procedure IsOidPF_Recognizes;
    [Test] procedure IsOidUnknown_RejectsBoth;
  end;

  [TestFixture]
  TTestOtherNameParser = class
  public
    [Test] procedure StripWrapper_OctetString;
    [Test] procedure StripWrapper_NoWrapper_Untouched;
    [Test] procedure ParseEcnpjData_ExtractsCnpj;
    [Test] procedure ParseEcnpjData_NoDigits_Fails;
    [Test] procedure ParseEcpfData_ExtractsCpfAndNasc;
  end;

{ TTestSubjectParser }

procedure TTestSubjectParser.ParseCN_eCNPJ_Standard;
var titular, doc: string;
begin
  Assert.IsTrue(ParseSubjectCN('ACME COMERCIO LTDA:11222333000181', titular, doc));
  Assert.AreEqual('ACME COMERCIO LTDA', titular);
  Assert.AreEqual('11222333000181', doc);
end;

procedure TTestSubjectParser.ParseCN_eCNPJ_NameWithSpaces;
var titular, doc: string;
begin
  Assert.IsTrue(ParseSubjectCN('EMPRESA TESTE S A:11444777000161', titular, doc));
  Assert.AreEqual('EMPRESA TESTE S A', titular);
  Assert.AreEqual('11444777000161', doc);
end;

procedure TTestSubjectParser.ParseCN_eCNPJ_NameWithColon;
var titular, doc: string;
begin
  Assert.IsTrue(ParseSubjectCN('EMPRESA COM:ESPACOS LTDA:11999000000159', titular, doc));
  Assert.AreEqual('EMPRESA COM:ESPACOS LTDA', titular);
  Assert.AreEqual('11999000000159', doc);
end;

procedure TTestSubjectParser.ParseCN_eCPF_Standard;
var titular, doc: string;
begin
  Assert.IsTrue(ParseSubjectCN('JOAO DA SILVA:11144477735', titular, doc));
  Assert.AreEqual('JOAO DA SILVA', titular);
  Assert.AreEqual('11144477735', doc);
end;

procedure TTestSubjectParser.ParseCN_NoColon_Fails;
var titular, doc: string;
begin
  Assert.IsFalse(ParseSubjectCN('SEM COLON AQUI', titular, doc));
end;

procedure TTestSubjectParser.ParseCN_EmptyString_Fails;
var titular, doc: string;
begin
  Assert.IsFalse(ParseSubjectCN('', titular, doc));
  Assert.IsFalse(ParseSubjectCN('   ', titular, doc));
end;

procedure TTestSubjectParser.ParseCN_NonNumericDocument_Fails;
var titular, doc: string;
begin
  Assert.IsFalse(ParseSubjectCN('NOME:NAO_E_NUMERICO', titular, doc));
end;

procedure TTestSubjectParser.ParseCN_WrongDocumentLength_Fails;
var titular, doc: string;
begin
  Assert.IsFalse(ParseSubjectCN('NOME:1234567890', titular, doc));
  Assert.IsFalse(ParseSubjectCN('NOME:1234567890123', titular, doc));
end;

{ TTestCnpjValidator }

procedure TTestCnpjValidator.CnpjValid_Synthetic1;
begin
  Assert.IsTrue(IsCnpjValido('11222333000181'));
end;

procedure TTestCnpjValidator.CnpjValid_Synthetic2;
begin
  Assert.IsTrue(IsCnpjValido('11444777000161'));
end;

procedure TTestCnpjValidator.CnpjValid_Formatted;
begin
  Assert.IsTrue(IsCnpjValido('11.222.333/0001-81'));
end;

procedure TTestCnpjValidator.CnpjInvalid_AllZeros;
begin
  Assert.IsFalse(IsCnpjValido('00000000000000'));
end;

procedure TTestCnpjValidator.CnpjInvalid_AllOnes;
begin
  Assert.IsFalse(IsCnpjValido('11111111111111'));
end;

procedure TTestCnpjValidator.CnpjInvalid_WrongDV;
begin
  Assert.IsFalse(IsCnpjValido('11222333000182'));
  Assert.IsFalse(IsCnpjValido('11222333000180'));
end;

procedure TTestCnpjValidator.CnpjInvalid_LengthWrong;
begin
  Assert.IsFalse(IsCnpjValido('1122233300018'));
  Assert.IsFalse(IsCnpjValido('112223330001811'));
  Assert.IsFalse(IsCnpjValido(''));
end;

procedure TTestCnpjValidator.CnpjInvalid_NonDigits;
begin
  Assert.IsFalse(IsCnpjValido('AB222333000181'));
end;

{ TTestCpfValidator }

procedure TTestCpfValidator.CpfValid_Synthetic1;
begin
  Assert.IsTrue(IsCpfValido('11144477735'));
end;

procedure TTestCpfValidator.CpfValid_Synthetic2;
begin
  Assert.IsTrue(IsCpfValido('39053344705'));
end;

procedure TTestCpfValidator.CpfValid_Formatted;
begin
  Assert.IsTrue(IsCpfValido('111.444.777-35'));
end;

procedure TTestCpfValidator.CpfInvalid_AllZeros;
begin
  Assert.IsFalse(IsCpfValido('00000000000'));
end;

procedure TTestCpfValidator.CpfInvalid_RepeatedDigits;
begin
  Assert.IsFalse(IsCpfValido('11111111111'));
  Assert.IsFalse(IsCpfValido('99999999999'));
end;

procedure TTestCpfValidator.CpfInvalid_WrongDV;
begin
  Assert.IsFalse(IsCpfValido('11144477736'));
  Assert.IsFalse(IsCpfValido('11144477734'));
end;

procedure TTestCpfValidator.CpfInvalid_LengthWrong;
begin
  Assert.IsFalse(IsCpfValido('1114447773'));
  Assert.IsFalse(IsCpfValido('111444777355'));
  Assert.IsFalse(IsCpfValido(''));
end;

{ TTestFormatters }

procedure TTestFormatters.FormatCnpj_FromRaw;
begin
  Assert.AreEqual('11.222.333/0001-81', FormatarCnpj('11222333000181'));
end;

procedure TTestFormatters.FormatCnpj_FromAlreadyFormatted;
begin
  Assert.AreEqual('11.222.333/0001-81', FormatarCnpj('11.222.333/0001-81'));
end;

procedure TTestFormatters.FormatCnpj_WrongLength_ReturnsEmpty;
begin
  Assert.AreEqual('', FormatarCnpj('123'));
  Assert.AreEqual('', FormatarCnpj(''));
end;

procedure TTestFormatters.FormatCpf_FromRaw;
begin
  Assert.AreEqual('111.444.777-35', FormatarCpf('11144477735'));
end;

procedure TTestFormatters.FormatCpf_WrongLength_ReturnsEmpty;
begin
  Assert.AreEqual('', FormatarCpf('123'));
end;

procedure TTestFormatters.ClassifyByDigitCount;
begin
  Assert.AreEqual(Ord(ibtECnpj),        Ord(ClassificarDocumento('11222333000181')));
  Assert.AreEqual(Ord(ibtECpf),         Ord(ClassificarDocumento('11144477735')));
  Assert.AreEqual(Ord(ibtDesconhecido), Ord(ClassificarDocumento('123')));
  Assert.AreEqual(Ord(ibtDesconhecido), Ord(ClassificarDocumento('')));
end;

{ TTestOidsHelpers }

procedure TTestOidsHelpers.OidsAreCorrect;
begin
  Assert.AreEqual('2.16.76.1.3.1', OID_ICPBR_E_CPF_DATA);
  Assert.AreEqual('2.16.76.1.3.4', OID_ICPBR_E_CNPJ_RESPONSAVEL);
  Assert.AreEqual('2.16.76.1.3.5', OID_ICPBR_E_CPF_TITULO);
  Assert.AreEqual('2.16.76.1.3.6', OID_ICPBR_E_CPF_INSS);
  Assert.AreEqual('2.16.76.1.3.7', OID_ICPBR_E_CNPJ_DATA);
  Assert.AreEqual('2.16.76.1.3.8', OID_ICPBR_E_CPF_RG);
end;

procedure TTestOidsHelpers.IsOidPJ_Recognizes;
begin
  Assert.IsTrue(IsOidIcpBrasilPJ('2.16.76.1.3.7'));
  Assert.IsTrue(IsOidIcpBrasilPJ('2.16.76.1.3.4'));
  Assert.IsFalse(IsOidIcpBrasilPJ('2.16.76.1.3.1'));
  Assert.IsFalse(IsOidIcpBrasilPJ('1.2.3.4.5'));
end;

procedure TTestOidsHelpers.IsOidPF_Recognizes;
begin
  Assert.IsTrue(IsOidIcpBrasilPF('2.16.76.1.3.1'));
  Assert.IsTrue(IsOidIcpBrasilPF('2.16.76.1.3.5'));
  Assert.IsTrue(IsOidIcpBrasilPF('2.16.76.1.3.6'));
  Assert.IsTrue(IsOidIcpBrasilPF('2.16.76.1.3.8'));
  Assert.IsFalse(IsOidIcpBrasilPF('2.16.76.1.3.7'));
end;

procedure TTestOidsHelpers.IsOidUnknown_RejectsBoth;
begin
  Assert.IsFalse(IsOidIcpBrasilPJ('1.2.3.4.5.6'));
  Assert.IsFalse(IsOidIcpBrasilPF('1.2.3.4.5.6'));
  Assert.IsFalse(IsOidIcpBrasilPJ(''));
  Assert.IsFalse(IsOidIcpBrasilPF(''));
end;

{ TTestOtherNameParser }

procedure TTestOtherNameParser.StripWrapper_OctetString;
var
  LBytes, LStripped: TByteArray;
begin
  SetLength(LBytes, 6);
  LBytes[0] := $04; LBytes[1] := $04;
  LBytes[2] := $41; LBytes[3] := $42; LBytes[4] := $43; LBytes[5] := $44;
  LStripped := StripASN1OctetWrapper(LBytes);
  Assert.AreEqual(NativeInt(4), NativeInt(Length(LStripped)));
  Assert.AreEqual(Integer($41), Integer(LStripped[0]));
  Assert.AreEqual(Integer($44), Integer(LStripped[3]));
end;

procedure TTestOtherNameParser.StripWrapper_NoWrapper_Untouched;
var
  LBytes, LStripped: TByteArray;
begin
  SetLength(LBytes, 3);
  LBytes[0] := $31; LBytes[1] := $32; LBytes[2] := $33;
  LStripped := StripASN1OctetWrapper(LBytes);
  Assert.AreEqual(NativeInt(3), NativeInt(Length(LStripped)));
end;

procedure TTestOtherNameParser.ParseEcnpjData_ExtractsCnpj;
var
  LBytes: TByteArray;
  LCnpj: string;
  LStr: AnsiString;
  I: Integer;
begin
  LStr := '11222333000181';
  SetLength(LBytes, Length(LStr));
  for I := 1 to Length(LStr) do
    LBytes[I-1] := Ord(LStr[I]);

  Assert.IsTrue(ParseEcnpjData(LBytes, LCnpj));
  Assert.AreEqual('11222333000181', LCnpj);
end;

procedure TTestOtherNameParser.ParseEcnpjData_NoDigits_Fails;
var
  LBytes: TByteArray;
  LCnpj: string;
begin
  SetLength(LBytes, 3);
  LBytes[0] := Ord('A'); LBytes[1] := Ord('B'); LBytes[2] := Ord('C');
  Assert.IsFalse(ParseEcnpjData(LBytes, LCnpj));
end;

procedure TTestOtherNameParser.ParseEcpfData_ExtractsCpfAndNasc;
var
  LBytes: TByteArray;
  LNasc: TDateTime;
  LCpf, LRg, LEmissor: string;
  LData: AnsiString;
  I: Integer;
begin
  LData := '0101199011144477735';
  SetLength(LBytes, Length(LData));
  for I := 1 to Length(LData) do
    LBytes[I-1] := Ord(LData[I]);

  Assert.IsTrue(ParseEcpfData(LBytes, LNasc, LCpf, LRg, LEmissor));
  Assert.AreEqual('11144477735', LCpf);
  Assert.IsTrue(LNasc > 0);
end;

var
  LRunner:  ITestRunner;
  LResults: IRunResults;

begin
  TDUnitX.RegisterTestFixture(TTestSubjectParser);
  TDUnitX.RegisterTestFixture(TTestCnpjValidator);
  TDUnitX.RegisterTestFixture(TTestCpfValidator);
  TDUnitX.RegisterTestFixture(TTestFormatters);
  TDUnitX.RegisterTestFixture(TTestOidsHelpers);
  TDUnitX.RegisterTestFixture(TTestOtherNameParser);

  LRunner := TDUnitX.CreateRunner;
  LRunner.AddLogger(TDUnitXConsoleLogger.Create(True));
  LResults := LRunner.Execute;

  if LResults.AllPassed then
    ExitCode := 0
  else
    ExitCode := 1;
end.
