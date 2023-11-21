{ Copyright (C) 2023 by Bill Stewart (bstewart at iname.com)

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the Free
  Software Foundation; either version 3 of the License, or (at your option) any
  later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
  details.

  You should have received a copy of the GNU Lesser General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

program ServMan;

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}
{$R *.res}

// wargcv and wgetopts units: https://github.com/Bill-Stewart/wargcv
uses
  windows,
  wargcv,
  wgetopts,
  wsMessage,
  wsUtil,
  wsService;

const
  PROGRAM_NAME = 'ServMan';
  PROGRAM_COPYRIGHT = 'Copyright (C) 2023 by Bill Stewart';
  SERVICE_TIMEOUT_DEFAULT_SECONDS = 30;
  SERVICE_STATE_BASE_EXITCODE = 900;
  CMD_NONE = $00;
  CMD_ENUM = $01;
  CMD_EXISTS = $02;
  CMD_STATE = $04;
  CMD_START = $08;
  CMD_STOP = $10;

type
  TCommandLine = object
    Error: DWORD;
    Help: Boolean;
    Quiet: Boolean;
    Flags: Integer;
    Timeout: Integer;
    ServiceName: string;
    procedure Parse();
  end;

procedure TCommandLine.Parse();
var
  Opts: array[1..10] of TOption;
  I: Integer;
  Opt: Char;
  LongOptName: string;
begin
  with Opts[1] do
  begin
    Name := 'help';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  with Opts[2] do
  begin
    Name := 'enum';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  with Opts[3] do
  begin
    Name := 'exists';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  with Opts[4] do
  begin
    Name := 'start';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  with Opts[5] do
  begin
    Name := 'stop';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  with Opts[6] do
  begin
    Name := 'state';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  with Opts[7] do
  begin
    Name := 'status';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  with Opts[8] do
  begin
    Name := 'timeout';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := #0;
  end;
  with Opts[9] do
  begin
    Name := 'quiet';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  with Opts[10] do
  begin
    Name := '';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  Error := ERROR_SUCCESS;
  Help := false;
  Quiet := false;
  Flags := CMD_NONE;
  Timeout := SERVICE_TIMEOUT_DEFAULT_SECONDS;
  ServiceName := '';
  OptErr := false;
  repeat
    Opt := GetLongOpts('', @Opts[1], I);
    if Opt = #0 then
    begin
      LongOptName := Opts[I].Name;
      case LongOptName of
        'help': Help := true;
        'enum': Flags := Flags or CMD_ENUM;
        'exists': Flags := Flags or CMD_EXISTS;
        'state': Flags := Flags or CMD_STATE;
        'status': Flags := Flags or CMD_STATE;
        'start': Flags := Flags or CMD_START;
        'stop': Flags := Flags or CMD_STOP;
        'quiet': Quiet := true;
        'timeout':
        begin
          if StrToInt(OptArg, Timeout) then
          begin
            if (Timeout < 0) or (Timeout > SERVICE_TIMEOUT_MAX_SECONDS) then
              Error := ERROR_INVALID_PARAMETER;
          end
          else
            Error := ERROR_INVALID_PARAMETER;
        end;
      end;
    end;
  until Opt = EndOfOptions;
  ServiceName := ParamStr(OptInd);
  if CountBits(Flags) > 1 then
    Error := ERROR_INVALID_PARAMETER;
end;

procedure Usage();
begin
  WriteLn(PROGRAM_NAME, ' ', GetFileVersion(ParamStr(0)), ' - ', PROGRAM_COPYRIGHT);
  WriteLn('This is free software and comes with ABSOLUTELY NO WARRANTY.');
  WriteLn();
  WriteLn('SYNOPSIS');
  WriteLn();
  WriteLn('Provides a few rudimentary Windows service management functions.');
  WriteLn();
  WriteLn('USAGE');
  WriteLn();
  WriteLn(PROGRAM_NAME, ' <servicename> --exists [--quiet]');
  WriteLn('* Checks whether a service exists.');
  WriteLn('* Exit code will be 0 if the service exists, or 1060 if it does not exist.');
  WriteLn();
  WriteLn(PROGRAM_NAME, ' <servicename> --state [--quiet]');
  WriteLn('* Gets the state of a service.');
  WriteLn('* Exit code will be one of the following:');
  WriteLn('  901 - Service is not running (stopped)');
  WriteLn('  902 - Service is starting (start pending)');
  WriteLn('  903 - Service is stopping (stop pending)');
  WriteLn('  904 - Service is running');
  WriteLn('  905 - Service continue is pending');
  WriteLn('  906 - Service pause is pending');
  WriteLn('  907 - Service is paused');
  WriteLn('  Any other exit code indicates an error.');
  WriteLn();
  WriteLn(PROGRAM_NAME, ' <servicename> --start [--timeout <secs>] [--quiet]');
  WriteLn('* Starts a service.');
  WriteLn('* The timeout value can be from 0 to ', SERVICE_TIMEOUT_MAX_SECONDS,
    ' seconds.');
  WriteLn('* The default timeout is ', SERVICE_TIMEOUT_DEFAULT_SECONDS, ' seconds.');
  WriteLn('* Exit code will be zero for success, or non-zero for error.');
  WriteLn();
  WriteLn(PROGRAM_NAME, ' <servicename> --stop [--timeout <secs>] [--quiet]');
  WriteLn('* Stops a service.');
  WriteLn('* The timeout value can be from 0 to ', SERVICE_TIMEOUT_MAX_SECONDS,
    ' seconds.');
  WriteLn('* The default timeout is ', SERVICE_TIMEOUT_DEFAULT_SECONDS, ' seconds.');
  WriteLn('* Exit code will be zero for success, or non-zero for error.');
  WriteLn();
  WriteLn('The --quiet parameter suppresses output.');
