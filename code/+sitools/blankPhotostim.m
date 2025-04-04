classdef blankPhotostim < handle
    % This is ScanImage user class.
    % Blanker for photostimulation for vDAQ RGG system.
    % This class generates waveform and triggers it using ScanImage's Beam-Modified Line Clock 
    % https://docs.scanimage.org/Concepts/Triggers/Exported+Clocks.html
    % 
    % You also need to build an electronics that accepts two BNC inputs. One of them is analog/digital input that 
    % gates photostimulation laser or LED. Another input is enable/disable signal and you should pass the blankPhotostim
    % to this input. TTL low is ENABLE and high is DISABLE.
  
    properties (Hidden, SetAccess=protected)
        daqName = 'vDAQ0'
        hTask
    end
    
    properties
        monitor_port = 1
        monitor_line = 5
        on_duration =12; % int £ in microseconds
        offset = 30; % for Lenovo
        scannerFrequency
        is_bidirectional
        mon_waveform
    end

    methods
        function obj = blankPhotostim(src)
            obj.scannerFrequency = src.hSI.hScan2D.scannerFrequency;
            obj.is_bidirectional = src.hSI.hScan2D.bidirectional;
            % get the handle for the vDAQ device
            hResourceStore = dabs.resources.ResourceStore();
            hvDAQ = hResourceStore.filterByName(obj.daqName);
            hFpga = hvDAQ.hDevice;

            % create task
            obj.hTask = dabs.vidrio.ddi.DoTask(hFpga,'Photostim Blanking waveform');
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
            obj.make_waveform(false)
        end
        
        function make_waveform(obj, last)        
            % convert from microseconds to samples
            on_timings = round(obj.on_duration * 1e-6 * obj.hTask.sampleRate);
            fullscan_timings = round((1/obj.scannerFrequency) * obj.hTask.sampleRate);
            off_timings = round((fullscan_timings - 2*on_timings) /2);
            
            if last % just output low TTL (0V)  
                obj.mon_waveform = [zeros(1,1)];
            else
                if obj.is_bidirectional
                    disp('Bidirectional scanning now!');
                    obj.mon_waveform = [ ...
                    ones(off_timings, 1); 
                    zeros(on_timings-obj.offset, 1);
                    ones(1,1);];

                else % unidirectional
                    disp('Unidirectional scanning now!');
                    obj.mon_waveform = [ ...
                    ones(off_timings, 1); 
                    zeros(on_timings-obj.offset, 1);
                    ones(obj.offset+off_timings, 1); 
                    zeros(on_timings-obj.offset, 1);
                    ones(1,1);];          
                end
            end
            
            obj.hTask.writeOutputBuffer(obj.mon_waveform);
            obj.hTask.samplesPerTrigger = size(obj.mon_waveform, 1);
        end
        
        function set.on_duration(obj, value)
            % update waveform and restart task
            if value>=0
                obj.on_duration = value;
                obj.make_waveform(false)
            else
                fprintf('Waveform timings must be a positive number (in usec).\n')
            end
        end
            
        function start(obj, msg)
            try
                obj.hTask.start();
                if msg
                    fprintf('Photostimulation blanker has started\n')
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
            fprintf('Photostimulation blanker is shutting down...')
            obj.make_waveform(true) % to ensure zero signals to the monitor (healthy for the circuit)
            obj.start(false)
            obj.stop()
            obj.hTask.delete();
            fprintf('done\n')
        end
    end
end