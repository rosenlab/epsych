function varargout = CondAvoidGUI(varargin)
% CondAvoidGUI M-file for CondAvoidGUI.fig
%      CondAvoidGUI, by itself, creates a new CondAvoidGUI or raises the existing
%      singleton*.
%
%      H = CondAvoidGUI returns the handle to a new CondAvoidGUI or the
%      handle to
%      the existing singleton*.
%
%      CondAvoidGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in CondAvoidGUI.M with the given input
%      arguments.
%
%      CondAvoidGUI('Property','Value',...) creates a new CondAvoidGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before CondAvoidGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to CondAvoidGUI_OpeningFcn via
%      varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help CondAvoidGUI

% Last Modified by GUIDE v2.5 08-Jun-2015 15:33:23

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @CondAvoidGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @CondAvoidGUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before CondAvoidGUI is made visible.
function CondAvoidGUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to CondAvoidGUI (see VARARGIN)

% Choose default command line output for CondAvoidGUI
handles.output = hObject;


% Update handles structure
guidata(hObject, handles);


T = CreateTimer(handles.figure1);

start(T);

set(handles.MaskAlone_radio,'value',1);
set(handles.VaryToneDur_radio,'value',0);
set(handles.VaryToneLevel_radio,'value',0);

MaskAlone_radio_Callback(hObject, eventdata, handles)
%intrial = RP.GetTagVal('In_Trial');
%disp(intrial);



% --- Outputs from this function are returned to the command line.
function varargout = CondAvoidGUI_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function CloseReq(f) %#ok<DEFNU>
T = timerfind('Name','BoxTimer');
if ~isempty(T), stop(T); delete(T); end

delete(f);


function T = CreateTimer(f)
% Create new timer for RPvds control of experiment
T = timerfind('Name','BoxTimer');
if ~isempty(T)
    stop(T);
    delete(T);
end

T = timer('BusyMode','drop', ...
    'ExecutionMode','fixedSpacing', ...
    'Name','BoxTimer', ...
    'Period',0.5, ...
    'StartFcn',{@BoxTimerSetup,f}, ...
    'TimerFcn',{@BoxTimerRunTime,f}, ...
    'ErrorFcn',{@BoxTimerError}, ...
    'StopFcn', {@BoxTimerStop}, ...
    'TasksToExecute',inf, ...
    'StartDelay',2);



function BoxTimerSetup(hObj,~,f)
global RUNTIME

h = guidata(f);

RUNTIME.StartTime = clock;

cols = {'ResponseCode','TrialType','Tone_Dur','Tone_dBSPL','Noise_Dur','Noise_dBSPL'};

set(h.DataTable,'ColumnName',cols,'data',[]);
set(h.NextTrialTable,'ColumnName',cols(2:end),'data',[],'RowName','>');

cla(h.AxPerformance);


function BoxTimerRunTime(hObj,~,f)
% function BoxTimerRunTime(hObj,~,f,hObject,eventdata,handles)
global RUNTIME

h = guidata(f);

T = RUNTIME.TRIALS;

if T.TrialIndex == 1, return; end

cols = get(h.DataTable,'ColumnName');

if RUNTIME.UseOpenEx
    cols = cellfun(@(a) (['Behave_' a]),cols,'UniformOutput',false);
    ind = ~cellfun(@isempty,strfind(cols,'ResponseCode'));
    cols{ind} = 'ResponseCode';
end

d = zeros(T.TrialIndex-1,length(cols));
for i = 1:length(cols)
    d(:,i) = [T.DATA.(cols{i})];
end


ts = zeros(T.TrialIndex-1,1);
for i = 1:T.TrialIndex-1
    ts(i) = etime(T.DATA(i).ComputerTimestamp,RUNTIME.StartTime);
end


PlotPerformance(h.AxPerformance,ts,[T.DATA.ResponseCode]);
HitMiss(h.NHitsFAs_axes,[T.DATA]);
NTrials(h.NTrials_axes,[T.DATA]);

d = flipud(d);

rows = T.TrialIndex-1:-1:1;

set(h.DataTable,'Data',d,'RowName',rows);

cols = get(h.NextTrialTable,'ColumnName');

if RUNTIME.UseOpenEx
    cols = cellfun(@(a) (['Behave.' a]),cols,'UniformOutput',false);
end

p = T.trials(T.NextTrialID,:);
nt = zeros(size(cols));
for i = 1:length(cols)
    ind = ismember(T.writeparams,cols{i});
    nt(i) = p{find(ind,1)};
