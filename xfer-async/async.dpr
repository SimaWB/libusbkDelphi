{*******************************************************}
{                                                       }
{       Asynchronously transfer example                 }
{                                                       }
{       Copyright (C) 12/2013                           }
{                                                       }
{       Author  : SimaWB                                }
{       Email   : simawb@gmail.com                      }
{                                                       }
{       http://stackoverflow.com/users/62313/simawb     }
{                                                       }
{*******************************************************}
program async;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Types,
  Windows,
  UExampleHelpers in '..\UExampleHelpers.pas',
  libusbK in '..\libusbK.pas';

const
  EP_ADDRESS              = $81;
  ASYNC_PENDING_IO_COUNT  = 3;
  ASYNC_TIMEOUT_MS        = 1000;
  DEFAULT_VID             = $0483; // Default Vendor Id
  DEFAULT_PID             = $5740; // Default Product Id

var
  Usb: KUSB_DRIVER_API;

  errorCode: DWORD;
  success: Boolean;

  deviceList: KLST_HANDLE;
  deviceInfo: KLST_DEVINFO_HANDLE;
  usbHandle: KUSB_HANDLE;
  ovlPool: KOVL_POOL_HANDLE;
  ovlArray: array[0..ASYNC_PENDING_IO_COUNT-1] of MY_IO_REQUEST;

  requestList: PMY_IO_REQUEST = nil;
  myRequest: PMY_IO_REQUEST;
  ovlIndex: DWORD;
  totalLength: LongWord;
  prmVID, prmPID: Integer;

  tmp: PMY_IO_REQUEST;

begin
  try
    prmVID := StrToIntDef(ParamStr(1), DEFAULT_VID);
    prmPID := StrToIntDef(ParamStr(2), DEFAULT_PID);

    errorcode := 0; totalLength := 0;
    try
      if not DllAvailable then
        raise Exception.Create('Dll not found!');

      if not LstK_Init(deviceList, 0) then
        raise Exception.Create('LstK_Init error');

      if not LstK_FindByVidPid(deviceList, prmVID, prmPID, deviceInfo) then
        raise Exception.Create('Device not found');

      LibK_LoadDriverAPI(Usb, deviceInfo.DriverID);

      if not Usb.Init(usbHandle, deviceInfo) then
      begin
        errorCode := GetLastError;
        raise Exception.Create('Init device failed. ErrorCode: ' + IntToHex(errorCode, 2));
      end;

      Writeln('Device opened successfully!');

      if not OvlK_Init(ovlPool, usbHandle, ASYNC_PENDING_IO_COUNT, KOVL_POOL_FLAG_NONE) then
        raise Exception.Create('OvlK_Init error. ErrorCode: ' + IntToHex(GetLastError, 2));

      ZeroMemory(@ovlArray, SizeOf(ovlArray));
      for ovlIndex := 0 to ASYNC_PENDING_IO_COUNT-1 do
      begin
        if not OvlK_Acquire(ovlArray[ovlIndex].Ovl, ovlPool) then
        begin
          errorCode := GetLastError;
          raise Exception.Create('OvlK_Acquire failed. ErrorCode: '+IntToHex(errorCode, 2));
        end;

        ovlArray[ovlIndex].Index      := ovlIndex;
        ovlArray[ovlIndex].BufferSize := SizeOf(ovlArray[ovlIndex].Buffer);

        tmp := @ovlArray[ovlIndex];
        DL_APPEND(requestList, tmp);
      end;

      myRequest := requestList;
      while myRequest^.next <> nil do
      begin
        if USB_ENDPOINT_DIRECTION_IN(EP_ADDRESS) then
          Usb.ReadPipe(usbHandle, EP_ADDRESS, myRequest^.Buffer, myRequest^.BufferSize, nil, myRequest^.Ovl)
        else
          Usb.WritePipe(usbHandle, EP_ADDRESS, myRequest^.Buffer, myRequest^.BufferSize, nil, myRequest^.Ovl);

        myRequest^.ErrorCode := GetLastError;

        if (myRequest^.ErrorCode <> ERROR_IO_PENDING) then
        begin
          errorCode := myRequest^.ErrorCode;
          Writeln(Format('Failed submitting transfer #%d for %d bytes.', [myRequest^.Index, myRequest^.BufferSize]));
          Break;
        end;

         Writeln(Format('Transfer #%d submitted for %d bytes.', [myRequest^.Index, myRequest^.BufferSize]));

         myRequest := myRequest^.next;
      end;

      myRequest := requestList;
      while myRequest^.next <> nil do
      begin
        if (myRequest^.ErrorCode = ERROR_IO_PENDING) then
        begin
          Writeln(Format('Waiting %d ms for transfer #%d to complete..', [ASYNC_TIMEOUT_MS, myRequest^.Index]));
          success := OvlK_WaitOrCancel(myRequest^.Ovl, ASYNC_TIMEOUT_MS, myRequest^.TransferLength);
          if not success then
          begin
            myRequest^.ErrorCode := GetLastError;
            errorCode := myRequest^.ErrorCode;
            Writeln(Format('Transfer #%d did not complete. ErrorCode=%s', [myRequest^.Index, IntToHex(myRequest^.ErrorCode, 2)]));
          end
          else
          begin
            myRequest^.ErrorCode := ERROR_SUCCESS;
            totalLength := totalLength + myRequest^.TransferLength;
            Writeln(Format('Transfer #%d completed with %d bytes.', [myRequest^.Index, myRequest^.TransferLength]));
          end;
        end;
        myRequest := myRequest^.next;
      end;

      if (errorCode = ERROR_SUCCESS) then
        Writeln(Format('Transferred %d bytes successfully.', [totalLength]))
      else
        Writeln(Format('Transferred %d bytes. ErrorCode=%s.', [totalLength, IntToHex(errorCode, 2)]));

    finally
      if Assigned(usbHandle) then
        Usb.Free(usbHandle);
      LstK_Free(deviceList);
      OvlK_Free(ovlPool);
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
