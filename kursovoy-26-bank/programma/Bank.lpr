program Bank;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // подключение набора визуальных компонентов LCL
  Forms, Unit1;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title := 'Банковские счета';
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
