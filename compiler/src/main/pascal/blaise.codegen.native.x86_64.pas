{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

unit blaise.codegen.native.x86_64;

{ x86_64 (System V AMD64 ABI) backend for the native code generator.

  Emits AT&T-syntax assembly text (fed to `as`/`cc`, like QBE's .s output).

  Expression evaluation strategy (naive, correctness-first): every integer
  expression is evaluated into %eax.  Binary operators evaluate the left
  operand into %eax, push it, evaluate the right operand into %eax, pop the
  left into %ecx, then combine.  This needs no register allocator and is
  correct for arbitrary nesting; the push/pop pairs are always balanced within
  one expression, so %rsp is back to its frame-aligned position at every call
  site (SysV requires 16-byte alignment at calls).

  Milestone M2: integer literals, + - * div mod, and Write/WriteLn of integers
  (mapped to the _SysWriteInt / _SysWriteNewline runtime calls). }

interface

uses
  SysUtils, contnrs, uAST, uSymbolTable,
  blaise.codegen.native.backend, blaise.codegen.target;

type
  TX86_64Backend = class(TNativeBackend)
  protected
    FLabelCount: Integer;   { monotonic source of unique local labels }

    { Allocate a fresh local assembly label (".L<prefix><N>"). }
    function NewLabel(const APrefix: string): string;

    procedure EmitProgram(AProg: TProgram); override;
    { Lower one statement. }
    procedure EmitStmt(AStmt: TASTStmt);
    { Lower a Write/WriteLn call (ANewline = WriteLn). }
    procedure EmitWrite(ACall: TProcCall; ANewline: Boolean);
    { Evaluate an integer expression; result left in %eax. }
    procedure EmitExprToEax(AExpr: TASTExpr);
    { Evaluate a boolean condition and branch: if true jump ATrueLabel, else
      fall through to AFalseLabel (a jmp is emitted to it). }
    procedure EmitCondBranch(AExpr: TASTExpr;
                             const ATrueLabel, AFalseLabel: string);
  public
    constructor Create(const ATarget: TTargetDesc); override;
  end;

implementation

constructor TX86_64Backend.Create(const ATarget: TTargetDesc);
begin
  inherited Create(ATarget);
  FLabelCount := 0;
end;

function TX86_64Backend.NewLabel(const APrefix: string): string;
begin
  Result := '.L' + APrefix + IntToStr(FLabelCount);
  Inc(FLabelCount);
end;

{ ------------------------------------------------------------------ }
{ Expression lowering                                                  }
{ ------------------------------------------------------------------ }

procedure TX86_64Backend.EmitExprToEax(AExpr: TASTExpr);
var
  BE: TBinaryExpr;
begin
  if AExpr is TIntLiteral then
  begin
    Self.Emit(Format(#9'movl $%d, %%eax', [TIntLiteral(AExpr).Value]));
    Exit;
  end;

  if AExpr is TBinaryExpr then
  begin
    BE := TBinaryExpr(AExpr);
    { left -> %eax, save; right -> %eax; left -> %ecx; combine. }
    Self.EmitExprToEax(BE.Left);
    Self.Emit(#9'pushq %rax');
    Self.EmitExprToEax(BE.Right);
    Self.Emit(#9'movl %eax, %ecx');   { right in %ecx }
    Self.Emit(#9'popq %rax');          { left in %eax }
    case BE.Op of
      boAdd: Self.Emit(#9'addl %ecx, %eax');
      boSub: Self.Emit(#9'subl %ecx, %eax');
      boMul: Self.Emit(#9'imull %ecx, %eax');
      boDiv:
        begin
          { signed 32-bit divide: sign-extend %eax into %edx:%eax, idiv %ecx,
            quotient in %eax. }
          Self.Emit(#9'cltd');
          Self.Emit(#9'idivl %ecx');
        end;
      boMod:
        begin
          Self.Emit(#9'cltd');
          Self.Emit(#9'idivl %ecx');
          Self.Emit(#9'movl %edx, %eax');  { remainder in %edx }
        end;
      { Signed integer comparisons -> boolean 0/1 in %eax.  AT&T `cmpl B, A`
        computes A - B, so with left in %eax and right in %ecx, `cmpl %ecx,
        %eax` sets flags for (left ? right); setcc then yields the 0/1. }
      boEQ, boNE, boLT, boGT, boLE, boGE:
        begin
          Self.Emit(#9'cmpl %ecx, %eax');
          case BE.Op of
            boEQ: Self.Emit(#9'sete %al');
            boNE: Self.Emit(#9'setne %al');
            boLT: Self.Emit(#9'setl %al');
            boGT: Self.Emit(#9'setg %al');
            boLE: Self.Emit(#9'setle %al');
            boGE: Self.Emit(#9'setge %al');
          end;
          Self.Emit(#9'movzbl %al, %eax');  { zero-extend the byte result }
        end;
    else
      raise ENativeCodeGenError.Create(
        'native backend: unsupported binary operator in integer expression');
    end;
    Exit;
  end;

  raise ENativeCodeGenError.Create(
    'native backend: unsupported expression form ' + AExpr.ClassName);
end;

procedure TX86_64Backend.EmitCondBranch(AExpr: TASTExpr;
                                        const ATrueLabel, AFalseLabel: string);
begin
  { Evaluate the condition to a 0/1 (or any nonzero=true) value in %eax, then
    branch.  testl sets ZF when %eax is zero. }
  Self.EmitExprToEax(AExpr);
  Self.Emit(#9'testl %eax, %eax');
  Self.Emit(#9'jne ' + ATrueLabel);
  Self.Emit(#9'jmp ' + AFalseLabel);
end;

{ ------------------------------------------------------------------ }
{ Statement lowering                                                   }
{ ------------------------------------------------------------------ }

procedure TX86_64Backend.EmitWrite(ACall: TProcCall; ANewline: Boolean);
var
  I:       Integer;
  ArgExpr: TASTExpr;
begin
  { One _SysWriteInt(fd=1, value) per integer argument; then a trailing
    newline for WriteLn.  M2 handles integer arguments only. }
  for I := 0 to ACall.Args.Count - 1 do
  begin
    ArgExpr := TASTExpr(ACall.Args.Items[I]);
    Self.EmitExprToEax(ArgExpr);     { value -> %eax }
    Self.Emit(#9'movl %eax, %esi');  { arg2 = value }
    Self.Emit(#9'movl $1, %edi');    { arg1 = fd (stdout) }
    Self.Emit(#9'callq _SysWriteInt');
  end;
  if ANewline then
  begin
    Self.Emit(#9'movl $1, %edi');    { fd = stdout }
    Self.Emit(#9'callq _SysWriteNewline');
  end;
end;

procedure TX86_64Backend.EmitStmt(AStmt: TASTStmt);
var
  PC:    TProcCall;
  Comp:  TCompoundStmt;
  IfS:   TIfStmt;
  WhileS: TWhileStmt;
  RepS:  TRepeatStmt;
  I:     Integer;
  LThen, LElse, LEnd:    string;
  LCond, LBody:          string;
begin
  if AStmt is TProcCall then
  begin
    PC := TProcCall(AStmt);
    if SameText(PC.Name, 'WriteLn') then
    begin
      Self.EmitWrite(PC, True);
      Exit;
    end;
    if SameText(PC.Name, 'Write') then
    begin
      Self.EmitWrite(PC, False);
      Exit;
    end;
    raise ENativeCodeGenError.Create(
      'native backend: unsupported procedure call ' + PC.Name);
  end;

  if AStmt is TCompoundStmt then
  begin
    Comp := TCompoundStmt(AStmt);
    for I := 0 to Comp.Stmts.Count - 1 do
      Self.EmitStmt(TASTStmt(Comp.Stmts.Items[I]));
    Exit;
  end;

  if AStmt is TIfStmt then
  begin
    IfS   := TIfStmt(AStmt);
    LThen := Self.NewLabel('then');
    LEnd  := Self.NewLabel('ifend');
    if IfS.ElseStmt <> nil then
      LElse := Self.NewLabel('else')
    else
      LElse := LEnd;
    Self.EmitCondBranch(IfS.Condition, LThen, LElse);
    Self.Emit(LThen + ':');
    Self.EmitStmt(IfS.ThenStmt);
    Self.Emit(#9'jmp ' + LEnd);
    if IfS.ElseStmt <> nil then
    begin
      Self.Emit(LElse + ':');
      Self.EmitStmt(IfS.ElseStmt);
      Self.Emit(#9'jmp ' + LEnd);
    end;
    Self.Emit(LEnd + ':');
    Exit;
  end;

  if AStmt is TWhileStmt then
  begin
    WhileS := TWhileStmt(AStmt);
    LCond  := Self.NewLabel('wcond');
    LBody  := Self.NewLabel('wbody');
    LEnd   := Self.NewLabel('wend');
    Self.Emit(LCond + ':');
    Self.EmitCondBranch(WhileS.Condition, LBody, LEnd);
    Self.Emit(LBody + ':');
    Self.EmitStmt(WhileS.Body);
    Self.Emit(#9'jmp ' + LCond);
    Self.Emit(LEnd + ':');
    Exit;
  end;

  if AStmt is TRepeatStmt then
  begin
    RepS  := TRepeatStmt(AStmt);
    LBody := Self.NewLabel('rbody');
    LEnd  := Self.NewLabel('rend');
    Self.Emit(LBody + ':');
    for I := 0 to RepS.Body.Stmts.Count - 1 do
      Self.EmitStmt(TASTStmt(RepS.Body.Stmts.Items[I]));
    { repeat exits when the condition is TRUE: branch true->end, false->body. }
    Self.EmitCondBranch(RepS.Condition, LEnd, LBody);
    Self.Emit(LEnd + ':');
    Exit;
  end;

  raise ENativeCodeGenError.Create(
    'native backend: unsupported statement ' + AStmt.ClassName);
end;

{ Emit the program entry function.

  The Blaise runtime expects an exported `main(argc, argv)` returning int.  It
  must call $_SetArgs(argc, argv) before any program code, then run the body,
  then return 0.  This mirrors the QBE backend's $main shape (see the QBE IR
  for an empty program).

  The body statements are lowered between the _SetArgs call and the return-0
  epilogue.  After `pushq %rbp` the stack is 16-byte aligned, and expression
  evaluation balances its push/pop pairs, so %rsp stays aligned at every call
  site. }
procedure TX86_64Backend.EmitProgram(AProg: TProgram);
var
  I: Integer;
begin
  Self.Emit('.text');
  Self.Emit('.globl main');
  Self.Emit('main:');
  { Prologue: establish a frame.  argc is in %edi, argv in %rsi per SysV. }
  Self.Emit(#9'pushq %rbp');
  Self.Emit(#9'movq %rsp, %rbp');
  { _SetArgs(argc, argv): args already in %edi/%rsi — pass through. }
  Self.Emit(#9'callq _SetArgs');
  { Program body. }
  for I := 0 to AProg.Block.Stmts.Count - 1 do
    Self.EmitStmt(TASTStmt(AProg.Block.Stmts.Items[I]));
  { Epilogue: return 0. }
  Self.Emit(#9'movl $0, %eax');
  Self.Emit(#9'leave');
  Self.Emit(#9'ret');
  Self.Emit('.type main, @function');
  { Mark the stack non-executable (matches QBE output). }
  Self.Emit('.section .note.GNU-stack,"",@progbits');
end;

end.
