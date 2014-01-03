{*******************************************************}
{                                                       }
{       Synchronously transfer                          }
{                                                       }
{       Copyright (C) 12/2013                           }
{                                                       }
{       Author  : SimaWB                                }
{       Email   : simawb@gmail.com                      }
{                                                       }
{       http://stackoverflow.com/users/62313/simawb     }
{                                                       }
{*******************************************************}
program sync;

{$APPTYPE CONSOLE}

uses
  SysUtils, Types,
  UExampleHelpers in '..\UExampleHelpers.pas',
  libusbK in '..\libusbK.pas';

const
  EP_ADDRESS          = $81;
  SYNC_TRANSFER_COUNT = 3;
  DEFAULT_VID         = $0403;// Default Vendor Id
  DEFAULT_PID         = $C938;// Default Product Id

var
  Usb: KUSB_DRIVER_API;

  errorCode: DWord;
  success: Boolean;

  deviceList: KLST_HANDLE;
  deviceInfo: KLST_DEVINFO_HANDLE;
  usbHandle: KUSB_HANDLE;
  myBuffer: array[1..4096] of Byte;

  totalLength,
  transferredLength,
  transferIndex: LongWord;

  prmVID, prmPID: Integer;
begin
  prmVID := StrToIntDef(ParamStr(1), DEFAULT_VID);
  prmPID := StrToIntDef(ParamStr(2), DEFAULT_PID);

  errorcode := 0; totalLength := 0;
  try
    if not DllAvailable then
      raise Exception.Create('Dll not found!');

    try
      if not LstK_Init(deviceList, 0) then
        raise Exception.Create('LstK_Init error');

      if not LstK_FindByVidPid(deviceList, prmVID, prmPID, deviceInfo) then
        raise Exception.Create('Device not found');

      LibK_LoadDriverAPI(Usb, deviceInfo.DriverID);

      if not Usb.Init(usbHandle, deviceInfo) then
      begin
        errorCode := GetLastError;
        raise Exception.Create('Init device failed. ErrorCode: ' + Inttostr(errorCode));
      end;

      Writeln('Device opened successfully!');

      transferIndex := 0;
      while (transferIndex < SYNC_TRANSFER_COUNT) do
      begin
        if USB_ENDPOINT_DIRECTION_IN(EP_ADDRESS) then
          success := Usb.ReadPipe(usbHandle, EP_ADDRESS, myBuffer, SizeOf(myBuffer), @transferredLength, nil)
        else
          success := Usb.WritePipe(usbHandle, EP_ADDRESS, myBuffer, sizeof(myBuffer), @transferredLength, nil);

        if not success then
        begin
          errorCode := GetLastError;
          Break;
        end;

        totalLength := totalLength + transferredLength;
        Writeln(Format('Transfer #%d completed with %d bytes.', [transferIndex, transferredLength]));

        Inc(transferIndex);
      end;

      Writeln(Format('Transferred %d bytes in %d transfers. errorCode= %s',
                [totalLength, transferIndex, IntToHex(errorCode, 2)]));

    finally
      if Assigned(usbHandle) then
        Usb.Free(usbHandle);

      LstK_Free(deviceList);
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
