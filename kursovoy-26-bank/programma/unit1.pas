unit Unit1;

{ Курсовой проект по дисциплине «Основы алгоритмизации и программирования»
  Тема 26: «Ведение банковских счетов на основании чеков» }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Menus, Grids;

type

  { TForm1 }

  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    MenuSchet: TMenuItem;
    MenuSchetRead: TMenuItem;
    MenuSchetWrite: TMenuItem;
    MenuSchetClear: TMenuItem;
    MenuOper: TMenuItem;
    MenuOperRead: TMenuItem;
    MenuOperWrite: TMenuItem;
    MenuOperClear: TMenuItem;
    MenuObr: TMenuItem;
    MenuObrRaschet: TMenuItem;
    MenuObrSave: TMenuItem;
    MenuObrOtchet: TMenuItem;
    MenuExit: TMenuItem;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    LabelPravila: TLabel;
    LabelInfo: TLabel;
    SG1: TStringGrid;
    SG2: TStringGrid;
    SG3: TStringGrid;
    SG4: TStringGrid;
    Memo1: TMemo;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    procedure FormCreate(Sender: TObject);
    procedure MenuSchetReadClick(Sender: TObject);
    procedure MenuSchetWriteClick(Sender: TObject);
    procedure MenuSchetClearClick(Sender: TObject);
    procedure MenuOperReadClick(Sender: TObject);
    procedure MenuOperWriteClick(Sender: TObject);
    procedure MenuOperClearClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure MenuExitClick(Sender: TObject);
  private
    procedure Oshibka(SG: TStringGrid; c, r: integer; tekst: string);
    function ProverkaSchetov: boolean;
    function ProverkaOperaciy: boolean;
    procedure VyvodNovogoSostoyaniya;
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

const
  MaxKl = 100;       // максимальное количество счетов
  MaxOp = 500;       // количество строк в таблице операций
  SborChek = 10;     // сбор за один выписанный чек, руб.
  MaxSbor = 30;      // предельная общая плата за банковские услуги, руб.
  Porog = 3000;      // при остатке не более этой суммы сбор не взимается, руб.
  Shtraf = 50;       // штраф за неправомерную выписку чека, руб.

type
  klient = packed record      // запись файла счетов
    fam: string[40];          // фамилия клиента
    nomer: string[20];        // номер счета
    sost: real;               // текущее состояние счета, руб.
  end;

  operaciya = packed record   // запись файла операций
    nomer: string[20];        // номер счета
    summa: real;              // сумма прихода (+) или расхода по чеку (-)
  end;

  schet = record              // рабочая запись для расчета по одному счету
    fam: string[40];          // фамилия клиента
    nomer: string[20];        // номер счета
    staroe: real;             // состояние счета до обработки операций
    vklad: real;              // сумма вкладов
    vydano: real;             // сумма, выданная по чекам
    sbor: real;               // удержанный чековый сбор
    shtr: real;               // удержанные штрафы
    sost: real;               // новое (текущее) состояние счета
  end;

var
  fkl: file of klient;        // файл счетов клиентов
  fop: file of operaciya;     // файл операций
  bufkl: klient;              // буферная переменная файла счетов
  bufop: operaciya;           // буферная переменная файла операций
  sch: array[1..MaxKl] of schet;  // массив счетов для расчета
  n: integer;                 // количество счетов в массиве sch
  rasschitano: boolean;       // признак выполненного расчета
  ImyaKl, ImyaOp, ImyaOtch: string;  // имена файлов счетов, операций, отчета

{ ---------------- Вспомогательные подпрограммы ---------------- }

function Okr(x: real): real;
// Округление суммы до копеек
begin
  Result := Round(x * 100) / 100;
end;

function StrToSumma(s: string; var x: real): boolean;
// Преобразование строки в денежную сумму.
// Разделителем дробной части может быть точка или запятая.
var
  i: integer;
  d: double;
begin
  s := Trim(s);
  for i := 1 to Length(s) do
    if (s[i] = '.') or (s[i] = ',') then
      s[i] := DefaultFormatSettings.DecimalSeparator;
  Result := TryStrToFloat(s, d);
  if Result then
    x := Okr(d);
end;

function SummaToStr(x: real): string;
// Вывод суммы с двумя знаками после запятой
begin
  Result := FormatFloat('0.00', x);
end;

