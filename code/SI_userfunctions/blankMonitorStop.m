function blankMonitorStop(src,~,varargin) 
    % This is ScanImage function. See the ScanImage doc for details.
    % https://docs.scanimage.org/Advanced+Features/User+Functions.html

    global MonitorBlanker
    MonitorBlanker.stop;
    MonitorBlanker.delete;
    
 end