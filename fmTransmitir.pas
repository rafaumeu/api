unit fmTransmitir;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, BusinessSkinForm, bsSkinBoxCtrls,
  Vcl.StdCtrls, Vcl.Mask, bsSkinCtrls, Vcl.ExtCtrls, idcontext, IdSocketHandle,
  IdCustomHTTPServer, IdBaseComponent, IdComponent, IdCustomTCPServer,
  IdHTTPServer, bsribbon, bsSkinExCtrls, Vcl.Clipbrd, bsdbctrls;

type
  TfTransmitir = class(TForm)
    bsBusinessSkinForm1: TbsBusinessSkinForm;
    GridPanel77: TGridPanel;
    Panel58: TPanel;
    bsSkinStdLabel142: TbsSkinStdLabel;
    Panel59: TPanel;
    bsSkinStdLabel143: TbsSkinStdLabel;
    seSrvPorta: TbsSkinNumericEdit;
    seSrvUrl: TbsSkinEdit;
    IdHTTPServer1: TIdHTTPServer;
    bsSkinPanel53: TbsSkinPanel;
    ckSrvConectar: TbsSkinCheckBox;
    bsRibbonDivider53: TbsRibbonDivider;
    bsSkinPanel1: TbsSkinPanel;
    bsSkinLabel1: TbsSkinLabel;
    lblStatus: TbsSkinLabel;
    bsSkinPanel2: TbsSkinPanel;
    bsSkinLabel2: TbsSkinLabel;
    lblLinkMus1: TbsSkinLinkLabel;
    btCopLinkMus1: TbsSkinSpeedButton;
    Memo1: TMemo;
    bsSkinPanel3: TbsSkinPanel;
    lblLinkMus2: TbsSkinLinkLabel;
    btCopLinkMus2: TbsSkinSpeedButton;
    bsSkinLabel3: TbsSkinLabel;
    bsSkinPanel4: TbsSkinPanel;
    bsSkinLabel4: TbsSkinLabel;
    bsSkinPanel5: TbsSkinPanel;
    bsSkinLabel5: TbsSkinLabel;
    bsSkinPanel6: TbsSkinPanel;
    lblLinkBib1: TbsSkinLinkLabel;
    btCopLinkBib1: TbsSkinSpeedButton;
    bsSkinLabel6: TbsSkinLabel;
    bsSkinPanel7: TbsSkinPanel;
    bsSkinButton2: TbsSkinButton;
    bsSkinPanel8: TbsSkinPanel;
    btServidor: TbsSkinSpeedButton;
    btIPRede: TbsSkinSpeedButton;
    ckSrvAltIPPorta: TbsSkinCheckBox;
    bsSkinPanel9: TbsSkinPanel;
    bsSkinLabel7: TbsSkinLabel;
    btCopLink: TbsSkinSpeedButton;
    lblLink: TbsSkinLinkLabel;
    Panel1: TPanel;
    bsSkinStdLabel1: TbsSkinStdLabel;
    seSrvToken: TbsSkinEdit;
    bsSkinSpeedButton1: TbsSkinSpeedButton;
    procedure seSrvUrlExit(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure IdHTTPServer1CommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure btServidorClick(Sender: TObject);
    procedure ckSrvConectarClick(Sender: TObject);
    procedure btCopLinkMus1Click(Sender: TObject);
    procedure btCopLinkMus2Click(Sender: TObject);
    procedure btCopLinkBib1Click(Sender: TObject);
    procedure bsSkinButton2Click(Sender: TObject);
    procedure btIPRedeClick(Sender: TObject);
    procedure ckSrvAltIPPortaClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure btCopLinkClick(Sender: TObject);
    function geraToken():string;
    procedure seSrvTokenExit(Sender: TObject);
    procedure bsSkinSpeedButton1Click(Sender: TObject);
  private
    { Private declarations }
    tentativaConexao: Integer;
  public
    { Public declarations }
  end;

var
  fTransmitir: TfTransmitir;

implementation

{$R *.dfm}

uses
  fmMusica,fmMenu;

procedure TfTransmitir.bsSkinButton2Click(Sender: TObject);
begin
  close;
end;

procedure TfTransmitir.btIPRedeClick(Sender: TObject);
begin
  seSrvUrl.Text := fmIndex.GetIP;
end;

procedure TfTransmitir.bsSkinSpeedButton1Click(Sender: TObject);
begin
  seSrvToken.Text := geraToken();
  fmIndex.gravaParam('Servidor', 'Token', seSrvToken.Text);
end;

procedure TfTransmitir.btCopLinkBib1Click(Sender: TObject);
begin
  Clipboard.AsText := lblLinkBib1.Caption;
end;

procedure TfTransmitir.btCopLinkClick(Sender: TObject);
begin
  Clipboard.AsText := lblLink.Caption;
end;

procedure TfTransmitir.btCopLinkMus1Click(Sender: TObject);
begin
  Clipboard.AsText := lblLinkMus1.Caption;
end;

procedure TfTransmitir.btCopLinkMus2Click(Sender: TObject);
begin
  Clipboard.AsText := lblLinkMus2.Caption;
end;

procedure TfTransmitir.btServidorClick(Sender: TObject);
var
  Binding : TIdSocketHandle;
  url: string;
begin
  tentativaConexao := tentativaConexao+1;

  seSrvUrl.Enabled := True;
  seSrvPorta.Enabled := True;
  seSrvToken.Enabled := True;
  btIPRede.Enabled := True;
  fmIndex.spServer.Caption := '';
  btServidor.Enabled := False;
  IdHTTPServer1.Active := False;
  IdHTTPServer1.Bindings.Clear;
  lblStatus.Caption := 'Desconectado';

  lblLink.Caption := '';
  lblLink.URL := lblLink.Caption;
  lblLinkMus1.Caption := '';
  lblLinkMus1.URL := lblLinkMus1.Caption;
  lblLinkMus2.Caption := '';
  lblLinkMus2.URL := lblLinkMus2.Caption;
  lblLinkBib1.Caption := '';
  lblLinkBib1.URL := lblLinkBib1.Caption;

  if (btServidor.ImageIndex = 9) then
  begin
    btServidor.ImageIndex := 8;
    btServidor.Caption := 'Iniciar Servidor';
    btServidor.Enabled := True;
    tentativaConexao := 0;
  end
  else
  begin
    if (trim(seSrvUrl.Text) = '')
      then seSrvUrl.Text := fmIndex.GetIP;
    if (trim(seSrvPorta.Text) = '')
      then seSrvPorta.Text := '7070';
    if (StrToInt(seSrvPorta.Text) <= 0)
      then seSrvPorta.Text := '7070';
    if (trim(seSrvToken.Text) = '')
      then seSrvToken.Text := geraToken();


    IdHTTPServer1.DefaultPort := StrToInt(seSrvPorta.Text);
    Binding := IdHTTPServer1.Bindings.Add;
    Binding.Port := IdHTTPServer1.DefaultPort;
    Binding.IP := seSrvUrl.Text;
    // Also bind to localhost for local API access (e.g., from web browsers)
    if seSrvUrl.Text <> '127.0.0.1' then
    begin
      Binding := IdHTTPServer1.Bindings.Add;
      Binding.Port := IdHTTPServer1.DefaultPort;
      Binding.IP := '127.0.0.1';
    end;
    try
      IdHTTPServer1.Active := True;
      btServidor.Enabled := True;
      btServidor.ImageIndex := 9;
      btServidor.Caption := 'Desconectar Servidor';
      seSrvUrl.Enabled := False;
      seSrvPorta.Enabled := False;
      seSrvToken.Enabled := False;
      btIPRede.Enabled := False;
      fmIndex.gravaParam('Servidor', 'URL', seSrvUrl.Text);
      fmIndex.gravaParam('Servidor', 'Porta', seSrvPorta.Text);
      fmIndex.gravaParam('Servidor', 'Token', seSrvToken.Text);

      url := 'http://'+seSrvUrl.Text+':'+seSrvPorta.Text;
      fmIndex.spServer.Caption := url;
      lblStatus.Caption := 'Conectado';

      lblLink.Caption := url;
      lblLink.URL := lblLink.Caption;
      lblLinkMus1.Caption := url+'/musica?transmissao';
      lblLinkMus1.URL := lblLinkMus1.Caption;
      lblLinkMus2.Caption := url+'/musica?retorno';
      lblLinkMus2.URL := lblLinkMus2.Caption;
      lblLinkBib1.Caption := url+'/biblia?transmissao';
      lblLinkBib1.URL := lblLinkBib1.Caption;

      memo1.lines.savetofile(fmIndex.dir_config+'server/file/file.ja');
    except
      IdHTTPServer1.Active := False;
      IdHTTPServer1.Bindings.Clear;
      btServidor.Enabled := True;

      if tentativaConexao < 3 then
      begin
        if (seSrvUrl.Text <> fmIndex.GetIP) then
        begin
          seSrvUrl.Text := fmIndex.GetIP;
          btServidorClick(Sender);
        end
        else
        begin
          seSrvPorta.Text := IntToStr(1 + Random(10000));
          btServidorClick(Sender);
        end;
      end
      else
      begin
        tentativaConexao := 0;
        Application.MessageBox(PChar('Erro ao iniciar servidor!'),fmIndex.TITULO,mb_ok+mb_iconerror);
      end;
    end;
  end;
end;

procedure TfTransmitir.ckSrvAltIPPortaClick(Sender: TObject);
begin
  if ckSrvAltIPPorta.Checked then
    fmIndex.gravaParam('Servidor', 'AltPortaIP', '1')
  else
    fmIndex.gravaParam('Servidor', 'AltPortaIP', '0');
end;

procedure TfTransmitir.ckSrvConectarClick(Sender: TObject);
begin
  if ckSrvConectar.Checked then
    fmIndex.gravaParam('Servidor', 'Conectar', '1')
  else
    fmIndex.gravaParam('Servidor', 'Conectar', '0');
end;

procedure TfTransmitir.FormActivate(Sender: TObject);
begin
  tentativaConexao := 0;
end;

procedure TfTransmitir.FormKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  fmIndex.FormKeyUp(Sender, Key, Shift);
end;

function TfTransmitir.geraToken: string;
const
  CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
var
  i: Integer;
begin
  Randomize;
  Result := '';
  for i := 1 to 5 do
    Result := Result + CHARS[Random(Length(CHARS)) + 1];
end;

procedure TfTransmitir.IdHTTPServer1CommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  url:string;
  arq:string;
  txt: TStringList;
  songId: Integer;
  tagValue: Integer;
  txtModo: string;
  tocarAudio: Boolean;
  messageDraw: string;
  attemptCount: Integer;
  success: Boolean;
  isLocalRequest: Boolean;
begin
  // Allow cross-origin requests from web applications
  AResponseInfo.CustomHeaders.Values['Access-Control-Allow-Origin'] := '*';
  AResponseInfo.CustomHeaders.Values['Access-Control-Allow-Methods'] := 'GET, OPTIONS';

  arq := ARequestInfo.Document;

  // Requests via localhost (127.0.0.1) are trusted — only processes on the
  // same machine can reach this binding. Token is only required for network access.
  // AContext.Binding.IP returns the server-side socket address (getsockname),
  // which cannot be spoofed by a remote client.
  isLocalRequest := (AContext.Binding.IP = '127.0.0.1');

  // API: Health check endpoint (used by web apps to detect if LouvorJA is running)
  if arq = '/api/ping' then
  begin
    AResponseInfo.ContentType := 'application/json';
    AResponseInfo.CharSet := 'utf-8';

    if (not isLocalRequest) and
       (ARequestInfo.Params.Values['token'] <> fmIndex.lerParam('Servidor', 'Token','')) then
    begin
      AResponseInfo.ContentText := '{"status":"error","message":"Invalid token","code":"INVALID_TOKEN"}';
      Exit;
    end;

    AResponseInfo.ContentText := '{"status":"ok","app":"LouvorJA"}';
    Exit;
  end;

  // API: Change to next slide or previous slide and get status slides
  if arq = '/api/song-slides' then
  begin
    AResponseInfo.ContentType := 'application/json';
    AResponseInfo.CharSet := 'utf-8';

    if (ARequestInfo.Params.Values['token'] <> fmIndex.lerParam('Servidor', 'Token','')) then
    begin
      AResponseInfo.ContentText := '{"status":"error","message":"Invalid token","code":"INVALID_TOKEN"}';
      Exit;
    end;

    if (ARequestInfo.Params.Values['action'] = 'next') then
    begin
      if (fMusica.Visible) then
      begin
        fMusica.acaoSlide('prox');
        AResponseInfo.ContentText := '{"status":"ok","message":"Advanced to the next slide"}';
        Exit;
      end
      else
      begin
        AResponseInfo.ContentText := '{"status":"error","message":"No song playing","code":"NO_SONG_PLAYING"}';
        Exit;
      end;
    end
    else if (ARequestInfo.Params.Values['action'] = 'previous') then
    begin
      if (fMusica <> nil) and (fMusica.Visible) then
      begin
        fMusica.acaoSlide('ant');
        AResponseInfo.ContentText :=
          '{"status":"ok","message":"Reverted to the previous slide"}';
        Exit;
      end
      else
      begin
        AResponseInfo.ContentText :=
          '{"status":"error","message":"No song playing","code":"NO_SONG_PLAYING"}';
        Exit;
      end;
    end
    else if (ARequestInfo.Params.Values['action'] = 'playing-check') then
    begin
      if (fMusica <> nil) and (fMusica.Visible) then
      begin
        AResponseInfo.ContentText :=
          '{"status":"ok","message":"Song playing","code":"SONG_PLAYING"}';
        Exit;
      end
      else
      begin
        AResponseInfo.ContentText :=
          '{"status":"error","message":"No song playing","code":"NO_SONG_PLAYING"}';
        Exit;
      end;
    end
    else if (ARequestInfo.Params.Values['action'] = 'close') then
    begin
      if (fMusica <> nil) and (fMusica.Visible) then
      begin
        fMusica.Close;
        AResponseInfo.ContentText :=
          '{"status":"ok","message":"Song closed","code":"SONG_CLOSED"}';
        Exit;
      end
      else
      begin
        AResponseInfo.ContentText :=
          '{"status":"error","message":"No song playing","code":"NO_SONG_PLAYING"}';
        Exit;
      end;
    end
    else
    begin
      AResponseInfo.ResponseNo := 400;
      AResponseInfo.ContentText :=
        '{"status":"error","message":"Missing or invalid action. Usage: /api/song-slides?action=next","code":"MISSING_ACTION"}';
    end;
    Exit;
  end;

  // API: Gets the time of the computer where Louvor JA is
  if arq = '/api/clock' then
  begin
    AResponseInfo.ContentType := 'application/json';
    AResponseInfo.CharSet := 'utf-8';

    if (ARequestInfo.Params.Values['token'] <> fmIndex.lerParam('Servidor', 'Token','')) then
    begin
      AResponseInfo.ContentText := '{"status":"error","message":"Invalid token","code":"INVALID_TOKEN"}';
      Exit;
    end;

    AResponseInfo.ContentText :=
      '{"status":"ok","hour":"' + formatdatetime('hh:mm:ss', now()) + '"}';
    Exit;
  end;

  // API: Control Drawing number
  if arq = '/api/drawing-number' then
  begin
    AResponseInfo.ContentType := 'application/json';
    AResponseInfo.CharSet := 'utf-8';

    if (ARequestInfo.Params.Values['token'] <> fmIndex.lerParam('Servidor', 'Token','')) then
    begin
      AResponseInfo.ContentText := '{"status":"error","message":"Invalid token","code":"INVALID_TOKEN"}';
      Exit;
    end;

    if (ARequestInfo.Params.Values['action'] = 'get-last') then
    begin
      attemptCount := 0;
      success := False;

      while (attemptCount < 3) do
      begin
        if (fmIndex.btSortear.Enabled) then
        begin
          messageDraw := fmIndex.lmdSorteio.Caption;
          AResponseInfo.ContentText := '{"status":"ok","action":"get-last","message":"' + messageDraw + '"}';
          success := True;
          Break;
        end
        else
        begin
          Inc(attemptCount);
          Sleep(1000);
        end;
      end;

      if not success then
      begin
        AResponseInfo.ContentText := '{"status":"error","message":"Failed after 3 attempts, button not enabled","code":"BUTTON_NOT_ENABLED"}';
      end;
      Exit;
    end
    else if (ARequestInfo.Params.Values['action'] = 'draw') then
    begin
      fmIndex.btSortearClick(fmIndex.btSortear);
      AResponseInfo.ContentText := '{"status":"ok","action":"get-last","message":"Sorteando n�mero"}';
      Exit;
    end;
    Exit;
  end;

  // API: Control Drawing name
  if arq = '/api/drawing-name' then
  begin
    AResponseInfo.ContentType := 'application/json';
    AResponseInfo.CharSet := 'utf-8';

    if (ARequestInfo.Params.Values['token'] <> fmIndex.lerParam('Servidor', 'Token','')) then
    begin
      AResponseInfo.ContentText := '{"status":"error","message":"Invalid token","code":"INVALID_TOKEN"}';
      Exit;
    end;

    if (ARequestInfo.Params.Values['action'] = 'get-last') then
    begin
      attemptCount := 0;
      success := False;

      while (attemptCount < 3) do
      begin
        if (fmIndex.btSortearNM.Enabled) then
        begin
          messageDraw := fmIndex.lmdSorteioNM.Caption;
          AResponseInfo.ContentText := '{"status":"ok","action":"get-last","message":"' + messageDraw + '"}';
          success := True;
          Break;
        end
        else
        begin
          Inc(attemptCount);
          Sleep(1000);
        end;
      end;

      if not success then
      begin
        AResponseInfo.ContentText := '{"status":"error","message":"Failed after 3 attempts, button not enabled","code":"BUTTON_NOT_ENABLED"}';
      end;
      Exit;
    end
    else if (ARequestInfo.Params.Values['action'] = 'draw') then
    begin
      fmIndex.btSortearNMClick(fmIndex.btSortearNM);
      AResponseInfo.ContentText := '{"status":"ok","action":"get-last","message":"Sorteando nome"}';
      Exit;
    end;
    Exit;
  end;

  // API: Open a song slide by its database ID
  // Usage: GET /api/open-song?id=123
  if arq = '/api/open-song' then
  begin
    AResponseInfo.ContentType := 'application/json';
    AResponseInfo.CharSet := 'utf-8';

    if (not isLocalRequest) and
       (ARequestInfo.Params.Values['token'] <> fmIndex.lerParam('Servidor', 'Token','')) then
    begin
      AResponseInfo.ContentText := '{"status":"error","message":"Invalid token","code":"INVALID_TOKEN"}';
      Exit;
    end;

    if TryStrToInt(ARequestInfo.Params.Values['id'], songId) then
    begin
      if not TryStrToInt(ARequestInfo.Params.Values['tag'], tagValue) then
        tagValue := 1;

      if tagValue = 2 then
        txtModo := 'PB'
      else
        txtModo := '';

      tocarAudio := tagValue < 3;

      TThread.Queue(nil,
        procedure
        begin
          if Assigned(fmIndex) then
            fmIndex.abreLetraMusica('BD', txtModo, songId, tocarAudio);
        end
      );
      AResponseInfo.ContentText :=
        '{"status":"ok","action":"open-song","id":' + IntToStr(songId) + '}';
    end
    else
    begin
      AResponseInfo.ResponseNo := 400;
      AResponseInfo.ContentText :=
        '{"status":"error","message":"Missing or invalid song ID. Usage: /api/open-song?id=123","code":"MISSING_ID"}';
    end;
    Exit;
  end;

  // Static file serving (existing behavior)
  if (Trim(arq) = '') or (Trim(arq) = '/') then
    arq := '/index.htm';
  if (Trim(arq) = '/musica') or (Trim(arq) = '/musica/') or
     (Trim(arq) = '/biblia') or (Trim(arq) = '/biblia/') then
    arq := '/page.htm';
  url := fmIndex.dir_config+'server'+arq;
  if not FileExists(url) then
  begin
    arq := '/pagina_nao_encontrada.htm';
    url := fmIndex.dir_config+'server'+arq;
  end;
  txt := TStringList.Create;
  try
    txt.LoadFromFile(url);
    AResponseInfo.ContentText := txt.Text;
  finally
    txt.Free;
  end;
end;

procedure TfTransmitir.seSrvTokenExit(Sender: TObject);
begin
  fmIndex.gravaParam('Servidor', 'Token', seSrvToken.Text);
end;

procedure TfTransmitir.seSrvUrlExit(Sender: TObject);
begin
  seSrvUrl.Text := StringReplace(seSrvUrl.Text,'http://','',[rfIgnoreCase, rfReplaceAll]);
  seSrvUrl.Text := StringReplace(seSrvUrl.Text,'https://','',[rfIgnoreCase, rfReplaceAll]);
  //192.168.56.1
end;

end.
