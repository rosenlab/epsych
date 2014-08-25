function CONFIG = ep_TimerFcn_Stop(CONFIG,RP,DA)
% CONFIG = ep_TimerFcn_Stop(CONFIG,RP,DA)
% 
% Default Stop timer function
% 
% Use ep_PsychConfig GUI to specify custom function.
% 
% Daniel.Stolzberg@gmail.com

% not doing anything with CONFIG

if isempty(RP)
    DA.SetSysMode(0);
    DA.CloseConnection;
    delete(DA);
    h = findobj('Type','figure','-and','Name','ODevFig');
    close(h);
else
    for i = 1:length(RP)
        RP(i).Halt;
    end
    delete(RP);
    h = findobj('Type','figure','-and','Name','RPfig');
    close(h);
end




