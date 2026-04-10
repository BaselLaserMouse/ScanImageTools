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
        monitor_line = 6
        on_duration = 5; % in microseconds.
        offset = 5 % -1; % in microseconds.
        scannerFrequency
        is_bidirectional
        mon_waveform
    end

    methods
        function obj = blankMonitor(src)
            obj.scannerFrequency = src.hSI.hScan2D.scannerFrequency;
            obj.is_bidirectional = src.hSI.hScan2D.bidirectional;
            % get the handle for the vDAQ device
            hResourceStore = dabs.resources.ResourceStore();
            hvDAQ = hResourceStore.filterByName(obj.daqName);
            hFpga = hvDAQ.hDevice;

            % create task
            obj.hTask = dabs.vidrio.ddi.DoTask(hFpga,'Monitor Blanking waveform');
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
            assert(2*on_timings < fullscan_timings, ...
                'on_duration too long: pulses will overlap');
            offset_samples = round(obj.offset * 1e-6 * obj.hTask.sampleRate);

            if obj.is_bidirectional
                fprintf('Bidirectional scanning now.\n')
                off_timings = round((fullscan_timings - 2*on_timings) /2);
                % [offset] | [on] | [off] | [on] | [rest] | [0]
                trailing  = offset_samples;
                leading = off_timings - offset_samples;  % absorbs the rest

                obj.mon_waveform = [ ...
                    zeros(leading, 1); 
                    ones(on_timings, 1);
                    zeros(off_timings, 1); 
                    ones(on_timings, 1);
                    zeros(trailing, 1);
                    zeros(1,1)];

                duty_cycle = 100 * 2 * on_timings / fullscan_timings;


            else % unidirectional
                fprintf('Unidirectional scanning now.\n')
                off_timings_uni = fullscan_timings - on_timings;
                leading = off_timings_uni - offset_samples;
                trailing  = offset_samples;

                obj.mon_waveform = [ ...
                    zeros(leading, 1); 
                    ones(on_timings, 1);
                    zeros(trailing, 1);
                    zeros(1,1)];

                duty_cycle = 100 * on_timings / fullscan_timings;

            end

            fprintf('on_duration: %d us, offset: %d us, off_timings: %d, duty_cycle: %.1f%%\n', obj.on_duration, obj.offset, off_timings, duty_cycle);
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