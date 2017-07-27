classdef ai_recorder < sitools.si_linker
    % sitools.ai_recorder s in data from analog input channels on a defined DAQ and can be synced to ScanImage
    %
    % Usage instructions
    %
    % Interactive use without ScanImage:
    % 1. Start:
    % AI = sitools.ai_recorder(false) %false so it does not attach to ScanImage
    % 
    % 2. Set any properties then run:
    % AI.connectAndStart
    %
    % You can then:
    % AI.stop
    % AI.start
    % 
    % Also:
    % AI.connectToDAQ
    %
    %
    % You can stop the acquisition by closing the figure window or doing:
    % delete(AI)
    %
    %
    %
    % Rob Campbell - Basel, 2017
    %
    % 
    % Also see:
    % https://github.com/tenss/MatlabDAQmx
    
    properties
        hTask % The DAQmx task handle
        devName = 'aux' % Name of the DAQ device to which we will connect
        
        hFig % The figure/GUI handle
        

        % DAQmx Task configuration
        AI_channels = 0:7 % Channels from which to acquire data
        voltageRange = 5  % Will acquire data over +/- this range
        sampleRate = 1E3  % Sample Rate in Hz
        sampleReadSize = 1000  % Read off this many samples each time
        
        % Saving and data configuration 
        fname = '' % Name of the file to write data to
        chanNames = {}; % Optionally enter the names of the channels
        
    end % Close properties
    
    properties (Hidden)
        figTagName = 'ai_recorder' % Tag for the figure/GUI window
        hAx % Figure axis handle
        taskName = 'airecorder' % Name for the task
        dataType = 'int16' % The format we will write the data in
        fid = -1       % File handle to which we will write data
        data       % The last read from the buffer is held here
    end % Close hidden properties

    
    
    methods
        
        function obj = ai_recorder(linkToScanImage)
            if nargin<1
                linkToScanImage=true;
            end
            
            if linkToScanImage
                obj.openFigureWindow % To display data as they come in 
                obj.connectToDAQ;
                obj.linkToScanImageAPI;  
                obj.listeners{1} = addlistener(obj.hSI,'acqState', 'PostSet', @obj.startWhenNotIdle);
            end
         
        end %constructor
        
        
        function delete(obj)
            fprintf('sitools.ai_recorder is shutting down\n')
            obj.hTask.stop
            obj.hTask.delete
            cellfun(@delete,obj.listeners)
            delete(obj.hFig) % Closes the plot window 
            obj.closeDataLogFile
        end % destructor
    
        
        function success=connectToDAQ(obj)
            % Connect to the DAQ using the object properties 
            if ~isempty(obj.hTask)
                fprintf('Not connecting to NI DAQ device "%s". sitools.ai_recoder has already connected to the DAQ\n',...
                    obj.devName)
                success=false;
                return
            end
            
            try               
                % Create a DAQmx task
                obj.hTask = dabs.ni.daqmx.Task(obj.taskName); 

                % * Set up analog inputs
                obj.hTask.createAIVoltageChan(obj.devName, obj.AI_channels, 'DAQmx_Val_NRSE', obj.voltageRange*-1, obj.voltageRange);


                % * Configure the sampling rate and the size of the buffer in samples using the on-board sanple clock
                bufferSize_numSamplesPerChannel = 40*obj.sampleReadSize; % The number of samples to be stored in the buffer per channel. 
                obj.hTask.cfgSampClkTiming(obj.sampleRate, 'DAQmx_Val_ContSamps', bufferSize_numSamplesPerChannel, 'OnboardClock');

                % * Set up a callback function to regularly read the buffer and plot it or write to disk
                obj.hTask.registerEveryNSamplesEvent(@obj.readData, obj.sampleReadSize, 1, 'Native');

                fprintf('Connected to %s with %d AI channels\n', obj.devName, length(obj.AI_channels))            
                success=true;
            catch ME
                % If the connection to the DAQ failed, display the error
                obj.reportError(ME)
                success=false;
            end                
        end % connectToDAQ
        
        
        
        
        
        % -----------------------------------------------------------
        % Callbacks

        function readData(obj,~,evt)
            % This callback function runs each time a pre-defined number of points have been collected
            % This is defined at the hTask.registerEveryNSamplesEvent method call.
            obj.data = evt.data;

            errorMessage = evt.errorMessage;

            % check for errors and close the task if any occur. 
            if ~isempty(errorMessage)
                obj.delete
                error(errorMessage);
            else
                if isempty(obj.data)
                    fprintf('Input buffer is empty\n' );
                else
                    if ~isempty(obj.hAx) && isvalid(obj.hAx)
                       plot(obj.hAx,obj.data) % Plot into the figure axes if they exist
                    end
                    if obj.fid>=0
                        fwrite(obj.fid, obj.data', obj.dataType);
                    end
                end
            end
        end % readData

            
        function windowCloseFcn(obj,~,~)
            % This runs when the user closes the figure window.
            fprintf('Shutting down sitools.si_linker.\n')
            obj.delete % simply call the destructor
        end %close windowCloseFcn
        
        function startWhenNotIdle(obj,~,~)
            % If ScanImage is connected and it starts imaging then
            % acquisition starts. If a file is being saved in ScanImage
            % then this causes this class to save data to dosk
            if isempty(obj.hSI)
                return
            end
            
            switch obj.hSI.acqState
                case 'grab'
                    if obj.hTask.isTaskDone
                        %Set up saving if needed
                        if obj.hSI.hChannels.loggingEnable
                            thisFname = sprintf('AI_%s_%03d.bin', obj.hSI.hScan2D.logFileStem, obj.hSI.hScan2D.logFileCounter);
                            obj.fname = fullfile(obj.hSI.hScan2D.logFilePath,thisFname);
                            obj.openFileForWriting;
                        end
                        obj.start; %start pulling in AI data
                    end
                case 'focus'                    
                    obj.closeDataLogFile                    
                    obj.start; %start pulling in AI data
                case 'idle'
                    obj.stop;
            end
        end % startWhenNotIdle
        
        
            % -----------------------------------------------------------
            % Short helper methods
        function openFigureWindow(obj)
            % Open a figure window and have it shut off the acquisition when closed
            % Only opens the figure if doesn't already exist
            obj.hFig = findobj(0, 'Tag', obj.figTagName);
            if isempty(obj.hFig)
                %If the figure does not exist, make it
                obj.hFig = figure;
                set(obj.hFig, 'Tag', obj.figTagName, 'Name', 'ScanImage AI Recorder')                
            end
            
            %Focus on the figure and clear it
            figure(obj.hFig)
            clf
            obj.hAx = cla;
            
            obj.hFig.CloseRequestFcn = @obj.windowCloseFcn;
        end % openFigureWindow
        
        function success=start(obj)
            % Begin the task and so start the acquisition
            
            try
                obj.hTask.start % Task will start right away if there are no triggers configured
                if ~isempty(obj.hFig) && isvalid(obj.hFig)
                    fprintf('Recording data on %s. Close window to stop.\n', obj.devName);
                    if ~isempty(obj.fname)
                        obj.hFig.Name=['SAVING TO: ',obj.fname];
                    else
                        obj.hFig.Name='AI recorder';
                    end
                else
                    fprintf('Recording data on %s. use stop method to halt acqusition.\n', obj.devName);
                end
                success=true;
            catch ME
                obj.reportError(ME)
                success=false;
            end
        end % start
              
        function success=stop(obj)
            % Stop the DAQ task and close the data file
            try
                obj.hTask.stop;
                obj.closeDataLogFile
                success=true;
            catch ME
                obj.reportError(ME)
                success=false;
            end
        end
        
        function connectAndStart(obj)
            % Connect to the DAQ and start
            obj.connectToDAQ;
            obj.start;
        end

    end % Close methods
    
 
    
    methods (Hidden)
                
        function openFileForWriting(obj)
            % Opens a data file for writing
            if ~isempty(obj.fname)
                obj.fid=fopen(obj.fname,'w+');
                
                % Write the critical meta-data to a .mat file so it's
                % possible to read the binary file
                [thisDir,thisFname] = fileparts(obj.fname);
                metaFname = fullfile(thisDir, [thisFname,'_meta.mat']);
                
               
                metaData.fname = obj.fname;
                metdData.dataType = obj.dataType;
                metaData.channels = obj.AI_channels;
                metaData.voltageRange = obj.voltageRange;
                metaData.sampleRate = obj.sampleRate;
                metaData.chanNames = obj.chanNames;
            
                save(metaFname,'metaData')
                fprintf('Opened file %s for writing\n', obj.fname)
                
            else
                obj.fid=-1;
            end
        end % openFileForWriting
        
        function closeDataLogFile(obj)
            if obj.fid>-1
                fclose(obj.fid);
                obj.fid=-1;
                obj.fname='';
            end 
        end % closeDataLogFile
            
        function reportError(~,ME)
            % Reports error from error structure, ME
            fprintf('ERROR: %s\n',ME.message)
            for ii=1:length(ME.stack)
                 fprintf(' on line %d of %s\n', ME.stack(ii).line,  ME.stack(ii).name)
            end
            fprintf('\n')
        end % reportError
        

        
    end % Close hidden methods


end % Close sitools.ai_recorder
