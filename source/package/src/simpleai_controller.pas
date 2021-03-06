{
This file is part of the SimpleAI package.
(c) Luri Darmawan <luri@fastplaz.com>

For the full copyright and license information, please view the LICENSE
file that was distributed with this source code.
}
unit simpleai_controller;

{$mode objfpc}{$H+}

interface

uses
  common, stemmingnazief_lib, json_lib, http_lib,
  simpleai_lib, dateutils, Dos, RegExpr, fpjson,
  IniFiles, Classes, SysUtils;

const
  _AI_NAME = 'CarikBot';

  _AI_COUNT__MINIMAL_ASKNAME = 5;
  _AI_ACTION_SEPARATOR = '|';

  _AI_CMD_OPENFILE = 'file';
  _AI_CMD_URL = 'url';
  _AI_CMD_GET = 'get';
  _AI_CMD_OPENJSONFILE = 'file-json';

  CMD_URL_WITH_CACHE = 'url-cache';
  CMD_GET_WITH_CACHE = 'get-cache';
  CMD_JSON = 'json';
  CMD_JSON_WITH_CACHE = 'json-cache';
  CMD_JSONGET = 'json-get';
  CMD_JSONGET_WITH_CACHE = 'json-get-cache';
  CMD_POST = 'post';
  CMD_POST_WITH_CACHE = 'post-cache';
  CommandList: array  [1..11] of string =
    (_AI_CMD_OPENFILE, _AI_CMD_GET, _AI_CMD_URL, CMD_JSONGET,
    CMD_URL_WITH_CACHE, CMD_GET_WITH_CACHE, CMD_JSON, CMD_JSON_WITH_CACHE,
    CMD_JSONGET_WITH_CACHE, CMD_POST, CMD_POST_WITH_CACHE);

type

  { TSimpleAI }

  TSimpleAI = class
  private
    FActionCallback: string;
    FAdditionalParameters: TStrings;
    FAIName: string;
    FIsExternal: Boolean;
    FIsURLEncoded: boolean;
    FKeyName: string;
    FMsg: string;
    FNonStandardWordFile: String;
    FOriginalMessage: string;
    FPrefixText: string;
    FRequestText: string;
    FResponseText: TStringList;
    FSimpleAILib: TSimpleAILib;
    FResponseData: TMemIniFile;
    FResponseDataAsList: TStringList;
    FStemmedText: string;
    FStemmedJson: string;
    FStemmedWordCount, FNonStandardWordCount, FUnknownWordCount : Integer;
    FStemmingDictionary: string;
    FSuffixText: string;
    FTrimMessage: boolean;
    FVarName: string;
    FIsStemming: boolean;
    FStandardWordCheck: Boolean;

    function getIsStemming: boolean;
    function getResponseJson: string;
    function getTimeSession(): string;

    function getAction: string;
    function getDebug: boolean;
    function getIntentName: string;
    function getParameters: TStrings;
    function getParameterValue(KeyName: string): string;
    function getPatternString: string;

    function generateGetQuery: string;
    function execPost(AURL: string; ACache: boolean = False): string;
    function execJson(AURL: string; ACache: boolean = False): string;
    function execJsonGet(AURL: string; ACache: boolean = False): string;
    function execGet(AURL: string; ACache: boolean = False): string;

    procedure setDebug(AValue: boolean);
    function isValidCommand(ACommandString: string): boolean;
    function isCommand(Msg: string): boolean;
    function execCommand(Message: string): string;
    function openFile(FileName: string): string;
    procedure setIsStemming(AValue: boolean);
    procedure SetStemmingDictionary(AValue: string);
  public
    StartTime, StopTime, ElapsedTime: cardinal;
    constructor Create; virtual;
    destructor Destroy; virtual;

    procedure Clear;
    function AddIntentFromFile(FileName: string): boolean;
    function AddEntitiesFromFile(FileName: string): boolean;
    function AddResponFromFile(FileName: string): boolean;

    function Exec(Text: string; AutoResponse: boolean = True): boolean;
    function GetQuestions(IntentName: string; Key: string = '';
      MsgCount: integer = _AI_COUNT__MINIMAL_ASKNAME): string;
    function GetResponse(IntentName: string; Action: string = '';
      EntitiesKey: string = ''): string;
    function SetResponseData(List: TStrings): boolean;
    function StringReplacement(Text: string; BURLEncode: boolean = False): string;

    property AIName: string read FAIName write FAIName;
    property SimpleAILib: TSimpleAILib read FSimpleAILib;
    property Action: string read getAction;
    property IntentName: string read getIntentName;
    property KeyName: string read FKeyName;
    property VarName: string read FVarName;
    property Parameters: TStrings read getParameters;
    property AdditionalParameters: TStrings
      read FAdditionalParameters write FAdditionalParameters;
    property Values[KeyValue: string]: string read getParameterValue; default;
    property ActionCallback: string read FActionCallback;
    property IsURLEncoded: Boolean read FIsURLEncoded;
    property IsExternal: Boolean read FIsExternal;
    property ResponseText: TStringList read FResponseText write FResponseText;
    property ResponseJson: string read getResponseJson;
    property ResponData: TMemIniFile read FResponseData;
    property PrefixText: string read FPrefixText write FPrefixText;
    property SuffixText: string read FSuffixText write FSuffixText;
    property Debug: boolean read getDebug write setDebug;
    property Pattern: string read getPatternString;
    property Msg: string read FMsg;
    property TrimMessage: boolean read FTrimMessage write FTrimMessage;
    property OriginalMessage: string read FOriginalMessage write FOriginalMessage;

    // Stemming
    property Stemming: boolean read getIsStemming write setIsStemming;
    property StemmingDictionary: string read FStemmingDictionary
      write SetStemmingDictionary;
    property StemmedText: string read FStemmedText;

    property StandardWordCheck: Boolean read FStandardWordCheck write FStandardWordCheck;
    property NonStandardWordFile: String read FNonStandardWordFile write FNonStandardWordFile;
  end;

