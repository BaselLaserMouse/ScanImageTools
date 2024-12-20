classdef ai_recorder < sitools.si_linker
    % sitools.ai_recorder - acquire data from analog input channels and sync some operations with ScanImage
    %
    % Purpose
    % Connect to a defined set of analog input channels on a defined DAQ 
    % (either NI or vDAQ) and acquire data at at a defined sample rate.
    % Data are streamed to a plot window. If ScanImage is started, data 
    % acquisition can be configured to start when "Focus" or "Grab" are 
    % pressed. In addition, if data are being saved in Grab mode a binary 
    % log file containing the acquired data is automatically saved in the 
    % same directory with a similar file name to the ScanImage TIFF. 
    %
    % Getting Help
    % Try "doc sitools.ai_recorder" and also look at the help text for the
    % following methods of this function:
    % sitools.ai_recorder.linkToScanImageAPI
    % sitools.ai_recorder.connectToDAQ
    % sitools.ai_recorder.openFigureWindow
    % sitools.ai_recorder.start
    % sitools.ai_recorder.stop
    % sitools.ai_recorder.loadSettings
    % sitools.ai_recorder.saveCurrentSettings
    %
    %
    % * Quick Start: connect to ScanImage with default settings
    %  a. Start ScanImage
    %  b. Do: AI = sitools.ai_recorder;
    %  c. Press "Focus" or "Grab". A .bin file is saved if you also choose
    %     to save image data. 
    %  d. Close window or do delete(AI) to shut down the AI recorder.
    % 
    %
    % * Create, save, then load a set of acquisition preferences
    % >> AI=sitools.ai_recorder(false);
    % >> AI.devType = 'DAQmx';  % set the DAQ type, either DAQmx or vDAQ
    % >> AI.chanNames={'frame_trigger','valve'};
    % >> AI.AI_channels=[0,1];
    % >> AI.saveCurrentSettings('prefsAIrec.mat');
    % >> delete(AI) %Just to prove it works
    %   sitools.ai_recorder is shutting down
    % >> scanimage
    % >> AI=sitools.ai_recorder('prefsAIrec.mat'); % check displayed properies
    %
    %
    % * Interactive use without ScanImage
    %  a. Start:
    %  >> AI = sitools.ai_recorder(false) %false so it does not attach to ScanImage
    %
    %  b. Set any desired properties then start
    %  >> AI.devType = 'DAQmx';  % set the DAQ type, either DAQmx or vDAQ
    %  >> AI.devName = 'auxDevice';
    %  >> AI.AI_channels=0:1; % acquire data on first two channels
    %  >> AI.voltageRange=1  % over +/- 1 volt
    %  >> obj.openFigureWindow % To display data as they come in
    %  >> AI.connectAndStart % begin acquisition
    %  
    %  c. You can the stop and start the acquisition at will:
    %  >> AI.stop
    %  >> AI.start
    %
    %  d. Save data to disk
    %  >> AI.fname='test.bin';
    %  >> AI.start
    %  % This creates a data file (the .bin) and also a .mat file that allows the .bin to be read back. 
    %  % Do not delete the .mat file. Read back data with 
    %
    %
    % KNOWN ISSUES
    %
    % 1)
    % If you see "ERROR: A Task with name 'airecorder' already exists in
    % the DAQmx System" then check for existing instances of this class
    % and delete them (e.g. delete(myAIrec) ). If there are no instances
    % then there is an orphan task. You will either need to change the
    % "taskName" property to a different string or restart MATLAB. 
    %
    % 2)
    % Changing data acquisition properties on the fly is not currently 
    % supported. You will need to change the settings, save the file,
    % close the object and re-load the file. This will be fixed in 
    % future. 
    %
    % 3)
    % When using vDAQ, the data range is fixed to 10 V and the sampling
    % rate must be above 3kHz.
    %
    % Rob Campbell - Basel, 2017
    %
    % 
    % Also see:
    % To read in data use: readAIrecorderBinFile
    % To learn more about DAQmx: https://github.com/tenss/MatlabDAQmx

    properties (SetAccess=protected, Hidden=false)

        hTask % The DAQmx task handle is stored here
        dataType = 'int16' % The format we will write the data in to binary file ai_recorder.fname
    end 

    properties
        % Saving and data configuration
        fname = ''  % File name for logging data to disk as binary using type ai_recoder.dataType
        hFig        % The figure/GUI handle

        numPointsInPlot=5E3 % The plot will scroll with a maximum of this many points

        % DAQmx Task configuration (these values are read on startup only)
        % CAUTION: Do not edit these values here for your experiment. Change 
        %          the properties in the live object and use the saveCurrentSettings
        %          and loadCurrentSettingsMethods
        
        devType = 'vDAQ';       % device type, can be "vDAQ" or "DAQmx"
        devName = 'Dev1'      % Name of the DAQ device to which we will connect
        AI_channels = 0:3     % Analog input channels from which to acquire data. e.g. 0:3
        voltageRange = 5      % Scalar defining the range over which data will be digitized
        sampleRate = 1E3      % Analog input sample Rate in Hz
        sampleReadSize = 250  % Read off this many samples then plot and log to disk
        
    end 

    properties (SetObservable)
        yMax % This is a vector of ylim values. The first subplot will have a max range of obj.yMax(1);
             % By default obj.yMax = repmat(obj.voltageRange,1,length(obj.AI_channels)). However, you can
             % modify it and save/reload values from a settings file. 
        yMin % Same as yMax but for the minimum y value. By default this is 
             % repmat(-obj.voltageRange,1,length(obj.AI_channels))
        chanNames = {}; % Cell array describing the channes. e.g. {'valve', 'trigger', 'frame_clock'}. 
                        % Auto-generated if left blank
        overlayTraces = false % If true, data are overlaid onto a single plot in different colours in stead of 
                             % being placed in different plots
    end


    properties (Hidden)
        figTagName = 'ai_recorder' % Tag for the figure/GUI window
        taskName = 'airecorder' % Name for the task
        subplots % Cell array of handles for the subplots (one per input channel)
        pltData  % Cell array of plot objects (one per subplot)
        titles   %plot titles
        fid = -1  % File handle to which we will write data
        data      % We hold data to be plotted here        
    end % Close hidden properties




    methods

        function obj = ai_recorder(linkToScanImage)
            % sitools.ai_recorder
            %
            % Inputs
            % linkToScanImage - true by default. 
            %           * If true, we attempt to connect to ScanImage so that analog data are
            %            acquired whenver Focus or Grab are pressed. 
            %           * If linkToScanImage is false, this is not done. Nothing is connectd or 
            %             started. Use this to set parameters. 
            %           * If linkToScanImage is a string, we treat it as a preference file name 
            %             and attempt to load it. 

            if nargin<1
                linkToScanImage=true;
            end

            if ischar(linkToScanImage)
                obj.loadSettings(linkToScanImage)
                linkToScanImage=true;
            end

            if linkToScanImage
                obj.openFigureWindow % To display data as they come in
                success = obj.connectToDAQ;
                if success
                    if obj.linkToScanImageAPI
                        obj.listeners{length(obj.listeners)+1} = addlistener(obj.hSI,'acqState', 'PostSet', @obj.startStopAcqWithScanImage);
                    end

                else
                    fprintf('\nNot connecting to ScanImage or DAQ --\n please check your DAQ settings and try again (see help text)\n\n')
                end %if success
            end

            obj.listeners{length(obj.listeners)+1} = addlistener(obj, 'yMax', 'PostSet', @obj.setPlotLimits);
            obj.listeners{length(obj.listeners)+1} = addlistener(obj, 'yMin', 'PostSet', @obj.setPlotLimits);
            obj.listeners{length(obj.listeners)+1} = addlistener(obj, 'chanNames', 'PostSet', @obj.setPlotTitlesFromChanNames);
            obj.listeners{length(obj.listeners)+1} = addlistener(obj, 'overlayTraces', 'PostSet', @obj.createPlotAxes);

        end %constructor


        function varargout=connectToDAQ(obj)
            % ai_recorder.connectToDAQ - Connect to the DAQ using the object properties
            %
            % Purpose
            % Run this method to connect to an DAQ device for analog
            % input using the parameters described in the properties of
            % this class. i.e.
            % devName - the name of the device
            % AI_channels - vector channel numbers
            % voltageRange - scalar defining the digitization range
            % sampleRate - number of samples per second to acquire
            % sampleReadSize - the number of samples to read before pulling
            %                  data off the DAQ for plotting or saving to disk
            
            switch lower(obj.devType)
                case 'vdaq'
                    varargout{1}=connectToVidrioDevice(obj);
                case 'daqmx'
                    % it is an NI device
                    varargout{1}=connectToNiDevice(obj);
                otherwise
                    error('devType must be vDAQ or DAQmx')
            end
            return
        end
            
        function varargout=connectToVidrioDevice(obj)
            % ai_recorder.connectToNiDevice - Connect to the DAQ using the object properties
            %
            % This function is called by connectToDAQ for devName that do
            % start with "v"
            hResourceStore = dabs.resources.ResourceStore();
            hvDAQ = hResourceStore.filterByName(obj.devName);
            if isempty(hvDAQ)
                fprintf('ERROR: Not connecting to vDAQ device "%s". The device could not be found in dabsresources\n',...
                    obj.devName)
                success=false;
                if nargout>0
                    varargout{1}=success;
                end
                return
            end
            hFpga = hvDAQ.hDevice;
            
            if obj.voltageRange ~= 10
                fprintf('Warning! Cannot change the voltage range of vDAQ. Using 10V.\n')
                obj.voltageRange = 10;
            end
            
            try
                % Create a vDAQ task
                obj.hTask = dabs.vidrio.ddi.AiTask(hFpga, 'ai_record Task');
                
                % * Set up analog inputs
                for i = 1:numel(obj.AI_channels)
                    obj.hTask.addChannel(obj.AI_channels(i));
                end
                
                % * Configure the sampling rate and the size of the buffer in samples using the on-board sanple clock
                obj.hTask.sampleRate = obj.sampleRate;
                if obj.sampleRate < 3000
                    fprintf('Warning! vDAQ seems weird with sampling rate below 3kHz.\n')
                end
                    
                bufferSize_numSamplesPerChannel = 40*obj.sampleReadSize;
                obj.hTask.bufferSize = bufferSize_numSamplesPerChannel;

                % * Set up a callback function to regularly read the buffer and plot it or write to disk
                obj.hTask.sampleCallbackN = obj.sampleReadSize;
                obj.hTask.sampleCallbackAutoRead = 1;
                obj.hTask.sampleCallback = @obj.readData;

                fprintf('Connected to %s with %d AI channels\n', obj.devName, length(obj.AI_channels))
                success=true;
            catch ME
                    % If the connection to the DAQ failed, display the error
                    obj.reportError(ME)
                    success=false;
            end
            if nargout>0
                varargout{1}=success;
            end
            disp('done')
        end

            
        function varargout=connectToNiDevice(obj)
            % ai_recorder.connectToNiDevice - Connect to the DAQ using the object properties
            %
            % This function is called by connectToDAQ for devName that do
            % not start with "v"
            
            if ~exist('dabs.ni.daqmx.System','class')
                success=false;
                fprintf('No Vidrio DAQmx wrapper found.\n')
                if nargout>0
                    varargout{1}=success;
                end
                return
            end
            if ~isempty(obj.hTask)
                fprintf('ERROR: Not connecting to NI DAQ device "%s". sitools.ai_recoder has already connected to the DAQ\n',...
                    obj.devName)
                success=false;
                if nargout>0
                    varargout{1}=success;
                end
                return
            end

            % Is the DAQ to which we are planning to connect present on the system?
            thisSystem = dabs.ni.daqmx.System;
            theseDevices = strsplit(thisSystem.devNames,', ');
            if isempty( strmatch(obj.devName, theseDevices) )
                fprintf('\nERROR: Device "%s" not present on system. Can not connect to DAQ. ',obj.devName)
                fprintf('Available devices are:\n',obj.devName)
                cellfun(@(x) fprintf(' * %s\n',x), theseDevices)
                success=false;
            else
                try
                    % Create a DAQmx task
                    obj.hTask = dabs.ni.daqmx.Task(obj.taskName);

                    % * Set up analog inputs
                    obj.hTask.createAIVoltageChan(obj.devName, obj.AI_channels, [], obj.voltageRange*-1, obj.voltageRange,[],[],'DAQmx_Val_NRSE');


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
            end

            if nargout>0
                varargout{1}=success;
            end
        end % connectToDAQ



        % -----------------------------------------------------------
        % Short helper methods
        function varargout=start(obj)
            % ai_recorder.start - begin acquiring data
            %
            % Purpose
            % Calls ai_recorder.hTask.start which tells DAQmx to start
            % acquiring data. Files are opened for writing if the fname
            % property contains a file name. If data are being saved to
            % disk, the plot window name is updated to report the log file name. 
            %
            % Outputs
            % Returns true if all went well and false otherwise

            if isempty(obj.hTask)
                fprintf('No NI DAQ connected to ai_recorder\n')
                return
            end
            try
                obj.openFileForWriting; % Only opens a file if the fname property is not empty
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

            if nargout>0
                varargout{1}=success;
            end
        end % start


        function varargout=stop(obj)
            % ai_recorder.stop - stop the acquisition and close any open data logging files
            %
            % Purpose
            % Calls ai_recorder.hTask.stop which tells DAQmx to stop
            % acquiring data. If data are being saved to disk, the log
            % file is closed. 
            %
            % Outputs
            % Returns true if all went well and false otherwise

            if isempty(obj.hTask)
                fprintf('No NI DAQ connected to ai_recorder\n')
                return
            end
            try
                obj.hTask.stop;
                obj.closeDataLogFile
                success=true;
            catch ME
                obj.reportError(ME)
                success=false;
            end
        
            if nargout>0
                varargout{1}=success;
            end
        end


        function connectAndStart(obj)
            % ai_recorder.connectAndStart - connect to the DAQ and start
            %
            % Purpose
            % simply runs the connect method and then start method

            obj.connectToDAQ
            obj.start
        end


        % Declare external methods
        openFigureWindow(obj)
        loadSettings(obj,fname)
        saveCurrentSettings(obj,fname)
    end % Close methods




    methods (Hidden)
        % Declare external hidden methods
        [p,n]=numSubPlots(~,n);


        function delete(obj)
            fprintf('sitools.ai_recorder is shutting down\n')
            obj.stop
            delete(obj.hTask)
            cellfun(@delete,obj.listeners)
            delete(obj.hFig) % Closes the plot window
        end % destructor

        function openFileForWriting(obj)
            % Opens a data file for writing
            if ~isempty(obj.fname) && ischar(obj.fname)
                obj.fid=fopen(obj.fname,'w+');

                % Write the critical meta-data to a .mat file so it's
                % possible to read the binary file
                [thisDir,thisFname] = fileparts(obj.fname);
                metaFname = fullfile(thisDir, [thisFname,'_meta.mat']);
                obj.saveCurrentSettings(metaFname)

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


        % -----------------------------------------------------------
        % Callbacks
        function readData(obj,~,evt)
            % This callback function runs each time a pre-defined number of points have been collected
            % This is defined at the hTask.registerEveryNSamplesEvent method call.
            obj.data = [obj.data;evt.data];

            % Always keep the most recent points
            if size(obj.data,1)>obj.numPointsInPlot
                obj.data(1:size(obj.data,1)-obj.numPointsInPlot,:)=[];
            end
            
            errorMessage = evt.errorMessage;

            % check for errors and close the task if any occur. 
            if ~isempty(errorMessage)
                obj.delete
                error(errorMessage);
            else
                if isempty(evt.data)
                    fprintf('Input buffer is empty!\n' );
                else

                    for ii=1:size(obj.data,2)
                        if ~isempty(obj.pltData{ii}) && isvalid(obj.pltData{ii})
                            obj.pltData{ii}.YData=obj.data(:,ii); % Plot into the figure axes if they exist
                        end
                    end
                    if obj.fid>=0
                        fwrite(obj.fid, evt.data', obj.dataType);
                    end
                end
            end
        end % readData


        function windowCloseFcn(obj,~,~)
            % This runs when the user closes the figure window.
            % If data are being saved, a confirmation dialog opens.
            if obj.fid>-1
                reply=questdlg('Closing the window will stop data acquisition. Are you sure?','Are you sure?');
                if ~strcmpi(reply,'Yes')
                    return
                end
            end
            fprintf('Shutting down sitools.si_linker.\n')
            obj.delete % simply call the destructor
        end %close windowCloseFcn


        function startStopAcqWithScanImage(obj,~,~)
            % If ScanImage is connected and it starts imaging then
            % acquisition starts. If a file is being saved in ScanImage
            % then this causes this class to save data to dosk
            if isempty(obj.hSI)
                return
            end

            switch obj.hSI.acqState
                case {'grab','loop'}
                    switch lower(obj.devType)
                        case 'vdaq'
                            done = obj.hTask.done;
                        case 'daqmx'
                            % it is an NI device
                            done = obj.hTask.isTaskDone;
                        otherwise
                            error('devType must be vDAQ or DAQmx')
                    end
                    if done
                        %Set up saving if needed
                        if obj.hSI.hChannels.loggingEnable
                            thisFname = sprintf('%s_AI_%03d.bin', obj.hSI.hScan2D.logFileStem, obj.hSI.hScan2D.logFileCounter);
                            obj.fname = fullfile(obj.hSI.hScan2D.logFilePath,thisFname);
                            % File will automatically be opened when we start
                        end
                        obj.start; %start pulling in AI data
                    end
                case 'focus'
                    obj.closeDataLogFile
                    obj.start; %start pulling in AI data
                case 'idle'
                    obj.stop;
            end
        end % startStopAcqWithScanImage


        function createPlotAxes(obj,~,~)
            % Create axes into which we will plot the incoming AI traces.
            % Make either one plot per trace or places all traces on the same plot

            if isempty(obj.yMax)
                obj.yMax = repmat(obj.voltageRange,1,length(obj.AI_channels));
            end
            if isempty(obj.yMin)
                obj.yMin = repmat(-obj.voltageRange,1,length(obj.AI_channels));
            end

            clf

            if obj.overlayTraces==false

                n=obj.numSubPlots(length(obj.AI_channels));
                for ii=1:length(obj.AI_channels)
                    obj.subplots{ii} = subplot(n(1),n(2),ii);
                    obj.pltData{ii}  = plot(zeros(100,1));
                    obj.titles{ii} = title(''); %create the handle
                    grid on
                end

            else

                obj.subplots{1} = cla;
                obj.subplots{1}.NextPlot='Add';
                obj.titles{1} = title(''); %create the handle, even though we are unlikely
                obj.subplots(2:end)=[];
                for ii=1:length(obj.AI_channels)
                    obj.pltData{ii}  = plot(zeros(100,1));
                    grid on
                end

            end

            obj.setPlotLimits;
            obj.setPlotTitlesFromChanNames;
        end % createPlotAxes


        function setPlotLimits(obj,~,~)
            % This listener callback runs whenever the user changes a desired plot limit.
            % The axes are changed for this plot.
            if obj.overlayTraces
                Y=[min(obj.yMin), max(obj.yMax)];
                obj.subplots{1}.YLim = (Y/obj.voltageRange) * 2^15;
            else
                    
                for ii=1:length(obj.subplots)

                    if length(obj.yMin)>=ii %check a value exists for this axis
                        ymin = obj.yMin(ii);
                    else
                        ymin = -obj.voltageRange;
                    end

                    if length(obj.yMax)>=ii
                        ymax = obj.yMax(ii);
                    else
                        ymax = obj.voltageRange;
                    end

                    obj.subplots{ii}.YLim = ([ymin, ymax]/obj.voltageRange) * 2^15;
                end
            end
        end % setPlotLimits


        function setPlotTitlesFromChanNames(obj,~,~)

            if obj.overlayTraces
                %Skip titles if there is just one plot
            else
                for ii=1:length(obj.subplots)
                    if length(obj.chanNames)>=ii && ~isempty(obj.chanNames{ii})
                        obj.titles{ii}.String = sprintf('AI%d %s', obj.AI_channels(ii), obj.chanNames{ii});
                    else
                        obj.titles{ii}.String = sprintf('AI %d', obj.AI_channels(ii));
                    end
                end
            end % if obj.overlayTraces
        end % setPlotTitlesFromChanNames

    end % Close hidden methods  
    

    
    % getters and setters
    methods
        function set.numPointsInPlot(obj,val)
            if val < obj.sampleRate
                fprintf('numPointsInPlot can not be smaller than the sample rate. Setting to the sample rate\n');
                obj.numPointsInPlot = obj.sampleRate;
            else
                obj.numPointsInPlot=val;
            end
        end

    end % Getters and setters


end % Close sitools.ai_recorder
