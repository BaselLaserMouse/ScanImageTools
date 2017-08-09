classdef monitor_blanker < sitools.si_linker
    % sitools.monitor_blanker - generate monitor blanking waveform 
    %
    % Purpose
    % Generate monitor blanking waveform.
    %
    %
    %
    % Rob Campbell - Basel, 2017
    %
    % 
    % Also see:
    % https://github.com/tenss/MatlabDAQmx

    properties

        % DAQmx Task configuration
        hTask % The DAQmx digital output task handle is stored here

        devName = 'galvo' % Name of the DAQ device to which we will connect

        % Pulse timing (values in microseconds)
        initialDelay = 0
        pulseDuration1 = 5
        pulseSpacing1 = 31
        pulseDuration2 = 10
        pulseSpacing2 = 31
        endState = 1

        PMTblankLatency = 1 % This will blank the PMTs 1 ms before the monitor goes on and re-enable them 1 ms after it switches off

        % Channel parameters
        monitorBlank_DO_Line = 'port0/line1'
        PMT_Blank_DO_Line = 'port0/line2' % The opposite of the monitor blank with a latency differenc in ms

        % Trigger parameters
        triggerChannel = 'PFI0' % If we run off the board that receives the resonant line trigger
        triggerEdge = 'DAQmx_Val_Falling'

        scannerFrequency = 12E3 % We can read this from ScanImage too
        hFig % The figure/GUI handle

    end % Close properties

    properties (Hidden)
        figTagName = 'monitor_blanker' % Tag for the figure/GUI window
        hAx % Figure axis handle
        taskName = 'monitorblanker_DO1' % Name for the digital task
        waveform %The waveform we will play out of the DO
    end % Close hidden properties

    properties(Hidden,SetAccess=protected)
        sampleRate = 1E6 % Do not change this unless you know what you're doing
        clockSource = '' % clock source should be the built-in digital souce
    end


    methods

        function obj = monitor_blanker(linkToScanImage)
            % sitools.monitor_blanker
            %
            % Inputs
            % linkToScanImage - true by default. If true, we attempt to
            %             connect to ScanImage so that...

            if nargin<1
                linkToScanImage=true;
            end

            obj.connectToDAQ;
            %obj.start;
        end %constructor


        function success=connectToDAQ(obj)
            % monitor_blanker.connectToDAQ - Connect to the DAQ using the object properties
            %
            % Purpose
            % Run this method to connect to an NI DAQ device for monitor blanking using the
            % parameters described in the properties of this class. i.e.
            % devName - the name of the NI device

            % Create waveforms based on the trigger paramaters
            obj.buildWaveform;
            
            if ~isempty(obj.hTask)
                fprintf('Not connecting to NI DAQ device "%s". sitools.monitor_blanking has already connected to the DAQ\n',...
                    obj.devName)
                success=false;
                return
            end

            try
                % Create a DAQmx task
                obj.hTask = dabs.ni.daqmx.Task(obj.taskName); 


                % * Set up the digital outputs
                obj.hTask.createDOChan(obj.devName,obj.monitorBlank_DO_Line);
                obj.hTask.createDOChan(obj.devName,obj.PMT_Blank_DO_Line);

                % * Configure the sampling rate and the size of the buffer in samples using the on-board sanple clock
                %bufferSize_numSamplesPerChannel = 40*obj.sampleReadSize; % The number of samples to be stored in the buffer per channel. 
                %obj.hTask.cfgSampClkTiming(obj.sampleRate, 'DAQmx_Val_ContSamps', bufferSize_numSamplesPerChannel, 'OnboardClock');


                % Set up the sample clock at obj.sampleRate 
                obj.hTask.cfgSampClkTiming(obj.sampleRate,'DAQmx_Val_FiniteSamps',size(obj.waveform,1)*2); %,sampleClockSource);
                obj.hTask.cfgOutputBuffer(size(obj.waveform,1)*2);


                % * Define the channel on which we listen for triggers and set task as retriggerable                
                obj.hTask.cfgDigEdgeStartTrig(obj.triggerChannel,obj.triggerEdge);
                obj.hTask.set('startTrigRetriggerable',1); 

                obj.hTask.writeDigitalData(obj.waveform,[],false); % False means no auto-start

                success=true;
            catch ME
                % If the connection to the DAQ failed, display the error
                obj.reportError(ME)
                success=false;
            end
        end % connectToDAQ



        % -----------------------------------------------------------
        % Short helper methods
        function success=start(obj)
            % monitor_blanker.start - begin producing waveforms
            %
            %
            % Outputs
            % Returns true if all went well and false otherwise

            if isempty(obj.hTask)
                fprintf('No NI DAQ connected to ai_recorder\n')
                return
            end
            try
                obj.hTask.start % Task will start right away if there are no triggers configured
                success=true;
            catch ME
                obj.reportError(ME)
                success=false;
            end
        end % start

        function success=stop(obj)
            % monitor_blanker.stop - stop the monitor blanking
            %
            % Purpose
            % Calls monitor_blanker.hTask.stop which tells DAQmx to stop
            %
            % Outputs
            % Returns true if all went well and false otherwise

            if isempty(obj.hTask)
                fprintf('No NI DAQ connected to ai_recorder\n')
                return
            end
            try
                obj.hTask.stop;
                success=true;
            catch ME
                obj.reportError(ME)
                success=false;
            end
        end


        function restart(obj)
            % Use to re-start acquisition when the user changes parameters
            obj.stop;
            obj.connectToDAQ;
            obj.start;
        end

        function buildWaveform(obj,pulseDuration,offset)
            % Build a single waveform to be played out at a sample rate defined by obj.sampelRate
            maxPoints = round((1/obj.scannerFrequency)*1E6);

            if nargin>1
                  targetWaveLength = round(maxPoints)-2;
                  obj.pulseDuration1 = offset;
                  obj.pulseDuration2 = pulseDuration;
                  space = ceil((targetWaveLength - pulseDuration*2)/2);
                  obj.pulseSpacing1 = space;
                  obj.pulseSpacing2 = space;
              end



            %Build the blanking waveform
            blankWaveform = [...
                repmat(0,obj.initialDelay,1); ...
                repmat(1,obj.pulseDuration1,1); ...
                repmat(0,obj.pulseSpacing1,1); ...
                repmat(1,obj.pulseDuration2,1); ...
                repmat(0,obj.pulseSpacing2,1); ...
                obj.endState];

            if length(blankWaveform)>maxPoints
                fprintf('WAVEFORM IS LONGER THAN SCAN PERIOD! TRUNCATING TO %d \n', maxPoints)
                blankingWaveform= blankWaveform(1:maxPoints);
            else
                fprintf('New waveform is of length %d\n', length(blankWaveform))
            end


            PMTpreceed = 1;
            PMTwaveform = [...
                repmat(1,obj.initialDelay,1); ...
                repmat(0,obj.pulseDuration1+PMTpreceed,1); ...
                repmat(1,obj.pulseSpacing1-PMTpreceed-1,1); ...
                repmat(0,obj.pulseDuration2+PMTpreceed+1,1); ...
                repmat(1,obj.pulseSpacing2-PMTpreceed,1); ...
                obj.endState];

            if length(PMTwaveform) ~= length(blankWaveform)
                fprintf('PMT length=%d but blank length=%d. Setting PMT to inverse of blank.\n',...
                    length(PMTwaveform), length(blankWaveform))
                PMTwaveform = ~blankWaveform;
            end
            obj.waveform = [blankWaveform,PMTwaveform];
            %obj.waveform(:,2) = circshift(obj.waveform(:,2),1);
            plot(obj.waveform,'o-')
        end


        % Setters 
        % The following setters are to allow the waveform to be changed on the fly without
        % the user having to start and stop the task.
        % Pulse timing (values in microseconds)
        function set.initialDelay(obj,value)
            if value<0
                return
            end
            obj.initialDelay = value;
            obj.regnerateWaveforms
        end

        function set.pulseDuration1(obj,value)
            if value<0
                return
            end
            obj.pulseDuration1 = value;
            obj.regnerateWaveforms
        end

        function set.pulseSpacing1(obj,value)
            if value<0
                return
            end
            obj.pulseSpacing1 = value;
            obj.regnerateWaveforms
        end

        function set.pulseDuration2(obj,value)
            if value<0
                return
            end
            obj.pulseDuration2 = value;
            obj.regnerateWaveforms
        end

        function set.pulseSpacing2(obj,value)
            if value<0
                return
            end
            obj.pulseSpacing2 = value;
            obj.regnerateWaveforms
        end

        function set.endState(obj,value)
            if value~=0 && value~=1
                return
            end
            obj.endState = value;
            obj.regnerateWaveforms
        end

        function set.triggerEdge(obj,value)
            if strcmp(value,'DAQmx_Val_Falling') && strcmp(value,'DAQmx_Val_Rising')
                return
            end
            obj.triggerEdge = value;
            obj.stop;
            obj.hTask.cfgDigEdgeStartTrig(obj.triggerChannel,obj.triggerEdge);
            obj.start;
        end

        function set.monitorBlank_DO_Line(obj,value)
            fprintf('You need to close and start the object to change this value\n')
        end

        function set.triggerChannel(obj,value)
            obj.triggerChannel = value;
            obj.stop;
            obj.hTask.cfgDigEdgeStartTrig(obj.triggerChannel,obj.triggerEdge);
            obj.start;
        end

    end % Close methods




    methods (Hidden)

        function delete(obj)
            fprintf('sitools.monitor_blanker is shutting down\n')
            obj.stop
            delete(obj.hTask)
            cellfun(@delete,obj.listeners)
            if ~isempty(obj.hFig) && isvalid(obj.hFig)
                delete(obj.hFig) % Closes the plot window
            end
        end % destructor

        function regnerateWaveforms(obj)
            % Regenerates the blanking waveforms and sends these to the device buffer. This method
            % is used when a waveform parameter is changed in order to immediately re-set the waveforms.

            obj.stop;
            obj.buildWaveform;

            try
                % Set the buffer size
                nSamples=size(obj.waveform,1);

                % We must unreserve the DAQ device before writing to the buffer:
                % https://forums.ni.com/t5/Multifunction-DAQ/How-to-flush-output-buffer-optionally-resize-it-and-write-to-it/td-p/3138640
                obj.hTask.control('DAQmx_Val_Task_Unreserve') 

                obj.hTask.cfgSampClkTiming(obj.sampleRate, 'DAQmx_Val_FiniteSamps', nSamples);
                obj.hTask.cfgOutputBuffer(nSamples);
 
                % Write data to the start of the buffer


                % Write the waveform to the buffer
                obj.hTask.writeDigitalData(obj.waveform, [], false);

            catch ME
                obj.reportError(ME)
                obj.delete
                return
            end

            obj.start;

        end % close regnerateWaveforms

    end % Close hidden methods

end % Close sitools.ai_recorder
