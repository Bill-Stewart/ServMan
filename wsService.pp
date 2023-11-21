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

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}

unit wsService;

interface

const
  SERVICE_TIMEOUT_MAX_SECONDS = 43200;  // 12 hours

type
  // Enumerated type values must be in ascending order
  TServiceState = (
    Stopped = 1,          // SERVICE_STOPPED
    StartPending = 2,     // SERVICE_START_PENDING
    StopPending = 3,      // SERVICE_STOP_PENDING
    Running = 4,          // SERVICE_RUNNING
    ContinuePending = 5,  // SERVICE_CONTINUE_PENDING
    PausePending = 6,     // SERVICE_PAUSE_PENDING
    Paused = 7            // SERVICE_PAUSED
    );
  TService = record
    Name: string;
    DisplayName: string;
    State: TServiceState;
  end;
  TServiceList = array of TService;

// Gets array of services; returns 0 for success, or non-zero for failure
function wsGetServices(var Services: TServiceList): DWORD;

// Gets a service by name; returns 0 for success, or non-zero for failure
function wsGetService(const ServiceName: string; var Service: TService): DWORD;

// Returns true if service exists, or false otherwise
function wsServiceExists(const ServiceName: string): Boolean;

// Gets service state; returns 0 for success, or non-zero for failure
function wsGetServiceState(const ServiceName: string; var State: TServiceState): DWORD;

// Stops service; if service not stopped within the specified number of
// timeout seconds, returns ERROR_SERVICE_REQUEST_TIMEOUT; returns 0 for
// success, or non-zero for failure
function wsStopService(const ServiceName: string; const TimeoutSecs: DWORD): DWORD;

// Starts service; if service not started within the specified number of
// timeout seconds, returns ERROR_SERVICE_REQUEST_TIMEOUT; returns 0 for
// success, or non-zero for failure
function wsStartService(const ServiceName: string; const TimeoutSecs: DWORD): DWORD;

implementation

uses
  Windows;

const
  SERVICE_WAIT_INTERVAL_MILLISECONDS = 500;

// Uses EnumServicesStatusW to retrieve a dynamic array of TService objects
function wsGetServices(var Services: TServiceList): DWORD;
type
  PENUM_SERVICE_STATUSW = ^ENUM_SERVICE_STATUSW;
const
  SC_MANAGER_ENUMERATE = SC_MANAGER_CONNECT or SC_MANAGER_ENUMERATE_SERVICE;
  SERVICE_STATE_ALL = SERVICE_ACTIVE or SERVICE_INACTIVE;
  SERVICE_ENUM_MAX_BUF_SIZE = 65536;
var
  BytesNeeded, NumServices, ResumeHandle, BufSize, N, I: DWORD;
  SCManager: SC_HANDLE;
  pServices, pStatus: PENUM_SERVICE_STATUSW;
  Done: Boolean;
