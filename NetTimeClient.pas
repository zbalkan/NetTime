{ ************************************************************************

   NetTime is copyrighted by Graham Mainwaring. Permission is hereby
   granted to use, modify, redistribute and create derivative works
   provided this attribution is not removed. I also request that if you
   make any useful changes, please e-mail the diffs to graham@mhn.org
   so that I can include them in an 'official' release.

  ************************************************************************ }

unit NetTimeClient;

interface

uses Windows, Classes, SysUtils, NetTimeCommon, NetTimeIPC,
  Dialogs, ExtCtrls, Winsock, WinsockUtil;

type

  TNetTimeProxy = class(TNetTimeServerBase)
  private
    FOnStateChange: TNotifyEvent;
    FOnWarnAdj: TWarnAdjEvent;
    FOnExit: TNotifyEvent;
    LocalUnsync: boolean;
    SyncTimer: TTimer;
    ClientIPC: TNetTimeIPCClient;
    ServerStatus: TServerStatusBlock;
    procedure SyncTimerEvent(Sender: TObject);
    procedure AdviseStatus(const Status: TServerStatusBlock);
    function DoWarnAdj(const ServerTime, StationTime: TDateTime): boolean;
    procedure ExitNow;
  public
    function GetActive: boolean; override;
    function GetStatus: TSyncStatus; override;
    function GetLastUpdateTime: TDateTime; override;
    function GetStateChange: TNotifyEvent; override;
    procedure SetStateChange(const sc: TNotifyEvent); override;
    function GetWarnAdj: TWarnAdjEvent; override;
    procedure SetWarnAdj(const wa: TWarnAdjEvent); override;
    function GetOnExit: TNotifyEvent; override;
    procedure SetOnExit(const ex: TNotifyEvent); override;
    function GetServer: boolean; override;
    procedure SetServer(const sv: boolean); override;
    procedure SetConfig(const cfg: TServerConfigBlock); override;
    function GetConfig: TServerConfigBlock; override;
    procedure ForceUpdate; override;
    procedure KillEverything; override;
    function UpdateNow: boolean; override;
    constructor Create;
    destructor Destroy; override;
  end;

implementation

uses Forms, timeconv;

function TNetTimeProxy.GetActive: boolean;
begin
  result := ServerStatus.Active;
end;

function TNetTimeProxy.GetStatus: TSyncStatus;

var
  i: integer;

begin
  if LocalUnsync then
    begin
      result.Synchronized := false;
      for i := 0 to MaxServers-1 do
        result.ss[i] := ssUnconfigured;
    end
  else
    result := ServerStatus.Status;
end;

function TNetTimeProxy.GetLastUpdateTime: TDateTime;
begin
  result := ServerStatus.LastUpdateTime;
end;

function TNetTimeProxy.GetStateChange: TNotifyEvent;
begin
  result := FOnStateChange;
end;

procedure TNetTimeProxy.SetStateChange(const sc: TNotifyEvent);
begin
  FOnStateChange := sc;
end;

function TNetTimeProxy.GetWarnAdj: TWarnAdjEvent;
begin
  result := FOnWarnAdj;
end;

procedure TNetTimeProxy.SetWarnAdj(const wa: TWarnAdjEvent);
begin
  FOnWarnAdj := wa;
end;

function TNetTimeProxy.GetOnExit: TNotifyEvent;
begin
  result := FOnExit;
end;

procedure TNetTimeProxy.SetOnExit(const ex: TNotifyEvent);
begin
  FOnExit := ex;
end;

function TNetTimeProxy.GetServer: boolean;
begin
  result := ServerStatus.Server;
end;

procedure TNetTimeProxy.SetServer(const sv: boolean);
begin
  ClientIPC.SetServer(sv);
  ForceUpdate;
end;

procedure TNetTimeProxy.SetConfig(const cfg: TServerConfigBlock);
begin
  ClientIPC.SetConfig(cfg);
  ForceUpdate;
end;

function TNetTimeProxy.GetConfig: TServerConfigBlock;
begin
  result := ServerStatus.Config;
end;

procedure TNetTimeProxy.SyncTimerEvent(Sender: TObject);

var
  lsu: boolean;

begin
  lsu := SecondsApart(Now,ServerStatus.LastUpdateTime) >
    int64(ServerStatus.Config.LostSync);
  if lsu <> LocalUnsync then
    begin
      LocalUnsync := lsu;
      if Assigned(FOnStateChange) then
        FOnStateChange(Self);
    end;
end;

procedure TNetTimeProxy.ForceUpdate;
begin
  ServerStatus := ClientIPC.GetServerStatus;
end;

function TNetTimeProxy.UpdateNow: boolean;
begin
  result := ClientIPC.UpdateNow;
end;

constructor TNetTimeProxy.Create;
begin
  inherited Create;
  LocalUnsync := false;
  ClientIPC := TNetTimeIPCClient.Create(AdviseStatus,
    DoWarnAdj,ExitNow);
  try
    ClientIPC.InitResources;
  except on e: exception do
    begin
      ShowMessage('Could not initialize IPC: '+e.Message);
      Halt;
    end;
  end;
  SyncTimer := TTimer.Create(nil);
  SyncTimer.OnTimer := SyncTimerEvent;
  SyncTimer.Interval := 1000;
  SyncTimer.Enabled := true;
end;

destructor TNetTimeProxy.Destroy;
begin
  SyncTimer.Enabled := false;
  SyncTimer.Free;
  ClientIPC.Free;
  inherited;
end;

procedure TNetTimeProxy.AdviseStatus(const Status: TServerStatusBlock);
begin
  ServerStatus := Status;
  if Assigned(FOnStateChange) then
    FOnStateChange(Self);
end;

function TNetTimeProxy.DoWarnAdj(const ServerTime, StationTime: TDateTime): boolean;
begin
  if Assigned(FOnWarnAdj) then
    result := FOnWarnAdj(Self, ServerTime,StationTime)
  else
    result := true;
end;

procedure TNetTimeProxy.ExitNow;
begin
  if Assigned(FOnExit) then
    FOnExit(Self);
end;

procedure TNetTimeProxy.KillEverything;
begin
  ClientIPC.KillEverything;
end;

end.
