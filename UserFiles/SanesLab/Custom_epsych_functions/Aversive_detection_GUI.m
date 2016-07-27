function varargout = Aversive_detection_GUI(varargin)
% GUI for aversive detection task
%
%To do:
%Fix AM depth percent plotting
%Change GO trial color on plot
%Add grouping variable plotting cabailities for optogenetics
%Add pause mode (make default) so animal can warm up and get reminders
%Remove Inf option for NOGO limit
%Add TTL plot like in Brad's program to monitor spout contact
%
% Written by ML Caras Apr 21, 2016


% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @Aversive_detection_GUI_OpeningFcn, ...
    'gui_OutputFcn',  @Aversive_detection_GUI_OutputFcn, ...
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


%SET UP INITIAL GUI TEXT BEFORE GUI IS MADE VISIBLE
function Aversive_detection_GUI_OpeningFcn(hObject, ~, handles, varargin)
global GUI_HANDLES PERSIST

%Start fresh
GUI_HANDLES = [];
PERSIST = 0;

%Choose default command line output for Aversive_detection_GUI
handles.output = hObject;

%Find the index of the RZ6 device (running behavior)
handles = findModuleIndex_SanesLab('RZ6', handles);

%Initialize physiology settings for 16 channel recording (if OpenEx)
handles = initializePhysiology_SanesLab(handles,16);

%Setup Response History Table and Trial History Table
handles = setupResponseandTrialHistory_SanesLab(handles);

%Setup Next Trial Table
handles = setupNextTrial_SanesLab(handles);

%Set up list of possible trial types (ignores reminder)
handles = populateLoadedTrials_SanesLab(handles);

%Setup X-axis options for I/O plot
handles = setupIOplot_SanesLab(handles);

%Collect GUI parameters for selecting next trial, and for pump settings
collectGUIHANDLES_SanesLab(handles);

%Start with paused trial delivery
handles = initializeTrialDelivery_SanesLab(handles);

%Disable frequency dropdown if it's a roved parameter or if it's not a
%parameter tag in the circuit
disabledropdown_SanesLab(handles.freq,handles.dev,'Freq')

%Disable FMRate dropdown if it's a roved parameter or if it's not a
%parameter tag in the circuit
disabledropdown_SanesLab(handles.FMRate,handles.dev,'FMrate')

%Disable FMDepth dropdown if it's a roved parameter or if it's not a
%parameter tag in the circuit
disabledropdown_SanesLab(handles.FMDepth,handles.dev,'FMdepth')

%Disable AMRate dropdown if it's a roved parameter or if it's not a
%parameter tag in the circuit
disabledropdown_SanesLab(handles.AMRate,handles.dev,'AMrate')

%Disable AMDepth dropdown if it's a roved parameter or if it's not a
%parameter tag in the circuit
disabledropdown_SanesLab(handles.AMDepth,handles.dev,'AMdepth')

%Disable Highpass dropdown if it's a roved parameter or if it's not a
%parameter tag in the circuit
disabledropdown_SanesLab(handles.Highpass,handles.dev,'Highpass')

%Disable Lowpass dropdown if it's a roved parameter or if it's not a
%parameter tag in the circuit
disabledropdown_SanesLab(handles.Lowpass,handles.dev,'Lowpass')

%Disable level dropdown if it's a roved parameter or if it's not a
%parameter tag in the circuit
disabledropdown_SanesLab(handles.level,handles.dev,'dBSPL')

%Disable sound duration dropdown if it's a roved parameter or if it's not a
%parameter tag in the circuit
disabledropdown_SanesLab(handles.sound_dur,handles.dev,'Stim_Duration')

%Disable response window duration dropdown if it's a roved parameter or if it's not a
%parameter tag in the circuit
disabledropdown_SanesLab(handles.respwin_dur,handles.dev,'RespWinDur')

%Disable intertrial interval if it's not a parameter tag in the circuit
disabledropdown_SanesLab(handles.ITI,handles.dev,'ITI_dur')

%Disable shock status if it's a roved parameter or if it's not a
%parameter tag in the circuit
disabledropdown_SanesLab(handles.ShockStatus,handles.dev,'ShockFlag')

%Disable shock duration if it's a roved parameter or if it's not a
%parameter tag in the circuit
disabledropdown_SanesLab(handles.Shock_dur,handles.dev,'ShockDur')

%Disable optogtenetic trigger if it's a roved parameter or if it's not a
%parameter tag in the circuit
disabledropdown_SanesLab(handles.optotrigger,handles.dev,'Optostim')

%Load in calibration file
handles = initializeCalibration_SanesLab(handles);

%Apply current settings
apply_Callback(handles.apply,[],handles)

%Update handles structure
guidata(hObject, handles);


%GUI OUTPUT FUNCTION AND INITIALIZING OF TIMER
function varargout = Aversive_detection_GUI_OutputFcn(hObject, ~, handles)

% Get default command line output from handles structure
varargout{1} = handles.output;



% Create new timer for RPvds control of experiment
%T = CreateTimer_SanesLab(hObject,0.025);
T = CreateTimer(hObject);

%Start timer
start(T);



%----------------------------------------------------------------------
%%%%%%%%%%%%%%%%%%%%%    TIMER FUNCTIONS   %%%%%%%%%%%%%%%%%%%%%%%%
%----------------------------------------------------------------------
%CREATE TIMER
function T = CreateTimer(f)

% Creates new timer for RPvds control of experiment
T = timerfind('Name','BoxTimer');
if ~isempty(T)
    stop(T);
    delete(T);
end

%All values in seconds
T = timer('BusyMode','drop', ...
    'ExecutionMode','fixedSpacing', ...
    'Name','BoxTimer', ...
    'Period',0.025, ...
    'StartFcn',{@BoxTimerSetup,f}, ...
    'TimerFcn',{@BoxTimerRunTime,f}, ...
    'ErrorFcn',{@BoxTimerError}, ...
    'StopFcn', {@BoxTimerStop}, ...
    'TasksToExecute',inf, ...
    'StartDelay',2);

%TIMER RUNTIME FUNCTION
function BoxTimerRunTime(~,event,f)
global RUNTIME
global PERSIST
persistent lastupdate starttime waterupdate

%Clear persistent variables if it's a fresh run
if PERSIST == 0
    lastupdate = [];
    starttime = clock;
    waterupdate = 0;
    
    PERSIST = 1;
end


h = guidata(f);

%Update Realtime Plot
UpdateAxHistory(h,starttime,event)

%Capture sound level from microphone
h = capturesound_SanesLab(h);

%Which trial are we on?
ntrials = length(RUNTIME.TRIALS.DATA);

%--------------------------------------------------------
%Only continue updates if a new trial has been completed
%--------------------------------------------------------
%--------------------------------------------------------
if (RUNTIME.UseOpenEx && isempty(RUNTIME.TRIALS.DATA(1).Behavior_TrialType)) ...
        | (~RUNTIME.UseOpenEx && isempty(RUNTIME.TRIALS.DATA(1).TrialType)) ...
        | ntrials == lastupdate %#ok<OR2>
    return
end

%Update runtime parameters
[HITind,MISSind,CRind,FAind,GOind,NOGOind,REMINDind,...
    reminders,variables,TrialTypeInd,TrialType,waterupdate,h] = ...
    update_params_runtime_SanesLab(waterupdate,ntrials,h);

%Update next trial table in gui
h = updateNextTrial_SanesLab(h);

