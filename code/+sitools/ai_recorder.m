classdef ai_recorder < sitools.si_linker
    % sitools.ai_recorder - acquire data from analog input channels and sync some operations with ScanImage
    %
    % Purpose
    % Connect to a defined set of analog input channels on a defined NI
    % DAQ and acquire data at at a defined sample rate. Data are streamed
    % to a plot window. If ScanImage is started, data acquisition can be
    % configured to start when "Focus" or "Grab" are pressed. In addition,
    % if data are being saved in Grab mode a binary log file containing
    % the acquired data is automatically saved in the same directory with
    % a similar file name to the ScanImage TIFF. 
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
    %
    %
    % Problems?
    % If you see "ERROR: A Task with name 'airecorder' already exists in
    % the DAQmx System" then check for existing instances of this class
    % and delete them (e.g. delete(myAIrec) ). If there are no instances
    % then there is an orphan task. You will either need to change the
    % "taskName" property to a different string or restart MATLAB. 
    %
    %
    % Rob Campbell - Basel, 2017
    %
    % 
    % Also see:
    % https://github.com/tenss/MatlabDAQmx

    properties (SetAccess=protected, Hidden=false)

        % DAQmx Task configuration (these values are read on startup only)
        % CAUTION: Do not edit these values here for your experiment. Change 
        %          the properties in the live object and use the saveCurrentSettings
        %          and loadCurrentSettingsMethods

        hTask % The DAQmx task handle is stored here
        devName = 'Dev1' % Name of the DAQ device to which we will connect
        AI_channels = 0:3 % Analog input channels from which to acquire data. e.g. 0:3
        voltageRange = 5  % Scalar defining the range over which data will be digitized
        sampleRate = 1E3  % Analog input sample Rate in Hz
        sampleReadSize = 500  % Read off this many samples then plot and log to disk
        dataType = 'int16' % The format we will write the data in to binary file ai_recorder.fname
    end 

    properties
        % Saving and data configuration
        fname = ''      % File name for logging data to disk as binary using type ai_recoder.dataType
        hFig % The figure/GUI handle
    end 

    properties (SetObservable)
        yMax % This is a vector of ylim values. The first subplot will have a max range of obj.yMax(1);
             % By default obj.yMax = repmat(obj.voltageRange,1,length(obj.AI_channels)). However, you can
             % modify it and save/reload values from a settings file. 
        yMin % Same as yMax but for the minimum y value. By default this is 
             % repmat(-obj.voltageRange,1,length(obj.AI_channels))
        chanNames = {}; % Cell array describing the channes. e.g. {'valve', 'trigger', 'frame_clock'}. 
                        % Auto-generated if left blank
    end


    properties (Hidden)
        figTagName = 'ai_recorder' % Tag for the figure/GUI window
        taskName = 'airecorder' % Name for the task
        subplots % Cell array of handles for the subplots (one per input channel)
        pltData % Cell array of plot objects (one per subplot)
        titles %plot titles
        fid = -1  % File handle to which we will write data
        data      % We hold data to be plotted here
        numPointsInPlot=5E3 % The plot will scroll with a maximum of this many points
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
                obj.connectToDAQ;
                if obj.linkToScanImageAPI
                    obj.listeners{length(obj.listeners)+1} = addlistener(obj.hSI,'acqState', 'PostSet', @obj.startWhenNotIdle);
                end
                obj.listeners{length(obj.listeners)+1} = addlistener(obj, 'yMax', 'PostSet', @obj.setPlotLimits);
                obj.listeners{length(obj.listeners)+1} = addlistener(obj, 'yMin', 'PostSet', @obj.setPlotLimits);
                obj.listeners{length(obj.listeners)+1} = addlistener(obj, 'chanNames', 'PostSet', @obj.setPlotTitlesFromChanNames);                
            end


        end %constructor


        function varargout=connectToDAQ(obj)
            % ai_recorder.connectToDAQ - Connect to the DAQ using the object properties
            %
            % Purpose
            % Run this method to connect to an NI DAQ device for analog
            % input using the parameters described in the properties of
            % this class. i.e.
            % devName - the name of the NI device
            % AI_channels - vector channel numbers
            % voltageRange - scalar defining the digitization range
            % sampleRate - number of samples per second to acquire
            % sampleReadSize - the number of samples to read before pulling
            %                  data off the DAQ for plotting or saving to disk
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

        function saveCurrentSettings(obj,fname)
            % ai_recorder.saveCurrentSettings(fname) - save settings file
            %
            % Purpose
            % Writes the current DAQ settings to a MATLAB structure.
            % This method is used to create the "meta" file saved
            % along with the .bin file. It's also used to save settings
            % so that they can be re-applied later using the method
            % ai_recorder.loadSettings
            %
            % The created file will contains the fields: fname, dataType,
            % channels, voltageRange, sampleRate, chanNames.
            %
            %
            % Inputs
            % fname - Relative or absolute path to the .mat file we will
            %         save data to. Existing files of the same name will be
            %         over-written without warning.
            %
            % Example
            % obj.saveCurrentSettings('myFileName')

            metaData.fname = obj.fname;
            metaData.dataType = obj.dataType;
            metaData.AI_channels = obj.AI_channels;
            metaData.voltageRange = obj.voltageRange;
            metaData.sampleRate = obj.sampleRate;
            metaData.chanNames = obj.chanNames;
            metaData.yMax = obj.yMax;
            metaData.yMin = obj.yMin;

            save(fname,'metaData')

        end % saveCurrentSettings

        function loadSettings(obj,fname)
            % ai_recorder.loadSettings(fname) - load settings file
            %
            % Purpose
            % Load DAQ settings and replace existing property values
            % with those from the loaded structur. This is used to save
            % values as a preference file so they can be quickly
            % re-applied. Use ai_recoder.saveCurrentSettings to create the
            % file. 
            %
            % The following fields will be replaced: dataType,
            % AI_channels, voltageRange, sampleRate, chanNames.
            %
            %
            % Inputs
            % fname - Relative or absolute path to the .mat file we will
            %         load data from. The file should contain a structure
            %         called "metaData" with the fields listed above.
            %         "fname" may also be a valid structure
            % 
            % Examples:
            % >> AI.loadSettings('hello_meta.mat')
            %   All settings updated
            % >> load('hello_meta.mat')
            % >> AI.loadSettings(metaData)
            %   All settings updated
            %

            if ischar(fname)
                load(fname)
                if ~exist('metaData','var')
                    fprintf('No variable "metaData" found in file %s\n', fname)
                    return
                end
            elseif isstruct(fname)
                metaData = fname;
            else
                fprintf('ai_recorder.loadSettings - Input variable should be a string or a struct\n')
                return
            end


            fieldsToApply = {'dataType', 'AI_channels', 'voltageRange', 'sampleRate', 'chanNames','yMax'};
            n=0;

            for ii=1:length(fieldsToApply)
                if ~isfield(metaData,fieldsToApply{ii})
                    fprintf('No field "%s" found in loaded structure. Skipping!\n', fieldsToApply{ii})
                    continue
                end
                obj.(fieldsToApply{ii}) = metaData.(fieldsToApply{ii});
                n=n+1;
            end

            if n==length(fieldsToApply)
                fprintf('All settings updated\n')
            end

        end % loadSettings

        function openFigureWindow(obj)
            % ai_recorder.openFigureWindow - open figure window for data display.
            %
            % Purpose
            % Open a figure window and configure it so that the recorder is
            % shutdown and acquisition stopped when the window is closed.
            % The figure window is only opened if doesn't already exist.
            % The y-axis limits are read from the two properties (yMin and yMax)
            % and applied. They can also be applied on the fly.
            obj.hFig = findobj(0, 'Tag', obj.figTagName);
            if isempty(obj.hFig)
                %If the figure does not exist, make it
                obj.hFig = figure;
                set(obj.hFig, 'Tag', obj.figTagName, 'Name', 'ScanImage AI Recorder')                
            end


            %Focus on the figure and clear it
            figure(obj.hFig)
            clf

            %Make the subplots
            if isempty(obj.yMax)
                obj.yMax = repmat(obj.voltageRange,1,length(obj.AI_channels));
            end
            if isempty(obj.yMin)
                obj.yMin = repmat(-obj.voltageRange,1,length(obj.AI_channels));
            end

            n=obj.numSubPlots(length(obj.AI_channels));
            for ii=1:length(obj.AI_channels)                
                obj.subplots{ii} = subplot(n(1),n(2),ii);
                obj.pltData{ii}  = plot(zeros(100,1));
                obj.titles{ii} = title(''); %create the handle
                grid on
            end

            obj.setPlotLimits;
            obj.setPlotTitlesFromChanNames;
            obj.hFig.CloseRequestFcn = @obj.windowCloseFcn;
        end % openFigureWindow

    end % Close methods




    methods (Hidden)

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
                        if ~isempty(obj.subplots{ii}) && isvalid(obj.subplots{ii})
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
        end % startWhenNotIdle


        function [p,n]=numSubPlots(~,n)
            % function [p,n]=numSubPlots(n)
            %
            % Purpose
            % Calculate how many rows and columns of sub-plots are needed to
            % neatly display n subplots. 
            %
            % Inputs
            % n - the desired number of subplots.     
            %  
            % Outputs
            % p - a vector length 2 defining the number of rows and number of
            %     columns required to show n plots.     
            % [ n - the current number of subplots. This output is used only by
            %       this function for a recursive call.]
            %
            %
            %
            % Example: neatly lay out 13 sub-plots
            % >> p=numSubPlots(13)
            % p = 
            %     3   5
            % for i=1:13; subplot(p(1),p(2),i), pcolor(rand(10)), end 
                 
            while isprime(n) & n>4, 
                n=n+1;
            end

            p=factor(n);

            if length(p)==1
                p=[1,p];
                return
            end

            while length(p)>2
                if length(p)>=4
                    p(1)=p(1)*p(end-1);
                    p(2)=p(2)*p(end);
                    p(end-1:end)=[];
                else
                    p(1)=p(1)*p(2);
                    p(2)=[];
                end    
                p=sort(p);
            end


            %Reformat if the column/row ratio is too large: we want a roughly
            %square design 
            while p(2)/p(1)>2.5
                N=n+1;
                [p,n]=obj.numSubPlots(N); %Recursive!
            end

        end %numSubPlots

        function setPlotLimits(obj,~,~)
            % This listener callback runs whenever the user changes a desired plot limit.
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

        function setPlotTitlesFromChanNames(obj,~,~)
            for ii=1:length(obj.subplots)
                if length(obj.chanNames)>=ii && ~isempty(obj.chanNames{ii})
                    obj.titles{ii}.String = obj.chanNames{ii};
                else
                    obj.titles{ii}.String = sprintf('AI %d', obj.AI_channels(ii));
                end
            end
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
