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
    obj.hFig.CloseRequestFcn = @obj.windowCloseFcn;


    % Clear the plot and build the axes and plot objects
    obj.createPlotAxes;

end % openFigureWindow