%Update response history table
h = updateResponseHistory_SanesLab(h,HITind,MISSind,...
    FAind,CRind,GOind,NOGOind,variables,...
    ntrials,TrialTypeInd,TrialType,...
    REMINDind);

%Update FA rate
h = updateFArate_SanesLab(h,variables,FAind,NOGOind,f);

%Calculate hit rates and update plot
if ~isempty(GOind)
    updateIOPlot(h,variables,HITind,GOind,REMINDind);
    
    %Update trial history table
    updateTrialHistory(h.TrialHistory,variables,reminders,HITind,FAind)
end

lastupdate = ntrials;
%--------------------------------------------------------
%--------------------------------------------------------




%TIMER ERROR FUNCTION
function BoxTimerError(~,~)

%TIMER STOP FUNCTION
function BoxTimerStop(~,~)

%TIMER START FUNCTION
function BoxTimerSetup(~,~,~)




%----------------------------------------------------------------------
%%%%%%%%%%%%%%%%%%%%%   TRIAL SELECTION FUNCTIONS   %%%%%%%%%%%%%%%%%%
%----------------------------------------------------------------------

%APPLY CHANGES BUTTON
function apply_Callback(hObject,~,handles)
global GUI_HANDLES AX RUNTIME

%Determine if we're currently in the middle of a trial
if RUNTIME.UseOpenEx
    trial_TTL = AX.GetTargetVal('Behavior.InTrial_TTL');
else
    trial_TTL = AX.GetTagVal('InTrial_TTL');
end

%Determine if we're in a safe trial
if RUNTIME.UseOpenEx
    trial_type = AX.GetTargetVal('Behavior.TrialType');
else
    trial_type = AX.GetTagVal('TrialType');
end

%If we're not in the middle of a trial, or we're in the middle of a NOGO
%trial
if trial_TTL == 0 || trial_type == 1
    
    
    %Collect GUI parameters for selecting next trial
    GUI_HANDLES.Nogo_lim = get(handles.nogo_max);
    GUI_HANDLES.Nogo_min = get(handles.nogo_min);
    GUI_HANDLES.trial_filter = get(handles.TrialFilter);
    
    %Update RUNTIME structure and parameters for next trial delivery
    updateRUNTIME
    
    %Update Next trial information in gui
    %updateNextTrial(handles.NextTrial);
    handles = updateNextTrial_SanesLab(handles);
    
    %Update trial order
    updateTrialOrder(handles);
    
    %Update pump control
    pumpcontrol(handles)
    set(handles.Pumprate,'ForegroundColor',[0 0 1]);
    
    %Update Response Window Duration
    updateResponseWinDur(handles)
    set(handles.respwin_dur,'ForegroundColor',[0 0 1]);
    
    %Update sound duration
    updateSoundDur(handles)
    
    %Update sound frequency and level
    updateSoundLevelandFreq(handles)
    
    %Update FM rate
    updateFMrate(handles)
    
    %Update FM depth
    updateFMdepth(handles)
    
    %Update AM rate: Important must be called BEFORE update AM depth
    updateAMrate(handles)
    
    %Update AM depth
    updateAMdepth(handles)
    
    %Update Highpass cutoff
    updateHighpass(handles)
    
    %Update Lowpass cutoff
    updateLowpass(handles)
    
    %Update intertrial interval
    updateITI(handles)
    
    %Update Optogenetic Trigger
    updateOpto(handles)
    
    %Update Shocker Status
    updateShock(handles)
    
    %Reset foreground colors of remaining drop down menus to blue
    set(handles.nogo_max,'ForegroundColor',[0 0 1]);
    set(handles.nogo_min,'ForegroundColor',[0 0 1]);
    set(handles.TrialFilter,'ForegroundColor',[0 0 1]);
    
    %Disable apply button
    set(handles.apply,'enable','off')
    
end


guidata(hObject,handles)

%REMIND BUTTON
function Remind_Callback(hObject, ~, handles)
global GUI_HANDLES AX RUNTIME

%Determine if we're currently in the middle of a trial
if RUNTIME.UseOpenEx
    trial_TTL = AX.GetTargetVal('Behavior.InTrial_TTL');
else
    trial_TTL = AX.GetTagVal('InTrial_TTL');
end

%Determine if we're in a safe trial
if RUNTIME.UseOpenEx
    trial_type = AX.GetTargetVal('Behavior.TrialType');
else
    trial_type = AX.GetTagVal('TrialType');
end



%If we're not in the middle of a trial, or we're in the middle of a safe
%trial
if trial_TTL == 0 || trial_type == 1
    
    %Force a reminder for the next trial
    GUI_HANDLES.remind = 1;
    
    %Update RUNTIME structure and parameters for next trial delivery
    updateRUNTIME
    
    %Update Next trial information in gui
    updateNextTrial(handles.NextTrial);
end

guidata(hObject,handles)


%DELIVER TRIALS BUTTON
function DeliverTrials_Callback(hObject, ~, handles)
global AX RUNTIME

%Determine if we're currently in the middle of a trial
if RUNTIME.UseOpenEx
    trial_TTL = AX.GetTargetVal('Behavior.InTrial_TTL');
else
    trial_TTL = AX.GetTagVal('InTrial_TTL');
end

%Determine if we're in a safe trial
if RUNTIME.UseOpenEx
    trial_type = AX.GetTargetVal('Behavior.TrialType');
else
    trial_type = AX.GetTagVal('TrialType');
end

%If we're not in the middle of a trial, or we're in the middle of a safe
%trial
if trial_TTL == 0 || trial_type == 1
    
    %Start Trial Delivery
    if RUNTIME.UseOpenEx
        AX.SetTargetVal('Behavior.TrialDelivery',1);
    else
        AX.SetTagVal('TrialDelivery',1);
    end
    
    %Enable pause trials button
    set(handles.PauseTrials,'enable','on');
    
    %Disable deliver trials button
    set(handles.DeliverTrials,'enable','off');
    
end

guidata(hObject,handles)


%PAUSE TRIALS BUTTON
function PauseTrials_Callback(hObject, ~, handles)
global AX RUNTIME

%Determine if we're currently in the middle of a trial
if RUNTIME.UseOpenEx
    trial_TTL = AX.GetTargetVal('Behavior.InTrial_TTL');
else
    trial_TTL = AX.GetTagVal('InTrial_TTL');
end

%Determine if we're in a safe trial
if RUNTIME.UseOpenEx
    trial_type = AX.GetTargetVal('Behavior.TrialType');
else
    trial_type = AX.GetTagVal('TrialType');
end


%If we're not in the middle of a trial, or we're in the middle of a safe
%trial
if trial_TTL == 0 || trial_type == 1
    
    %Pause Trial Delivery
    if RUNTIME.UseOpenEx
        AX.SetTargetVal('Behavior.TrialDelivery',0);
    else
        AX.SetTagVal('TrialDelivery',0);
    end
    
    %Disable pause trials button
    set(handles.PauseTrials,'enable','off');
    
    %Enable deliver trials button
    set(handles.DeliverTrials,'enable','on');
    
end

guidata(hObject,handles)

%TRIAL FILTER SELECTION
function TrialFilter_CellSelectionCallback(hObject, eventdata, handles)

