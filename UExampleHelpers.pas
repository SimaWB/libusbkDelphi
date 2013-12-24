unit UExampleHelpers;

interface

uses
  SysUtils, Classes, Windows, libusbK;

const
  USB_ENDPOINT_DIRECTION_MASK = $80;

type
  PMY_IO_REQUEST = ^MY_IO_REQUEST;
  MY_IO_REQUEST = record
    Ovl: KOVL_HANDLE;
    Index: DWORD;
    ErrorCode: DWORD;
    BufferSize: DWORD;
    Buffer: array[1..64] of Byte;
    TransferLength: DWORD;

    prev: PMY_IO_REQUEST;
    next: PMY_IO_REQUEST;
  end;


function USB_ENDPOINT_DIRECTION_IN(Addr: Byte): Boolean;

procedure DL_APPEND(var aCurrentItem, aNewItem: PMY_IO_REQUEST);

// ListLibusbKDevices return the DevicePathes of all found devices.
// If the given VID/PID is >= 0 then only matching devices returned
procedure ListLibusbKDevices(const ADeviceList : TStrings; const AVID :Integer = -1; const APID : Integer = -1);

implementation

procedure ListLibusbKDevices(const ADeviceList : TStrings; const AVID :Integer = -1; const APID : Integer = -1);
var
  deviceCount : Cardinal;
  lDeviceList : KLST_HANDLE;
  lDeviceInfo : KLST_DEVINFO_HANDLE;
  vidmatch, pidmatch : Boolean;
begin
  if not Assigned(ADeviceList) then Exit;
  if not DllAvailable then Exit;
  deviceCount := 0;
  lDeviceList := Nil;
  lDeviceInfo := Nil;
  // Get the device list
  if (not LstK_Init(lDeviceList, 0)) then Exit;
  try
    LstK_Count(lDeviceList, deviceCount);
    if (deviceCount = 0) then Exit; // List is freed in finally
    while LstK_MoveNext(lDeviceList, lDeviceInfo) do
    begin
      if Assigned(lDeviceInfo) then
      begin
        if AVID < 0 then
          vidmatch := True
        else
          vidmatch := (lDeviceInfo.Common.Vid = AVID);
        if APID < 0 then
          pidmatch := True
        else
          pidmatch := (lDeviceInfo.Common.Pid = APID);
        if vidmatch and pidmatch then
          ADeviceList.Add(lDeviceInfo.DevicePath);
      end;
    end;
  finally
    // If lDeviceList is still assigned than free
    if Assigned(lDeviceList) then
      LstK_Free(lDeviceList);
  end;
end;

function USB_ENDPOINT_DIRECTION_IN(Addr: Byte): Boolean;
begin
  Result := (Addr and USB_ENDPOINT_DIRECTION_MASK) <> 0;
end;

procedure DL_APPEND(var aCurrentItem, aNewItem: PMY_IO_REQUEST);
begin
  if aCurrentItem = nil then
    aCurrentItem := aNewItem
  else
    DL_APPEND(aCurrentItem^.Next, aNewItem);
end;

end.