function ProverkaNomera(s: string): boolean;
// Номер счета: от 1 до 20 цифр
var
  i: integer;
begin
  Result := (Length(s) >= 1) and (Length(s) <= 20);
  for i := 1 to Length(s) do
    if not (s[i] in ['0'..'9']) then
      Result := false;
end;

function PustayaStroka(SG: TStringGrid; r: integer): boolean;
// Проверка, что строка r таблицы SG не заполнена
var
  c: integer;
begin
  Result := true;
  for c := 0 to SG.ColCount - 1 do
    if Trim(SG.Cells[c, r]) <> '' then
      Result := false;
end;

procedure OchistitTablicu(SG: TStringGrid);
// Очистка всех строк таблицы, кроме шапки
var
  r, c: integer;
begin
  for r := 1 to SG.RowCount - 1 do
    for c := 0 to SG.ColCount - 1 do
      SG.Cells[c, r] := '';
end;

procedure ZagruzitScheta;
// Чтение файла счетов в массив sch
begin
  Reset(fkl);
  n := 0;
  while (not eof(fkl)) and (n < MaxKl) do
  begin
    read(fkl, bufkl);
    inc(n);
    sch[n].fam := bufkl.fam;
    sch[n].nomer := bufkl.nomer;
    sch[n].staroe := bufkl.sost;
    sch[n].sost := bufkl.sost;
    sch[n].vklad := 0;
    sch[n].vydano := 0;
    sch[n].sbor := 0;
    sch[n].shtr := 0;
  end;
  CloseFile(fkl);
end;

function NaitiSchet(nom: string): integer;
// Поиск счета с номером nom в массиве sch.
// Результат - индекс счета в массиве или 0, если счет не найден
var
  i: integer;
begin
  Result := 0;
  i := 1;
  while (i <= n) and (Result = 0) do
  begin
    if sch[i].nomer = nom then
      Result := i;
    inc(i);
  end;
end;

procedure ObrabotkaOperacii(j: integer; summa: real; var vid: string;
  var sb, sh: real);
// Обработка одной операции по счету sch[j].
// vid - вид операции, sb - удержанный сбор, sh - удержанный штраф
var
  s: real;    // сумма чека
begin
  sb := 0;
  sh := 0;
  if summa > 0 then
  begin
    // вклад: сумма зачисляется на счет
    sch[j].sost := Okr(sch[j].sost + summa);
    sch[j].vklad := Okr(sch[j].vklad + summa);
    vid := 'Вклад';
  end
  else
  begin
    // выдача денег по чеку
    s := -summa;
    if s > sch[j].sost then
    begin
      // чек превышает остаток: чек не обрабатывается, удерживается штраф
      sh := Shtraf;
      sch[j].sost := Okr(sch[j].sost - sh);
      sch[j].shtr := Okr(sch[j].shtr + sh);
      vid := 'Чек отклонен';
    end
    else
    begin
      // чек обрабатывается; сбор берется, если на счету больше Porog руб.
      // и общая плата за услуги не превысит MaxSbor руб.
      if (sch[j].sost > Porog) and (sch[j].sbor + SborChek <= MaxSbor) then
        sb := SborChek;
      sch[j].sost := Okr(sch[j].sost - s - sb);
      sch[j].vydano := Okr(sch[j].vydano + s);
      sch[j].sbor := Okr(sch[j].sbor + sb);
      vid := 'Чек';
    end;
  end;
end;

{ ---------------- Обработчики событий формы ---------------- }