implementation

const
  _BASEDIR = 'files/';

// command

var
  NamaHari: TWeekNameArray = ('Minggu', 'Senin', 'Selasa', 'Rabu',
    'Kamis', 'Jumat', 'Sabtu');
  NamaBulan: TMonthNameArray = ('Januari', 'Februari', 'Maret', 'April',
    'Mei', 'Juni', 'Juli', 'Augustus', 'September', 'Oktober', 'November', 'Desember');

{ TSimpleAI }

function TSimpleAI.getIntentName: string;
begin
  Result := FSimpleAILib.IntentName;
end;

function TSimpleAI.getParameters: TStrings;
begin
  Result := FSimpleAILib.Parameters;
end;

function TSimpleAI.getParameterValue(KeyName: string): string;
begin
  Result := FSimpleAILib.Parameters.Values[KeyName];
end;

function TSimpleAI.getPatternString: string;
begin
  Result := FSimpleAILib.Pattern;
end;

function TSimpleAI.generateGetQuery: string;
var
  i: integer;
begin
  Result := '';
  for i := 0 to FSimpleAILib.Parameters.Count - 1 do
  begin
    Result := Result + '&' + FSimpleAILib.Parameters.Names[i] + '=' +
      UrlEncode(FSimpleAILib.Parameters.ValueFromIndex[i]);
  end;
end;

function TSimpleAI.StringReplacement(Text: string; BURLEncode: boolean): string;
var
  i: integer;
  s, t, range: string;
  y, m, d: word;
  regex: TRegExpr;
  dateTimePosition: TDateTime;
