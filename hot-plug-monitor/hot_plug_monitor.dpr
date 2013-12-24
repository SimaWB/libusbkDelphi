{*******************************************************}
{                                                       }
{       Hot-plug monitor                                }
{                                                       }
{       Copyright (C) 12/2013                           }
{                                                       }
{       Author  : SimaWB                                }
{       Email   : simawb@gmail.com                      }
{                                                       }
{       http://stackoverflow.com/users/62313/simawb     }
{                                                       }
{*******************************************************}
program hot_plug_monitor;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Windows,
  libusbK in '..\libusbK.pas';

const
  QuitKey = $51; //Virtual key code of "q"

var
  errorCode: DWORD = ERROR_SUCCESS;
  hotHandle: KHOT_HANDLE = nil;
  hotParams: KHOT_PARAMS;

function KeyPressed(ExpectedKey: Word):Boolean;
var lpNumberOfEvents: DWORD;
    lpBuffer: TInputRecord;
    lpNumberOfEventsRead : DWORD;
    nStdHandle: THandle;
begin
  result := false;
  nStdHandle := GetStdHandle(STD_INPUT_HANDLE);
  lpNumberOfEvents := 0;
  GetNumberOfConsoleInputEvents(nStdHandle,lpNumberOfEvents);
  if lpNumberOfEvents<>0 then begin
    PeekConsoleInput(nStdHandle,lpBuffer,1,lpNumberOfEventsRead);
    if lpNumberOfEventsRead<>0 then
      if lpBuffer.EventType=KEY_EVENT then
        if lpBuffer.Event.KeyEvent.bKeyDown and
           ((ExpectedKey=0) or (lpBuffer.Event.KeyEvent.wVirtualKeyCode=ExpectedKey)) then
          result := true else
          FlushConsoleInputBuffer(nStdHandle) else
        FlushConsoleInputBuffer(nStdHandle);
  end;
end;

procedure OnHotPlug(Handle: KHOT_HANDLE; DeviceInfo: KLST_DEVINFO_HANDLE;
  NotificationType: KLST_SYNC_FLAG); stdcall;
var
  NotificationTypeStr: string;
begin
  if NotificationType = KLST_SYNC_FLAG_ADDED then
    NotificationTypeStr := 'ARRIVAL'
  else
    NotificationTypeStr := 'REMOVAL';
  Writeln(Format(
    '[%s] %s (%s) [%s]'#13#10+
    '  InstanceID          : %s'#13#10+
    '  DeviceInterfaceGUID : %s'#13#10+
    '  DevicePath          : %s'#13#10,
    [NotificationTypeStr,
    DeviceInfo.DeviceDesc,
    DeviceInfo.Mfg,
    DeviceInfo.Service,
    DeviceInfo.Common.InstanceID,
    DeviceInfo.DeviceInterfaceGUID,
    DeviceInfo.DevicePath]));
end;

begin
  try
    FillChar(hotParams, SizeOf(hotParams), 0);
    hotParams.OnHotPlug := OnHotPlug;
    hotParams.Flags := hotParams.Flags or KHOT_FLAG_PLUG_ALL_ON_INIT;

    StrCopy(hotParams.PatternMatch.DeviceInterfaceGUID, '{53906475-A5A1-23C2-43C9-79CE0E44AD83}');

    Writeln('Initialize a HotK device notification event monitor.');
    Writeln('Looking for "DeviceInterfaceGUID"s matching the pattern :', hotParams.PatternMatch.DeviceInterfaceGUID);

    // Initializes a new HotK handle.
    if not HotK_Init(hotHandle, @hotParams) then
    begin
        errorCode := GetLastError();
        Writeln('HotK_Init failed. ErrorCode: %.8Xh\n',  errorCode);
        Halt(errorCode);
    end;

    Writeln('HotK monitor initialized successfully!');
    Writeln('Press "q" to exit...'#13#10);


    while not KeyPressed(QuitKey) do
      Sleep(100);

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
