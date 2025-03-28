function blankPhotostimStart(src,~,varargin) 
    % This is ScanImage function. See the ScanImage doc for details.
    % https://docs.scanimage.org/Advanced+Features/User+Functions.html
    % ScanImage Arguments:
    %   on_duration: int. The duration of when photostimulation is ON in usec.
    
    global PhotostimBlanker
    PhotostimBlanker = sitools.blankPhotostim(src);
    if nargin>2 % when varagin is used
        PhotostimBlanker.set.on_duration(varargin{1});
    end
    PhotostimBlanker.start(true);
    
 end