begin
  Result := Text;
  Result := FSimpleAILib.Intent.Entities.preg_replace(
    '%(time_session)%', getTimeSession, Result, False);
  Result := FSimpleAILib.Intent.Entities.preg_replace(
    '%(AIName)%', AIName, Result, False);
  Result := FSimpleAILib.Intent.Entities.preg_replace(
    '%(BotName)%', AIName, Result, False);

  dateTimePosition := now;

  //Setup Additional Parameter
  for i := 0 to FAdditionalParameters.Count - 1 do
  begin
    FSimpleAILib.Parameters.Values[FAdditionalParameters.Names[i]] :=
      FAdditionalParameters.ValueFromIndex[i];
  end;



  //if in range
  range := FSimpleAILib.Parameters.Values['range_value'];
  {
  if range = 'sekarang' then
    range := '';
  }
  if (range <> '') then
  begin
    case range of
      'kemaren lusa',
      'kemarin lusa':
      begin
        dateTimePosition := IncDay(Now, -2);
      end;
      'kemaren',
      'kemarin':
      begin
        dateTimePosition := IncDay(Now, -1);
      end;
      'bsk',
      'besok':
      begin
        dateTimePosition := IncDay(Now, 1);
      end;
      'lusa':
      begin
        dateTimePosition := IncDay(Now, 2);
      end;
      'besok lusa':
      begin
        dateTimePosition := IncDay(Now, 3);
      end;
    end;
  end;
  // waktu
  if FSimpleAILib.Intent.Entities.preg_match('%(time)%', Result) then
  begin
    DecodeDate(dateTimePosition, y, m, d);
    s := Parameters.Values['Waktu'];
    if s = '' then
      s := 'jam';
    t := '';
    case s of
      'jam': t := FormatDateTime('hh:nn', dateTimePosition) + ' ' + getTimeSession;
      'hari': t := NamaHari[DayOfWeek(dateTimePosition)];
      'bulan': t := NamaBulan[m];
      'tahun': t := IntToStr(y);
      'tanggal': t := FormatDateTime('dd/mm/yyyy', dateTimePosition)
    end;
    t := range + ' ' + t;
    Result := FSimpleAILib.Intent.Entities.preg_replace(
      '%(time)%', t, Result, False);
  end;

  regex := TRegExpr.Create;
  //regex.Expression := '%(.*)%';
  regex.Expression := '%([a-zA-Z0-9_]+)%';
  if regex.Exec(Result) then
  begin
    s := regex.Match[1];
    if FSimpleAILib.Parameters.Values[s] <> '' then
    begin
      if BURLEncode then
        Result := SimpleAILib.Intent.Entities.preg_replace(
          '%' + s + '%', UrlEncode(FSimpleAILib.Parameters.Values[s]), Result, True)
      else
        Result := SimpleAILib.Intent.Entities.preg_replace(
          '%' + s + '%', FSimpleAILib.Parameters.Values[s], Result, True);
    end;

    while regex.ExecNext do
    begin
      s := regex.Match[1];
      if FSimpleAILib.Parameters.Values[s] <> '' then
      begin
        if BURLEncode then
          Result := SimpleAILib.Intent.Entities.preg_replace(
            '%' + s + '%', UrlEncode(FSimpleAILib.Parameters.Values[s]), Result, True)
        else
          Result := SimpleAILib.Intent.Entities.preg_replace(
            '%' + s + '%', FSimpleAILib.Parameters.Values[s], Result, True);
      end
      else
      begin
        Result := SimpleAILib.Intent.Entities.preg_replace(
          '%' + s + '%', '', Result, True);
      end;
    end;

  end;
  regex.Free;

end;

procedure TSimpleAI.setDebug(AValue: boolean);
begin
  FSimpleAILib.Intent.Debug := AValue;
end;

function TSimpleAI.isValidCommand(ACommandString: string): boolean;
var
  s: string;
begin
  Result := False;
  for s in CommandList do
  begin
    if ACommandString = s then
      Exit(True);
  end;
end;

function TSimpleAI.isCommand(Msg: string): boolean;
var
  lst: TStrings;
begin
  Result := False;
  if Msg = '' then
    Exit;
  lst := Explode(Msg, ':');
  if lst.Count = 1 then
  begin
    lst.Free;
    Exit;
  end;

  if isValidCommand(lst[0]) then
    Result := True;

  lst.Free;
end;