end
set(h.NextTrialTable,'Data',nt(:)');

ind = ~cellfun(@isempty,strfind(T.writeparams,'TrialType'));
ind = find(ind,1);
if p{ind} == 1
    set(h.NextTrialTable,'ForegroundColor','g');
else
    set(h.NextTrialTable,'ForegroundColor','r');
end



function BoxTimerError(~,~)



function BoxTimerStop(~,~)



function PlotPerformance(ax,ts,RCode)

HITS = RCode == 17;
MISS = RCode == 18;
CR   = RCode == 40;
FA   = RCode == 36;

ind = ts < ts(end) - 60;
ts(ind) = [];
HITS(ind) = [];
MISS(ind) = [];
CR(ind) = [];
FA(ind) = [];

cla(ax);

hold(ax,'on');
plot(ax,ts(HITS),2*ones(sum(HITS),1),'rs','markerfacecolor','r');
plot(ax,ts(MISS),ones(sum(MISS),1),'ro','markerfacecolor','r');
plot(ax,ts(CR),ones(sum(CR),1),'gs','markerfacecolor','g');
plot(ax,ts(FA),2*ones(sum(FA),1),'go','markerfacecolor','g');
hold(ax,'off');

set(ax,'ylim',[0 2.5],'xlim',[ts(end)-120 ts(end)]);




function HitMiss(ax,Data)

% global traintype tonedur tonelev

% NB: ax contains UserData for gui item NHitsFAs_axes
PrevNTrials = get(ax,'UserData');
NTrials = Data(end).TrialID; % how many trials (SAFES and WARNS both) have been presented)

% If 1) This is not the first trial in the session and 
%    2) the most recent trial has not already been processed and
%    3) the most recent trial was a WARN
if NTrials > 0 && PrevNTrials~=NTrials && Data(end).TrialType == 0  
    
    HITS = [Data.ResponseCode] == 17; % logical vector of HITS
    MISS = [Data.ResponseCode] == 18;
    CR   = [Data.ResponseCode] == 40;
    FA   = [Data.ResponseCode] == 36;
    
    tonedurs = [Data.Tone_Dur];
    tonelevs = [Data.Tone_dBSPL];
    DursLevs = [tonedurs', tonelevs'];
    
    [combos m n] = unique(DursLevs,'rows');
    % for each unique row
    for i = 1:size(combos,1)
        % first column is duration; second column is level
        durcolidx(:,i) = DursLevs(:,1) == combos(i,1);
        levcolidx(:,i) = DursLevs(:,2) == combos(i,2);
        uniqueCombos{i} = durcolidx & levcolidx;        
    end
    % uC is a logical matrix showing locations of unique values corresponding to combos.
    % Column 1 of uC is logical of which rows of A correspond to row 1 of combos
    uC = uniqueCombos{end};
    
    for r = 1:size(combos,1) % for rows of combos (unique combinations of duration and level)
        labels{r} = [num2str(combos(r,1)),'ms:', num2str(combos(r,2)),'dB'];
        uCRowidx{r} = find(uC(:,r)); % indices of rows containing each unique combo
    end
    
    % The first item in uCRowidx contains SAFES (tonedur & tonelev both 0), so start from item 2 for WARNS
    % Step through each unique stimulus type
    for C = 2:size(uCRowidx,2)
        nWARNS(C) = length(uCRowidx{C});
        nHITS(C)  = sum(HITS(uCRowidx{C}));
        percHITS(C) = nHITS(C)/nWARNS(C);
    end
    
    SAFES = [Data.TrialType] == 1; % vector where WARNS are ones and SAFES are zeros
    SAFEidx = find(SAFES==1);
    nSAFES = sum(SAFES);
    nFA = sum(FA(SAFEidx));
    percFAoverall = nFA/nSAFES;
    percFAoverall = repmat(percFAoverall,1,length(percHITS));
    Y = [percHITS',percFAoverall'];
        
    cla(ax)
    hold(ax,'on');
    hb = bar(ax,Y);
    set(ax,'ylim',[0 1]);    
    hbc = get(hb, 'Children');
    set(hbc{1}, 'FaceColor', 'r')   %   Red bars for 1st column, WARNS
    set(hbc{2}, 'FaceColor', 'g')   % Green bars for 2nd column, SAFES
    set(ax,'XTick',[1:length(Y)],'XTickLabel', labels,'fontsize',8);
    hold(ax,'off');
    
