program JsonDecode;

uses
  Forms,
  frm_JdMain in 'frm_JdMain.pas' {frmJdMain},
  superobject in 'superobject.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmJdMain, frmJdMain);
  Application.Run;
end.
