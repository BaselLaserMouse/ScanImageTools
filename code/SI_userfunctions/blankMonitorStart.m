function blankMonitorStart(src,~,varargin) 
    % This is ScanImage function. See the ScanImage doc for details.
    % https://docs.scanimage.org/Advanced+Features/User+Functions.html
    % ScanImage Arguments:
    %   on_duration: int. The duration of when monitor is ON in usec.
    
    global MonitorBlanker
    MonitorBlanker = sitools.blankMonitor(src);
    if nargin>2 % when varagin is used
        MonitorBlanker.set.on_duration(varargin{1});
    end
    MonitorBlanker.start(true);
    
 end