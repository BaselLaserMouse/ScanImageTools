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

    metaData.devName = obj.devName;
    metaData.fname = obj.fname;
    metaData.dataType = obj.dataType;
    metaData.AI_channels = obj.AI_channels;
    metaData.voltageRange = obj.voltageRange;
    metaData.sampleRate = obj.sampleRate;
    metaData.chanNames = obj.chanNames;
    metaData.overlayTraces = obj.overlayTraces;
    metaData.numPointsInPlot = obj.numPointsInPlot;
    metaData.yMax = obj.yMax;
    metaData.yMin = obj.yMin;

    save(fname,'metaData')

end % saveCurrentSettings