procedure TForm1.FormCreate(Sender: TObject);
// Начальные действия при запуске программы
begin
  // имена файлов: файлы хранятся в каталоге программы
  ImyaKl := ExtractFilePath(Application.ExeName) + 'klienty.dat';
  ImyaOp := ExtractFilePath(Application.ExeName) + 'operacii.dat';
  ImyaOtch := ExtractFilePath(Application.ExeName) + 'otchet.txt';
  AssignFile(fkl, ImyaKl);
  AssignFile(fop, ImyaOp);
  rasschitano := false;
  n := 0;

  // шапки таблиц
  SG1.RowCount := MaxKl + 1;
  SG1.Cells[0, 0] := 'Фамилия клиента';
  SG1.Cells[1, 0] := 'Номер счета';
  SG1.Cells[2, 0] := 'Состояние счета';

  SG2.RowCount := MaxOp + 1;
  SG2.Cells[0, 0] := 'Номер счета';
  SG2.Cells[1, 0] := 'Сумма';

  SG3.Cells[0, 0] := '№';
  SG3.Cells[1, 0] := 'Номер счета';
  SG3.Cells[2, 0] := 'Фамилия';
  SG3.Cells[3, 0] := 'Сумма';
  SG3.Cells[4, 0] := 'Вид операции';
  SG3.Cells[5, 0] := 'Остаток до';
  SG3.Cells[6, 0] := 'Сбор';
  SG3.Cells[7, 0] := 'Штраф';
  SG3.Cells[8, 0] := 'Остаток после';

  SG4.Cells[0, 0] := 'Фамилия';
  SG4.Cells[1, 0] := 'Номер счета';
  SG4.Cells[2, 0] := 'Было';
  SG4.Cells[3, 0] := 'Вклады';
  SG4.Cells[4, 0] := 'Выдано';
  SG4.Cells[5, 0] := 'Сборы';
  SG4.Cells[6, 0] := 'Штрафы';
  SG4.Cells[7, 0] := 'Стало';

  // ширина столбцов таблиц
  SG1.ColWidths[0] := 190; SG1.ColWidths[1] := 130; SG1.ColWidths[2] := 120;
  SG2.ColWidths[0] := 130; SG2.ColWidths[1] := 115;
  SG3.ColWidths[0] := 40;  SG3.ColWidths[1] := 120; SG3.ColWidths[2] := 200;
  SG3.ColWidths[3] := 110; SG3.ColWidths[4] := 180; SG3.ColWidths[5] := 140;
  SG3.ColWidths[6] := 90;  SG3.ColWidths[7] := 90;  SG3.ColWidths[8] := 150;
  SG4.ColWidths[0] := 140; SG4.ColWidths[1] := 105;
  SG4.ColWidths[2] := 90;  SG4.ColWidths[3] := 90;  SG4.ColWidths[4] := 90;
  SG4.ColWidths[5] := 75;  SG4.ColWidths[6] := 75;  SG4.ColWidths[7] := 95;

  LabelPravila.Caption :=
    'Сбор за чек ' + IntToStr(SborChek) + ' руб. (всего не более ' +
    IntToStr(MaxSbor) + ' руб.);' + LineEnding +
    'при остатке не более ' + IntToStr(Porog) +
    ' руб. сбор не взимается;' + LineEnding +
    'штраф за чек сверх остатка ' + IntToStr(Shtraf) + ' руб.';
  LabelInfo.Caption := '';

  // если файлы уже существуют, они сразу считываются в таблицы
  if FileExists(ImyaKl) then
    MenuSchetReadClick(Sender);
  if FileExists(ImyaOp) then
    MenuOperReadClick(Sender);
end;

procedure TForm1.Oshibka(SG: TStringGrid; c, r: integer; tekst: string);
// Сообщение об ошибке в ячейке (c, r) таблицы SG
begin
  SG.Col := c;
  SG.Row := r;
  ShowMessage('Ошибка в строке ' + IntToStr(r) + ': ' + tekst +
    '.' + LineEnding + 'Данные в файл не записаны.');
end;

procedure TForm1.MenuSchetReadClick(Sender: TObject);
// Чтение файла счетов в таблицу SG1
var
  i: integer;
begin
  if not FileExists(ImyaKl) then
  begin
    ShowMessage('Файл счетов не найден: ' + ImyaKl);
    exit;
  end;
  OchistitTablicu(SG1);
  Reset(fkl);
  i := 0;
  while (not eof(fkl)) and (i < SG1.RowCount - 1) do
  begin
    read(fkl, bufkl);
    inc(i);
    SG1.Cells[0, i] := bufkl.fam;
    SG1.Cells[1, i] := bufkl.nomer;
    SG1.Cells[2, i] := SummaToStr(bufkl.sost);
  end;
  CloseFile(fkl);
end;

function TForm1.ProverkaSchetov: boolean;
// Проверка правильности данных в таблице счетов SG1
var
  i, j: integer;
  fam, nom: string;
  x: real;
