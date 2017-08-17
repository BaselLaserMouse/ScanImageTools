function appendDateAndTimeToFname(src,evt,varargin)
    % ScanImage user function to append the current date and time to the file string
    %
    % function appendDateAndTimeToFname(src,evt,fileSavePath)
    %
    % Purpose
    % Appends the current date and time to the file string entered in ScanImage.
    % e.g. If the user enters 'mouse_01' into the "Basename" then this will be
    % replaced by: 'yyyymmdd_hhmmss__mouse_01' 
    % This string will be updated each time "Grab" or "Loop" is pressed. 
    % You don't need to re-enter "mouse_01"
    % NOTE: Do not use a double underscore ("__") in the file name you enter.
    %
    % How to set it up:
    % a) Add directory containing his function to the path
    % b) In ScanImage go to the User Functions and associate this function with 
    %    the Event Name "acqModeStart". 
    % c) If you wish to always save in a certain directory, supply that as an
    %    string in the "Arguments" box. 
    % d) Enable the user function. 
    % e) You can optioanlly save the above state as a Configuration file. 
    %
    %
    % Inputs
    % The third input arg (i.e. what's entered in the ScanImage Arguments box)
    % should be a path to which all files will be saved. It must exist.
    %
    %
    %
    % Rob Campbell - Basel 2017

    % in myUserFcn.m somewhere on the matlab path.

    if nargin<2
        fprintf('\n\nThis is a ScanImage userfunction. See the help text:\n\n')
        help(mfilename)
        return
    end

    if nargin>2
        % Optionally set the file path
        filePath = varargin{1};
        if ~exist('filePath','dir')
            fprintf('Can not find directory %s. Will not set the save path\n', filePath)
        else
            hSI.hScan2D.logFilePath = filePath;
        end
    end

    hSI = src.hSI;

    currentFname = strsplit(hSI.hScan2D.logFileStem, '__');

    if length(currentFname)>2
        fprintf('\nYou placed a double underscore in the sample name! The file string may now not be what you expect\n')
    end

    sampleName = currentFname{end}; % now we have a sample (mouse) name

    % Build name with date and time
    hSI.hScan2D.logFileStem = [datestr(now ,'yyyymmdd_HHMMSS__'), sampleName];

end