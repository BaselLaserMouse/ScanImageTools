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
        hTaskDO % The DAQmx digital output task handle is stored here

        devName = 'aux' % Name of the DAQ device to which we will connect

        % Pulse timing (values in microseconds)
        initialDelay = 0
        pulseDuration1 = 2
        pulseSpacing1 = 31
        pulseDuration2 = 10
        pulseSpacing2 = 31
        endState = 1

        % Channel parameters
        outputLine = 'port0/line1'

        % Trigger parameters
        clockInput = 'PFI15'
        triggerEdge = 'falling'


        hFig % The figure/GUI handle

    end % Close properties

    properties (Hidden)
        figTagName = 'monitor_blanker' % Tag for the figure/GUI window
        hAx % Figure axis handle
        DO_taskName = 'monitorblanker_DO' % Name for the digital task
        waveform %The waveform we will play out of the DO
    end % Close hidden properties

    properties(Hidden,SetAccess=Protected)
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

            obj.buildWaveform;
            obj.connectToDAQ;
            obj.start;
        end %constructor


        function success=connectToDAQ(obj)
            % monitor_blanker.connectToDAQ - Connect to the DAQ using the object properties
            %
            % Purpose
            % Run this method to connect to an NI DAQ device for monitor blanking using the
            % parameters described in the properties of this class. i.e.
            % devName - the name of the NI device

            if ~isempty(obj.hTask)
                fprintf('Not connecting to NI DAQ device "%s". sitools.monitor_blanking has already connected to the DAQ\n',...
                    obj.devName)
                success=false;
                return
            end

            try
                % Create a DAQmx task
                obj.hTask = dabs.ni.daqmx.Task(obj.taskName); 


                % * Set up a digital output
                obj.hTask.createDOChan(obj.devName,obj.outputLine);


                % * Configure the sampling rate and the size of the buffer in samples using the on-board sanple clock
                %bufferSize_numSamplesPerChannel = 40*obj.sampleReadSize; % The number of samples to be stored in the buffer per channel. 
                %obj.hTask.cfgSampClkTiming(obj.sampleRate, 'DAQmx_Val_ContSamps', bufferSize_numSamplesPerChannel, 'OnboardClock');


                % Set up the sample clock at obj.sampleRate 
                obj.hTask.cfgSampClkTiming(obj.sampleRate,'DAQmx_Val_FiniteSamps',length(obj.waveform) ); %,sampleClockSource);
                obj.hTask.cfgOutputBuffer(length(obj.waveform));

                % Create waveforms based on the trigger paramaters

                % make it re-triggerable, finite samples trigger source,
                
                % * Define the channel on which we listen for triggers and set task as retriggerable                
                obj.hTask.cfgDigEdgeStartTrig(triggerChannel,'DAQmx_Val_Rising');
                obj.hTask.set('startTrigRetriggerable',1); 

                obj.hTask.writeDigitalData(obj.waveform)


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
            obj.buildWaveform;
            obj.connectToDAQ;
            obj.start;
        end

        function buildWaveform(obj)
            % Build a single waveform to be played out at a sample rate defined by obj.sampelRate
            obj.waveform = [...
                repmat(0,1,obj.initialDelay), ...
                repmat(1,1,obj.pulseDuration1), ...
                repmat(0,1,obj.pulseSpacing1), ...
                repmat(1,1,obj.pulseDuration2), ...
                repmat(0,1,obj.pulseSpacing2), ...
                obj.endState];
            ]
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
            obj.restart
        end

        function set.pulseDuration1(obj,value)
            if value<0
                return
            end
            obj.pulseDuration1 = value;
            obj.restart
        end

        function set.pulseSpacing1(obj,value)
            if value<0
                return
            end
            obj.pulseSpacing1 = value;
            obj.restart
        end

        function set.pulseDuration2(obj,value)
            if value<0
                return
            end
            obj.pulseDuration2 = value;
            obj.restart
        end

        function set.pulseSpacing2(obj,value)
            if value<0
                return
            end
            obj.pulseSpacing2 = value;
            obj.restart
        end

        function set.endState(obj,value)
            if value~=0 && value~=1
                return
            end
            obj.endState = value;
            obj.restart
        end

        function set.triggerEdge(obj,value)
            if strcmp(value,'falling') && strcmp(value,'rising')
                return
            end
            obj.triggerEdge = value;
            obj.restart
        end

        function set.outputLine(obj,value)
            obj.outputLine = value;
            obj.restart
        end

        function set.clockInput(obj,value)
            obj.clockInput = value;
            obj.restart
        end

    end % Close methods




    methods (Hidden)

        function delete(obj)
            fprintf('sitools.monitor_blanker is shutting down\n')
            obj.stop
            delete(obj.hTask)
            cellfun(@delete,obj.listeners)
            if isempty(obj.hFig) && isvalid(obj.hFig)
                delete(obj.hFig) % Closes the plot window
            end
        end % destructor

    end % Close hidden methods

end % Close sitools.ai_recorder