begin
  Result := false;
  x := 0;
  for i := 1 to SG1.RowCount - 1 do
    if not PustayaStroka(SG1, i) then
    begin
      fam := Trim(SG1.Cells[0, i]);
      nom := Trim(SG1.Cells[1, i]);
      if (fam = '') or (Length(fam) > 40) then
      begin
        Oshibka(SG1, 0, i, 'фамилия клиента не задана или слишком длинная');
        exit;
      end;
      if not ProverkaNomera(nom) then
      begin
        Oshibka(SG1, 1, i, 'номер счета должен состоять из цифр (не более 20)');
        exit;
      end;
      for j := 1 to i - 1 do
        if Trim(SG1.Cells[1, j]) = nom then
        begin
          Oshibka(SG1, 1, i, 'счет ' + nom + ' уже есть в строке ' + IntToStr(j));
          exit;
        end;
      if not StrToSumma(SG1.Cells[2, i], x) then
      begin
        Oshibka(SG1, 2, i, 'состояние счета должно быть числом');
        exit;
      end;
    end;
  Result := true;
end;

procedure TForm1.MenuSchetWriteClick(Sender: TObject);
// Запись таблицы SG1 в файл счетов
var
  i, kol: integer;
  x: real;
begin
  if not ProverkaSchetov then
    exit;
  Rewrite(fkl);
  kol := 0;
  x := 0;
  for i := 1 to SG1.RowCount - 1 do
    if not PustayaStroka(SG1, i) then
    begin
      bufkl.fam := Trim(SG1.Cells[0, i]);
      bufkl.nomer := Trim(SG1.Cells[1, i]);
      StrToSumma(SG1.Cells[2, i], x);
      bufkl.sost := x;
      write(fkl, bufkl);
      inc(kol);
    end;
  CloseFile(fkl);
  rasschitano := false;
  ShowMessage('В файл счетов записано записей: ' + IntToStr(kol));
end;

procedure TForm1.MenuSchetClearClick(Sender: TObject);
// Очистка файла счетов
begin
  if QuestionDlg('Подтверждение', 'Удалить все записи из файла счетов?',
    mtConfirmation, [mrYes, 'Да', mrNo, 'Нет'], 0) = mrYes then
  begin
    Rewrite(fkl);
    CloseFile(fkl);
    OchistitTablicu(SG1);
    rasschitano := false;
  end;
end;

procedure TForm1.MenuOperReadClick(Sender: TObject);
// Чтение файла операций в таблицу SG2
var
  i: integer;
begin
  if not FileExists(ImyaOp) then
  begin
    ShowMessage('Файл операций не найден: ' + ImyaOp);
    exit;
  end;
  OchistitTablicu(SG2);
  Reset(fop);
  i := 0;
  while (not eof(fop)) and (i < SG2.RowCount - 1) do
  begin
    read(fop, bufop);
    inc(i);
    SG2.Cells[0, i] := bufop.nomer;
    SG2.Cells[1, i] := SummaToStr(bufop.summa);
  end;
  CloseFile(fop);
end;

function TForm1.ProverkaOperaciy: boolean;
// Проверка правильности данных в таблице операций SG2
var
  i: integer;
  x: real;
begin
  Result := false;
  x := 0;
  for i := 1 to SG2.RowCount - 1 do
    if not PustayaStroka(SG2, i) then
    begin
      if not ProverkaNomera(Trim(SG2.Cells[0, i])) then
      begin
        Oshibka(SG2, 0, i, 'номер счета должен состоять из цифр (не более 20)');
        exit;
      end;
      if not StrToSumma(SG2.Cells[1, i], x) then
      begin
        Oshibka(SG2, 1, i, 'сумма операции должна быть числом');
        exit;
      end;
      if x = 0 then
      begin
        Oshibka(SG2, 1, i, 'сумма операции не может быть равна нулю');
        exit;
      end;
    end;
  Result := true;
end;

procedure TForm1.MenuOperWriteClick(Sender: TObject);
// Запись таблицы SG2 в файл операций
var
  i, kol: integer;
  x: real;
begin
  if not ProverkaOperaciy then
    exit;
  Rewrite(fop);
  kol := 0;
  x := 0;
  for i := 1 to SG2.RowCount - 1 do
    if not PustayaStroka(SG2, i) then
    begin
      bufop.nomer := Trim(SG2.Cells[0, i]);
      StrToSumma(SG2.Cells[1, i], x);
      bufop.summa := x;
      write(fop, bufop);
      inc(kol);
    end;
  CloseFile(fop);
  rasschitano := false;
  ShowMessage('В файл операций записано записей: ' + IntToStr(kol));
end;