begin
  SCManager := OpenSCManagerW(nil,  // LPCWSTR lpMachineName
    nil,                            // LPCWSTR lpDatabaseName
    SC_MANAGER_ENUMERATE);          // DWORD   dwDesiredAccess
  if SCManager = 0 then
  begin
    result := GetLastError();
    exit;
  end;
  // Initial call: Get buffer size needed
  EnumServicesStatusW(SCManager,  // SC_HANDLE              hSCManager
    SERVICE_WIN32,                // DWORD                  dwServiceType
    SERVICE_STATE_ALL,            // DWORD                  dwServiceState
    nil,                          // LPENUM_SERVICE_STATUSW lpServices
    0,                            // DWORD                  cbBufSize
    @BytesNeeded,                 // LPDWORD                pcbBytesNeeded
    @NumServices,                 // LPDWORD                lpServicesReturned
    @ResumeHandle);               // LPDWORD                lpResumeHandle
  result := GetLastError();
  // GetLastError() = ERROR_MORE_DATA is normal case
  if result <> ERROR_MORE_DATA then
    exit;
  result := 0;
  // API specifies buffer size limit
  if BytesNeeded > SERVICE_ENUM_MAX_BUF_SIZE then
    BufSize := SERVICE_ENUM_MAX_BUF_SIZE
  else
    BufSize := BytesNeeded;
  // First enumeration: Count total number of services
  N := 0;
  ResumeHandle := 0;
  repeat
    GetMem(pServices, BufSize);
    Done := EnumServicesStatusW(SCManager,  // SC_HANDLE              hSCManager
      SERVICE_WIN32,                        // DWORD                  dwServiceType
      SERVICE_STATE_ALL,                    // DWORD                  dwServiceState
      pServices,                            // LPENUM_SERVICE_STATUSW lpServices
      BufSize,                              // DWORD                  cbBufSize
      @BytesNeeded,                         // LPDWORD                pcbBytesNeeded
      @NumServices,                         // LPDWORD                lpServicesReturned
      @ResumeHandle);                       // LPDWORD                lpResumeHandle
    Done := Done or (GetLastError() <> ERROR_MORE_DATA);
    Inc(N, NumServices);
    FreeMem(pServices);
  until Done;
  // Set dynamic array size
  SetLength(Services, N);
  // Second enumeration: Populate dynamic array
  N := 0;
  ResumeHandle := 0;
  repeat
    GetMem(pServices, BufSize);
    Done := EnumServicesStatusW(SCManager,  // SC_HANDLE              hSCManager
      SERVICE_WIN32,                        // DWORD                  dwServiceType
      SERVICE_STATE_ALL,                    // DWORD                  dwServiceState
      pServices,                            // LPENUM_SERVICE_STATUSW lpServices
      BufSize,                              // DWORD                  cbBufSize
      @BytesNeeded,                         // LPDWORD                pcbBytesNeeded
      @NumServices,                         // LPDWORD                lpServicesReturned
      @ResumeHandle);                       // LPDWORD                lpResumeHandle
    Done := Done or (GetLastError() <> ERROR_MORE_DATA);
    pStatus := pServices;
    for I := 0 to NumServices - 1 do
    begin
      Services[N].Name := pStatus^.lpServiceName;
      Services[N].DisplayName := pStatus^.lpDisplayName;
      Services[N].State := TServiceState(pStatus^.ServiceStatus.dwCurrentState);
      Inc(N);
      Inc(pStatus);
    end;
    FreeMem(pServices);
  until Done;
  CloseServiceHandle(SCManager);  // SC_HANDLE hSCObject
end;

function SameText(const S1, S2: string): Boolean;
const
  CSTR_EQUAL = 2;
begin
  result := CompareStringW(GetThreadLocale(),  // LCID    Locale
    LINGUISTIC_IGNORECASE,                     // DWORD   dwCmpFlags
    PChar(S1),                                 // PCNZWCH lpString1
    -1,                                        // int     cchCount1
    PChar(S2),                                 // PCNZWCH lpString2
    -1) = CSTR_EQUAL;                          // int     cchCount2
end;

function wsGetService(const ServiceName: string; var Service: TService): DWORD;
var
  Services: TServiceList;
  I: DWORD;
begin
  result := wsGetServices(Services);
  if result <> ERROR_SUCCESS then
    exit;
  for I := 0 to Length(Services) - 1 do
  begin
    if SameText(ServiceName, Services[I].Name) or SameText(ServiceName, Services[I].DisplayName) then
    begin
      Service := Services[I];
      exit;
    end;
  end;
  result := ERROR_SERVICE_DOES_NOT_EXIST;
end;

function wsServiceExists(const ServiceName: string): Boolean;
var
  SCManager, Service: SC_HANDLE;
begin
  result := false;
  SCManager := OpenSCManagerW(nil,  // LPCWSTR lpMachineName
    nil,                            // LPCWSTR lpDatabaseName
    SC_MANAGER_CONNECT);            // DWORD   dwDesiredAccess
  if SCManager <> 0 then
  begin
    Service := OpenServiceW(SCManager,  // SC_HANDLE hSCManager
      PChar(ServiceName),               // LPCWSTR   lpServiceName
      SERVICE_QUERY_STATUS);            // DWORD     dwDesiredAccess
    result := Service <> 0;
    if result then
      CloseServiceHandle(Service);  // SC_HANDLE hSCObject
    CloseServiceHandle(SCManager);  // SC_HANDLE hSCObject
  end;
end;

function wsGetServiceState(const ServiceName: string; var State: TServiceState): DWORD;
var
  Service: TService;
begin
  result := wsGetService(ServiceName, Service);
  if result <> 0 then
    exit;
  State := Service.State;
end;

function wsStopService(const ServiceName: string; const TimeoutSecs: DWORD): DWORD;
var
  SCManager, Service: SC_HANDLE;
  Status: SERVICE_STATUS;
  WaitTime: DWORD;
  State: TServiceState;