end  % IF NTrials and WARN

set(ax,'UserData',NTrials);





function NTrials(ax,Data)

% NB: ax contains UserData for gui item NTrials_axes
PrevNTrials = get(ax,'UserData');
NTrials = Data(end).TrialID; % how many trials (SAFES and WARNS both) have been presented)

% If 1) This is not the first trial in the session and 
%    2) the most recent trial has not already been processed and
%    3) the most recent trial was a WARN
if NTrials > 0 && PrevNTrials~=NTrials && Data(end).TrialType == 0  
    
    tonedurs = [Data.Tone_Dur];
    tonelevs = [Data.Tone_dBSPL];
    DursLevs = [tonedurs', tonelevs'];
    
    [combos m n] = unique(DursLevs,'rows');
    % for each unique row
    for i = 1:size(combos,1)
        % first column is duration; second column is level
        durcolidx(:,i) = DursLevs(:,1) == combos(i,1);
        levcolidx(:,i) = DursLevs(:,2) == combos(i,2);
        uniqueCombos{i} = durcolidx & levcolidx;        
    end
    % uC is a logical matrix showing locations of unique values corresponding to combos.
    % Column 1 of uC is logical of which rows of A correspond to row 1 of combos
    uC = uniqueCombos{end};
    
    for r = 1:size(combos,1) % for rows of combos (unique combinations of duration and level)
        labels{r} = [num2str(combos(r,1)),'ms:', num2str(combos(r,2)),'dB'];
        uCRowidx{r} = find(uC(:,r)); % indices of rows containing each unique combo
    end
    
    % The first item in uCRowidx contains SAFES (tonedur & tonelev both 0), so start from item 2 for WARNS
    % Step through each unique stimulus type
    for C = 2:size(uCRowidx,2)
        nWARNS(C) = length(uCRowidx{C});
%         nHITS(C)  = sum(HITS(uCRowidx{C}));
%         percHITS(C) = nHITS(C)/nWARNS(C);
    end
    
    cla(ax)
    hold(ax,'on');
    hb = bar(ax,nWARNS,'FaceColor','r','BarWidth',0.3);
    set(ax,'XTick',[1:length(uCRowidx)],'XTickLabel', labels,'fontsize',8);
    hold(ax,'off');
    
end  % IF NTrials and WARN

set(ax,'UserData',NTrials);