procedure TForm1.MenuOperClearClick(Sender: TObject);
// Очистка файла операций
begin
  if QuestionDlg('Подтверждение', 'Удалить все записи из файла операций?',
    mtConfirmation, [mrYes, 'Да', mrNo, 'Нет'], 0) = mrYes then
  begin
    Rewrite(fop);
    CloseFile(fop);
    OchistitTablicu(SG2);
    rasschitano := false;
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
// Расчет нового состояния счетов по файлу операций
var
  k: integer;       // порядковый номер операции
  j: integer;       // индекс счета в массиве sch
  ostDo: real;      // остаток на счету до операции
  vid: string;      // вид операции
  sb, sh: real;     // удержанные по операции сбор и штраф
  otkl: integer;    // количество отклоненных чеков
  nenaid: integer;  // количество операций с ненайденным счетом
begin
  if (not FileExists(ImyaKl)) or (not FileExists(ImyaOp)) then
  begin
    ShowMessage('Не найден файл счетов или файл операций.' + LineEnding +
      'Запишите данные в файлы через меню «Счета» и «Операции».');
    exit;
  end;
  ZagruzitScheta;
  Memo1.Clear;
  Reset(fop);
  SG3.RowCount := FileSize(fop) + 1;
  OchistitTablicu(SG3);
  k := 0;
  otkl := 0;
  nenaid := 0;
  while not eof(fop) do
  begin
    read(fop, bufop);
    inc(k);
    SG3.Cells[0, k] := IntToStr(k);
    SG3.Cells[1, k] := bufop.nomer;
    SG3.Cells[3, k] := SummaToStr(bufop.summa);
    j := NaitiSchet(bufop.nomer);
    if j = 0 then
    begin
      inc(nenaid);
      SG3.Cells[2, k] := '—';
      SG3.Cells[4, k] := 'Счет не найден';
      Memo1.Lines.Add('Операция ' + IntToStr(k) + ': счет ' + bufop.nomer +
        ' не найден, операция не выполнена.');
    end
    else
    begin
      ostDo := sch[j].sost;
      ObrabotkaOperacii(j, bufop.summa, vid, sb, sh);
      SG3.Cells[2, k] := sch[j].fam;
      SG3.Cells[4, k] := vid;
      SG3.Cells[5, k] := SummaToStr(ostDo);
      SG3.Cells[6, k] := SummaToStr(sb);
      SG3.Cells[7, k] := SummaToStr(sh);
      SG3.Cells[8, k] := SummaToStr(sch[j].sost);
      if sh > 0 then
      begin
        inc(otkl);
        Memo1.Lines.Add('УВЕДОМЛЕНИЕ. Операция ' + IntToStr(k) + '. Клиент ' +
          sch[j].fam + ', счет ' + sch[j].nomer + ': чек на сумму ' +
          SummaToStr(-bufop.summa) + ' руб. превышает остаток счета ' +
          SummaToStr(ostDo) + ' руб. Чек не обработан, удержан штраф ' +
          SummaToStr(sh) + ' руб.');
      end;
    end;
  end;
  CloseFile(fop);
  VyvodNovogoSostoyaniya;
  rasschitano := true;
  LabelInfo.Caption := 'Обработано операций: ' + IntToStr(k) +
    LineEnding + 'Отклонено чеков: ' + IntToStr(otkl) +
    ', не найдено счетов: ' + IntToStr(nenaid);
end;

procedure TForm1.VyvodNovogoSostoyaniya;
// Вывод нового состояния счетов и итоговой строки в таблицу SG4
var
  i: integer;
  itStar, itVkl, itVyd, itSb, itSh, itNov: real;  // итоги по графам
