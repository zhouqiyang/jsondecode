unit frm_JdMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, Menus, StdCtrls, ComCtrls, Grids, Wwdbigrd,
  Wwdbgrid, ImgList, superobject, DB, Wwdatsrc, DBClient, wwclient,
  Clipbrd, midaslib;

type
  TfrmJdMain = class(TForm)
    pnlTop: TPanel;
    MainMenu1: TMainMenu;
    N1: TMenuItem;
    Splitter1: TSplitter;
    pnlBottom: TPanel;
    pnlBottomLeft: TPanel;
    Splitter2: TSplitter;
    pnlBottomRight: TPanel;
    dbgJson: TwwDBGrid;
    TreeView1: TTreeView;
    mmSource: TMemo;
    pnlBottomRightCtl: TPanel;
    Label1: TLabel;
    edtKeyword: TEdit;
    rbLocate: TRadioButton;
    rbFilter: TRadioButton;
    btnExport: TButton;
    N2: TMenuItem;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    miReadFile: TMenuItem;
    StatusBar1: TStatusBar;
    imgState: TImageList;
    ImageList1: TImageList;
    cdsJson: TwwClientDataSet;
    dsJson: TwwDataSource;
    cdsClone: TwwClientDataSet;
    btnFindNext: TButton;
    ProgressBar1: TProgressBar;
    N3: TMenuItem;
    N4: TMenuItem;
    pmJson: TPopupMenu;
    miCopy: TMenuItem;
    procedure miReadFileClick(Sender: TObject);
    procedure mmSourceKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure mmSourceChange(Sender: TObject);
    procedure TreeView1Expanded(Sender: TObject; Node: TTreeNode);
    procedure TreeView1Collapsed(Sender: TObject; Node: TTreeNode);
    procedure TreeView1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure edtKeywordChange(Sender: TObject);
    procedure btnFindNextClick(Sender: TObject);
    procedure dbgJsonCalcCellColors(Sender: TObject; Field: TField;
      State: TGridDrawState; Highlight: Boolean; AFont: TFont;
      ABrush: TBrush);
    procedure rbLocateClick(Sender: TObject);
    procedure rbFilterClick(Sender: TObject);
    procedure cdsJsonFilterRecord(DataSet: TDataSet; var Accept: Boolean);
    procedure dbgJsonUpdateFooter(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure dbgJsonDrawDataCell(Sender: TObject; const Rect: TRect;
      Field: TField; State: TGridDrawState);
    procedure N3Click(Sender: TObject);
    procedure dbgJsonMemoOpen(Grid: TwwDBGrid; MemoDialog: TwwMemoDialog);
    procedure N4Click(Sender: TObject);
    procedure dbgJsonKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure miCopyClick(Sender: TObject);
  private
    FDataList: TStringList;
    FPriorSelectNode: TTreeNode;
    FCurrentJsonString: string;
    fieldList: TList;
    procedure ShowText(const msg: string = '');
    procedure FillTreeList(json: ISuperObject; parent: TTreeNode);
    function GetTreeNodeData(const path: string; const data: string): Pointer;
    procedure FillDataSet(json: ISuperObject);
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmJdMain: TfrmJdMain;

implementation

{$R *.dfm}

const
  CONST_OVERLAYINDEX_FILE = 0;
  CONST_OVERLAYINDEX_FOLDER = 1;

  //StateIndex会影响树状布局，已经屏蔽该功能
  CONST_STATEINDEX_FILE = 0;
  CONST_STATEINDEX_FOLDER_CLOSED = 1;
  CONST_STATEINDEX_FOLDER_OPENED = 2;

  CONST_IMAGEINDEX_ARRAY = 0;
  CONST_IMAGEINDEX_OBJECT = 1;
  CONST_IMAGEINDEX_VALUE = 2;
  CONST_IMAGEINDEX_ITEM = 3;

  CONST_FIELDWIDTH_MIN = 6;
  CONST_FIELDWIDTH_MAX = 50;

  CONST_FIELD_PREFIX_AGGREGATE = '___FIELD_SUM_';
  CONST_NODENAME_ROOT = 'Root';

procedure TfrmJdMain.ShowText(const msg: string);
begin
  StatusBar1.Panels[0].Text := msg;
end;

procedure TfrmJdMain.miReadFileClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    mmSource.Lines.LoadFromFile(OpenDialog1.FileName);
  end;
end;

procedure TfrmJdMain.mmSourceKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (ssCtrl in Shift) and (Key = Ord('A')) then
  begin
    mmSource.SelectAll;
  end;
end;

function TfrmJdMain.GetTreeNodeData(const path: string; const data: string): Pointer;
begin
  if path <> '' then
  begin
    FDataList.Add(path + '.' + data);
  end
  else
  begin
    FDataList.Add(data);
  end;
  Result := Pointer(FDataList[FDataList.Count - 1]);
end;

procedure TfrmJdMain.FillTreeList(json: ISuperObject; parent: TTreeNode);
var
  root: TTreeNode;
  item: TTreeNode;
  iter: TSuperObjectIter;
  ja: TSuperArray;
  jo: ISuperObject;
  i: Integer;
begin
  if not (json.DataType in [stArray, stObject]) then
  begin
    item := TreeView1.Items.AddChild(parent, json.AsString);
    item.ImageIndex := CONST_IMAGEINDEX_VALUE;
    item.SelectedIndex := CONST_IMAGEINDEX_VALUE;
    item.StateIndex := CONST_STATEINDEX_FILE;
    item.Data := GetTreeNodeData(string(parent.Data), string(json.AsString));
    Exit;
  end;
  //数据
  if json.IsType(stArray) then
  begin
    ja := json.AsArray;
    for i := 0 to ja.Length - 1 do
    begin
      jo := ja.O[i];
      if jo.DataType in [stArray, stObject] then
      begin
        FillTreeList(jo, parent);
      end
      else
      begin
        item := TreeView1.Items.AddChild(parent, jo.AsString);
        item.ImageIndex := CONST_IMAGEINDEX_VALUE;
        item.SelectedIndex := CONST_IMAGEINDEX_VALUE;
        item.StateIndex := CONST_STATEINDEX_FILE;
        item.Data := GetTreeNodeData(string(parent.Data), IntToStr(i));
      end;
    end;
    Exit;
  end;
  if ObjectFindFirst(json, iter) then
  begin
    root := TreeView1.Items.AddChild(parent, iter.key);
    if iter.val.IsType(stObject) then
    begin    
      root.ImageIndex := CONST_IMAGEINDEX_OBJECT;
      root.SelectedIndex := CONST_IMAGEINDEX_OBJECT;
      root.Data := GetTreeNodeData(string(parent.Data), string(iter.key));
      FillTreeList(iter.val, root);
    end
    else if iter.val.IsType(stArray) then
    begin    
      root.OverlayIndex := CONST_OVERLAYINDEX_FOLDER;
      root.ImageIndex := CONST_IMAGEINDEX_ARRAY;
      root.SelectedIndex := CONST_IMAGEINDEX_ARRAY;
      root.Data := GetTreeNodeData(string(parent.Data), string(iter.key));
      ja := iter.val.AsArray;
      for i := 0 to ja.Length - 1 do
      begin
        jo := ja.O[i];
        item := TreeView1.Items.AddChild(root, IntToStr(i));
        if jo.IsType(stObject) then
        begin
          item.ImageIndex := CONST_IMAGEINDEX_OBJECT;
          item.SelectedIndex := CONST_IMAGEINDEX_OBJECT;
          item.StateIndex := CONST_STATEINDEX_FILE;
          FillTreeList(jo, item);
        end
        else if jo.IsType(stArray) then
        begin
          item.ImageIndex := CONST_IMAGEINDEX_ARRAY;
          item.SelectedIndex := CONST_IMAGEINDEX_ARRAY;
          item.StateIndex := CONST_STATEINDEX_FOLDER_CLOSED; 
          FillTreeList(jo, item);
        end
        else
        begin
          item.ImageIndex := CONST_IMAGEINDEX_VALUE;
          item.SelectedIndex := CONST_IMAGEINDEX_VALUE;
          item.Text := jo.AsString;
        end;
        item.Data := GetTreeNodeData('', string(root.Data) + '[' + IntToStr(i) + ']');
      end;
    end
    else
    begin
      root.ImageIndex := CONST_IMAGEINDEX_VALUE;
      root.SelectedIndex := CONST_IMAGEINDEX_VALUE;
      root.StateIndex := CONST_STATEINDEX_FILE;    
      root.Data := GetTreeNodeData(string(parent.Data), string(iter.key));
    end;
  end;
  while ObjectFindNext(iter) do
  begin
    root := TreeView1.Items.AddChild(parent, iter.key);
    if iter.val.IsType(stObject) then
    begin 
      root.ImageIndex := CONST_IMAGEINDEX_OBJECT;
      root.SelectedIndex := CONST_IMAGEINDEX_OBJECT;
      root.Data := GetTreeNodeData(string(parent.Data), string(iter.key));
      FillTreeList(iter.val, root);
    end
    else if iter.val.IsType(stArray) then
    begin
      root.OverlayIndex := CONST_OVERLAYINDEX_FOLDER;
      root.ImageIndex := CONST_IMAGEINDEX_ARRAY;
      root.SelectedIndex := CONST_IMAGEINDEX_ARRAY;
      root.Data := GetTreeNodeData(string(parent.Data), string(iter.key));
      ja := iter.val.AsArray;
      for i := 0 to ja.Length - 1 do
      begin
        jo := ja.O[i];
        item := TreeView1.Items.AddChild(root, IntToStr(i));
        item.Data := GetTreeNodeData('', string(root.Data) + '[' + IntToStr(i) + ']');
        if jo.IsType(stObject) then
        begin
          item.ImageIndex := CONST_IMAGEINDEX_OBJECT;
          item.SelectedIndex := CONST_IMAGEINDEX_OBJECT;
          item.StateIndex := CONST_STATEINDEX_FILE;  
          FillTreeList(jo, item);
        end
        else if jo.IsType(stArray) then
        begin
          item.ImageIndex := CONST_IMAGEINDEX_ARRAY;
          item.SelectedIndex := CONST_IMAGEINDEX_ARRAY;
          item.StateIndex := CONST_STATEINDEX_FOLDER_CLOSED;
          FillTreeList(jo, item);
        end
        else
        begin 
          item.ImageIndex := CONST_IMAGEINDEX_VALUE;
          item.SelectedIndex := CONST_IMAGEINDEX_VALUE;
          item.Text := jo.AsString;
        end;
      end;
    end
    else
    begin
      root.ImageIndex := CONST_IMAGEINDEX_VALUE;
      root.SelectedIndex := CONST_IMAGEINDEX_VALUE;
      root.StateIndex := CONST_STATEINDEX_FILE;
      root.Data := GetTreeNodeData(string(parent.Data), string(iter.key));
    end;
  end;
end;

procedure TfrmJdMain.mmSourceChange(Sender: TObject);
var
  json: ISuperObject;
  root: TTreeNode; 
  item: TTreeNode;
  jo: ISuperObject;
  ja: TSuperArray;
  i: Integer;
begin
  ShowText();
  FCurrentJsonString := mmSource.Text;
  if FCurrentJsonString = '' then
    Exit;
  json := SO(FCurrentJsonString);
  if json = nil then
  begin
    ShowText('Json格式不正确。');
    Exit;
  end;
  cdsJson.Close;
  FDataList.Clear;
  TreeView1.Items.Clear;
  try
    if json.IsType(stObject) then
    begin
      root := TreeView1.Items.AddChild(nil, CONST_NODENAME_ROOT);
      root.OverlayIndex := CONST_OVERLAYINDEX_FILE;
      root.ImageIndex := CONST_IMAGEINDEX_OBJECT;
      root.SelectedIndex := CONST_IMAGEINDEX_OBJECT;
      root.StateIndex := CONST_STATEINDEX_FOLDER_CLOSED;
      root.Data := GetTreeNodeData('', CONST_NODENAME_ROOT);
      FillTreeList(json, root);
    end
    else if json.IsType(stArray) then
    begin    
      root := TreeView1.Items.AddChild(nil, CONST_NODENAME_ROOT);
      root.OverlayIndex := CONST_OVERLAYINDEX_FOLDER;
      root.ImageIndex := CONST_IMAGEINDEX_ARRAY;
      root.SelectedIndex := CONST_IMAGEINDEX_ARRAY;
      root.StateIndex := CONST_STATEINDEX_FOLDER_CLOSED; 
      root.Data := GetTreeNodeData('', CONST_NODENAME_ROOT);
    
      ja := json.AsArray;
      for i := 0 to ja.Length - 1 do
      begin
        jo := ja.O[i];   
        item := TreeView1.Items.AddChild(root, IntToStr(i)); 
        item.OverlayIndex := CONST_OVERLAYINDEX_FILE; 
        item.Data := GetTreeNodeData('', CONST_NODENAME_ROOT + '[' + IntToStr(i) + ']');
        if jo.IsType(stObject) then
        begin
          item.ImageIndex := CONST_IMAGEINDEX_OBJECT;
          item.SelectedIndex := CONST_IMAGEINDEX_OBJECT;
          item.StateIndex := CONST_STATEINDEX_FILE;
          FillTreeList(jo, item);
        end
        else if jo.IsType(stArray) then
        begin
          item.ImageIndex := CONST_IMAGEINDEX_ARRAY;
          item.SelectedIndex := CONST_IMAGEINDEX_ARRAY;
          item.StateIndex := CONST_STATEINDEX_FOLDER_CLOSED;
          FillTreeList(jo, item);
        end
        else
        begin 
          item.ImageIndex := CONST_IMAGEINDEX_Value;
          item.SelectedIndex := CONST_IMAGEINDEX_Value;
          item.StateIndex := CONST_STATEINDEX_FILE;
        end;
      end;
    end
    else
    begin
      Exit;
    end;
    FPriorSelectNode := nil;
  except
    on e: Exception do
    begin
      ShowText('解析JSON失败，可能不支持该格式：' + e.Message);
    end;
  end;
end;

procedure TfrmJdMain.TreeView1Expanded(Sender: TObject; Node: TTreeNode);
begin
  if Node.OverlayIndex = CONST_OVERLAYINDEX_FOLDER then
    Node.StateIndex := CONST_STATEINDEX_FOLDER_OPENED;
end;

procedure TfrmJdMain.TreeView1Collapsed(Sender: TObject; Node: TTreeNode);
begin
  if Node.OverlayIndex = CONST_OVERLAYINDEX_FOLDER then
    Node.StateIndex := CONST_STATEINDEX_FOLDER_CLOSED;
end;
   
function GetObjectByPath(jo: ISuperObject; path: string): ISuperObject;
var
  i, iPos: Integer;
  flag: Boolean; //上一字节是否汉字首字节
  sNodeName: string;
  iNodeIndex: Integer;
  found: Boolean;
  sPath: string;
begin
  //去掉开头的点
  if path[1] = '.' then
  begin
    Delete(path, 1, 1);
  end;
  found := False;
  flag := False;
  for i := 1 to Length(path) do
  begin
    if (path[i] = '.') and (not flag) then
    begin
      found := True;
      sNodeName := Copy(path, 1, i - 1);
      Break;
    end;
    if not flag then
      flag := IsDBCSLeadByte(Byte(path[i]))
    else
      flag := False;
  end;
  //是否有点号，有则截取前面部分
  if not found then
  begin
    sNodeName := path;
  end;
  sPath := Copy(path, i, Length(path));
  //判断是否数组
  iPos := Pos('[', sNodeName);
  iNodeIndex := -1;
  if Pos('[', sNodeName) > 0 then
  begin    
    iNodeIndex := StrToInt(Copy(sNodeName, iPos + 1, Pos(']', sNodeName) - iPos - 1));
    sNodeName := Copy(sNodeName, 1, iPos - 1);
  end;

  if sNodeName <> CONST_NODENAME_ROOT then
  begin
    jo := jo.O[sNodeName];
  end;
  if iNodeIndex >= 0 then
  begin
    jo := jo.AsArray[iNodeIndex];
  end;
  if sPath = '' then
  begin
    //如果是常量，则转换为对象
    if jo.DataType in [stArray, stObject] then
    begin    
      Result := jo;
      Exit;
    end;
    Result := SO();
    Result.O[sNodeName] := jo;
    Exit;
  end;
  Result := GetObjectByPath(jo, sPath);
end;

procedure TfrmJdMain.TreeView1Click(Sender: TObject);
var
  node: TTreeNode;
  path: string;
  json: ISuperObject; 
  jo: ISuperObject;
begin
  node := TreeView1.Selected;
  if node <> FPriorSelectNode then
  begin
    FPriorSelectNode := node;
    //ShowMessage(StrPas(node.Data));
    //开始解析json
    path := StrPas(node.Data);
    json := SO(FCurrentJsonString);
    jo := GetObjectByPath(json, path);
    try
      FillDataSet(jo);
    except
      on e: Exception do
      begin
        ShowText('加载数据集出错：' + e.Message);
      end;
    end;
  end;
end;

procedure TfrmJdMain.FillDataSet(json: ISuperObject);
var
  ja: TSuperArray;   
  jo: ISuperObject;
  i: Integer;
  iter: TSuperObjectIter;
  aggField: TAggregateField;
  field: TField;
  s: string;
const
  C_LENGTH_FIELDSIZE = 200;
begin
  Screen.Cursor := crHourGlass;
  try
    ShowText();
    ProgressBar1.Position := 0;
    if cdsJson.Active then
      cdsJson.Close;

    for i := 0 to fieldList.Count - 1 do
    begin
      //FreeAndNil(TAggregateField(fieldList[i]));
      TAggregateField(fieldList[i]).Free;
    end;
    fieldList.Clear;
    cdsJson.FieldDefs.Clear;
                              
    if json.IsType(stArray) then
    begin 
      ja := json.AsArray;
    end
    else
    begin
      ja := SA([json]).AsArray;
    end;
    if ja.Length = 0 then
      Exit;
    ProgressBar1.Max := ja.Length * 2;
    for i := 0 to ja.Length - 1 do
    begin
      jo := ja.O[i];
      //判断jo是常量还是Object
      if jo.IsType(stObject) then
      begin
        if ObjectFindFirst(jo, iter) then
        begin
          if cdsJson.FieldDefs.IndexOf(iter.key) < 0 then
          begin
            with cdsJson.FieldDefs.AddFieldDef do
            begin
              Name := iter.key;
              //自动合计功能也已屏蔽
              if iter.val.DataType in [stDouble, stCurrency, stInt] then
              begin
                DataType := ftFloat;
                aggField := TAggregateField.Create(cdsJson);
                aggField.FieldName := CONST_FIELD_PREFIX_AGGREGATE + iter.key;
                aggField.Expression := Format('SUM(%s)', [iter.key]);
                aggField.DataSet := cdsJson;
                aggField.Active := True;
                fieldList.Add(aggField);
              end
              else
              begin
                DataType := ftMemo;
              end;
            end;
          end;
        end;
        while ObjectFindNext(iter) do
        begin
          if cdsJson.FieldDefs.IndexOf(iter.key) < 0 then
          begin
            with cdsJson.FieldDefs.AddFieldDef do
            begin
              Name := iter.key;
              if iter.val.DataType in [stDouble, stCurrency, stInt] then
              begin
                DataType := ftFloat;
                aggField := TAggregateField.Create(cdsJson);
                aggField.FieldName := CONST_FIELD_PREFIX_AGGREGATE + iter.key;
                aggField.Expression := Format('SUM(%s)', [iter.key]);
                aggField.DataSet := cdsJson;
                aggField.Active := True; 
                fieldList.Add(aggField);
              end
              else
              begin
                DataType := ftMemo;
              end;
            end;
          end;
        end;
      end
      else
      //常量
      begin     
        if cdsJson.FieldDefs.IndexOf(CONST_NODENAME_ROOT) < 0 then
        begin
          with cdsJson.FieldDefs.AddFieldDef do
          begin
            Name := CONST_NODENAME_ROOT;
            if jo.DataType in [stDouble, stCurrency, stInt] then
            begin
              DataType := ftFloat;
              aggField := TAggregateField.Create(cdsJson);
              aggField.FieldName := CONST_FIELD_PREFIX_AGGREGATE + CONST_NODENAME_ROOT;
              aggField.Expression := Format('SUM(%s)', [CONST_NODENAME_ROOT]);
              aggField.DataSet := cdsJson;
              aggField.Active := True;
              fieldList.Add(aggField);
            end
            else
            begin
              DataType := ftMemo;
              //Size := C_LENGTH_FIELDSIZE;
            end;
          end;
        end;
      end;
      ProgressBar1.StepIt;
    end;
    if cdsJson.FieldDefs.Count = 0 then
    begin
      ProgressBar1.Position := ProgressBar1.Max;
      Exit;
    end;
    cdsJson.CreateDataSet;
    for i := 0 to cdsJson.FieldCount - 1 do
    begin
      cdsJson.Fields[i].DisplayWidth := 15;
    end;
    cdsJson.DisableControls;
    try
      for i := 0 to ja.Length - 1 do
      begin
        jo := ja.O[i];
        cdsJson.Append; 
        //判断jo是常量还是Object
        if jo.IsType(stObject) then
        begin
          if ObjectFindFirst(jo, iter) then
          begin
            if iter.val.DataType <> stNull then
            begin
              field := cdsJson.FieldByName(iter.key);
              s := iter.val.AsString;  //WideString转为string
              field.AsString := s;
              if field.Tag < Length(s) then
              begin
                field.Tag := Length(s);
              end;
            end;
          end;  
          while ObjectFindNext(iter) do
          begin
            if iter.val.DataType <> stNull then
            begin
              field := cdsJson.FieldByName(iter.key);
              s := iter.val.AsString;  //WideString转为string
              field.AsString := s;
              if field.Tag < Length(s) then
              begin
                field.Tag := Length(s);
              end;
            end;
          end;
        end
        else
        begin
          if jo.DataType <> stNull then
          begin
            field := cdsJson.FieldByName(CONST_NODENAME_ROOT);
            s := jo.AsString;  //WideString转为string
            field.AsString := s;
            if field.Tag < Length(s) then
            begin
              field.Tag := Length(s);
            end;
          end;
        end;
        cdsJson.Post;
        ProgressBar1.StepIt;
      end;
      cdsJson.First;
    finally
      cdsJson.EnableControls;
    end;
    cdsJson.First; 
    for i := 0 to cdsJson.FieldCount - 1 do
    begin
      if cdsJson.Fields[i].Tag < CONST_FIELDWIDTH_MIN then
      begin
        cdsJson.Fields[i].DisplayWidth := CONST_FIELDWIDTH_MIN;
      end
      else if cdsJson.Fields[i].Tag > CONST_FIELDWIDTH_MAX then
      begin
        cdsJson.Fields[i].DisplayWidth := CONST_FIELDWIDTH_MAX;
      end
      else
      if cdsJson.Fields[i].Tag > 0 then
      begin
        cdsJson.Fields[i].DisplayWidth := cdsJson.Fields[i].Tag;
      end;
      //dbgJson.AutoSizeColumn(i);
    end;
    dbgJsonUpdateFooter(dbgJson);
    ShowText('记录数：' + IntToStr(cdsJson.RecordCount));
  finally
    ProgressBar1.Position := 0;
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmJdMain.dbgJsonUpdateFooter(Sender: TObject);
var
  i: Integer;
begin
  //动态添加合计列
  for i := 1 to dbgJson.FieldCount do
  begin
    if dbgJson.Fields[i - 1] is TNumericField then
    begin
      dbgJson.Columns[i - 1].FooterValue := VarToStr(cdsJson.FieldByName(CONST_FIELD_PREFIX_AGGREGATE + dbgJson.Fields[i - 1].FieldName).Value);
    end;
  end;
end;

procedure TfrmJdMain.FormCreate(Sender: TObject);
begin
  FDataList := TStringList.Create;
  fieldList := TList.Create;
end;

procedure TfrmJdMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(fieldList);
  FreeAndNil(FDataList);
end;

procedure TfrmJdMain.edtKeywordChange(Sender: TObject);
var
  i: Integer;
  sKeyWord: string;
begin
  if not cdsJson.Active then
    Exit;
  if rbFilter.Checked then
  begin
    cdsJson.Filtered := False;
    if edtKeyword.Text <> '' then
      cdsJson.Filtered := True;
  end
  else if rbLocate.Checked then
  begin  
    cdsJson.Filtered := False;
    if edtKeyword.Text <> '' then
    begin
      sKeyWord := LowerCase(edtKeyword.Text);
      cdsClone.CloneCursor(cdsJson, False);
      cdsClone.First;
      while not cdsClone.Eof do
      begin
        for i := 0 to cdsClone.FieldCount - 1 do
        begin
          if Pos(sKeyWord, LowerCase(cdsClone.Fields[i].AsString)) > 0 then
          begin
            cdsJson.RecNo := cdsClone.RecNo;
            Exit;
          end;
        end; 
        cdsClone.Next;
      end;
    end;
  end;
end;

procedure TfrmJdMain.btnFindNextClick(Sender: TObject);
var
  i, j: Integer;
  sKeyWord: string;
begin
  if not cdsJson.Active then
    Exit;
  sKeyWord := LowerCase(edtKeyword.Text);
  cdsClone.CloneCursor(cdsJson, False);
  cdsClone.RecNo := cdsJson.RecNo;
  for i := 0 to cdsClone.RecordCount - 1 do
  begin
    cdsClone.Next;
    if cdsClone.Eof then
      cdsClone.First;
    for j := 0 to cdsClone.FieldCount - 1 do
    begin
      if Pos(sKeyWord, LowerCase(cdsClone.Fields[j].AsString)) > 0 then
      begin
        cdsJson.RecNo := cdsClone.RecNo;
        Exit;
      end;
    end;
  end;
end;

procedure TfrmJdMain.dbgJsonCalcCellColors(Sender: TObject; Field: TField;
  State: TGridDrawState; Highlight: Boolean; AFont: TFont; ABrush: TBrush);
var
  sKeyWord: string;
begin
  sKeyWord := LowerCase(edtKeyword.Text);
  if Pos(sKeyWord, LowerCase(Field.AsString)) > 0 then
  begin
    ABrush.Color := clYellow;
    if Highlight then
    begin
      AFont.Color := clBlack;
    end;
  end;
end;

procedure TfrmJdMain.rbLocateClick(Sender: TObject);
begin
  edtKeywordChange(edtKeyword);
end;

procedure TfrmJdMain.rbFilterClick(Sender: TObject);
begin
  edtKeywordChange(edtKeyword);
end;

procedure TfrmJdMain.cdsJsonFilterRecord(DataSet: TDataSet;
  var Accept: Boolean);
var
  i: Integer;
  sKeyWord: string;
begin
  if not cdsJson.Active then
    Exit;
  if edtKeyword.Text = '' then
    Exit;
  Accept := False;
  sKeyWord := LowerCase(edtKeyword.Text);
  for i := 0 to cdsJson.FieldCount - 1 do
  begin
    if Pos(sKeyWord, LowerCase(cdsJson.Fields[i].AsString)) > 0 then
    begin
      Accept := True;
      Exit;
    end;
  end;
end;

procedure TfrmJdMain.btnExportClick(Sender: TObject);
var
  txt: TextFile;
  i: Integer;
begin
  if not cdsJson.Active then
    Exit;
  if SaveDialog1.Execute then
  begin
    SaveDialog1.FileName;
    AssignFile(txt, SaveDialog1.FileName);
    Rewrite(txt);
    for i := 0 to cdsJson.FieldCount - 1 do
    begin
      Write(txt, cdsJson.Fields[i].FieldName);
      if (i < cdsJson.FieldCount - 1) then
        Write(txt, ',');
    end;
    Write(txt, #13#10);
    cdsJson.First;
    while not cdsJson.Eof do
    begin
      for i := 0 to cdsJson.FieldCount - 1 do
      begin
        Write(txt, cdsJson.Fields[i].AsString);
        if (i < cdsJson.FieldCount - 1) then
          Write(txt, ',');
      end;
      Write(txt, #13#10);
      cdsJson.Next;
    end;
    CloseFile(txt);
    Application.MessageBox('保存成功。', '提示');
  end;
end;

procedure TfrmJdMain.dbgJsonDrawDataCell(Sender: TObject;
  const Rect: TRect; Field: TField; State: TGridDrawState);
var
  x, y: Integer;
  s: string;
begin
  if Field is TMemoField then
  begin
    s := Field.AsString;
    if Length(s) > CONST_FIELDWIDTH_MAX then
    begin
      s := Copy(s, 1, CONST_FIELDWIDTH_MAX - 3) + '...';
    end;
    y := Rect.Top + (Rect.Bottom - Rect.Top - dbgJson.Canvas.TextHeight(s)) div 2;
    x := Rect.Left + 2;
    dbgJson.Canvas.TextRect(Rect, x, y, s);
  end
  else if Field is TNumericField then
  begin
    y := Rect.Top + (Rect.Bottom - Rect.Top - Canvas.TextHeight(Field.AsString)) div 2;
    x := Rect.Right - dbgJson.Canvas.TextWidth(Field.AsString) - 2;
    dbgJson.Canvas.TextRect(Rect, x, y, Field.AsString);
  end
  else
  begin 
    y := Rect.Top + (Rect.Bottom - Rect.Top - dbgJson.Canvas.TextHeight(Field.AsString)) div 2;
    x := Rect.Left + 2;
    dbgJson.Canvas.TextRect(Rect, x, y, Field.AsString);
  end;
end;

procedure TfrmJdMain.N3Click(Sender: TObject);
begin
  MessageBox(Application.Handle, PChar('输入JSON字符串，解析为树状结构，可以显示为表格形式。' + #13#10 +
    '图例：A-数组；O-对象；V-常量。'), '帮助提示', 0);
end;

procedure TfrmJdMain.dbgJsonMemoOpen(Grid: TwwDBGrid;
  MemoDialog: TwwMemoDialog);
begin
  if Grid.SelectedField.Tag < CONST_FIELDWIDTH_MAX then
  begin
    Abort;
  end;
end;

procedure TfrmJdMain.N4Click(Sender: TObject);
var
  frm: TForm;
  lab: TLabel;
  btn: TButton;
  pnl: TPanel;
begin
  frm := TForm.Create(nil);
  try
    frm.Caption := '关于本软件';
    frm.ClientWidth := 400;
    frm.ClientHeight := 200;
    frm.Position := poScreenCenter;
    frm.BorderStyle := bsDialog;

    pnl := TPanel.Create(frm);
    pnl.Parent := frm;
    pnl.Align := alTop; 
    pnl.Top := 0;
    pnl.Height := 163;
    pnl.Color := clWindow;
    pnl.BevelOuter := bvNone;

    // 添加文本
    lab := TLabel.Create(frm);
    lab.Parent := pnl;
    //lab.Align := alTop;
    lab.Height := 148;
    lab.Top := 15;
    //lab.WordWrap := True;
    lab.AutoSize := True;
    lab.Caption :=
    '┏──────────────────────────────┓' + #13#10 +
    '┃   _          _ _                                           ┃' + #13#10 +
    '┃  | |        | | |                                          ┃' + #13#10 +
    '┃  | |__   ___| | | ___                                      ┃' + #13#10 +
    '┃  | ''_ \ / _ \ | |/ _ \            欢迎使用本软件           ┃' + #13#10 +
    '┃  | | | |  __/ | | (_) |                                    ┃' + #13#10 +
    '┃  |_| |_|\___|_|_|\___/                                     ┃' + #13#10 +
    '┃                                                            ┃' + #13#10 +    
    '┃  BUG反馈：zhouqiyang@yahoo.com                             ┃' + #13#10 +
    '┃  源码下载：https://github.com/zhouqiyang/jsondecode        ┃' + #13#10 +
    '┃                                                            ┃' + #13#10 +
    '┗──────────────────────────────┛';
    lab.Font.Name := '宋体';  // 设置字体
    lab.Font.Size := 9;        // 设置字号 
    lab.Left := (frm.ClientWidth - lab.Width) div 2;

    // 添加按钮
    btn := TButton.Create(frm);
    btn.Parent := frm;
    btn.Caption := '确定';
    btn.ModalResult := mrOK;
    btn.Height := 22; 
    btn.Width := 74;
    btn.Top := 173;
    btn.Left := (frm.ClientWidth - btn.Width) div 2;
    //btn.Left := frm.ClientWidth - btn.Width - 28;

    frm.ShowModal;
  finally
    frm.Free;
  end;
end;

procedure TfrmJdMain.dbgJsonKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (ssCtrl in Shift) and (Key = Ord('C')) then
  begin
    if dbgJson.SelectedField <> nil then
    begin
      Clipboard.AsText := dbgJson.SelectedField.AsString;
    end;
  end;
end;

procedure TfrmJdMain.miCopyClick(Sender: TObject);
begin
  if dbgJson.SelectedField <> nil then
  begin
    Clipboard.AsText := dbgJson.SelectedField.AsString;
  end;
end;

end.
