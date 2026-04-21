unit cp.test.interfaces;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, fpcunit, testregistry,
  uLexer, uParser, uAST, uSymbolTable, uSemantic, uCodeGenQBE;

type
  TInterfaceTests = class(TTestCase)
  private
    function ParseSrc(const ASrc: string): TProgram;
    function AnalyseSrc(const ASrc: string): TProgram;
    function GenIR(const ASrc: string): string;
    procedure AnalyseExpectError(const ASrc: string);
  published
    { ------------------------------------------------------------------ }
    { Parser                                                               }
    { ------------------------------------------------------------------ }
    procedure TestParse_Interface_Empty;
    procedure TestParse_Interface_WithMethods;
    procedure TestParse_Interface_WithParent;
    procedure TestParse_Class_ImplementsInterface;
    procedure TestParse_Class_ImplementsMultiple;

    { ------------------------------------------------------------------ }
    { Semantic                                                             }
    { ------------------------------------------------------------------ }
    procedure TestSemantic_Interface_Registered;
    procedure TestSemantic_Interface_IsInterfaceKind;
    procedure TestSemantic_Interface_MethodsRegistered;
    procedure TestSemantic_ClassImplements_OK;
    procedure TestSemantic_ClassImplements_MissingMethod_RaisesError;

    { ------------------------------------------------------------------ }
    { Code generation                                                      }
    { ------------------------------------------------------------------ }
    procedure TestCodegen_Interface_TypeInfo_Emitted;
    procedure TestCodegen_Class_Itab_Emitted;
    procedure TestCodegen_Itab_ContainsMethodPointer;
    procedure TestCodegen_InterfaceVar_AllocsTwoSlots;
    procedure TestCodegen_InterfaceMethodCall_IndirectDispatch;
  end;

implementation

const
  SrcInterfaceEmpty =
    'program P;'                + LineEnding +
    'type'                      + LineEnding +
    '  IFoo = interface'        + LineEnding +
    '  end;'                    + LineEnding +
    'begin'                     + LineEnding +
    'end.';

  SrcInterfaceWithMethods =
    'program P;'                        + LineEnding +
    'type'                              + LineEnding +
    '  IFoo = interface'                + LineEnding +
    '    procedure DoIt;'               + LineEnding +
    '    function GetVal: Integer;'     + LineEnding +
    '  end;'                            + LineEnding +
    'begin'                             + LineEnding +
    'end.';

  SrcInterfaceWithParent =
    'program P;'                    + LineEnding +
    'type'                          + LineEnding +
    '  IBase = interface'           + LineEnding +
    '    procedure Base;'           + LineEnding +
    '  end;'                        + LineEnding +
    '  IChild = interface(IBase)'   + LineEnding +
    '    procedure Child;'          + LineEnding +
    '  end;'                        + LineEnding +
    'begin'                         + LineEnding +
    'end.';

  SrcClassImplements =
    'program P;'                               + LineEnding +
    'type'                                     + LineEnding +
    '  IFoo = interface'                       + LineEnding +
    '    procedure DoIt;'                      + LineEnding +
    '    function GetVal: Integer;'            + LineEnding +
    '  end;'                                   + LineEnding +
    '  TFoo = class(TObject, IFoo)'            + LineEnding +
    '    procedure DoIt;'                      + LineEnding +
    '    function GetVal: Integer;'            + LineEnding +
    '  end;'                                   + LineEnding +
    'procedure TFoo.DoIt;'                     + LineEnding +
    'begin'                                    + LineEnding +
    'end;'                                     + LineEnding +
    'function TFoo.GetVal: Integer;'           + LineEnding +
    'begin'                                    + LineEnding +
    '  Result := 42'                           + LineEnding +
    'end;'                                     + LineEnding +
    'begin'                                    + LineEnding +
    'end.';

  SrcClassImplementsMultiple =
    'program P;'                               + LineEnding +
    'type'                                     + LineEnding +
    '  IFoo = interface'                       + LineEnding +
    '    procedure DoIt;'                      + LineEnding +
    '  end;'                                   + LineEnding +
    '  IBar = interface'                       + LineEnding +
    '    procedure DoBar;'                     + LineEnding +
    '  end;'                                   + LineEnding +
    '  TFoo = class(TObject, IFoo, IBar)'      + LineEnding +
    '    procedure DoIt;'                      + LineEnding +
    '    procedure DoBar;'                     + LineEnding +
    '  end;'                                   + LineEnding +
    'procedure TFoo.DoIt;'                     + LineEnding +
    'begin'                                    + LineEnding +
    'end;'                                     + LineEnding +
    'procedure TFoo.DoBar;'                    + LineEnding +
    'begin'                                    + LineEnding +
    'end;'                                     + LineEnding +
    'begin'                                    + LineEnding +
    'end.';

  SrcClassMissingMethod =
    'program P;'                               + LineEnding +
    'type'                                     + LineEnding +
    '  IFoo = interface'                       + LineEnding +
    '    procedure DoIt;'                      + LineEnding +
    '  end;'                                   + LineEnding +
    '  TFoo = class(TObject, IFoo)'            + LineEnding +
    '  end;'                                   + LineEnding +
    'begin'                                    + LineEnding +
    'end.';

  SrcInterfaceVar =
    'program P;'                               + LineEnding +
    'type'                                     + LineEnding +
    '  IFoo = interface'                       + LineEnding +
    '    procedure DoIt;'                      + LineEnding +
    '  end;'                                   + LineEnding +
    '  TFoo = class(TObject, IFoo)'            + LineEnding +
    '    procedure DoIt;'                      + LineEnding +
    '  end;'                                   + LineEnding +
    'procedure TFoo.DoIt;'                     + LineEnding +
    'begin'                                    + LineEnding +
    'end;'                                     + LineEnding +
    'var'                                      + LineEnding +
    '  F: IFoo;'                               + LineEnding +
    '  T: TFoo;'                               + LineEnding +
    'begin'                                    + LineEnding +
    '  T := TFoo.Create;'                      + LineEnding +
    '  F := T;'                                + LineEnding +
    '  F.DoIt'                                 + LineEnding +
    'end.';

