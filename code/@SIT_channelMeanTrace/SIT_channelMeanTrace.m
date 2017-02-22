classdef SIT_channelMeanTrace < scanImageTool_base
% Monitor open ScanImage windows and plot a rolling average trace
% This function attaches the userFunction channelMeanTrace_uFun to ScanImage
%

	properties 
		minUpdateInterval=0.05 %The minimum time to wait in seconds between updates of the plot
		colors='rgbc'
		secondsToDisplay=5
	end

	methods
		%constructor
		function obj = SIT_channelMeanTrace

			%Define the function to inject
			uFun.EventName='frameAcquired';
			uFun.UserFcnName='channelMeanTrace_uFun';
			uFun.Arguments={obj.minUpdateInterval,obj.colors,obj.secondsToDisplay};
			obj.userFunctions = uFun;

			%Inject it
			obj.injectUserFunctions;		
		end %constructor


		function settings = returnSettings(obj)
			settings.colors = obj.colors;
			settings.minUpdateInterval = obj.minUpdateInterval;
		end %Returns the settings that will be fed to the mean plotting user functions


		%Getters and setters for the settings
		function set.colors(obj,colors)
			if obj.isAcquiring
				fprintf('Can not change user function settings during an acquisition\n')
				return 
			end
			if ~ischar(colors)
				fprintf('colors must be a character array\n')
				return
			end
			if length(colors)~=4
				fprintf('colors must be a character array of length 4\n')
				return
			end
			obj.colors=colors;
			obj.updateUserFunc
		end

		function set.secondsToDisplay(obj,secondsToDisplay)
			if obj.isAcquiring
				fprintf('Can not change user function settings during an acquisition\n')
				return 
			end
			if ~isnumeric(secondsToDisplay)
				fprintf('secondsToDisplay must be a number\n')
				return
			end
			if ~isscalar(secondsToDisplay)
				fprintf('secondsToDisplay must be a scalar\n')
				return
			end
			obj.secondsToDisplay=secondsToDisplay;
			obj.updateUserFunc
		end

		function set.minUpdateInterval(obj,minUpdateInterval)
			if obj.isAcquiring
				fprintf('Can not change user function settings during an acquisition\n')
				return 
			end
			if ~isnumeric(minUpdateInterval)
				fprintf('minUpdateInterval must be a number\n')
				return
			end
			if ~isscalar(minUpdateInterval)
				fprintf('minUpdateInterval must be a scalar\n')
				return
			end
			obj.minUpdateInterval=minUpdateInterval;
			obj.updateUserFunc
		end


	end %methods



	methods (Hidden)
		function updateUserFunc(obj)
			obj.userFunctions.Arguments={obj.minUpdateInterval,obj.colors,obj.secondsToDisplay};
			obj.injectUserFunctions;
			obj.enable
		end %updateUserFunc
	end %hidden methods


end %SIT_channelMeanTrace < handle