classdef blankMonitor < handle
    % This is ScanImage user class.
    % monitor_blanker 2.0 for vDAQ RGG system.
    % This class generates waveform and triggers it using ScanImage's Beam-Modified Line Clock 
    % https://docs.scanimage.org/Concepts/Triggers/Exported+Clocks.html
    % 
    % Inspired and heavily adapted from
    % si_tools.monitor_blanker by Rob Campbell 
    % https://github.com/BaselLaserMouse/ScanImageTools/blob/master/code/%2Bsitools/monitor_blanker.m
    % microscope-control/monitor_blanker by Petr Znamenskiy
    % https://github.com/znamlab/microscope-control/blob/master/src/monitor-blanking/monitor_blanker.m

    properties (Hidden, SetAccess=protected)
        daqName = 'vDAQ0'
        hTask
    end
    
    properties
        monitor_port = 1
        monitor_line = 7
        on_duration = 15; % in microseconds
        scannerFrequency
        is_bidirectional
        mon_waveform
    end

    methods
        function obj = blankMonitor(src)
            obj.scannerFrequency = src.hSI.hScan2D.scannerFrequency;
            obj.is_bidirectional = src.hSI.hScan2D.beamClockExtend  ;
            % get the handle for the vDAQ device
            hResourceStore = dabs.resources.ResourceStore();
            hvDAQ = hResourceStore.filterByName(obj.daqName);
            hFpga = hvDAQ.hDevice;

            % create task
            obj.hTask = dabs.vidrio.ddi.DoTask(hFpga,'Blanking waveform');
            mon_ch = sprintf('D%d.%d', obj.monitor_port, obj.monitor_line);
            obj.hTask.addChannel(mon_ch);
            obj.hTask.sampleRate = obj.hTask.maxSampleRate;

            % setup trigger            
            obj.hTask.cfgDigEdgeStartTrig(...
                src.hSI.hScan2D.trigBeamClkOutInternalTerm);
            obj.hTask.allowRetrigger = true;
            obj.hTask.sampleMode = 'finite';
            obj.hTask.triggerOnStart = 1;    
            
            % setup waveform
            obj.make_waveform()
        end
        
        function make_waveform(obj)        
            % convert from microseconds to samples
            on_timings = round(obj.on_duration * 1e-6 * obj.hTask.sampleRate);
            fullscan_timings = round((1/obj.scannerFrequency) * obj.hTask.sampleRate);
            off_timings = round((fullscan_timings - 2*on_timings) /2);
            
            if obj.is_bidirectional
                obj.mon_waveform = [ ...
                   zeros(off_timings, 1); 
                   ones(on_timings-10, 1);
                   zeros(1,1);];  % to keep it zero (healthy for the monitor)
            else % unidirectional
                  obj.mon_waveform = [ ...
                   zeros(off_timings, 1); 
                   ones(on_timings, 1);
                   zeros(off_timings, 1); 
                   ones(on_timings-10, 1);
                   zeros(1,1);];  % to keep it zero (healthy for the monitor)              
            end
                       
            obj.hTask.writeOutputBuffer(obj.mon_waveform);
            obj.hTask.samplesPerTrigger = size(obj.mon_waveform, 1);
        end
        
        function set.on_duration(obj, value)
            % update waveform and restart task
            if value>=0
                obj.on_duration = value;
                obj.make_waveform()
            else
                fprintf('Waveform timings must be a positive number (in usec).\n')
            end
        end
            
        function start(obj, msg)
            try
                obj.hTask.start();
                if msg
                    fprintf('Monitor blanker has started\n')
                end
            catch ME
                error('Failed to start task')
            end
        end
        
        function stop(obj)
            try
                obj.hTask.stop();
            catch ME
                error('Failed to stop task')
            end
        end
        
        function delete(obj)
            fprintf('Monitor blanker is shutting down...')
            obj.start(false) % to ensure zero signals to the monitor (healthy for the monitor)
            obj.stop()
            obj.hTask.delete();
            fprintf('done\n')
        end
    end
end