{ ------------------------------------------------------------------ }
{ Helpers                                                             }
{ ------------------------------------------------------------------ }

function TInterfaceTests.ParseSrc(const ASrc: string): TProgram;
var
  L: TLexer;
  P: TParser;
begin
  L := TLexer.Create(ASrc);
  P := TParser.Create(L);
  try
    Result := P.Parse;
  finally
    P.Free;
    L.Free;
  end;
end;

function TInterfaceTests.AnalyseSrc(const ASrc: string): TProgram;
var
  SA: TSemanticAnalyser;
begin
  Result := ParseSrc(ASrc);
  SA     := TSemanticAnalyser.Create;
  try
    SA.Analyse(Result);
  finally
    SA.Free;
  end;
end;

function TInterfaceTests.GenIR(const ASrc: string): string;
var
  CG: TCodeGenQBE;
  Prog: TProgram;
begin
  Prog := AnalyseSrc(ASrc);
  CG   := TCodeGenQBE.Create;
  try
    CG.Generate(Prog);
    Result := CG.GetOutput;
  finally
    CG.Free;
    Prog.Free;
  end;
end;

procedure TInterfaceTests.AnalyseExpectError(const ASrc: string);
var
  Prog: TProgram;
  SA:   TSemanticAnalyser;
begin
  Prog := ParseSrc(ASrc);
  SA   := TSemanticAnalyser.Create;
  try
    try
      SA.Analyse(Prog);
      Fail('Expected ESemanticError but none was raised');
    except
      on E: ESemanticError do
        { expected };
    end;
  finally
    SA.Free;
    Prog.Free;
  end;
end;

{ ------------------------------------------------------------------ }
{ Parser tests                                                         }
{ ------------------------------------------------------------------ }

procedure TInterfaceTests.TestParse_Interface_Empty;
var
  Prog: TProgram;
  TD:   TTypeDecl;
begin
  Prog := ParseSrc(SrcInterfaceEmpty);
  try
    AssertEquals('one type decl', 1, Prog.Block.TypeDecls.Count);
    TD := TTypeDecl(Prog.Block.TypeDecls[0]);
    AssertEquals('name is IFoo', 'IFoo', TD.Name);
    AssertTrue('def is TInterfaceTypeDef', TD.Def is TInterfaceTypeDef);
  finally
    Prog.Free;
  end;
end;

procedure TInterfaceTests.TestParse_Interface_WithMethods;
var
  Prog: TProgram;
  ITD:  TInterfaceTypeDef;
begin
  Prog := ParseSrc(SrcInterfaceWithMethods);
  try
    ITD := TInterfaceTypeDef(TTypeDecl(Prog.Block.TypeDecls[0]).Def);
    AssertEquals('two methods', 2, ITD.Methods.Count);
    AssertEquals('first method DoIt',   'DoIt',   TMethodDecl(ITD.Methods[0]).Name);
    AssertEquals('second method GetVal','GetVal',  TMethodDecl(ITD.Methods[1]).Name);
  finally
    Prog.Free;
  end;
end;

procedure TInterfaceTests.TestParse_Interface_WithParent;
var
  Prog:  TProgram;
  Child: TInterfaceTypeDef;
begin
  Prog := ParseSrc(SrcInterfaceWithParent);
  try
    Child := TInterfaceTypeDef(TTypeDecl(Prog.Block.TypeDecls[1]).Def);
    AssertEquals('parent is IBase', 'IBase', Child.ParentName);
  finally
    Prog.Free;
  end;
end;

procedure TInterfaceTests.TestParse_Class_ImplementsInterface;
var
  Prog: TProgram;
  CD:   TClassTypeDef;
begin
  Prog := ParseSrc(SrcClassImplements);
  try
    { type decl index 0 = IFoo, index 1 = TFoo }
    CD := TClassTypeDef(TTypeDecl(Prog.Block.TypeDecls[1]).Def);
    AssertEquals('one implements name', 1, CD.ImplementsNames.Count);
    AssertEquals('implements IFoo', 'IFoo', CD.ImplementsNames[0]);
  finally
    Prog.Free;
  end;