function TSimpleAI.execCommand(Message: string): string;
var
  convertedMessage, s, url: string;
  lst: TStrings;

  function stripText(AText: string): string;
  begin
    Result := StringReplace(AText, '<b>', '*', [rfReplaceAll]);
    Result := StringReplace(Result, '</b>', '*', [rfReplaceAll]);
    Result := StripHTML(Result);
    Result := StringReplace(Result, #9, '', [rfReplaceAll]);
    Result := StringReplace(Result, #13, '\n', [rfReplaceAll]);
    Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  end;

begin
  Result := Message;
  convertedMessage := StringReplacement(Message);
  lst := Explode(convertedMessage, ':');
  case lst[0] of
    _AI_CMD_OPENFILE:
    begin
      s := trim(_BASEDIR + lst[1]);
      Result := openFile(s);
      if Result = '' then
        Result := convertedMessage;
      Result := Trim(Result);
      Result := StringReplace(Result, #13, '\n', [rfReplaceAll]);
      Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
      Result := StringReplacement(Result);
    end;
    _AI_CMD_OPENJSONFILE:
    begin
      s := trim(_BASEDIR + lst[1]);
      Result := openFile(s);
      if Result = '' then
        Result := convertedMessage;
      Result := StringReplacement(Result);
    end;

    CMD_POST:
    begin
      convertedMessage := StringReplacement(Message, True);
      url := Trim(Copy(convertedMessage, Pos(':', convertedMessage) + 1));
      Result := execPost(url);
      Result := stripText(Result);
    end;
    CMD_POST_WITH_CACHE:
    begin
      convertedMessage := StringReplacement(Message, True);
      url := Trim(Copy(convertedMessage, Pos(':', convertedMessage) + 1));
      Result := execPost(url, True);
      Result := stripText(Result);
    end;

    CMD_JSON:
    begin
      convertedMessage := StringReplacement(Message, True);
      url := Trim(Copy(convertedMessage, Pos(':', convertedMessage) + 1));
      Result := execJson(url);
      Result := stripText(Result);
    end;
    CMD_JSON_WITH_CACHE:
    begin
      convertedMessage := StringReplacement(Message, True);
      url := Trim(Copy(convertedMessage, Pos(':', convertedMessage) + 1));
      Result := execJson(url, True);
      Result := stripText(Result);
    end;

    _AI_CMD_GET,
    _AI_CMD_URL:
    begin
      convertedMessage := StringReplacement(Message, True);
      Result := Trim(Copy(convertedMessage, Pos(':', convertedMessage) + 1));
      Result := execGet(Result);
      Result := stripText(Result);
      if Result <> '' then
        Result := Result + GetResponse(IntentName + 'Footer');
    end;
    CMD_GET_WITH_CACHE,
    CMD_URL_WITH_CACHE:
    begin
      convertedMessage := StringReplacement(Message, True);
      Result := Trim(Copy(convertedMessage, Pos(':', convertedMessage) + 1));
      Result := execGet(Result, True);
      Result := stripText(Result);
      if Result <> '' then
        Result := Result + GetResponse(IntentName + 'Footer');
    end;
    CMD_JSONGET:
    begin
      convertedMessage := StringReplacement(Message, True);
      url := Trim(Copy(convertedMessage, Pos(':', convertedMessage) + 1));
      Result := execJsonGet(url);
      Result := stripText(Result);
    end;
    CMD_JSONGET_WITH_CACHE:
    begin
      convertedMessage := StringReplacement(Message, True);
      url := Trim(Copy(convertedMessage, Pos(':', convertedMessage) + 1));
      Result := execJsonGet(url, True);
      Result := stripText(Result);
    end;
  end;

  lst.Free;
end;

function TSimpleAI.openFile(FileName: string): string;
var
  _note: TStringList;
begin
  Result := '';
  if FileExists(trim(FileName)) then
  begin
    _note := TStringList.Create;
    _note.LoadFromFile(trim(FileName));
    Result := _note.Text;
    _note.Free;
  end;
end;

function TSimpleAI.execPost(AURL: string; ACache: boolean): string;
var
  i: integer;
  s: string;
  lst: TStrings;
  Response: IHTTPResponse;
begin
  Result := '';

  if ACache then
  begin
    Result := LoadCache(AURL);
    Result := Trim(Result);
    if Result <> '' then
      Exit;
  end;

  with THTTPLib.Create(AURL) do
  begin
    try
      AddHeader('_source', 'carik');
      //get header from response list
      s := GetResponse(IntentName, '', 'header');
      s := StringReplace(s, ':', '=', [rfReplaceAll]);
      lst := Explode(s, '|');
      for i := 0 to lst.Count - 1 do
      begin
        if lst.Names[i] <> '' then
          AddHeader(lst.Names[i], lst.ValueFromIndex[i]);
      end;
      lst.Free;

      for i := 0 to FSimpleAILib.Parameters.Count - 1 do
      begin
        FormData[FSimpleAILib.Parameters.Names[i]] :=
          UrlEncode(FSimpleAILib.Parameters.ValueFromIndex[i]);
      end;
      Response := Post();
      Result := Response.ResultText;
      if Response.ResultCode = 200 then
      begin
        if ACache and (Result <> '') then
        begin
          SaveCache(AURL, Result);
        end;
      end
      else
      begin
        Result := 'FAILED: ' + Result;
        if not Debug then
          Result := '';
      end;
    except
      on e: Exception do
      begin
        if Debug then
        begin
          Result := e.Message;
        end;
      end;
    end;

    Free;
  end;
end;

function TSimpleAI.execJson(AURL: string; ACache: boolean): string;
var
  pathName: string;
  lst: TStrings;
  json: TJSONUtil;
begin
  Result := '';
  pathName := 'text';
  lst := Explode(AURL, '|');
  if lst.Count > 1 then
  begin
    pathName := lst[0];
    AURL := lst[1];
    Result := pathName;
  end;
  lst.Free;

  if ACache then
  begin
    Result := LoadCache(AURL);
    Result := Trim(Result);
    if Result <> '' then
      Exit;
  end;

  Result := execPost( AURL);

  if Result = '' then
    Exit;

  json := TJSONUtil.Create;
  try
    json.LoadFromJsonString(Result);
    Result := json[pathName];
    if ACache and (Result <> '') then
    begin
      SaveCache(AURL, Result);
    end;
  except
    Result := '';
  end;

end;

function TSimpleAI.execJsonGet(AURL: string; ACache: boolean): string;
var
  pathName: string;
  lst: TStrings;
  json: TJSONUtil;
begin
  Result := '';
  pathName := 'text';
  lst := Explode(AURL, '|');
  if lst.Count > 1 then
  begin
    pathName := lst[0];
    AURL := lst[1];
    Result := pathName;
  end;
  lst.Free;

  if ACache then
  begin
    Result := LoadCache(AURL);
    Result := Trim(Result);
    if Result <> '' then
      Exit;
  end;

  Result := file_get_contents(AURL);
  if Result = '' then
    Exit;

  json := TJSONUtil.Create;
  try
    json.LoadFromJsonString(Result);
    Result := json[pathName];
    if ACache and (Result <> '') then
    begin
      SaveCache(AURL, Result);
    end;
  except
    Result := '';
  end;
  json.Free;
end;

function TSimpleAI.execGet(AURL: string; ACache: boolean): string;
var
  i: integer;
  s, tempURL: string;
  lst: TStrings;
  Response: IHTTPResponse;
begin
  Result := '';
  if ACache then
  begin
    Result := LoadCache(AURL);
    Result := Trim(Result);
    if Result <> '' then
      Exit;
  end;

  tempURL := AURL;
  if GetResponse(IntentName, '', 'full-query') = 'yes' then
    tempURL := AURL + generateGetQuery;

  with THTTPLib.Create(tempURL) do
  begin
    try
      AddHeader('_source', 'carik');
      //get header from response list
      s := GetResponse(IntentName, '', 'header');
      s := StringReplace(s, ':', '=', [rfReplaceAll]);
      lst := Explode(s, '|');
      for i := 0 to lst.Count - 1 do
      begin
        if lst.Names[i] <> '' then
          AddHeader(lst.Names[i], lst.ValueFromIndex[i]);
      end;
      lst.Free;

      for i := 0 to FSimpleAILib.Parameters.Count - 1 do
      begin
        FormData[FSimpleAILib.Parameters.Names[i]] :=
          UrlEncode(FSimpleAILib.Parameters.ValueFromIndex[i]);
      end;
      Response := Get();
      Result := Response.ResultText;
      if Response.ResultCode <> 200 then
      begin
        Result := 'FAILED: ' + Result;
        if not Debug then
          Result := '';
      end;
    except
      on e: Exception do
      begin
        if Debug then
        begin
          Result := e.Message;
        end;
      end;
    end;
    Free;
  end;

  if ACache and (Result <> '') then
  begin
    SaveCache(AURL, Result);
  end;
end;

function TSimpleAI.getTimeSession(): string;
var
  Hour, Min, Sec, HSec: word;
begin
  GetTime(Hour, Min, Sec, HSec);
  Result := 'pagi';
  if Hour > 11 then
    Result := 'siang';
  if Hour >= 15 then
    Result := 'sore';
  if Hour > 17 then
    Result := 'sore';
  if Hour >= 18 then
    Result := 'malam';
end;

function TSimpleAI.getAction: string;
begin
  Result := FSimpleAILib.Action;
end;

function TSimpleAI.getDebug: boolean;
begin
  Result := FSimpleAILib.Intent.Debug;
end;

constructor TSimpleAI.Create;
begin
  FAIName := _AI_NAME;
  FResponseData := TMemIniFile.Create('');
  FResponseDataAsList := TStringList.Create;
  FSimpleAILib := TSimpleAILib.Create;
  FResponseText := TStringList.Create;
  FAdditionalParameters := TStringList.Create;
  FMsg := '';
  FOriginalMessage := '';
  FActionCallback := '';
  FIsURLEncoded := false;
  FTrimMessage := False;
  FIsExternal := False;

  // Stemming
  FIsStemming := False;
  FStemmingDictionary := 'files' + DirectorySeparator + STEMMINGNAZIEF_DICTIONARY_FILE;
  FStemmedText := '';
  FStandardWordCheck := False;
  FNonStandardWordFile := 'files' + DirectorySeparator + WORD_NONSTANDARD_FILE;
end;

destructor TSimpleAI.Destroy;
begin
  FAdditionalParameters.Free;
  FResponseText.Free;
  FResponseDataAsList.Free;
  FResponseData.Free;
  FSimpleAILib.Free;
end;

procedure TSimpleAI.Clear;
begin
  FSimpleAILib.Clear;
end;

function TSimpleAI.AddIntentFromFile(FileName: string): boolean;
begin
  Result := FSimpleAILib.AddDataIntentFromFile(FileName);
end;

function TSimpleAI.AddEntitiesFromFile(FileName: string): boolean;
begin
  Result := FSimpleAILib.AddDataEntitiesFromFile(FileName);
end;

function TSimpleAI.AddResponFromFile(FileName: string): boolean;
var
  lst: TStrings;
begin
  Result := False;
  if not FileExists(FileName) then
    exit;

  if Assigned(FResponseData) then
    FResponseData.Free;
  FResponseData := TMemIniFile.Create('');
  FResponseData.Clear;
  lst := TStringList.Create;
  with TStringList.Create do
  begin
    LoadFromFile(FileName);
    FResponseDataAsList.Add(Text);

    lst.Text := FResponseDataAsList.Text;
    FResponseData.SetStrings(lst);

    Result := True;
    Free;
  end;
  lst.Free;

end;

function TSimpleAI.Exec(Text: string; AutoResponse: boolean): boolean;
var
  stemmer: TStemmingNazief;
begin
  FMsg := '';
  Result := False;
  FIsExternal := False;
  if Text = '' then
    Exit;

  StartTime := _GetTickCount;
  if FTrimMessage then
  begin
    Text := ReplaceAll(Text, ['''', '"'], '');
  end;

  if FIsStemming then
  begin
    stemmer := TStemmingNazief.Create;
    stemmer.LoadDictionaryFromFile(FStemmingDictionary);
    stemmer.StandardWordCheck := FStandardWordCheck;
    if FStandardWordCheck then
      stemmer.LoadNonStandardWordFromFile( FNonStandardWordFile);
    FStemmedJson := stemmer.ParseSentence(Text);
    FStemmedWordCount := stemmer.WordCount;
    FNonStandardWordCount := stemmer.NonStandardWordCount;
    FUnknownWordCount := stemmer.UnknownWordCount;
    FStemmedText := stemmer.Text;
    FIsStemming := stemmer.IsDictionaryLoaded;
    Stemmer.Free;
  end;

  FResponseText.Clear;
  Result := FSimpleAILib.Exec(Text);
  if not AutoResponse then
    Exit;

  FRequestText := Text;

  if Result then
  begin
    FResponseText.Add(GetResponse(IntentName, Action, ''));
    FActionCallback := GetResponse(IntentName, '', 'action');
    FIsURLEncoded := s2b( GetResponse(IntentName, '', 'urlencoded'));
    if FActionCallback = '._' then
      FActionCallback := '';
  end
  else
  begin
    FResponseText.Add(GetResponse('none', '', ''));
    FActionCallback := '';
  end;

  FResponseText.Text := FPrefixText + FResponseText.Text + FSuffixText;
  if FSimpleAILib.Intent.Entities.preg_match('%(.*)%', FResponseText.Text) then
  begin
    FResponseText.Text := StringReplacement(FResponseText.Text, FIsURLEncoded);
  end;

  // is Command
  if isCommand(FResponseText.Text) then
  begin
    //FResponseText.Text := execCommand(FResponseText.Text);
  end;
  StopTime := _GetTickCount;
  ElapsedTime := StopTime - StartTime;
end;

function TSimpleAI.GetQuestions(IntentName: string; Key: string;
  MsgCount: integer): string;
begin
  Result := GetResponse(IntentName, '', Key);
end;

function TSimpleAI.GetResponse(IntentName: string; Action: string;
  EntitiesKey: string): string;
var
  i: integer;
  item_list: TStringList;
begin
  Result := '';

  if EntitiesKey <> '' then
  begin
    Result := FResponseData.ReadString(IntentName, EntitiesKey, '._');
    Exit;
  end;

  item_list := TStringList.Create;
  FResponseData.ReadSectionRaw(IntentName, item_list);

  // clean up
  for i := item_list.Count - 1 downto 0 do
  begin
    if pos('say=', item_list[i]) <> 1 then
      item_list.Delete(i);
  end;

  if item_list.Count > 0 then
  begin
    Randomize;

    RandSeed := GetTickCount64;
    i := Random(item_list.Count);

    Result := item_list[i];
    FKeyName := item_list.Names[i];
    i := pos(':', Result);
    if i > 0 then
    begin
      FVarName := copy(FKeyName, i + 1);
      FKeyName := copy(FKeyName, 0, i - 1);
    end;

    if Debug then
    begin
      //FMsg := '';
    end;
    Result := copy(Result, pos('=', Result) + 1);
  end;

  item_list.Free;
  if isCommand(Result) then
  begin
    FIsExternal := True;
    Result := execCommand(Result);
  end;
end;

function TSimpleAI.SetResponseData(List: TStrings): boolean;
begin
  Result := False;
  if not Assigned(List) then
    Exit;

  if Assigned(FResponseData) then
    FResponseData.Free;
  FResponseData := TMemIniFile.Create('');
  FResponseData.Clear;

  FResponseDataAsList.Add(List.Text);
  FResponseData.SetStrings(List);

  Result := True;
end;


function TSimpleAI.getResponseJson: string;
var
  i: integer;
  s, json, actionName, txt, v: string;
  lst: TStrings;
  o: TJSONUtil;
  cmdAction, parameterAction, fieldAction : TStrings;
begin
  Result := '';
  actionName := Action;
  lst := FSimpleAILib.Intent.Explode(Action, _AI_ACTION_SEPARATOR);
  if lst.Count > 0 then
    actionName := lst[0];

  // response text
  txt := '';
  for i := 0 to FResponseText.Count - 1 do
  begin
    txt := txt + '"' + StringToJSONString(FResponseText[i]) + '"';
    if i < FResponseText.Count - 1 then
      txt := txt + ',';
  end;

  json := json + '';
  json := json + '{';
  json := json + '"code" : 0,';
  json := json + '"request" : {';
  json := json + '"text" : "' + StringToJSONString(FRequestText) + '"';
  if FOriginalMessage <> '' then
    json := json + ',"original_text" : "' + StringToJSONString(FOriginalMessage) + '"';
  json := json + '},';
  if FIsStemming then
  begin
    json := json + '"stemming" : {';
    json := json + '"text" : "' + FStemmedText + '",';
    json := json + '"wordcount" : "' + i2s(FStemmedWordCount) + '",';
    json := json + '"nonstandardword_count" : "' + i2s(FNonStandardWordCount) + '",';
    json := json + '"unknownword_count" : "' + i2s(FUnknownWordCount) + '",';
    json := json + '"response" : ' + FStemmedJson;
    json := json + '},';
  end;
  json := json + '"response" : {';
  json := json + '"intents" : {';
  json := json + '"action" : "' + actionName + '",';
  json := json + '"name" : "' + IntentName + '",';
  if Debug then
  begin
    json := json + '"key" : "' + FSimpleAILib.Intent.IntentKey + '",';
    json := json + '"pattern" : "' + StringToJSONString(FSimpleAILib.Pattern) + '",';
    //json := json + '"time_usage" : "' + IntToStr(ElapsedTime) + '",';
  end;
  json := json + '"parameters" : {';

  for i := 0 to FSimpleAILib.Parameters.Count - 1 do
  begin
    v := FSimpleAILib.Parameters.ValueFromIndex[i];
    v := StringToJSONString(v);
    json := json + '"' + FSimpleAILib.Parameters.Names[i] + '" : "' + v + '"';

    if i < FSimpleAILib.Parameters.Count - 1 then
      json := json + ',';
  end;
  json := json + '}';
  json := json + '},';
  json := json + '"text" : [' + txt + ']';
  if FIsExternal then
    json := json + ',"external" : true';
  if FMsg <> '' then
    json := json + ',"msg" : "' + FMsg + '"';
  json := json + '}';
  json := json + '}';

  lst.Free;

  if FActionCallback <> '' then
  begin
    FActionCallback := StringReplacement(FActionCallback);
    parameterAction := Explode(FActionCallback, '|');
    cmdAction := Explode(parameterAction[0], '.');

    o := TJSONUtil.Create;
    o.LoadFromJsonString( json);
    o['response/action/callback_string'] := FActionCallback;
    o['response/action/callback_name'] := cmdAction[0];
    if cmdAction.Count > 1 then
      o['response/action/callback_method'] := cmdAction[1];
    for i := 1 to parameterAction.count - 1 do
    begin
      fieldAction := Explode(parameterAction[i], '=');
      s := '';
      try
        s := fieldAction[1];
      except
      end;
      o['response/action/parameter_' + i2s(i)] := parameterAction[i];
      o['response/action/' + fieldAction[0]] := s;
      fieldAction.Free;
    end;

    json := o.AsJSON;
    o.Free;
    cmdAction.Free;
    parameterAction.Free;
  end;// FActionCallback

  Result := json;
end;

procedure TSimpleAI.setIsStemming(AValue: boolean);
begin
  FIsStemming := AValue;
end;

procedure TSimpleAI.SetStemmingDictionary(AValue: string);
begin
  if FStemmingDictionary = AValue then
    Exit;
  FStemmingDictionary := AValue;
end;

function TSimpleAI.getIsStemming: boolean;
begin
  Result := FIsStemming;
end;


end.
