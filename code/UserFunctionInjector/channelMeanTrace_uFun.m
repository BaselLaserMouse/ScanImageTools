function channelMeanTrace_uFun(src,event,varargin)
	% Creates a rolling plot of the mean intensity in each open ScanImage channel
	% This is a user-function. It can be inserted manually into ScanImage or via the
	% channelMeanTrace object.
	%
	% function channelMeanTrace_uFun(src,event, minUpdateInterval, colors, secondsToDisplay)
	%
	% Inputs
	% minUpdateInterval - the minimum time in seconds between plot updates
	% colors - a character array of length 4 that defines the channel colors
	% secondsToDisplay - how many seconds worth of data to display on the screen
	%
	%
	% 

	%Pull data out of varargin. No need for anything fancy, we know what the inputs must be
	minUpdateInterval=varargin{1};
	channelColors=varargin{2};
	secondsToDisplay=varargin{3};

	maxChannels=4;

	hSI = src.hSI; % get the handle to the ScanImage object (the API or model, depending on how you wish to call it)
 	framPeriod = hSI.hRoiManager.scanFramePeriod; %frame period in seconds
	numDataPoints=round(secondsToDisplay/framPeriod); %max number of data points


	%Set up the figure for the first time if it does not currently exist
	figureTag  = 'meanTraceFig';
	axTag  = 'meanTraceAx';
	axH = findobj('Tag',axTag);

	if isempty(axH)
		figH = figure('Tag',figureTag);
		figure(figH);
		plotData=nan(numDataPoints,maxChannels);
		pH = plot(plotData);
		axH = gca;
		axH.Tag = axTag;

		data.pointsPlotted=1; %Store the number of points plotted to date in the userdata
		data.lastUpdate=now; %Time of last plot update
		for ii=1:length(channelColors)
			data.plotData{ii}=plotData(:,ii);
		end
		figH.UserData=data; 
		grid on
		set(figH,'Name','Mean traces')		
	else
		figH = findobj('Tag',figureTag);
		pH = axH.Children;
    end

    tH = title('','Parent',axH);

	% scanimage stores image data in a data structure called 'stripeData'
    lastStripe = hSI.hDisplay.stripeDataBuffer{hSI.hDisplay.stripeDataBufferPointer}; % get the pointer to the last acquired stripeData
    channels =  lastStripe.channelNumbers;


    %Extract means and store in figure's UserData
	timeSinceLastUpdate = (now-figH.UserData.lastUpdate)*24*60^2;
    meansToDisplay=nan(1,length(channelColors));
    for ii = 1:length(channelColors) 
    	if ~any(channels==ii) %then it's not being recorded
    		mu=nan;
   		else
   			f=find(channels==ii);
			imData=lastStripe.roiData{1}.imageData{f}{1}; 
			mu=mean(imData(:));
			meansToDisplay(ii)=mu;
    	end

		if figH.UserData.pointsPlotted<numDataPoints
			figH.UserData.plotData{ii}(figH.UserData.pointsPlotted)=mu;
		else %start scrolling once all data points have been filled
			figH.UserData.plotData{ii}(end+1)=mu;
			figH.UserData.plotData{ii}(1)=[];
		end

    end


	%Restrict the rate of plot update. 
	if (now-figH.UserData.lastUpdate)*24*60^2 > minUpdateInterval
		titleStr='';
		for ii=1:4
			pH(ii).YData = figH.UserData.plotData{ii};
			pH(ii).Color = channelColors(ii);
			if ~isnan(meansToDisplay(ii))
				titleStr = [titleStr,sprintf('CH%d=%0.2f ',ii,meansToDisplay(ii))];
			end
		end
    	figH.UserData.lastUpdate=now;
    	tH.String = titleStr;
    	drawnow
    end


    if figH.UserData.pointsPlotted<numDataPoints
	    figH.UserData.pointsPlotted = figH.UserData.pointsPlotted+1;
	end


end