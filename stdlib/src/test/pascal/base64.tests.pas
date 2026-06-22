{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

{ Tests for Encoding.Base64.  Self-registers via the initialization section. }

unit Base64.Tests;

interface

uses
  blaise.testing, Encoding.Base64;

type
  TBase64Tests = class(TTestCase)
  published
    procedure TestEncode_KnownVectors;
    procedure TestEncode_Empty;
    procedure TestDecode_KnownVectors;
    procedure TestDecode_IgnoresWhitespace;
    procedure TestRoundTrip;
  end;

implementation

procedure TBase64Tests.TestEncode_KnownVectors;
begin
  { RFC 4648 test vectors. }
  AssertEquals('f',      'Zg==',     Base64Encode('f'));
  AssertEquals('fo',     'Zm8=',     Base64Encode('fo'));
  AssertEquals('foo',    'Zm9v',     Base64Encode('foo'));
  AssertEquals('foob',   'Zm9vYg==', Base64Encode('foob'));
  AssertEquals('fooba',  'Zm9vYmE=', Base64Encode('fooba'));
  AssertEquals('foobar', 'Zm9vYmFy', Base64Encode('foobar'));
  AssertEquals('Man',    'TWFu',     Base64Encode('Man'));
end;

procedure TBase64Tests.TestEncode_Empty;
begin
  AssertEquals('empty', '', Base64Encode(''));
end;

procedure TBase64Tests.TestDecode_KnownVectors;
begin
  AssertEquals('Zg==',     'f',      Base64Decode('Zg=='));
  AssertEquals('Zm8=',     'fo',     Base64Decode('Zm8='));
  AssertEquals('Zm9v',     'foo',    Base64Decode('Zm9v'));
  AssertEquals('Zm9vYmFy', 'foobar', Base64Decode('Zm9vYmFy'));
end;

procedure TBase64Tests.TestDecode_IgnoresWhitespace;
begin
  { Newlines/spaces in wrapped Base64 are ignored. }
  AssertEquals('wrapped', 'foobar', Base64Decode('Zm9v' + #10 + 'YmFy'));
end;

procedure TBase64Tests.TestRoundTrip;
var s: string;
begin
  s := 'The quick brown fox jumps over the lazy dog.';
  AssertEquals('roundtrip', s, Base64Decode(Base64Encode(s)));
end;

initialization
  RegisterTest(TBase64Tests);

end.