begin
  SG4.RowCount := n + 2;
  OchistitTablicu(SG4);
  itStar := 0; itVkl := 0; itVyd := 0;
  itSb := 0; itSh := 0; itNov := 0;
  for i := 1 to n do
  begin
    SG4.Cells[0, i] := sch[i].fam;
    SG4.Cells[1, i] := sch[i].nomer;
    SG4.Cells[2, i] := SummaToStr(sch[i].staroe);
    SG4.Cells[3, i] := SummaToStr(sch[i].vklad);
    SG4.Cells[4, i] := SummaToStr(sch[i].vydano);
    SG4.Cells[5, i] := SummaToStr(sch[i].sbor);
    SG4.Cells[6, i] := SummaToStr(sch[i].shtr);
    SG4.Cells[7, i] := SummaToStr(sch[i].sost);
    itStar := itStar + sch[i].staroe;
    itVkl := itVkl + sch[i].vklad;
    itVyd := itVyd + sch[i].vydano;
    itSb := itSb + sch[i].sbor;
    itSh := itSh + sch[i].shtr;
    itNov := itNov + sch[i].sost;
  end;
  SG4.Cells[0, n + 1] := 'ИТОГО';
  SG4.Cells[2, n + 1] := SummaToStr(itStar);
  SG4.Cells[3, n + 1] := SummaToStr(itVkl);
  SG4.Cells[4, n + 1] := SummaToStr(itVyd);
  SG4.Cells[5, n + 1] := SummaToStr(itSb);
  SG4.Cells[6, n + 1] := SummaToStr(itSh);
  SG4.Cells[7, n + 1] := SummaToStr(itNov);
end;

procedure TForm1.Button2Click(Sender: TObject);
// Сохранение нового состояния счетов в файле счетов
var
  i: integer;
begin
  if not rasschitano then
  begin
    ShowMessage('Сначала выполните расчет нового состояния счетов.');
    exit;
  end;
  Rewrite(fkl);
  for i := 1 to n do
  begin
    bufkl.fam := sch[i].fam;
    bufkl.nomer := sch[i].nomer;
    bufkl.sost := sch[i].sost;
    write(fkl, bufkl);
  end;
  CloseFile(fkl);
  rasschitano := false;
  MenuSchetReadClick(Sender);
  if QuestionDlg('Подтверждение', 'Новое состояние счетов записано в файл ' +
    'счетов.' + LineEnding + 'Операции проведены. Очистить файл операций?',
    mtConfirmation, [mrYes, 'Да', mrNo, 'Нет'], 0) = mrYes then
  begin
    Rewrite(fop);
    CloseFile(fop);
    OchistitTablicu(SG2);
  end;
end;

procedure TForm1.Button3Click(Sender: TObject);
// Сохранение отчета о расчете в текстовый файл
var
  f: TextFile;
  i: integer;
begin
  if SG4.Cells[0, 1] = '' then
  begin
    ShowMessage('Сначала выполните расчет нового состояния счетов.');
    exit;
  end;
  AssignFile(f, ImyaOtch);
  Rewrite(f);
  writeln(f, 'ОТЧЕТ О ВЕДЕНИИ БАНКОВСКИХ СЧЕТОВ');
  writeln(f, 'Дата формирования: ', FormatDateTime('dd.mm.yyyy hh:nn', Now));
  writeln(f);
  writeln(f, 'Журнал операций:');
  for i := 1 to SG3.RowCount - 1 do
    if SG3.Cells[5, i] = '' then    // операция по несуществующему счету
      writeln(f, SG3.Cells[0, i], '. Счет ', SG3.Cells[1, i], ': ',
        SG3.Cells[4, i], ', сумма ', SG3.Cells[3, i])
    else
      writeln(f, SG3.Cells[0, i], '. Счет ', SG3.Cells[1, i], ' (',
        SG3.Cells[2, i], '): ', SG3.Cells[4, i], ', сумма ', SG3.Cells[3, i],
        '; остаток до ', SG3.Cells[5, i], '; сбор ', SG3.Cells[6, i],
        '; штраф ', SG3.Cells[7, i], '; остаток после ', SG3.Cells[8, i]);
  writeln(f);
  writeln(f, 'Новое состояние счетов:');
  for i := 1 to SG4.RowCount - 1 do
    writeln(f, Trim(SG4.Cells[0, i] + ' ' + SG4.Cells[1, i]), ': было ',
      SG4.Cells[2, i], '; вклады ', SG4.Cells[3, i], '; выдано ',
      SG4.Cells[4, i], '; сборы ', SG4.Cells[5, i], '; штрафы ',
      SG4.Cells[6, i], '; стало ', SG4.Cells[7, i]);
  writeln(f);
  writeln(f, 'Уведомления:');
  for i := 0 to Memo1.Lines.Count - 1 do
    writeln(f, Memo1.Lines[i]);
  CloseFile(f);
  ShowMessage('Отчет сохранен в файл ' + ImyaOtch);
end;

procedure TForm1.MenuExitClick(Sender: TObject);
// Выход из программы
begin
  Close;
end;

end.