end;

procedure TInterfaceTests.TestParse_Class_ImplementsMultiple;
var
  Prog: TProgram;
  CD:   TClassTypeDef;
begin
  Prog := ParseSrc(SrcClassImplementsMultiple);
  try
    { type decl indices 0=IFoo, 1=IBar, 2=TFoo }
    CD := TClassTypeDef(TTypeDecl(Prog.Block.TypeDecls[2]).Def);
    AssertEquals('two implements names', 2, CD.ImplementsNames.Count);
    AssertEquals('first is IFoo', 'IFoo', CD.ImplementsNames[0]);
    AssertEquals('second is IBar', 'IBar', CD.ImplementsNames[1]);
  finally
    Prog.Free;
  end;
end;

{ ------------------------------------------------------------------ }
{ Semantic tests                                                       }
{ ------------------------------------------------------------------ }

procedure TInterfaceTests.TestSemantic_Interface_Registered;
var
  Prog: TProgram;
  Sym:  TSymbol;
begin
  Prog := AnalyseSrc(SrcInterfaceWithMethods);
  try
    Sym := Prog.SymbolTable.Lookup('IFoo');
    AssertNotNull('IFoo symbol exists', Sym);
    AssertEquals('IFoo is skType', Ord(skType), Ord(Sym.Kind));
  finally
    Prog.Free;
  end;
end;

procedure TInterfaceTests.TestSemantic_Interface_IsInterfaceKind;
var
  Prog: TProgram;
  TD:   TTypeDesc;
begin
  Prog := AnalyseSrc(SrcInterfaceWithMethods);
  try
    TD := Prog.SymbolTable.FindType('IFoo');
    AssertNotNull('IFoo type exists', TD);
    AssertEquals('kind is tyInterface', Ord(tyInterface), Ord(TD.Kind));
  finally
    Prog.Free;
  end;
end;

procedure TInterfaceTests.TestSemantic_Interface_MethodsRegistered;
var
  Prog: TProgram;
  ITD:  TInterfaceTypeDesc;
begin
  Prog := AnalyseSrc(SrcInterfaceWithMethods);
  try
    ITD := TInterfaceTypeDesc(Prog.SymbolTable.FindType('IFoo'));
    AssertTrue('has DoIt',   ITD.HasMethod('DoIt'));
    AssertTrue('has GetVal', ITD.HasMethod('GetVal'));
  finally
    Prog.Free;
  end;
end;

procedure TInterfaceTests.TestSemantic_ClassImplements_OK;
var
  Prog: TProgram;
begin
  Prog := AnalyseSrc(SrcClassImplements);
  try
    { No exception = success }
    AssertNotNull('prog not nil', Prog);
  finally
    Prog.Free;
  end;
end;

procedure TInterfaceTests.TestSemantic_ClassImplements_MissingMethod_RaisesError;
begin
  AnalyseExpectError(SrcClassMissingMethod);
end;

{ ------------------------------------------------------------------ }
{ Codegen tests                                                        }
{ ------------------------------------------------------------------ }

procedure TInterfaceTests.TestCodegen_Interface_TypeInfo_Emitted;
var
  IR: string;
begin
  IR := GenIR(SrcClassImplements);
  AssertTrue('typeinfo_IFoo in IR', Pos('$typeinfo_IFoo', IR) > 0);
end;

procedure TInterfaceTests.TestCodegen_Class_Itab_Emitted;
var
  IR: string;
begin
  IR := GenIR(SrcClassImplements);
  AssertTrue('itab_TFoo_IFoo in IR', Pos('$itab_TFoo_IFoo', IR) > 0);
end;

procedure TInterfaceTests.TestCodegen_Itab_ContainsMethodPointer;
var
  IR:      string;
  ItabPos: Integer;
begin
  IR := GenIR(SrcClassImplements);
  ItabPos := Pos('$itab_TFoo_IFoo', IR);
  AssertTrue('itab present', ItabPos > 0);
  AssertTrue('TFoo_DoIt appears after itab label',
    PosEx('$TFoo_DoIt', IR, ItabPos) > 0);
end;

procedure TInterfaceTests.TestCodegen_InterfaceVar_AllocsTwoSlots;
var
  IR: string;
begin
  IR := GenIR(SrcInterfaceVar);
  AssertTrue('obj slot for F', Pos('_var_F_obj', IR) > 0);
  AssertTrue('itab slot for F', Pos('_var_F_itab', IR) > 0);
end;

procedure TInterfaceTests.TestCodegen_InterfaceMethodCall_IndirectDispatch;
var
  IR: string;
begin
  IR := GenIR(SrcInterfaceVar);
  { Interface dispatch loads the itab pointer and calls indirectly }
  AssertTrue('loads itab pointer', Pos('_var_F_itab', IR) > 0);
  AssertTrue('indirect call via register', Pos('call %', IR) > 0);
end;

initialization
  RegisterTest(TInterfaceTests);

end.
