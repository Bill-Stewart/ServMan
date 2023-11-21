# ServMan

**ServMan** is a Windows console (text-based, command-line) program that provides a few rudimentary Windows service management functions.

## AUTHOR

Bill Stewart - bstewart at iname dot com

## LICENSE

**ServMan** is covered by the GNU Public License (GPL). See the file `LICENSE` for details.

## USAGE

Command-line parameters, except for the service name, are case-sensitive.

---

### CHECK IF SERVICE EXISTS

`ServMan` _servicename_ `--exists` [`--quiet`]

Checks whether a service exists. The exit code will be one of the following:

| Exit Code | Description
| --------- | -----------
| 0         | Service exists
| 1060      | Service does not exist

Other exit codes indicate an error.

---

### GET SERVICE STATE

`ServMan` _servicename_ `--state` [`--quiet`]

Gets the state of a service. The exit code will be one of the following:

| Exit Code | Description
| --------- | -----------
| 901       | Service is not running
| 902       | Service is starting (start pending)
| 903       | Service is stopping (stop pending)
| 904       | Service is running
| 905       | Service continue is pending
| 906       | Service pause is pending
| 907       | Service is paused

Any other exit code indicates an error.

---

### START A SERVICE

`ServMan` _servicename_ `--start` [`--timeout` _secs_] [`--quiet`]

Starts a service.

The timeout value specifies the number of seconds to wait for the service to start and can be from 0 to 43200 seconds (12 hours). The default timeout is 30 seconds.

Common exit codes are the following:

| Exit Code | Description
| --------- | -----------
| 0         | Service was started successfully
| 5         | Access denied
| 1053      | Service did not start within timeout
| 1056      | Service is already running
| 1060      | Service does not exist
| 1068      | One or more dependent services are not running

Exit code 5 is common if the logged on user isn't running as administrator.

---

### STOP A SERVICE

`ServMan` _servicename_ `--stop` [`--timeout` _secs_] [`--quiet`]

Stops a service.

The timeout value specifies the number of seconds to wait for the service to stop and can be from 0 to 43200 seconds (12 hours). The default timeout is 30 seconds.

Common exit codes are the following:

| Exit Code | Description
| --------- | -----------
| 0         | Service was stopped successfully
| 5         | Access denied
| 1051      | One or more dependent services are still running
| 1053      | Service did not stop within timeout
| 1060      | Service does not exist
| 1062      | Service is not running

Exit code 5 is common if the logged on user isn't running as administrator.

---

## REMARKS

* The _servicename_ parameter can be the internal name or display name of the service and is not case-sensitive. If the service name contains whitespace (space or tab characters), enclose it in quote characters (`"`).

* A timeout value of 0 (i.e., `--timeout 0`) specifies not to wait for the service to start or stop (i.e., **ServMan** only delivers the start or stop signal to the service).

* **ServMan** makes no attempt to resolve service dependencies when starting or stopping services:

  * If you try to start a service that has stopped dependencies, **ServMan** will return error 1068 ("The dependency service or group failed to start."). To start the service, first start the service(s) on which the service depends, then start the service.

  * If you try to stop a service on which other services depend, **ServMan** will return error 1051 ("A stop control has been sent to a service that other running services are dependent on"). To stop the service, first stop the other running service(s) that have the service as a dependency, then stop the service.

* A cmd.exe shell script (batch file) can check the exit code using the **ERRORLEVEL** environment variable (i.e., `if %ERRORLEVEL% EQU 1060 ...`).

* A PowerShell script can check the exit code using the **$LASTEXITCODE** variable (i.e., `if ( $LASTEXITCODE -eq 1060 ) { ...`).

## EXAMPLES

1. `ServMan sshd --exists`

   **ServMan** will return an exit code of 0 if the service exists; otherwise it will return an exit code of 1060.

2. `ServMan BITS --state`

   **ServMan** will return the state of the specified service.

3. `ServMan "Syncthing Service" --start`

   **ServMan** will send the start signal to the specified service, and will wait up to 30 seconds for it to start. If the service reports that it is running within that period of time, **ServMan** will return an exit code of 0; otherwise, it will return an exit code of 1053.

4. `ServMan "Bluetooth Support Service" --stop --timeout 10`

   **ServMan** will send the stop signal to the specified service, and will wait for up to 10 seconds for the service to stop. If the service reports that it is stopped within that period of time, **ServMan** will return an exit code of 0; otherwise, will return an exit code of 1053.

## VERSION HISTORY

### 0.0.1 (2023-11-21)

* Initial version.
