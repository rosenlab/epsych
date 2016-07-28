function column = SanesLab_findCol(colnames,variable,handles)
%Custom function for SanesLab epsych
%
%This function finds the row and column index for a specified variable
%Inputs:
%   colnames: cell-string array of column names
%   variable: string identifier for variable of interest
%   handles: GUI handles structure
%
%Example usage: column = findCol({'OptoStim', 'TrialType'},'TrialType')
%
%Written by ML Caras 7.28.2016

global RUNTIME


%Check that there are 3 input variables
narginchk(3,3)



if RUNTIME.UseOpenEx
    variable = [RUNTIME.TDT.name{handles.dev},'.',variable];
end


column = find(ismember(colnames,variable));


end