% --- Executes on button press in TrigWater.
function TrigWater_Callback(hObject, eventdata, handles)
% hObject    handle to TrigWater (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global AX RUNTIME 

c = get(hObject,'backgroundcolor');
set(hObject,'backgroundcolor','g'); drawnow

if RUNTIME.UseOpenEx
    AX.SetTargetVal('Behave.!AddDrop',1);
    pause(0.001);
    AX.SetTargetVal('Behave.!AddDrop',0);
else
    AX.SetTagVal('!AddDrop',1);
    pause(0.001);
    AX.SetTagVal('!AddDrop',0);
end

% if RUNTIME.UseOpenEx
%     licked = AX.GetTargetVal('Behave.!Licking',1);
% else
%     licked = AX.GetTagVal('!Licking',1);
%     disp('licked: ',num2str(licked))
% end


set(hObject,'backgroundcolor',c); drawnow

% The !AddDrop button will send a Schmitt trigger high for 1500ms and
% deliver water for that duration (can see this in rpv circuit)
pumprate = get(handles.WaterRate_edit,'string');
pumprate = str2num(pumprate); % typically ml/min; set during initialization
newvol = pumprate * 0.025 ; % the additional water volume. 0.025 is 1500ms expressed in minutes
totwater = str2num(get(handles.totalWater_text,'string')) + newvol; % typically in ml
set(handles.totalWater_text,'string',num2str(totwater)); drawnow;

% Update handles structure
guidata(hObject, handles);

% --- Executes on button press in Pause.
function Pause_Callback(hObject, eventdata, handles)
% hObject    handle to Pause (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of Pause

global AX RUNTIME

c = get(handles.figure1,'color');

if get(hObject,'Value') == 1
    set(hObject,'backgroundcolor','r'); drawnow
    if RUNTIME.UseOpenEx
        AX.SetTargetVal('Behave.!Pause',1);
    else
        AX.SetTagVal('!Pause',1);
    end
else
    if RUNTIME.UseOpenEx
        AX.SetTargetVal('Behave.!Pause',0);
    else
        AX.SetTagVal('!Pause',0);
    end
    set(hObject,'backgroundcolor',c); drawnow
end





% --- Executes on button press in DeBug_pushbutton.
function DeBug_pushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to DeBug_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
keyboard




function WaterRate_edit_Callback(hObject, eventdata, handles)
% hObject    handle to WaterRate_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of WaterRate_edit as text
%        str2double(get(hObject,'String')) returns contents of WaterRate_edit as a double

global AX RUNTIME pumprate

rate = str2double(get(hObject,'String'));

%Initialize the pump with inner diameter of syringe and water rate in ml/min
TrialFcn_PumpControl_ROSEN(14.5,rate); % 14.5 mm ID (estimate); 0.3 ml/min water rate

pumprate = rate;
% Update handles structure
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function WaterRate_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to WaterRate_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end





% SPOUT TRAINING SECTION (safes only presented)
% --- Executes on button press in MaskAlone_radio.
function MaskAlone_radio_Callback(hObject, eventdata, handles)
% hObject    handle to MaskAlone_radio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of MaskAlone_radio
set(handles.VaryToneDur_radio,'value',0); % these two lines make the radio buttons mutually exclusive
set(handles.VaryToneLevel_radio,'value',0);

global traintype
traintype = 'spoutTrain';





% VARY TONE DURATION SECTION (training with increasingly shorter tones)
% --- Executes on button press in VaryToneDur_radio.
function VaryToneDur_radio_Callback(hObject, eventdata, handles)
% hObject    handle to VaryToneDur_radio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of VaryToneDur_radio
set(handles.MaskAlone_radio,'value',0);% these two lines make the radio buttons mutually exclusive
set(handles.VaryToneLevel_radio,'value',0);
% Update handles structure
guidata(hObject, handles);

%VaryToneDur_edit_Callback(hObject, eventdata, handles)
ToneDur_popup_Callback(hObject, eventdata, handles)


% --- Executes during object creation, after setting all properties.
function VaryToneDur_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to VaryToneDur_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in ToneDur_popup.
function ToneDur_popup_Callback(hObject, eventdata, handles)
% hObject    handle to ToneDur_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns ToneDur_popup contents as cell array
%        contents{get(hObject,'Value')} returns selected item from ToneDur_popup
global tonedur traintype

hObject1 = handles.ToneDur_popup;
tone_pop_options = (get(hObject1,'String'));
tone_pop_select = tone_pop_options(get(hObject1,'Value'));
tonedur = str2double(tone_pop_select);
if get(handles.VaryToneDur_radio,'value');
traintype = 'varydurTrain';
end

% --- Executes during object creation, after setting all properties.
function ToneDur_popup_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ToneDur_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% VARY TONE LEVEL SECTION (testing for tone threshold)
% --- Executes on button press in VaryToneLevel_radio.
function VaryToneLevel_radio_Callback(hObject, eventdata, handles)
% hObject    handle to VaryToneLevel_radio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of VaryToneLevel_radio
set(handles.MaskAlone_radio,'value',0);% these two lines make the radio buttons mutually exclusive
set(handles.VaryToneDur_radio,'value',0);
% Update handles structure
guidata(hObject, handles);

%VaryToneLevel_edit_Callback(hObject, eventdata, handles)
ToneLev_popup_Callback(hObject, eventdata, handles)


% --- Executes on selection change in ToneLev_popup.
function ToneLev_popup_Callback(hObject, eventdata, handles)
% hObject    handle to ToneLev_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns ToneLev_popup contents as cell array
%        contents{get(hObject,'Value')} returns selected item from ToneLev_popup
global tonelev traintype

hObject1 = handles.ToneLev_popup;
lev_pop_options = (get(hObject1,'String'));
lev_pop_select = lev_pop_options(get(hObject1,'Value'));
tonelev = str2double(lev_pop_select);
if get(handles.VaryToneLevel_radio,'value');
traintype = 'varylevTest';
end

% --- Executes during object creation, after setting all properties.
function ToneLev_popup_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ToneLev_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in DL_list.
function DL_list_Callback(hObject, eventdata, handles)
% hObject    handle to DL_list (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns DL_list contents as cell array
%        contents{get(hObject,'Value')} returns selected item from DL_list


% --- Executes during object creation, after setting all properties.
function DL_list_CreateFcn(hObject, eventdata, handles)
% hObject    handle to DL_list (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
