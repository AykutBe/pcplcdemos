unit Connect;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ComCtrls, StdCtrls, Spin, Menus,ShellApi, ExtCtrls,Math;

type
  TConnectForm = class
  private
    { Private declarations }
  public
    { Public declarations }
    passwordOk:boolean;
    procedure Disconnect(Handle:HWND; var Text:string);
    procedure SetupConnection(Handle:HWND; var Text:string);
    function ShowStatus(Status:Integer; LastOpr:string):string;
    function GetMode:Integer;
    procedure Start;
    function GetChannelConnected : boolean;
    function Connection(Handle:HWND; var Text:string) : boolean;
  end;

var
  ConnectForm: TConnectForm;

type
  MyPChar=Array[0..63] of Char;
  TReserved=Array[0..83] of Byte;

  CWORD        =  word;
  CDWORD       =  Cardinal;
  CSHORT       =  SmallInt;
  CBOOL        =  LongBool;
  CCHAR        =  MyPChar;
  pPcdConn     = ^Cardinal;
  pPCDOPENDATA = ^PCDOPENDATA;
  pREQSTATION  = ^REQSTATION;

  REQSTATION =  record     //@Field Complete station number information <t REQSTATION>
   SbusStation:   CWORD;   //@Field S-Bus station number
   FdlStation :   CWORD;   //@Field Profi-S-Bus station number
   TcpPort    :   CWORD;   //@Field Tcp port number
   IpAddress  :   CDWORD;  //@Field Ip address<nl>format "1.2.3.4" = 0x01020304
  end;

  PCDOPENDATA  =  record
   Port        :  CSHORT;	//Port number TAPI,RAS,COMx,SOCKET <t enumComPort>
   Device      :  CSHORT;   //COM port number or Socket Port.
   bPguMode    :  CBOOL; 	//TRUE=using PGU mode (S-BUS/P800)
   SbusMode    :  CDWORD;	//S-BUS mode: <t enumSBusModes>
   Protocol    :  CDWORD;	//Type of protocol, <t enumProtocol>
   BaudRate    :  CDWORD;	//110..38400 <t enumBaudRate>
   TsDelay     :  CDWORD;   //S-BUS training sequence delay, mS
   TnDelay     :  CDWORD;	//S-BUS turnaround time, mS
   Timeout     :  CDWORD;	//S-BUS timeout in mS
   BreakLen    :  CDWORD;	//S-BUS break length in chars, PCD_BREAK mode
   UartFifoLen :  CDWORD; 	//Number of characters in UART Fifo buffer (to wait for RTS)
   bDontClose  :  CBOOL;  	//Do not close the port.
   bPortOpen   :  CBOOL;	//The port is open.
   bConnected  :  CBOOL;	//The port is connected with the function PcdConnectChannel

   // connection
   dwType      :  CDWORD;	//Channel type.
   Channel     :  CCHAR;	//string[64];   //Channel name 'PGU'.
   Section     :  CCHAR;	//string[64];	 //Name of the section in INI file or Registry
   ModeToTry   :  CDWORD;	//Mode to connect, <t enumSBusModesToTry>
   Cpu         :  CDWORD;	//CPU number: 0..6
   bAutoStn    :  CBOOL;	//TRUE=send "read S-BUS station" telegram
   Retry       :  CDWORD;	//Retry count, default = 3

   // for TAPI, RAS or Socket
   DeviceName  :  CCHAR;	//string[64];	 //TAPI, RAS or Socket IP Address device name.

   // TAPI connection
   bUseModem   :  CBOOL;	//Use dialing (TAPI modem).
   bAutoAnswer :  CBOOL;	//Open the TAPI port in AutoAnswer mode.
   PhoneNumber :  CCHAR;	//string[64];	 //Phone number for TAPI or RAS dialing.
   CountryCode :  CDWORD;	//Country code (Switzerland 41).
   AreaCode    :  CDWORD;	//Area code (Morat 26).
   Location    :  CCHAR;	//string[64];	 //Location name.
   bUseDialing :  CBOOL;	//Use dialing (translate phone number).
   DialRetry   :  CDWORD;	//Number of retry when dialing.

   // Bues Connection
   bBues       :  CBOOL;	//Bues flag

   // password dialog box parent window
   hPWDlgParentWnd   :  HWND;	 //Parent window for password dialog box <t PcdSetParentWnd>.

   //station
   ReqStation  :  REQSTATION;
   SrcSap      :  CSHORT;	//@Field Source service access point for Profi-S-Bus communication
   DstSap      :  CSHORT;	//@Field Destination service access point for Profi-S-Bus communication
   BDstSap     :  CSHORT;	//@Field Broadcast Destination service access point for Profi-S-Bus communication
   Reserved    :  TReserved;   //Reserved for future extension
  end;

type
  lpDataType = Array [0..49] of Cardinal;
  lpDataDB = Array [0..1005] of Cardinal;
var
  mOpenData   : PCDOPENDATA;
  lpData      : lpDataType;
  lpDB        : lpDataDB;
  PcdConn     : Cardinal;
  respons     : integer;
  lpLength    : lpDataType;

