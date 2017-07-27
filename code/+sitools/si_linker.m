classdef si_linker < handle
    % Provides methods for finding the ScanImage API object and
    % incorporating it into a class
    %
    % sitools.si_linker
    
    properties (Hidden)
        scanimageObjectName = 'hSI' % If connecting to ScanImage look for this variable in the base workspace
        hSI % The ScanImage API attaches here
        listeners = {} % Reserved for listeners we might make
    end % Close hidden methods
    
    
    methods
        
        function obj = si_linker

        end % Constructor
        
        
        function delete(obj)
            obj.hSI=[];
        end % Destructor
        
        function linkToScanImageAPI(obj)
            % Link to ScanImage API by importing from base workspace and
            % copying handling to obj.hSI

            W = evalin('base','whos');
            SIexists = ismember(obj.scanimageObjectName,{W.name});
            
            if ~SIexists
                fprintf('ScanImage not started, unable to link to it.\n')
                return
            end

            API = evalin('base',obj.scanimageObjectName); % get hSI from the base workspace
            if ~isa(API,'scanimage.SI')
                fprintf('hSI is not a ScanImage object.\n')
                return
            end

            obj.hSI=API; % Make composite object
            
        end % linkToScanImageAPI
                    

    end % Close methods
    
    
end % Close classdef