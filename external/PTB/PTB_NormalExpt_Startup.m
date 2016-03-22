function [windowPtr,ScreenRect,frameRate] = PTB_NormalExpt_Startup(ScreenNum,useBitsPlusPlus)
% [windowPtr,ScreenRect,frameRate] = PTB_NormalExpt_Startup([ScreenNum],[useBitsPlusPlus])
%
% Daniel.Stolzberg@gmail.com 2016

Screen('Preference', 'SkipSyncTests', 0);

if nargin == 2 && useBitsPlusPlus
    PsychImaging('PrepareConfiguration');
    PsychImaging('AddTask', 'General', 'FloatingPoint32Bit');
    PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'ClampOnly');
    PsychImaging('AddTask', 'General', 'EnableBits++Mono++Output');
end

PsychGPUControl('SetGPUPerformance',10);

Priority(1);

if nargin == 0 || isempty(ScreenNum)
    ScreenNum = max(Screen('Screens'));
end

[windowPtr,ScreenRect] = PsychImaging('OpenWindow',ScreenNum,0.5);

frameRate=Screen('NominalFrameRate', windowPtr);