//C:\Program Files\SAIA-Burgess\PG5\
//init-exit
function PcdInitInterface():boolean;stdcall; external 'ScommDll.dll' name 'PcdInitInterface';
function PcdComUnloadDrv(unload:boolean):integer;stdcall; external 'ScommDll.dll' name 'PcdComUnloadDrv';
procedure PcdExitInterface;stdcall; external 'ScommDll.dll' name 'PcdExitInterface';
function PcdPoll(PcdConn :Cardinal):integer;stdcall; external 'ScommDll.dll' name 'PcdPoll';
//service
function PcdClear(PcdConn:Cardinal;Typ:Char):integer;stdcall; external 'ScommDll.dll' name 'PcdClear';
function PcdRun(PcdConn:Cardinal; Cpu:Cardinal):integer;stdcall; external 'ScommDll.dll' name 'PcdRun';
function PcdStop(PcdConn:Cardinal;Cpu:Cardinal):integer;stdcall; external 'ScommDll.dll' name 'PcdStop';
function PcdRestart(PcdConn:Cardinal; Cpu, WarmCold:Cardinal):integer;stdcall; external 'ScommDll.dll' name 'PcdRestart';
//setup
function PcdRdChanSetupFromIni( szIniName , szAppName:MyPChar;lpOpenData:pPCDOPENDATA):integer;stdcall; external 'ScommDll.dll' name 'PcdRdChanSetupFromIni';
function PcdWrChanSetupToIni  ( szIniName , szAppName:MyPChar;const lpOpenData:pPCDOPENDATA):integer;stdcall; external 'ScommDll.dll' name 'PcdWrChanSetupToIni';
function PcdConnectionDialog(hParentWnd:HWND; lpOpenData:pPCDOPENDATA):integer;stdcall; external 'ScommUsr.dll' name 'PcdConnectionDialog';
function PcdChannelList(hParentWnd:HWND; lpOpenData:pPCDOPENDATA):integer;stdcall; external 'ScommUsr.dll' name 'PcdChannelList';
//connect-disconnect
function PcdConnectChannel(lpPcdConn:pPcdConn; lpOpenData:pPCDOPENDATA; dwFlags : Cardinal; hCallbackWnd:HWND):integer;stdcall; external 'ScommDll.dll' name 'PcdConnectChannel';
function PcdDisconnectChannel(PcdConn ,  dwFlags:Cardinal; hCallbackWnd:HWND):integer;stdcall; external 'ScommDll.dll' name 'PcdDisconnectChannel';
function PcdComOpen(lpPcdConn:pPcdConn; lpOpenData : pPCDOPENDATA; dwFlags:Cardinal; hCallbackWnd:HWND):integer;stdcall; external 'ScommDll.dll' name 'PcdComOpen';
function PcdComClose(PcdConn : Cardinal; dwFlags : Cardinal;  hCallbackWnd:HWND):integer;stdcall; external 'ScommDll.dll' name 'PcdComClose';
function PcdGetPortName(lpOpenData:pPCDOPENDATA; lpszName :PChar; MaxNameSize: Cardinal):integer;stdcall; external 'ScommDll.dll' name 'PcdGetPortName';
function PcdGetBaudrateName(lpOpenData:pPCDOPENDATA; lpszName :PChar; MaxNameSize: Cardinal):integer;stdcall; external 'ScommDll.dll' name 'PcdGetBaudrateName';
function PcdGetOpenData(PcdConn : Cardinal; lpOpenData:pPCDOPENDATA):integer;stdcall; external 'ScommDll.dll' name 'PcdGetOpenData';
//read-write res
function PcdRdRTC(PcdConn:Cardinal; Typ:Char; Address, Count:Cardinal; lpData:lpDataType):integer;stdcall; external 'ScommDll.dll' name 'PcdRdRTC';
function PcdWrRTC(PcdConn:Cardinal; Typ:Char; Address, Count:Cardinal; lpData:lpDataType):integer;stdcall; external 'ScommDll.dll' name 'PcdWrRTC';
function PcdRdIOF(PcdConn:Cardinal; Typ:Char; Address, Count:Cardinal; lpData:PChar):integer;stdcall; external 'ScommDll.dll' name 'PcdRdIOF';
function PcdWrOF (PcdConn:Cardinal; Typ:Char; Address, Count:Cardinal; lpData:PChar):integer;stdcall; external 'ScommDll.dll' name 'PcdWrOF';
function PcdMessage(Status:integer):PChar;stdcall; external 'ScommDll.dll' name 'PcdMessage';
function PcdSetClockDialog(PcdConn:Cardinal; hParentWnd:HWND):integer;stdcall; external 'ScommUsr.dll' name 'PcdSetClockDialog';
function PcdRdEEPROM(PcdConn:Cardinal; Address, Count:Cardinal; lpData:lpDataType):integer;stdcall; external 'ScommDll.dll' name 'PcdRdEEPROM';
function PcdWrEEPROM(PcdConn:Cardinal;  Address, Data:Cardinal):integer;stdcall; external 'ScommDll.dll' name 'PcdWrEEPROM';
//station
function PcdRdStation(PcdConn:Cardinal; Station:lpDataType):integer;stdcall; external 'ScommDll.dll' name 'PcdRdStation';
function PcdWrStation(PcdConn:Cardinal; Station:Cardinal):integer;stdcall; external 'ScommDll.dll' name 'PcdWrStation';
function PcdSetStation(PcdConn:Cardinal; Station:Cardinal):integer;stdcall; external 'ScommDll.dll' name 'PcdSetStation';
//extra
function PcdRdText(PcdConn:Cardinal; Number:Cardinal; lpLength:lpDataType; lpData:PChar):integer;stdcall; external 'ScommDll.dll' name 'PcdRdText';
{function PcdWrText not working yet!}
function PcdWrText(PcdConn:Cardinal; Number, Size:Cardinal; lpszText:PChar):integer;stdcall; external 'ScommDll.dll' name 'PcdWrText';
function PcdRdTextChar(PcdConn:Cardinal; Number, Offset:Cardinal; lpLength:lpDataType; lpData:PChar):integer;stdcall; external 'ScommDll.dll' name 'PcdRdTextChar';
function PcdWrTextChar(PcdConn:Cardinal; Number, Offset, Size:Cardinal; lpszText:PChar):integer;stdcall; external 'ScommDll.dll' name 'PcdWrTextChar';
//data blocks
function PcdRdDBItem(PcdConn:Cardinal; Number, Item:Cardinal; lpItems: lpDataType; lpData:lpDataDB):integer;stdcall; external 'ScommDll.dll' name 'PcdRdDBItem';
function PcdRdDB(PcdConn:Cardinal; Number:Cardinal; lpItems, lpData: lpDataType):integer;stdcall; external 'ScommDll.dll' name 'PcdRdDB';