if ~isempty(eventdata.Indices)
    
    %Get the row and column of the selected or de-selected checkbox
    r = eventdata.Indices(1);
    c = eventdata.Indices(2);
    
    
    %Identify some important columns
    col_names = get(hObject,'ColumnName');
    trial_type_col = find(ismember(col_names,'TrialType'));
    logical_col = find(ismember(col_names,'Present'));
    
    if c == logical_col
        
        %Determine the data we currently have active
        table_data = get(hObject,'Data');
        active_ind = (strfind(table_data(:,c),'false'));
        active_ind = cellfun('isempty',active_ind);
        active_data = table_data(active_ind,:);
        
        
        %Define the starting state of the check box
        starting_state = table_data{r,c};
        
        %If the box started out as checked, we need to determine whether it's
        %okay to uncheck it
        if strcmpi(starting_state,'true')
            %Prevent the only NOGO from being de-selected
            NOGO_row_active = find(ismember(active_data(:,trial_type_col),'NOGO'));
            if numel(NOGO_row_active) > 1
                NOGO_row = 0;
            else
                NOGO_row = find(ismember(table_data(:,trial_type_col),'NOGO'));
                NOGO_row = num2cell(NOGO_row');
            end
            
            %Prevent the only GO from being deselected
            GO_row_active = find(ismember(active_data(:,trial_type_col),'GO'));
            if numel(GO_row_active) > 1
                GO_row = 0;
            else
                GO_row = find(ismember(table_data(:,trial_type_col),'GO'));
                GO_row = num2cell(GO_row');
            end
            
            
            %If the box started out as unchecked, it's always okay to check it
        else
            NOGO_row = 0;
            GO_row = 0;
        end
        
        
        %If the selected/de-selected row matches one of the special cases,
        %present a warning to the user and don't alter the trial selection
        switch r
            case [NOGO_row, GO_row]
                
                beep
                warnstring = 'The following trial types cannot be deselected: (a) The only GO trial  (b) The only NOGO trial';
                warnhandle = warndlg(warnstring,'Trial selection warning');
                
                
                %If it's okay to select or de-select the checkbox, then proceed
            otherwise
                
                %If the box started as checked, uncheck it
                switch starting_state
                    case 'true'
                        table_data(r,c) = {'false'};
                        
                        %If the box started as unchecked, check it
                    otherwise
                        table_data(r,c) = {'true'};
                end
                
                set(hObject,'Data',table_data);
                set(hObject,'ForegroundColor',[1 0 0]);
                
                %Enable apply button
                set(handles.apply,'enable','on');
        end
        
        guidata(hObject,handles)
        
    end
end

function TrialFilter_CellEditCallback(~, ~, ~)

%DROPDOWN CHANGE SELECTION
function selection_change_callback(hObject, ~, handles)

set(hObject,'ForegroundColor','r');
set(handles.apply,'enable','on');

switch get(hObject,'Tag')
    
    case {'Highpass', 'Lowpass'}
        Highpass_str =  get(handles.Highpass,'String');
        Highpass_val =  get(handles.Highpass,'Value');
        
        Highpass_val = str2num(Highpass_str{Highpass_val}); %Hz
        
        Lowpass_str =  get(handles.Lowpass,'String');
        Lowpass_val =  get(handles.Lowpass,'Value');
        
        Lowpass_val = 1000*str2num(Lowpass_str{Lowpass_val}); %Hz
        
        if Lowpass_val < Highpass_val
            beep
            set(handles.apply,'enable','off');
            errortext = 'Lowpass filter cutoff must be larger than highpass filter cutoff';
            e = errordlg(errortext);
        end
        
end



guidata(hObject,handles)

%UPDATE RUNTIME STRUCTURE
function updateRUNTIME
global RUNTIME AX


% Reduce TRIALS.TrialCount for the currently selected trial index
RUNTIME.TRIALS.TrialCount(RUNTIME.TRIALS.NextTrialID) = ...
    RUNTIME.TRIALS.TrialCount(RUNTIME.TRIALS.NextTrialID) - 1;

%Re-select the next trial using trial selection function
RUNTIME.TRIALS.NextTrialID = feval(RUNTIME.TRIALS.trialfunc,RUNTIME.TRIALS);


% Increment TRIALS.TrialCount for the selected trial index
RUNTIME.TRIALS.TrialCount(RUNTIME.TRIALS.NextTrialID) = ...
    RUNTIME.TRIALS.TrialCount(RUNTIME.TRIALS.NextTrialID) + 1;

% Send trigger to reset components before updating parameters
if RUNTIME.UseOpenEx
    TrigDATrial(AX,RUNTIME.ResetTrigStr{1});
else
    TrigRPTrial(AX(RUNTIME.ResetTrigIdx),RUNTIME.ResetTrigStr{1});
end

% Update parameters for next trial
feval(sprintf('Update%stags',RUNTIME.TYPE),AX,RUNTIME.TRIALS);

% Send trigger to indicate ready for a new trial
if RUNTIME.UseOpenEx
    TrigDATrial(AX,RUNTIME.NewTrialStr{1});
else
    TrigRPTrial(AX(RUNTIME.NewTrialIdx),RUNTIME.NewTrialStr{1});
end




%----------------------------------------------------------------------
%%%%%%%%%%%%%%%%%%%%%   HARDWARE CONTROL FUNCTIONS   %%%%%%%%%%%%%%%%%
%----------------------------------------------------------------------

%UPDATE SOUND DURATION
function updateSoundDur(h)
global AX RUNTIME

switch get(h.sound_dur,'enable')
    
    case 'on'
        %Get sound duration from GUI
        soundstr = get(h.sound_dur,'String');
        soundval = get(h.sound_dur,'Value');
        
        if RUNTIME.UseOpenEx
            fs = RUNTIME.TDT.Fs(h.dev);
        else
            fs = AX.GetSFreq;
        end
        
        
        sound_dur = str2num(soundstr{soundval})*1000; %in msec
        
        %Use Active X controls to set duration directly in RPVds circuit
        if RUNTIME.UseOpenEx
            AX.SetTargetVal('Behavior.Stim_Duration',sound_dur);
        else
            AX.SetTagVal('Stim_Duration',sound_dur);
        end
        
        set(h.sound_dur,'ForegroundColor',[0 0 1]);
        
end

%UPDATE SOUND LEVEL AND FREQUENCY
function updateSoundLevelandFreq(h)
global AX RUNTIME

%If the user has GUI control over the sound frequency, set the frequency in
%the RPVds circuit to the desired value. Otherwise, simply read the
%frequency from the circuit directly.
switch get(h.freq,'enable')
    case 'on'
        
        %Get sound frequency from GUI
        soundstr = get(h.freq,'String');
        soundval = get(h.freq,'Value');
        sound_freq = str2num(soundstr{soundval}); %Hz
        
        if RUNTIME.UseOpenEx
            AX.SetTargetVal('Behavior.Freq',sound_freq)
        else
            AX.SetTagVal('Freq',sound_freq);
        end
        
        set(h.freq,'ForegroundColor',[0 0 1]);
        
    otherwise
        
        %If Frequency is a parameter tag in the circuit
        if RUNTIME.UseOpenEx
            if ~isempty(find(ismember(RUNTIME.TDT.devinfo(h.dev).tags,'Freq'),1))
                sound_freq = AX.GetTargetVal('Behavior.Freq');
            end
        else
            if ~isempty(find(ismember(RUNTIME.TDT.devinfo(h.dev).tags,'Freq'),1))
                sound_freq = AX.GetTagVal('Freq');
            end
        end
end


%Set the voltage adjustment for calibration in RPVds circuit
%If Frequency is a parameter tag in the circuit
if ~isempty(find(ismember(RUNTIME.TDT.devinfo(h.dev).tags,'Freq'),1))
    CalAmp = Calibrate(sound_freq,h.C);
else
    CalAmp = h.C.data(1,4);
end

if RUNTIME.UseOpenEx
    AX.SetTargetVal('Behavior.~Freq_Amp',CalAmp);
else
    AX.SetTagVal('~Freq_Amp',CalAmp);
end


%If the user has GUI control over the sound level, set the level in
%the RPVds circuit to the desired value. Otherwise, do nothing.
switch get(h.level,'enable')
    case 'on'
        soundstr = get(h.level,'String');
        soundval = get(h.level,'Value');
        sound_level = str2num(soundstr{soundval}); %dB SPL
        
        %Use Active X controls to set duration directly in RPVds circuit
        if RUNTIME.UseOpenEx
            AX.SetTargetVal('Behavior.dBSPL',sound_level);
        else
            AX.SetTagVal('dBSPL',sound_level);
        end
        
        set(h.level,'ForegroundColor',[0 0 1]);
end

%UPDATE TRIAL ORDER
function updateTrialOrder(h)
global GUI_HANDLES

%Get reward rate from GUI
GUI_HANDLES.trial_order = get(h.trial_order);

set(h.trial_order,'ForegroundColor',[0 0 1]);

%UPDATE FM RATE
function updateFMrate(h)
global AX RUNTIME

%If the user has GUI control over the FMRate, set the rate in
%the RPVds circuit to the desired value.

switch get(h.FMRate,'enable')
    case 'on'
        %Get FM rate from GUI
        ratestr = get(h.FMRate,'String');
        rateval = get(h.FMRate,'Value');
        FMrate = str2num(ratestr{rateval}); %Hz
        
        if RUNTIME.UseOpenEx
            AX.SetTargetVal('Behavior.FMrate',FMrate);
        else
            AX.SetTagVal('FMrate',FMrate);
        end
        set(h.FMRate,'ForegroundColor',[0 0 1]);
end

%UPDATE FM DEPTH
function updateFMdepth(h)
global AX RUNTIME

%If the user has GUI control over the FMDepth, set the depth in
%the RPVds circuit to the desired value.
switch get(h.FMDepth,'enable')
    case 'on'
        %Get FM depth from GUI
        depthstr = get(h.FMDepth,'String');
        depthval = get(h.FMDepth,'Value');
        FMdepth = str2num(depthstr{depthval}); %proportion of Freq
        
        if RUNTIME.UseOpenEx
            AX.SetTargetVal('Behavior.FMdepth',FMdepth);
        else
            AX.SetTagVal('FMdepth',FMdepth);
        end
        
        set(h.FMDepth,'ForegroundColor',[0 0 1]);
end

%UPDATE AM RATE
function updateAMrate(h)
global AX RUNTIME

%If the user has GUI control over the AMRate, set the rate in
%the RPVds circuit to the desired value.
switch get(h.AMRate,'enable')
    case 'on'
        %Get AM rate from GUI
        ratestr = get(h.AMRate,'String');
        rateval = get(h.AMRate,'Value');
        AMrate = str2num(ratestr{rateval}); %Hz
        
        %RPVds can't handle floating point values of zero, apparently, at
        %least for the Freq component.  If the value is set to zero, the
        %sound will spuriously and randomly drop out during a session.  To
        %solve this problem, set the value to the minimum value required by
        %the component (0.001).
        if AMrate == 0
            AMrate = 0.001;
        end
        
        if RUNTIME.UseOpenEx
            AX.SetTargetVal('Behavior.AMrate',AMrate);
        else
            AX.SetTagVal('AMrate',AMrate);
        end
        set(h.AMRate,'ForegroundColor',[0 0 1]);
end

%UPDATE AM DEPTH
function updateAMdepth(h)
global AX RUNTIME

%If the user has GUI control over the AMDepth, set the depth in
%the RPVds circuit to the desired value.
switch get(h.AMDepth,'enable')
    case 'on'
        
        %Get AM depth from GUI
        depthstr = get(h.AMDepth,'String');
        depthval = get(h.AMDepth,'Value');
        AMdepth = (str2num(depthstr{depthval}))/100; %proportion for RPVds
        
        if RUNTIME.UseOpenEx
            AX.SetTargetVal('Behavior.AMdepth',AMdepth);
        else
            AX.SetTagVal('AMdepth',AMdepth);
        end
        
        set(h.AMDepth,'ForegroundColor',[0 0 1]);
end

%UPDATE HIGHPASS CUTOFF
function updateHighpass(h)
global AX RUNTIME

%If the user has GUI control over the Highpass cutoff, set the cutoff in
%the RPVds circuit to the desired value.
switch get(h.Highpass,'enable')
    case 'on'
        %Get Highpass from GUI
        str = get(h.Highpass,'String');
        val = get(h.Highpass,'Value');
        Highpass = str2num(str{val}); %Hz
        
        if RUNTIME.UseOpenEx
            AX.SetTargetVal('Behavior.Highpass',Highpass);
        else
            AX.SetTagVal('Highpass',Highpass);
        end
        set(h.Highpass,'ForegroundColor',[0 0 1]);
end

%UPDATE LOWPASS CUTOFF
function updateLowpass(h)
global AX RUNTIME

%If the user has GUI control over the Lowpass cutoff, set the cutoff in
%the RPVds circuit to the desired value.
switch get(h.Lowpass,'enable')
    case 'on'
        %Get Lowpass from GUI
        str = get(h.Lowpass,'String');
        val = get(h.Lowpass,'Value');
        Lowpass = str2num(str{val})*1000; %kHz
        
        if RUNTIME.UseOpenEx
            AX.SetTargetVal('Behavior.Lowpass',Lowpass);
        else
            AX.SetTagVal('Lowpass',Lowpass);
        end
        set(h.Lowpass,'ForegroundColor',[0 0 1]);
end

%UPDATE RESPONSE WINDOW DURATION
function updateResponseWinDur(h)
global AX RUNTIME

switch get(h.respwin_dur,'enable')
    
    case 'on'
        %Get response window duration from GUI
        str = get(h.respwin_dur,'String');
        val = get(h.respwin_dur,'Value');
        dur = str2num(str{val})*1000; %msec
        
        %Use Active X controls to set duration directly in RPVds circuit
        if RUNTIME.UseOpenEx
            AX.SetTargetVal('Behavior.RespWinDur',dur);
        else
            AX.SetTagVal('RespWinDur',dur);
        end
        
        set(h.respwin_dur,'ForegroundColor',[0 0 1]);
        
end

%UPDATE INTERTRIAL INTERVAL
function updateITI(h)
global AX RUNTIME

switch get(h.ITI,'enable')
    
    case 'on'
        %Get intertrial interval duration from GUI
        str = get(h.ITI,'String');
        val = get(h.ITI,'Value');
        delay = str2num(str{val})*1000; %msec
        
        %Use Active X controls to set duration directly in RPVds circuit
        if RUNTIME.UseOpenEx
            AX.SetTargetVal('Behavior.ITI_dur',delay);
        else
            AX.SetTagVal('ITI_dur',delay);
        end
        
        set(h.ITI,'ForegroundColor',[0 0 1]);
        
end

%UPDATE OPTOGENETIC TRIGGER
function updateOpto(h)
global AX RUNTIME

switch get(h.optotrigger,'enable')
    
    case 'on'
        %Get intertrial interval duration from GUI
        str = get(h.optotrigger,'String');
        val = get(h.optotrigger,'Value');
        optotrigger_status = str{val};
        
        switch optotrigger_status
            case 'On'
                opto = 1;
            case 'Off'
                opto = 0;
        end
        
        %Use Active X controls to set duration directly in RPVds circuit
        if RUNTIME.UseOpenEx
            AX.SetTargetVal('Behavior.Optostim',opto);
        else
            AX.SetTagVal('Optostim',opto);
        end
        
        set(h.optotrigger,'ForegroundColor',[0 0 1]);
        
end

%UPDATE SHOCKER
function updateShock(h)
global AX RUNTIME

switch get(h.ShockStatus,'enable')
    case 'on'
        %Get shock status from GUI
        str = get(h.ShockStatus,'String');
        val = get(h.ShockStatus,'Value');
        shock_status = str{val};
        
        %Get shock duration from GUI
        str = get(h.Shock_dur,'String');
        val = get(h.Shock_dur,'Value');
        shock_dur = str2num(str{val})*1000; %msec
        
        
        switch shock_status
            case 'On'
                ShockFlag = 1;
            case 'Off'
                ShockFlag = 0;
        end
        
        %Use Active X controls to set duration directly in RPVds circuit
        if RUNTIME.UseOpenEx
            AX.SetTargetVal('Behavior.ShockFlag',ShockFlag);
            AX.SetTargetVal('Behavior.ShockDur',shock_dur);
        else
            AX.SetTagVal('ShockFlag',ShockFlag);
            AX.SetTagVal('ShockDur',shock_dur);
        end
        
        
        set(h.ShockStatus,'ForegroundColor',[0 0 1]);
        set(h.Shock_dur,'ForegroundColor',[0 0 1]);
end

%PUMP CONTROL FUNCTION
function pumpcontrol(h)
global PUMPHANDLE GUI_HANDLES

%Get reward rate from GUI
ratestr = get(h.Pumprate,'String');
rateval = get(h.Pumprate,'Value');
GUI_HANDLES.rate = str2num(ratestr{rateval}); %ml/min

%Set pump rate directly (ml/min)
fprintf(PUMPHANDLE,'RAT%0.1f\n',GUI_HANDLES.rate)




%----------------------------------------------------------------------
%%%%%%%%%%%%%%%%%%    TEXT UPDATE FUNCTIONS   %%%%%%%%%%%%%%%%%%%%%%
%----------------------------------------------------------------------


% %UPDATE FALSE ALARM RATE
% function [FArates,h] = updateFArate(h,variables,FAind,NOGOind,f)
% global ROVED_PARAMS RUNTIME
% 
% %Find the current handles containing FA text data
% FA_handles = [];
% FArates = [];
% flds = fieldnames(h);
% idx = ~cellfun('isempty',strfind(flds,'FArate'));
% flds = flds(idx);
% 
% for i = 1:numel(flds)
%     FA_handles = [FA_handles,h.(flds{i})];
% end
% 
% 
% %Compile data into a matrix
% currentdata = [variables,FAind];
% 
% %Select out just the NOGO trials
% NOGOtrials = currentdata(NOGOind,:);
% 
% %Determine if the user is plotting the data as a whole, or grouped by
% %variables
% grpstr = get(h.group_plot,'String');
% grpval = get(h.group_plot,'Value');
% 
% %If plotting as a whole...
% switch grpstr{grpval}
%     case 'None'
%         
%         %If at least one NOGO trial has been completed...
%         if ~isempty(NOGOtrials)
%             
%             %Calculate the overall FA rate
%             FArate = 100*(sum(NOGOtrials(:,end))/numel(NOGOtrials(:,end)));
%             
%             %Scroll through each FA text handle
%             for i = 1:numel(FA_handles)
%                 
%                 %If it's the first one...
%                 if i == 1
%                     
%                     %Set the text and color
%                     set(FA_handles(i),'String', sprintf( '%0.2f',FArate));
%                     set(FA_handles(i),'ForegroundColor',[1 0 0]);
%                 
%                 %Otherwise...
%                 else
%                     
%                     %Empty the text
%                     set(FA_handles(i),'String','');
%                     
%                 end
%             end
%             
%         %If no NOGO trials have been completed...    
%         else
%             %Collect the FA rate from the GUI (it's just 0.00).
%             FArate = str2num(get(FA_handles(1),'String'));
%         end
%         
%         %Collect FA rates
%         FArates = [FArates;FArate];
%         
%         
%     %If plotting is grouped by a variable, calculate a separate FA rate for
%     %each NOGO type, if applicable.
%     otherwise
%         
%         %Find the column index for the grouping variable of interest
%         if RUNTIME.UseOpenEx
%             rp = cellfun(@(x) x(10:end), ROVED_PARAMS, 'UniformOutput',false);
%             grp_ind = find(strcmpi(grpstr(grpval),rp));
%         else
%             grp_ind = find(strcmpi(grpstr(grpval),ROVED_PARAMS));
%         end
%         
%         %Find the groups
%         grps = unique(NOGOtrials(:,grp_ind));
%         
%         %Set the starting text position and color map
%         x = 0.095; y = 0.681; width = 0.821; height = 0.362;
%         clrmap = jet(numel(grps));
%         
%         %For each group...
%         for i = 1:numel(grps)
%             
%             %Define our target
%             if i == 1
%                 target = 'FArate';
%             else
%                 target = ['FArate' num2str(i)];
%             end
%             
%             %If text handle has not already been created for the group
%             if ~isfield(h,target)
%                 
%                 %Adjust y position
%                 y = y-0.5;
%                 
%                 %Create new text handle
%                 p = uicontrol(f,'Style','text','String','','FontName','Arial',...
%                     'FontSize',[16],'FontWeight','bold',...
%                     'Units','normalized','SelectionHighlight','off',...
%                     'Tag',target);
%                 h.(target) = p;
%                 set(h.(target),'Parent',h.FApanel,...
%                     'Position',[x y width height]);
%                 
%                 %Update the FA handle vector
%                 FA_handles = [FA_handles, h.(target)];
%             end
%             
%         end
%         
%      
%         %Now that we have all of our FA handles...
%         for i = 1:numel(grps)
%             
%             %Let's format them:
%             %If there is more than one group, each FA is colored separately
%             if numel(grps)>1
%                 clr = clrmap(i,:);
%                 set(FA_handles(i),'ForegroundColor',clr);
%                 
%             %If there is only one group...
%             else
%                 %The first handle gets colored red...
%                 if i == 1
%                     set(FA_handles(i),'ForegroundColor',[1 0 0]);
%                     
%                 %Remaining handle texts are emptied
%                 else
%                     set(FA_handles(i),'String','');
%                 end
%             end
%             
%             
%             %Finally, let's calculate the FA rates and display them
%             %Pull out the group data
%             grp_data = NOGOtrials(NOGOtrials(:,grp_ind) == grps(i),:);
%             
%             %Calculate each FA rate separately
%             if ~isempty(grp_data)
%                 FArate = 100*(sum(grp_data(:,end))/numel(grp_data(:,end)));
%                 set(FA_handles(i),'String', sprintf( '%0.2f',FArate));
%             else
%                 FArate = str2num(get(FA_handles(i),'String'));
%             end
%             
%             %Collect FA rates
%             FArates = [FArates;FArate];
%             
%         end
%         
% end
% 
% %Update GUI handles
% guidata(f,h)
% 


%UPDATE TRIAL HISTORY
function updateTrialHistory(handle,variables,reminders,HITind,FAind)

%Find unique trials
data = [variables,reminders];
unique_trials = unique(data,'rows');

%Determine column indices
colnames = get(handle,'ColumnName');
colind = find(strcmpi(colnames,'TrialType'));

%Pull out go trials
go_trials = unique_trials(unique_trials(:,colind) == 0,:);
nogo_trials = unique_trials(unique_trials(:,colind) == 1,:);

%Determine the total number of presentations and hits for each go trialtype
numgoTrials = zeros(size(go_trials,1),1);
numHits = zeros(size(go_trials,1),1);

for i = 1:size(go_trials,1)
    numgoTrials(i) = sum(ismember(data,go_trials(i,:),'rows'));
    numHits(i) = sum(HITind(ismember(data,go_trials(i,:),'rows')));
end


%Determine the total number of presentations and fas for each nogo
%trialtype
numnogoTrials = zeros(size(nogo_trials,1),1);
numFAs = zeros(size(nogo_trials,1),1);

for i = 1:size(nogo_trials,1)
    numnogoTrials(i) = sum(ismember(data,nogo_trials(i,:),'rows'));
    numFAs(i) = sum(FAind(ismember(data,nogo_trials(i,:),'rows')));
end



%Calculate hit rates for each trial type
hitrates = 100*(numHits./numgoTrials);

%Calculate fa rates for each trial type
farates = 100*(numFAs./numnogoTrials);

%Calculate dprimes for each trial type
corrected_hitrates = hitrates/100;
corrected_hitrates(corrected_hitrates > .95) = .95;
corrected_hitrates(corrected_hitrates < .05) = .05;
zhit = sqrt(2)*erfinv(2*corrected_hitrates-1);

corrected_farates = farates/100;
corrected_farates(corrected_farates > .95) = .95;
corrected_farates(corrected_farates < .05) = .05;
zfa = sqrt(2)*erfinv(2*corrected_farates-1);

%If there is more than one nogo
if numel(zfa) > 1
    
    %Find the column that differs for nogo trials
    for i = 1:size(nogo_trials,2)
        if numel(unique(nogo_trials(:,i))) == 2
            break
        end
    end
    
    %For each go stimulus, find the corresponding nogo stimulus and
    %calculate separate dprime values
    dprimes = [];
    for j = 1:size(go_trials,1)
        for k = 1:size(nogo_trials,1)
            
            if go_trials(j,i) == nogo_trials(k,i)
                dprimes = [dprimes;zhit(j)-zfa(k)];
            end
        end
    end
    
    
else
    
    dprimes = zhit-zfa;
    
end

%Append extra data columns for GO trials
go_trials(:,end) = numgoTrials; %n Trials
go_trials(:,end+1) = hitrates; %hit rates
go_trials(:,end+1) = dprimes; %dprimes

%Append extra data columns for NOGO trials
nogo_trials(:,end) = numnogoTrials; %n Trials
nogo_trials(:,end+1) = NaN(size(nogo_trials,1),1); %(hit rates)
nogo_trials(:,end+1) = NaN(size(nogo_trials,1),1); %(dprimes)

all_trials = [go_trials;nogo_trials];


%Create cell array
D =  num2cell(all_trials);

%Update the text of the datatable
GOind = find([D{:,colind}] == 0);
NOGOind = find([D{:,colind}] == 1);
REMINDind = find([D{:,end}] == 1);

D(GOind,colind) = {'GO'};
D(NOGOind,colind) = {'NOGO'};
D(REMINDind,colind) = {'REMIND'};

set(handle,'Data',D)

%UPDATE WATER VOLUME TEXT
function updatewater(handle)
global PUMPHANDLE

%Wait for pump to finish water delivery
pause(0.06)

%Flush the pump's input buffer
flushinput(PUMPHANDLE);

%Query the total dispensed volume
fprintf(PUMPHANDLE,'DIS');
[V,count] = fscanf(PUMPHANDLE,'%s',10); %very very slow

%Pull out the digits and display in GUI
ind = regexp(V,'\.');
V = num2str(V(ind-1:ind+3));
set(handle,'String',V);



%-----------------------------------------------------------
%%%%%%%%%%%%%% PLOTTING FUNCTIONS %%%%%%%%%%%%%%%
%------------------------------------------------------------

%PLOT REALTIME HISTORY
function UpdateAxHistory(handles,starttime,event)

%Update the TTL histories
[handles,xmin,xmax,timestamps,trial_hist,spout_hist,type_hist] = ...
    update_TTLhistory_SanesLab(handles,starttime,event);


%Update realtime displays
str = get(handles.realtime_display,'String');
val = get(handles.realtime_display,'Value');


switch str{val}
    case {'Continuous'}
        plotContinuous(timestamps,trial_hist,handles.trialAx,[0.5 0.5 0.5],xmin,xmax,[],type_hist);
        plotContinuous(timestamps,spout_hist,handles.spoutAx,'k',xmin,xmax,'Time (s)')
    case {'Triggered'}
        %plotTriggered(timestamps,trial_hist,poke_hist,h.trialAx,[0.5 0.5 0.5]);
        %plotTriggered(timestamps,spout_hist,poke_hist,h.spoutAx,'k');
end


%PLOT CONTINUOUS REALTIME TTLS
function plotContinuous(timestamps,action_TTL,ax,clr,xmin,xmax,varargin)

%Plot action
ind = logical(action_TTL);
xvals = timestamps(ind);
yvals = ones(size(xvals));


%Find existing plots
current_plots = get(ax,'children');


if nargin == 8
    trial_history = varargin{2};
    trial_history = trial_history(ind);
    
    %Find nogos
    nogo_ind = find(trial_history == 1);
    xnogo = xvals(nogo_ind);
    ynogo = yvals(nogo_ind);
    
    %Find gos
    go_ind = find(trial_history == 0);
    xgo = xvals(go_ind);
    ygo = yvals(go_ind);
    
    
    
    %If the nogo and go plots already exist
    if numel(current_plots) >1
        h_nogo= current_plots(1);
        h_go = current_plots(2);
        
        %Update the nogo data
        if ~isempty(xnogo)
            set(h_nogo,'Xdata',xnogo);
            set(h_nogo,'Ydata',ynogo);
            set(h_nogo,'color',[0.5, 0.5, 0.5]);
        end
        
        %Update the go data
        if ~isempty(xgo)
            set(h_go,'Xdata',xgo);
            set(h_go,'Ydata',ygo);
            set(h_go,'color','g');
        end
        
        %If the nogo and go plots do not already exist
    else
        %Create nogo plot for first time
        if ~isempty(xnogo)
            h_nogo = plot(ax,xnogo,ynogo,'s','color',clr,'linewidth',20);
            hold(ax,'all');
        end
        
        %Create go plot for first time
        if ~isempty(xgo)
            h_go = plot(ax,xgo,ygo,'s','color','g','linewidth',20);
            hold(ax,'all');
        end
    end
    
    
    
else
    
    %If the spout plot already exists
    if ~isempty(current_plots)
        
        h_spout = current_plots(1);
        
        %Update plot
        if ~isempty(xvals)
            set(h_spout,'xdata',xvals);
            set(h_spout,'ydata',yvals);
        end
        
        
    else
        
        %Create spout plot for first time
        if ~isempty(xvals)
            plot(ax,xvals,yvals,'s','color',clr,'linewidth',20)
        end
        
    end
    
    
end


%Format plot
set(ax,'ylim',[0.9 1.1]);
set(ax,'xlim',[xmin xmax]);
set(ax,'YTickLabel','');
set(ax,'XGrid','on');
set(ax,'XMinorGrid','on');

if nargin == 7
    xlabel(ax,varargin{1},'Fontname','Arial','FontSize',12)
else
    set(ax,'XTickLabel','');
end

hold(ax,'off');


%PLOT TRIGGERED REALTIME TTLS
function plotTriggered(timestamps,action_TTL,trial_TTL,ax,clr,varargin)
%Find the onset of the most recent trial
d = diff(trial_TTL);
onset = find(d == 1,1,'last')+1;

%Find end of the most recent action
action_end = find(action_TTL == 1,1,'last');

%Limit time and TTLs to the onset of the most recent trial and the end of
%the most recent action
timestamps = timestamps(onset:action_end);
action_TTL = action_TTL(onset:action_end);

%Plot action
ind = logical(action_TTL);
xvals = timestamps(ind);
yvals = ones(size(xvals));


if ~isempty(xvals)
    plot(ax,xvals,yvals,'s','color',clr,'linewidth',20)
    
    %Format plot
    xmin = timestamps(1) - 2; %start 2 sec before trial onset
    xmax = timestamps(1) + 5; %end 5 sec after trial onset
    set(ax,'xlim',[xmin xmax]);
    set(ax,'ylim',[0.9 1.1]);
    set(ax,'YTickLabel','');
    set(ax,'XGrid','on');
    set(ax,'XMinorGrid','on');
    
    %Enable zooming and panning
    dragzoom(ax);
    
end


if nargin == 6
    xlabel(ax,varargin{1},'Fontname','Arial','FontSize',12)
else
    set(ax,'XTickLabel','');
end


%PLOT INPUT-OUTPUT FUNCTION
function updateIOPlot(h,variables,HITind,GOind,REMINDind)
global ROVED_PARAMS RUNTIME

%Compile data into a matrix.
currentdata = [variables,HITind];

%If user wants to exclude reminder trials...
if get(h.PlotRemind,'Value') == 0
    currentdata(REMINDind,:) = [];
    
    if RUNTIME.UseOpenEx
        rp = cellfun(@(x) x(10:end), ROVED_PARAMS, 'UniformOutput',false);
        TrialTypeInd = find(strcmpi('TrialType',rp));
    else
        TrialTypeInd = find(strcmpi('TrialType',ROVED_PARAMS));
    end
    
    TrialType = currentdata(:,TrialTypeInd);
    GOind = find(TrialType == 0);
end

if ~isempty(currentdata)
    
    %Select out just the GO trials
    GOtrials = currentdata(GOind,:);
    
    %Determine the variable to plot on the x axis
    x_ind = get(h.Xaxis,'Value');
    x_strings = get(h.Xaxis,'String');
    
    
    %Find the column index for the xaxis variable of interest
    if RUNTIME.UseOpenEx
        rp = cellfun(@(x) x(10:end), ROVED_PARAMS, 'UniformOutput',false);
        col_ind = find(strcmpi(x_strings(x_ind),rp));
    else
        col_ind = find(strcmpi(x_strings(x_ind),ROVED_PARAMS));
    end
    
    %If the user wants to group data by a selected variable before
    %plotting, group the data now.
    grpstr = get(h.group_plot,'String');
    grpval = get(h.group_plot,'Value');
    
    switch grpstr{grpval}
        case 'None'
            %Calculate hit rate for each value of the roved parameter of interest
            vals = unique(GOtrials(:,col_ind));
            plotting_data = [];
            
            for i = 1: numel(vals)
                val_data = GOtrials(GOtrials(:,col_ind) == vals(i),:);
                hit_rate = 100*(sum(val_data(:,end))/numel(val_data(:,end)));
                plotting_data = [plotting_data;vals(i),hit_rate,str2num(get(h.FArate,'String'))];
            end
            
        otherwise
            %Find the column index for the grouping variable of interest
            if RUNTIME.UseOpenEx
                grp_ind = find(strcmpi(grpstr(grpval),rp));
            else
                grp_ind = find(strcmpi(grpstr(grpval),ROVED_PARAMS));
            end
            
            %Find the groups
            grps = unique(GOtrials(:,grp_ind));
            if ~isempty(get(h.FArate2,'String'))
                FAs = [str2num(get(h.FArate,'String')),str2num(get(h.FArate2,'String'))];
            else
                FAs = [str2num(get(h.FArate,'String')),str2num(get(h.FArate,'String'))];
            end
            
            plotting_data = [];
            
            %For each group
            for i = 1:numel(grps)
                
                %Pull out the group data
                grp_data = GOtrials(GOtrials(:,grp_ind) == grps(i),:);
                vals = unique(grp_data(:,col_ind));
                
                
                for j = 1:numel(vals)
                    val_data = grp_data(grp_data(:,col_ind) == vals(j),:);
                    hit_rate = 100*(sum(val_data(:,end))/numel(val_data(:,end)));
                    plotting_data = [plotting_data;vals(j),hit_rate,FAs(i),grps(i)];
                end
                
                
            end
            
            
    end
    
    %Set up the x text
    switch x_strings{x_ind}
        case 'dB SPL'
            xtext = 'Sound Level (dB SPL)';
        case 'Freq'
            xtext = 'Sound Frequency (Hz)';
        case 'Stim_duration'
            xtext = 'Sound duration (s)';
        case 'FMdepth'
            xtext = 'FM depth (%)';
            plotting_data(:,1) = plotting_data(:,1)*100; %percent
            vals = vals*100; %percent
        case 'FMrate'
            xtext = 'FM rate (Hz)';
        case 'AMdepth'
            xtext = 'AM depth (%)';
            plotting_data(:,1) = plotting_data(:,1)*100; %percent
            vals = vals*100; %percent
        case 'AMrate'
            xtext = 'AM rate (Hz)';
        otherwise
            xtext = '';
    end
    
    
    %Determine if we need to plot hit rate or d prime
    y_ind = get(h.Yaxis,'Value');
    y_strings = get(h.Yaxis,'String');
    
    switch y_strings{y_ind}
        
        %If we want to plot hit rate, we just need to format the plot
        case 'Hit Rate'
            
            ylimits = [0 100];
            ytext = 'Hit rate (%)';
            
            %If we want to plot d', we need to do some calculations and format the plot
        case 'd'''
            
            ylimits = [0 3.5];
            ytext = 'd''';
            
            %Convert back to proportions
            plotting_data(:,2) = plotting_data(:,2)/100;
            plotting_data(:,3) = plotting_data(:,3)/100;
            
            %Set bounds for hit rate and FA rate (5-95%)
            %Setting bounds prevents d' values of -Inf and Inf from occurring
            plotting_data(plotting_data(:,2) < 0.05,2) = 0.05;
            plotting_data(plotting_data(:,2) > 0.95,2) = 0.95;
            plotting_data(plotting_data(:,3) < 0.05,3) = 0.05;
            plotting_data(plotting_data(:,3) > 0.95,3) = 0.95;
            
            %Covert proportions into z scores
            z_fa = sqrt(2)*erfinv(2*plotting_data(:,3)-1);
            z_hit = sqrt(2)*erfinv(2*plotting_data(:,2)- 1);
            
            %Calculate d prime
            plotting_data(:,2) = z_hit - z_fa;
    end
    
    
    %Update plot
    if ~isempty(plotting_data)
        
        %Clear and reset scale
        ax = h.IOPlot;
        hold(ax,'off');
        cla(ax)
        legend(ax,'hide');
        xmin = min(vals)-10;
        xmax = max(vals)+10;
        
        %If no grouping variable is applied
        switch grpstr{grpval}
            case 'None'
                
                plot(ax,plotting_data(:,1),plotting_data(:,2),'rs-','linewidth',2,...
                    'markerfacecolor','r')
                
                %Otherwise, group data and plot accordingly
            otherwise
                legendhandles = [];
                legendtext = {};
                clrmap = jet(numel(grps));
                
                for i = 1:numel(grps)
                    clr = clrmap(i,:);
                    
                    grouped = plotting_data(plotting_data(:,4) == grps(i),:);
                    hp = plot(ax,grouped(:,1),grouped(:,2),'s-','linewidth',2,...
                        'markerfacecolor',clr,'color',clr);
                    hold(ax,'on');
                    
                    legendhandles = [legendhandles;hp];
                    legendtext{i} = [grpstr{grpval},' ', num2str(grps(i))];
                end
                
                l = legend(legendhandles,legendtext);
                set(l,'location','southeast')
                
                
        end
        
        
        %Format plot
        set(ax,'ylim',ylimits,'xlim',[xmin xmax],'xgrid','on','ygrid','on');
        xlabel(ax,xtext,'FontSize',12,'FontName','Arial','FontWeight','Bold')
        ylabel(ax,ytext,'FontSize',12,'FontName','Arial','FontWeight','Bold')
        
        %Adjust plot formatting if selected variable is Expected
        switch x_strings{x_ind}
            
            case 'TrialType'
                set(ax,'XLim',[-1 1])
                set(ax,'XTick',0);
                set(ax,'XTickLabel',{'GO Trials'})
                set(ax,'FontSize',12,'FontWeight','Bold')
                
            case 'FMdepth'
                set(ax,'XLim',[-0.2 0.2])
                set(ax,'XTick',-0.2:0.1:0.2);
                
            case 'Freq'
                set(ax,'XScale','log')
                set(ax,'XTick',[1000 2000 4000 8000 16000]);
        end
        
    end
    
end





%-----------------------------------------------------------
%%%%%%%%%%%%%%        GUI FUNCTIONS           %%%%%%%%%%%%%%%
%------------------------------------------------------------

%CLOSE GUI WINDOW
function figure1_CloseRequestFcn(hObject, ~, ~)
global RUNTIME PUMPHANDLE

%Check to see if user has already pressed the stop button
if~isempty(RUNTIME)
    if RUNTIME.UseOpenEx
        h = findobj('Type','figure','-and','Name','ODevFig');
    else
        h = findobj('Type','figure','-and','Name','RPfig');
    end
    
    %If not, prompt user to press STOP
    if ~isempty(h)
        beep
        warnstring = 'You must press STOP before closing this window';
        warnhandle = warndlg(warnstring,'Close warning');
    else
        %Close COM port to PUMP
        fclose(PUMPHANDLE);
        delete(PUMPHANDLE);
        
        %Clean up global variables
        clearvars -global PUMPHANDLE CONSEC_NOGOS
        clearvars -global GUI_HANDLES ROVED_PARAMS USERDATA
        
        %Delete figure
        delete(hObject)
        
    end
    
else
    
    %Close COM port to PUMP
    fclose(PUMPHANDLE);
    delete(PUMPHANDLE);
    
    %Clean up global variables
    clearvars -global PUMPHANDLE CONSEC_NOGOS
    clearvars -global GUI_HANDLES ROVED_PARAMS USERDATA
    
    %Delete figure
    delete(hObject)
    
end





%-----------------------------------------------------------
%%%%%%%%%%%%%%       PHYSIOLOGY FUNCTIONS     %%%%%%%%%%%%%%%
%------------------------------------------------------------
%REFERENCE PHYSIOLOGY
function ReferencePhys_Callback(hObject, eventdata, handles)
global AX
%The method we're using here to reference channels is the following:
%First, bad channels are removed.
%Second a single channel is selected and held aside.
%Third, all of the remaining (good, non-selected) channels are averaged.
%Fourth, this average is subtracted from the selected channel.
%This process is repeated for each good channel.
%
%The way this method is implemented in the RPVds circuit is as follows:
%
%From Brad Buran:
%
% This is implemented using matrix multiplication in the format D x C =
% R. C is a single time-slice of data in the shape [16 x 1]. In other
% words, it is the value from all 16 channels sampled at a single point
% in time. D is a 16 x 16 matrix. R is the referenced output in the
% shape [16 x 1]. Each row in the matrix defines the weights of the
% individual channels. So, if you were averaging together channels 2-16
% and subtracting the mean from the first channel, the first row would
% contain the weights:
%
% [1 -1/15 -1/15 ... -1/15]
%
% If you were averaging together channels 2-8 and subtracting the mean
% from the first channel:
%
% [1 -1/7 -1/7 ... -1/7 0 0 0 ... 0]
%
% If you were averaging together channels 3-8 (because channel 2 was
% bad) and subtracting the mean from the first channel:
%
% [1 0 -1/6 ... -1/6 0 0 0 ... 0]
%
% To average channels 1-4 and subtract the mean from the first channel:
%
% [3/4 -1/4 -1/4 -1/4 0 ... 0]
%
% To repeat the same process (average channels 1-4 and subtract the
% mean) for the second channel, the second row in the matrix would be:
%
% [-1/4 3/4 -1/4 -1/4 0 ... 0]




%Hard coded for a 16 channel array
numchannels = 16;

%Prompt user to identify bad channels
channelList = {'1','2','3','4','5','6','7','8',...
    '9','10','11','12','13','14','15','16'};

header = 'Select bad channels. Hold Cntrl to select multiple channels.';

bad_channels = listdlg('ListString',channelList,'InitialValue',8,...
    'Name','Channels','PromptString',header,...
    'SelectionMode','multiple','ListSize',[300,300])


if ~isempty(bad_channels)
    %Calculate weight for non-identical pairs
    weight = -1/(numchannels - numel(bad_channels) - 1);
    
    %Initialize weight matrix
    WeightMatrix = repmat(weight,numchannels,numchannels);
    
    %The weights of all bad channels are 0.
    WeightMatrix(:,bad_channels) = 0;
    
    %Do not perform averaging on bad channels: leave as is.
    WeightMatrix(bad_channels,:) = 0;
    
    %For each channel
    for i = 1:numchannels
        
        %Its own weight is 1
        WeightMatrix(i,i) = 1;
        
    end
    
    
    
    %Reshape matrix into single row for RPVds compatibility
    WeightMatrix =  reshape(WeightMatrix',[],1);
    WeightMatrix = WeightMatrix';
    
    
    %Send to RPVds
    AX.WriteTargetVEX('Phys.WeightMatrix',0,'F32',WeightMatrix);
    %verify = AX.ReadTargetVEX('Phys.WeightMatrix',0, 256,'F32','F64');
end






