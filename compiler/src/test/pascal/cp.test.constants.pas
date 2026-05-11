{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit cp.test.constants;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, bcl.testing,
  uLexer, uParser, uAST, uSemantic, uCodeGenQBE;

type
  TConstTests = class(TTestCase)
  private
    function GenIR(const ASrc: string): string;
    function ParseUnit(const ASrc: string): TUnit;
    function IRContains(const AIR, AFragment: string): Boolean;
  published
    { Exported interface constant is visible in importing program }
    procedure TestExportedConstVisibleInProgram;
    { Integer constant in program scope }
    procedure TestIntConstInProgramScope;
    { Negative integer constant }
    procedure TestNegativeIntConst;
    { String constant in program scope }
    procedure TestStringConst;
    { Integer constant in unit interface section is parsed }
    procedure TestIntConstInUnitInterface;
    { Integer constant in unit implementation section is parsed }
    procedure TestIntConstInUnitImpl;
    { Implementation-section constant is usable in a method body in that unit }
    procedure TestImplConstUsableInMethodBody;
    { Constant used in assignment }
    procedure TestConstUsedInAssignment;
    { Constant used as WriteLn argument }
    procedure TestConstUsedInWriteLn;
    { Multiple constants in one const block }
    procedure TestMultipleConstsInBlock;
    { Two const blocks in same scope }
    procedure TestTwoConstBlocks;
    { Local constant inside a standalone procedure }
    procedure TestLocalConstInProcedure;
    { Local constant inside a standalone function }
    procedure TestLocalConstInFunction;
    { Local constant inside a class method }
    procedure TestLocalConstInMethod;
    { Constant in a class declaration section (class-level constant) }
    procedure TestConstInClassDeclaration;
  end;

implementation

function TConstTests.GenIR(const ASrc: string): string;
var
  L:  TLexer;
  P:  TParser;
  Pr: TProgram;
  A:  TSemanticAnalyser;
  CG: TCodeGenQBE;
begin
  L  := TLexer.Create(ASrc);
  P  := TParser.Create(L);
  Pr := P.Parse;
  A  := TSemanticAnalyser.Create;
  try
    A.Analyse(Pr);
  finally
    A.Free;
  end;
  CG := TCodeGenQBE.Create;
  try
    CG.Generate(Pr);
    Result := CG.GetOutput;
  finally
    CG.Free;
    Pr.Free;
    P.Free;
    L.Free;
  end;
end;

function TConstTests.ParseUnit(const ASrc: string): TUnit;
var
  L: TLexer;
  P: TParser;
begin
  L := TLexer.Create(ASrc);
  P := TParser.Create(L);
  try
    Result := P.ParseUnit;
  finally
    P.Free;
    L.Free;
  end;
end;

function TConstTests.IRContains(const AIR, AFragment: string): Boolean;
begin
  Result := Pos(AFragment, AIR) > 0;
end;

procedure TConstTests.TestExportedConstVisibleInProgram;
const
  UnitSrc =
    '''
        unit MyConsts;
        interface
        const
          dupAccept = 0;
          dupIgnore = 1;
          dupError  = 2;
        implementation
        end.
        ''';
  ProgSrc =
    '''
        program TestP;
        uses MyConsts;
        var x: Integer;
        begin
          x := dupIgnore
        end.
        ''';
var
  U:    TUnit;
  Prog: TProgram;
  SA:   TSemanticAnalyser;
  L:    TLexer;
  P:    TParser;
begin
  L := TLexer.Create(UnitSrc);
  P := TParser.Create(L);
  U := P.ParseUnit;
  P.Free; L.Free;

  L := TLexer.Create(ProgSrc);
  P := TParser.Create(L);
  Prog := P.Parse;
  P.Free; L.Free;

  SA := TSemanticAnalyser.Create;
  try
    SA.AnalyseUnitForExport(U);
    { If dupIgnore is not in global scope, Analyse will raise ESemanticError }
    SA.Analyse(Prog);
    AssertNotNull('Program should analyse without error', Prog.SymbolTable);
  finally
    SA.Free;
    Prog.Free;
    U.Free;
  end;
end;

procedure TConstTests.TestIntConstInProgramScope;
var
  IR: string;
begin
  IR := GenIR(
    '''
        program Test;
        const MaxItems = 10;
        var x: Integer;
        begin
          x := MaxItems;
        end.
        '''
  );
  AssertTrue('IR should be non-empty for program with integer const', IR <> '');
end;

procedure TConstTests.TestNegativeIntConst;
var
  IR: string;
begin
  IR := GenIR(
    '''
        program Test;
        const MinVal = -1;
        var x: Integer;
        begin
          x := MinVal;
        end.
        '''
  );
  AssertTrue('IR should be non-empty', IR <> '');
  AssertTrue('Negative const should fold to -1', IRContains(IR, '-1'));
end;

procedure TConstTests.TestStringConst;
var
  IR: string;
begin
  IR := GenIR(
    '''
        program Test;
        const AppName = 'MyApp';
        begin
          WriteLn(AppName);
        end.
        '''
  );
  AssertTrue('IR should be non-empty', IR <> '');
  AssertTrue('String const value should appear in IR', IRContains(IR, 'MyApp'));
end;

procedure TConstTests.TestIntConstInUnitInterface;
var
  U: TUnit;
begin
  U := ParseUnit(
    '''
        unit MyConsts;
        interface
        const
          dupAccept = 0;
          dupIgnore = 1;
          dupError  = 2;
        implementation
        end.
        '''
  );
  try
    AssertEquals('Interface const block should have 3 entries',
      3, U.IntfBlock.ConstDecls.Count);
    AssertEquals('First const name', 'dupAccept',
      TConstDecl(U.IntfBlock.ConstDecls.Items[0]).Name);
    AssertEquals('First const value', 0,
      TConstDecl(U.IntfBlock.ConstDecls.Items[0]).IntVal);
    AssertEquals('Second const name', 'dupIgnore',
      TConstDecl(U.IntfBlock.ConstDecls.Items[1]).Name);
    AssertEquals('Third const name', 'dupError',
      TConstDecl(U.IntfBlock.ConstDecls.Items[2]).Name);
    AssertEquals('Third const value', 2,
      TConstDecl(U.IntfBlock.ConstDecls.Items[2]).IntVal);
  finally
    U.Free;
  end;
end;

procedure TConstTests.TestIntConstInUnitImpl;
var
  U: TUnit;
begin
  U := ParseUnit(
    '''
        unit MyConsts;
        interface
        implementation
        const
          InternalVal = 42;
        end.
        '''
  );
  try
    AssertEquals('Impl const block should have 1 entry',
      1, U.ImplBlock.ConstDecls.Count);
    AssertEquals('Impl const name', 'InternalVal',
      TConstDecl(U.ImplBlock.ConstDecls.Items[0]).Name);
    AssertEquals('Impl const value', 42,
      TConstDecl(U.ImplBlock.ConstDecls.Items[0]).IntVal);
  finally
    U.Free;
  end;
end;

procedure TConstTests.TestImplConstUsableInMethodBody;
const
  UnitSrc =
    '''
        unit Checker;
        interface
        function GetLimit: Integer;
        implementation
        const
          Limit = 99;
        function GetLimit: Integer;
        begin
          Result := Limit
        end;
        end.
        ''';
var
  U:  TUnit;
  SA: TSemanticAnalyser;
begin
  U  := ParseUnit(UnitSrc);
  SA := TSemanticAnalyser.Create;
  try
    { AnalyseUnitForExport raises ESemanticError if Limit is not resolved }
    SA.AnalyseUnitForExport(U);
    AssertNotNull('Unit should analyse without error', U);
  finally
    SA.Free;
    U.Free;
  end;
end;

procedure TConstTests.TestConstUsedInAssignment;
var
  IR: string;
begin
  IR := GenIR(
    '''
        program Test;
        const Limit = 5;
        var x: Integer;
        begin
          x := Limit;
        end.
        '''
  );
  AssertTrue('IR should be non-empty', IR <> '');
  AssertTrue('Const value should appear in IR', IRContains(IR, '5'));
end;

procedure TConstTests.TestConstUsedInWriteLn;
var
  IR: string;
begin
  IR := GenIR(
    '''
        program Test;
        const ErrCode = 42;
        begin
          WriteLn(ErrCode);
        end.
        '''
  );
  AssertTrue('IR should be non-empty', IR <> '');
  AssertTrue('Constant value should appear in IR', IRContains(IR, '42'));
end;

procedure TConstTests.TestMultipleConstsInBlock;
var
  IR: string;
begin
  IR := GenIR(
    '''
        program Test;
        const
          A = 1;
          B = 2;
          C = 3;
        var x: Integer;
        begin
          x := A;
        end.
        '''
  );
  AssertTrue('IR should be non-empty', IR <> '');
end;

procedure TConstTests.TestTwoConstBlocks;
var
  IR: string;
begin
  IR := GenIR(
    '''
        program Test;
        const First = 10;
        var x: Integer;
        const Second = 20;
        begin
          x := First + Second;
        end.
        '''
  );
  AssertTrue('IR should be non-empty', IR <> '');
end;

procedure TConstTests.TestLocalConstInProcedure;
var
  IR: string;
begin
  IR := GenIR(
    '''
        program Test;
        procedure DoWork;
        const Threshold = 7;
        var x: Integer;
        begin
          x := Threshold
        end;
        begin
          DoWork
        end.
        '''
  );
  AssertTrue('IR should be non-empty', IR <> '');
  AssertTrue('Local const value should appear in IR', IRContains(IR, '7'));
end;

procedure TConstTests.TestLocalConstInFunction;
var
  IR: string;
begin
  IR := GenIR(
    '''
        program Test;
        function Compute: Integer;
        const Base = 100;
        begin
          Result := Base
        end;
        var r: Integer;
        begin
          r := Compute
        end.
        '''
  );
  AssertTrue('IR should be non-empty', IR <> '');
  AssertTrue('Local const value should appear in IR', IRContains(IR, '100'));
end;

procedure TConstTests.TestLocalConstInMethod;
var
  IR: string;
begin
  IR := GenIR(
    '''
        program Test;
        type
          TFoo = class
            function Bar: Integer;
          end;
        function TFoo.Bar: Integer;
        const Magic = 55;
        begin
          Result := Magic
        end;
        var f: TFoo;
        begin
          f := TFoo.Create;
          WriteLn(f.Bar);
          f.Free
        end.
        '''
  );
  AssertTrue('IR should be non-empty', IR <> '');
  AssertTrue('Local const value should appear in IR', IRContains(IR, '55'));
end;

procedure TConstTests.TestConstInClassDeclaration;
var
  IR: string;
begin
  IR := GenIR(
    '''
        program Test;
        type
          TFoo = class
          const
            MaxItems = 100;
          var
            FCount: Integer;
          end;
        var x: Integer;
        begin
          x := TFoo.MaxItems
        end.
        '''
  );
  AssertTrue('IR should be non-empty', IR <> '');
  AssertTrue('Class const value should appear in IR', IRContains(IR, '100'));
end;

initialization
  RegisterTest(TConstTests);

end.