implementation



{$R *.DFM}

function TConnectForm.GetMode:Integer;
begin
  result:=mOpenData.Protocol;
end;

procedure TConnectForm.Start;
begin
  PcdMessage(PcdRdChanSetupFromIni('SkidSim.ini', 'GoOnline', @mOpenData));
end;

function TConnectForm. GetChannelConnected(): boolean;
begin
  if(PcdGetOpenData(PcdConn, @mOpenData) = 0) then
    Result := mOpenData.bConnected
  else Result := false;
end;

function TConnectForm.Connection(Handle:HWND; var Text:string): boolean;
var
  str1       : string;
  str2       : string;
  TempString : array[0..32] of Char;
  Buffer     : PChar;
begin
  Result := false;
  if ((GetChannelConnected = false) {and (mOpenData.Protocol = 0)}) then
  begin
    Buffer := @TempString;
    respons := PcdConnectChannel(Addr(PcdConn),  @mOpenData, 0, Handle);
    Text:=ShowStatus(respons ,'Connection : ');
    if (respons = 0) then
    begin
      PcdGetPortName( @mOpenData,Buffer,32);
      str1 := string(Buffer);
      PcdGetBaudrateName( @mOpenData,Buffer,32);
      str2 := string(Buffer);
      Text:=Text+'   '+ str1+ ', '+ str2 +' bps';
      Result := mOpenData.bConnected
    end
    else Text := 'Disconnected';
  end
  else MessageDlg('Second connection!',mtWarning,[mbOk],0);
end;

procedure TConnectForm.SetupConnection(Handle:HWND; var Text:string);
begin
  if (GetChannelConnected) then
  begin
    MessageDlg('Disconnect before changing communication options!',mtWarning,[mbOk],0);
    if (MessageDlg('Disconnect?',mtConfirmation,[mbYes, mbNo],0)=mrYes) then
    begin
      Text:=ShowStatus(PcdDisconnectChannel(PcdConn ,  0,Handle),'Disconnect : ');
      if (respons = 0)  then
      begin
        Text := 'Disconnected';
      end;
    end;
  end
  else
  begin
    respons := PcdRdChanSetupFromIni('SkidSim.ini', 'GoOnline', @mOpenData);
    if(PcdConnectionDialog(handle, @mOpenData)= IDOK) then
    begin
      respons := PcdWrChanSetupToIni('SkidSim.ini', 'GoOnline', @mOpenData);
    end;
    Text:=ShowStatus(respons, 'Read - write setup to ini.');
  end;
end;

procedure TConnectForm.Disconnect(Handle:HWND; var Text:string);
begin
  if GetChannelConnected=true then
  begin
    respons := PcdDisconnectChannel(PcdConn ,  0,Handle);
    Text:=ShowStatus(respons, 'Disconnect : ');
    if (respons = 0)  then
    begin
      Text:= 'Disconnected';
    end;
  end
  else Text:= 'Disconnected';
end;

function TConnectForm.ShowStatus(Status:Integer; LastOpr:string):string;
begin
  result := LastOpr + StrPas(PcdMessage(Status));
end;

end.
