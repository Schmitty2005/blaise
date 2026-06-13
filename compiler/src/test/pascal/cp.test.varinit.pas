{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit cp.test.varinit;

{ IR-level tests for initialised global variables: var G: T = value.
  The initialiser is folded at compile time and emitted into the data
  section.  E2E coverage (compile -> run, both backends) lives in
  cp.test.e2e.varinit.pas. }

interface

uses
  blaise.testing,
  uLexer, uParser, uAST, uSemantic, uSymbolTable, blaise.codegen.qbe;

type
  TVarInitTests = class(TTestCase)
  private
    function GenIR(const ASrc: string): string;
    function ParseProg(const ASrc: string): TProgram;
    function IRHas(const AIR, AFragment: string): Boolean;
  published
    { Parser }
    procedure TestParse_ScalarInit_AttachesInitConst;
    procedure TestParse_NoInit_InitConstNil;
    procedure TestParse_MultiName_WithInit_Rejected;

    { Semantic }
    procedure TestSemantic_TypeMismatch_StringIntoInteger_Rejected;
    procedure TestSemantic_LocalInit_Rejected;
    procedure TestSemantic_RecordInit_Rejected;

    { Codegen — data section }
    procedure TestCodegen_IntegerInit_EmitsValue;
    procedure TestCodegen_StringInit_EmitsHeaderPointer;
    procedure TestCodegen_BooleanInit_EmitsOne;
    procedure TestCodegen_ArrayInit_EmitsElements;
    procedure TestCodegen_NoInit_StillZero;
  end;

implementation

function TVarInitTests.ParseProg(const ASrc: string): TProgram;
var L: TLexer; P: TParser;
begin
  L := TLexer.Create(ASrc);
  P := TParser.Create(L);
  try
    Result := P.Parse();
  finally
    P.Free(); L.Free();
  end;
end;

function TVarInitTests.GenIR(const ASrc: string): string;
var
  L:  TLexer;
  P:  TParser;
  Pr: TProgram;
  A:  TSemanticAnalyser;
  CG: TCodeGenQBE;
begin
  L  := TLexer.Create(ASrc);
  P  := TParser.Create(L);
  Pr := P.Parse();
  A  := TSemanticAnalyser.Create();
  try
    A.Analyse(Pr);
    CG := TCodeGenQBE.Create();
    try
      CG.Generate(Pr);
      Result := CG.GetOutput();
    finally
      CG.Free();
    end;
  finally
    A.Free();
    Pr.Free();
    P.Free();
    L.Free();
  end;
end;

function TVarInitTests.IRHas(const AIR, AFragment: string): Boolean;
begin
  Result := Pos(AFragment, AIR) >= 0;
end;

{ ------------------------------------------------------------------ }
{ Parser                                                              }
{ ------------------------------------------------------------------ }

procedure TVarInitTests.TestParse_ScalarInit_AttachesInitConst;
var P: TProgram; Decl: TVarDecl;
begin
  P := ParseProg('program X; var G: Integer = 42; begin end.');
  try
    Decl := TVarDecl(P.Block.Decls.Items[0]);
    AssertNotNull('InitConst attached', Decl.InitConst);
    AssertEquals('folded value 42', 42, Decl.InitConst.IntVal);
  finally P.Free(); end;
end;

procedure TVarInitTests.TestParse_NoInit_InitConstNil;
var P: TProgram; Decl: TVarDecl;
begin
  P := ParseProg('program X; var G: Integer; begin end.');
  try
    Decl := TVarDecl(P.Block.Decls.Items[0]);
    AssertNull('no initialiser', Decl.InitConst);
  finally P.Free(); end;
end;

procedure TVarInitTests.TestParse_MultiName_WithInit_Rejected;
var Raised: Boolean;
begin
  Raised := False;
  try
    ParseProg('program X; var A, B: Integer = 1; begin end.').Free();
  except
    on E: EParseError do Raised := True;
  end;
  AssertTrue('multi-name initialiser is a parse error', Raised);
end;

{ ------------------------------------------------------------------ }
{ Semantic                                                            }
{ ------------------------------------------------------------------ }

procedure TVarInitTests.TestSemantic_TypeMismatch_StringIntoInteger_Rejected;
var Raised: Boolean;
begin
  Raised := False;
  try
    GenIR('program X; var N: Integer = ''text''; begin end.');
  except
    on E: ESemanticError do Raised := True;
  end;
  AssertTrue('string-into-Integer rejected', Raised);
end;

procedure TVarInitTests.TestSemantic_LocalInit_Rejected;
var Raised: Boolean;
begin
  Raised := False;
  try
    GenIR('program X; procedure Q; var L: Integer = 5; begin end; begin end.');
  except
    on E: ESemanticError do Raised := True;
  end;
  AssertTrue('local initialiser rejected', Raised);
end;

procedure TVarInitTests.TestSemantic_RecordInit_Rejected;
var Raised: Boolean;
begin
  { Records have no const-initialiser machinery yet; must fail cleanly,
    not silently mis-emit. }
  Raised := False;
  try
    GenIR('program X; type TR = record a: Integer; end; ' +
          'var R: TR = 0; begin end.');
  except
    on E: ESemanticError do Raised := True;
  end;
  AssertTrue('record initialiser rejected', Raised);
end;

{ ------------------------------------------------------------------ }
{ Codegen                                                             }
{ ------------------------------------------------------------------ }

procedure TVarInitTests.TestCodegen_IntegerInit_EmitsValue;
var IR: string;
begin
  IR := GenIR('program X; var G: Integer = 42; begin end.');
  AssertTrue('data slot holds 42, not 0',
    IRHas(IR, 'data $G = { w 42 }'));
end;

procedure TVarInitTests.TestCodegen_StringInit_EmitsHeaderPointer;
var IR: string;
begin
  { An initialised string global points at an immortal static header. }
  IR := GenIR('program X; var S: string = ''hi''; begin end.');
  AssertTrue('string global points at $__sN + 12',
    IRHas(IR, 'data $S = { l $__s'));
end;

procedure TVarInitTests.TestCodegen_BooleanInit_EmitsOne;
var IR: string;
begin
  IR := GenIR('program X; var B: Boolean = True; begin end.');
  AssertTrue('boolean True folds to 1',
    IRHas(IR, 'data $B = { w 1 }'));
end;

procedure TVarInitTests.TestCodegen_ArrayInit_EmitsElements;
var IR: string;
begin
  IR := GenIR('program X; var A: array[0..2] of Integer = (10, 20, 30); begin end.');
  AssertTrue('array elements inlined into the data slot',
    IRHas(IR, 'data $A = { w 10, w 20, w 30 }'));
end;

procedure TVarInitTests.TestCodegen_NoInit_StillZero;
var IR: string;
begin
  IR := GenIR('program X; var G: Integer; begin end.');
  AssertTrue('uninitialised global is still zero',
    IRHas(IR, 'data $G = { w 0 }'));
end;

initialization
  RegisterTest(TVarInitTests);

end.