begin
  if TimeoutSecs > SERVICE_TIMEOUT_MAX_SECONDS then
  begin
    result := ERROR_INVALID_PARAMETER;
    exit;
  end;
  SCManager := OpenSCManagerW(nil,  // LPCWSTR lpMachineName
    nil,                            // LPCWSTR lpDatabaseName
    SC_MANAGER_CONNECT);            // DWORD   dwDesiredAccess
  if SCManager = 0 then
  begin
    result := GetLastError();
    exit;
  end;
  result := ERROR_SUCCESS;
  Service := OpenServiceW(SCManager,  // SC_HANDLE hSCManager
    PChar(ServiceName),               // LPCWSTR   lpServiceName
    SERVICE_ALL_ACCESS);              // DWORD     dwDesiredAccess
  if Service <> 0 then
  begin
    if ControlService(Service,  // SC_HANDLE        hService
      SERVICE_CONTROL_STOP,     // DWORD            dwControl
      Status) then              // LPSERVICE_STATUS lpServiceStatus
    begin
      if TimeoutSecs > 0 then
      begin
        WaitTime := 0;
        repeat
          Sleep(SERVICE_WAIT_INTERVAL_MILLISECONDS);
          Inc(WaitTime, SERVICE_WAIT_INTERVAL_MILLISECONDS);
          if QueryServiceStatus(Service,  // SC_HANDLE        hService
            Status) then                  // LPSERVICE_STATUS lpServiceStatus
          begin
            State := TServiceState(Status.dwCurrentState);
          end
          else
          begin
            result := GetLastError();
            break;
          end;
          if WaitTime > TimeoutSecs * 1000 then
          begin
            result := ERROR_SERVICE_REQUEST_TIMEOUT;
            break;
          end;
        until State = Stopped;
      end;
    end
    else
      result := GetLastError();
    CloseServiceHandle(Service);  // SC_HANDLE hSCObject
  end
  else
    result := GetLastError();
  CloseServiceHandle(SCManager);  // SC_HANDLE hSCObject
end;

function wsStartService(const ServiceName: string; const TimeoutSecs: DWORD): DWORD;
var
  SCManager, Service: SC_HANDLE;
  WaitTime: DWORD;
  Status: SERVICE_STATUS;
  State: TServiceState;
begin
  if TimeoutSecs > SERVICE_TIMEOUT_MAX_SECONDS then
  begin
    result := ERROR_INVALID_PARAMETER;
    exit;
  end;
  result := ERROR_SUCCESS;
  SCManager := OpenSCManagerW(nil,  // LPCWSTR lpMachineName
    nil,                            // LPCWSTR lpDatabaseName
    SC_MANAGER_CONNECT);            // DWORD   dwDesiredAccess
  if SCManager = 0 then
  begin
    result := GetLastError();
    exit;
  end;
  Service := OpenServiceW(SCManager,  // SC_HANDLE hSCManager
    PChar(ServiceName),               // LPCWSTR   lpServiceName
    SERVICE_ALL_ACCESS);              // DWORD     dwDesiredAccess
  if Service <> 0 then
  begin
    if StartServiceW(Service,  // SC_HANDLE hService
      0,                       // DWORD     dwNumServiceArgs
      nil) then                // LPCWSTR   *lpServiceArgVectors
    begin
      if TimeoutSecs > 0 then
      begin
        WaitTime := 0;
        repeat
          Sleep(SERVICE_WAIT_INTERVAL_MILLISECONDS);
          Inc(WaitTime, SERVICE_WAIT_INTERVAL_MILLISECONDS);
          if QueryServiceStatus(Service,  // SC_HANDLE        hService
            Status) then                  // LPSERVICE_STATUS lpServiceStatus
          begin
            State := TServiceState(Status.dwCurrentState);
          end
          else
          begin
            result := GetLastError();
            break;
          end;
          if WaitTime > TimeoutSecs * 1000 then
          begin
            result := ERROR_SERVICE_REQUEST_TIMEOUT;
            break;
          end;
        until State = Running;
      end;
    end
    else
      result := GetLastError();
    CloseServiceHandle(Service);  // SC_HANDLE hSCObject
  end
  else
    result := GetLastError();
  CloseServiceHandle(SCManager);  // SC_HANDLE hSCObject
end;

begin
end.