end;

var
  RC, I: DWORD;
  CmdLine: TCommandLine;
  Services: TServiceList;
  Service: TService;

begin
  RC := ERROR_SUCCESS;

  CmdLine.Parse();

  if CmdLine.Help or (CmdLine.Flags = CMD_NONE) then
  begin
    Usage();
    exit;
  end;
  if CmdLine.Error <> ERROR_SUCCESS then
  begin
    WriteLn(GetWindowsMessage(CmdLine.Error, true));
    ExitCode := LongInt(CmdLine.Error);
    exit;
  end;

  // Undocumented troubleshooting function - enumerate services of type
  // SERVICE_WIN32_OWN_PROCESS and SERVICE_WIN32_SHARE_PROCESS, output as CSV
  if (CmdLine.Flags and CMD_ENUM) <> 0 then
  begin
    RC := wsGetServices(Services);
    if RC = 0 then
    begin
      WriteLn('"Name","DisplayName","State"');
      for I := 0 to Length(Services) - 1 do
      begin
        WriteLn('"', Services[I].Name, '","', Services[I].DisplayName,
          '","', Services[I].State, '"');
      end;
    end
    else
    begin
      WriteLn(GetWindowsMessage(RC, true));
      ExitCode := LongInt(RC);
    end;
    exit;
  end;

  if CmdLine.ServiceName = '' then
  begin
    ExitCode := ERROR_INVALID_PARAMETER;
    WriteLn(GetWindowsMessage(ExitCode, true));
    exit;
  end;

  // Return non-zero if can't get service
  RC := wsGetService(CmdLine.ServiceName, Service);
  if RC <> 0 then
  begin
    if not CmdLine.Quiet then
      WriteLn(GetWindowsMessage(RC, true));
    ExitCode := LongInt(RC);
    exit;
  end;

  // --exists
  if (CmdLine.Flags and CMD_EXISTS) <> 0 then
  begin
    if not CmdLine.Quiet then
      WriteLn('Found service ', Service.Name, ' (', Service.DisplayName, ')');
  end;

  // --state or --status
  if (CmdLine.Flags and CMD_STATE) <> 0 then
  begin
    ExitCode := SERVICE_STATE_BASE_EXITCODE + LongInt(Service.State);
    if not CmdLine.Quiet then
      WriteLn('Service "', Service.DisplayName, '": ', Service.State);
    exit;
  end;

  // --start
  if (CmdLine.Flags and CMD_START) <> 0 then
  begin
    if not CmdLine.Quiet then
      Write('Service "', Service.DisplayName, '": ');
    RC := wsStartService(Service.Name, CmdLine.Timeout);
    if RC = 0 then
    begin
      if not CmdLine.Quiet then
      begin
        if CmdLine.Timeout = 0 then
          WriteLn('Start signal sent')
        else
          WriteLn('Started');
      end;
      exit;
    end;
  end;

  // --stop
  if (CmdLine.Flags and CMD_STOP) <> 0 then
  begin
    if not CmdLine.Quiet then
      Write('Service "', Service.DisplayName, '": ');
    RC := wsStopService(Service.Name, CmdLine.Timeout);
    if RC = 0 then
    begin
      if not CmdLine.Quiet then
      begin
        if CmdLine.Timeout = 0 then
          WriteLn('Stop signal sent')
        else
          WriteLn('Stopped');
      end;
      exit;
    end;
  end;

  if RC <> 0 then
  begin
    ExitCode := LongInt(RC);
    if not CmdLine.Quiet then
      WriteLn(GetWindowsMessage(RC, true));
  end;

end.
