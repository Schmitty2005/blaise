{
  Blaise - An Object Pascal Compiler
  Copyright (c) 2026 Graeme Geldenhuys
  SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
  Licensed under the Apache License v2.0 with Runtime Library Exception.
  See LICENSE file in the project root for full license terms.
}

{ Tests for Net.Sockets: IPv4 address helpers and a loopback TCP round-trip.
  Self-registers via the initialization section. }

unit Sockets.Tests;

interface

uses
  blaise.testing, Net.Sockets;

type
  TSocketsTests = class(TTestCase)
  published
    procedure TestIPv4_Loopback;
    procedure TestIPv4_AllInterfaces;
    procedure TestParseIPv4_Valid;
    procedure TestParseIPv4_Invalid;
    procedure TestTcpRoundTrip_Local;
  end;

implementation

procedure TSocketsTests.TestIPv4_Loopback;
begin
  { IPv4(127,0,0,1) must equal the canonical INADDR_LOOPBACK constant. }
  AssertEquals('loopback', Int64(INADDR_LOOPBACK), Int64(IPv4(127, 0, 0, 1)));
end;

procedure TSocketsTests.TestIPv4_AllInterfaces;
begin
  AssertEquals('any', Int64(INADDR_ANY), Int64(IPv4(0, 0, 0, 0)));
end;

procedure TSocketsTests.TestParseIPv4_Valid;
var A: UInt32;
begin
  AssertTrue('parse ok', ParseIPv4('127.0.0.1', A));
  AssertEquals('value', Int64(IPv4(127, 0, 0, 1)), Int64(A));
  AssertTrue('parse 2', ParseIPv4('192.168.1.255', A));
  AssertEquals('value 2', Int64(IPv4(192, 168, 1, 255)), Int64(A));
end;

procedure TSocketsTests.TestParseIPv4_Invalid;
var A: UInt32;
begin
  AssertFalse('too few octets', ParseIPv4('1.2.3', A));
  AssertFalse('octet > 255',    ParseIPv4('1.2.3.256', A));
  AssertFalse('trailing dot',   ParseIPv4('1.2.3.4.', A));
  AssertFalse('letters',        ParseIPv4('a.b.c.d', A));
  AssertFalse('empty',          ParseIPv4('', A));
end;

{ A full loopback round-trip in one process: listen, connect, accept, then
  send a message client->server and read it back on the server side. }
procedure TSocketsTests.TestTcpRoundTrip_Local;
const
  PORT = 28765;
  MSG  = 'hello over tcp';
var
  Srv, Cli, Conn: Integer;
  Received: string;
begin
  Srv := TcpListenLocal(PORT, 8);
  AssertTrue('listen', Srv >= 0);

  Cli := TcpConnectLocal(PORT);
  AssertTrue('connect', Cli >= 0);

  Conn := AcceptConn(Srv);
  AssertTrue('accept', Conn >= 0);

  AssertTrue('send', SendAll(Cli, MSG));

  Received := RecvString(Conn, 256);
  AssertEquals('payload', MSG, Received);

  Close(Conn);
  Close(Cli);
  Close(Srv);
end;

initialization
  RegisterTest(TSocketsTests);

end.
