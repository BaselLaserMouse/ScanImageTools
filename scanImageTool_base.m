classdef scanImageTool_base < handle
% ScanImageTool_base is a class used to create ScanImage_tools
% A ScanImage tool is an object that lives in the base work space
% and is capable of injecting a defined user function into ScanImage.
% This allows easy, scriptable, modification of ScanImage's properties.
%
% Classes that interact with ScanImage should inherit this class


	properties (Hidden)
		hC %The ScanImage object is kept here
		scanImageObjectName = 'hSI'; %The name of the base worspace object that contains ScanImage
		userFunctions % A structure containing the user functions injected into ScanImage.
		              % This structure should have fields: 'EventName', 'UserFcnName', and Arguments
		              % See hSI.hUserFunctions.userFunctionsCfg
	end


	methods

		%constructor
		function obj =  scanImageTool_base 
			obj.connectToScanImage;
		end %constructor

		%destructor
		function delete(obj)
			obj.removeInjectedFunctions
		end %destructor


		function varargout = connectToScanImage(obj)
			%Connects to ScanImage by storing a reference to the ScanImage base workspace object in obj.hC
			%
			% Inputs - none
			% Outputs - optionally returns a boolean that indicates whether the connection succeeded.
	        W = evalin('base','whos');
			SIexists = ismember(obj.scanImageObjectName,{W.name});
	        if ~SIexists
	            fprintf('ScanImage not started. Can not connect to it.\n')
	            success = false;
	        else
	            obj.hC = evalin('base',obj.scanImageObjectName); % get scan image objet from the base workspace
	            success = obj.isScanImageConnected;
	        end

	        if nargout>0
	        	varargout{1}=success;
	        end
		end % connectToScanImage


		function isConnected = isScanImageConnected(obj)
			%Returns true if scanimage is connected. False otherwise
			if isempty(obj.hC)	
				isConnected=false;
			elseif isa(obj.hC,'scanimage.SI')
				isConnected = true;
			end
		end %isScanImageConnected


		function removeInjectedFunctions(obj)
			%Remove all existing user functions with the the same name as those handled by this class.
			%A bit crude...
			if ~obj.isScanImageConnected
				return
			end
			existingUserFunctions={obj.hC.hUserFunctions.userFunctionsCfg.UserFcnName};
			if isempty(existingUserFunctions)
				return
			end

			for ii=1:length(obj.userFunctions)
				thisUfn = obj.userFunctions(ii);
                ind=strmatch(existingUserFunctions, thisUfn.UserFcnName);

                if ~isempty(ind) %Remove the userfunction of that name
					obj.hC.hUserFunctions.userFunctionsCfg(ind)=[];
					existingUserFunctions={obj.hC.hUserFunctions.userFunctionsCfg.UserFcnName};					
				end
			end
		end %removeInjectedFunctions


		function enable(obj)
			%Enable all user functions injected by this class
			obj.toggleInjectedUserFunctions(true);
		end %enable


		function disable(obj)
			%Disable all user functions injected by this class
			obj.toggleInjectedUserFunctions(true);
		end %disable

	end %methods


	methods (Hidden)
		function injectUserFunctions(obj)
			% Injects the user functions defined by the hidden property, userFunctions
			% Does not enable them
			if ~obj.isScanImageConnected
				return
			end

			if ~isstruct(obj.userFunctions)
				fprintf('Method injectUserFunctions failed to insert any user functions into ScanImage. None are defined\n')
				return
			end

            obj.removeInjectedFunctions;
			for ii=1:length(obj.userFunctions)
				%Add the user function
				thisFunc.EventName   = obj.userFunctions(ii).EventName;
				thisFunc.UserFcnName = obj.userFunctions(ii).UserFcnName;
				thisFunc.Arguments   = obj.userFunctions(ii).Arguments;
				thisFunc.Enable      = false;

				obj.hC.hUserFunctions.userFunctionsCfg(end+1) = thisFunc;
			end

		end %userFunctions		


		function toggleInjectedUserFunctions(obj,toggleState)
			%Disable all user functions injected by this class
			if ~obj.isScanImageConnected
				return
			end

			existingUserFunctions={obj.hC.hUserFunctions.userFunctionsCfg.UserFcnName};
			for ii=1:length(obj.userFunctions)
				thisUfn = obj.userFunctions(ii);
                ind=strmatch(existingUserFunctions, thisUfn.UserFcnName);

                if ~isempty(ind) %Remove the userfunction of that name
					obj.hC.hUserFunctions.userFunctionsCfg(ind).Enable=toggleState;
				end
			end
		end %disable


        function acquiring = isAcquiring(obj)
            %Returns true if ScanImage is acquiring data
            acquiring=obj.hC.active;
        end %isAcquiring


	end %hidden methods


end % scanImageTool_base