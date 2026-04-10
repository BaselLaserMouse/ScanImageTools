function copyMROIFile(src, ~, varargin)
% copyMROIFile  Copy the active MROI definition file to the current SI save directory.
%
% Wire as a ScanImage user function on event: acqModeStart
% Arguments box: path to the folder where .roi files are stored (optional)
% Does nothing if MROI mode is off.

    hSI = src.hSI;

    % Silently skip if not in MROI mode
    if ~hSI.hRoiManager.mroiEnable
        fprintf('[copyMROIFile] MROI disabled - skipping.\n')
        return
    end

    % --- Locate the .roi file ---
    mroi_name = hSI.hRoiManager.roiGroupMroi.name;
    roi_filename = [mroi_name, '.roi'];

    if nargin > 2 && ~isempty(varargin{1})
        roiFolder = varargin{1};
        mroi_src = fullfile(roiFolder, roi_filename);
    else
        mroi_src = roi_filename; % fall back to current directory
    end

    if ~isfile(mroi_src)
        fprintf('[copyMROIFile] Could not locate %s. Skipping.\n', mroi_src)
        return
    end

    % --- Determine destination ---
    destDir = hSI.hScan2D.logFilePath;

    if ~exist(destDir, 'dir')
        fprintf('[copyMROIFile] Save directory does not exist: %s. Skipping.\n', destDir)
        return
    end

    % Use the same stem as the current acquisition
    dest = fullfile(destDir, sprintf('%s_%00001.roi', hSI.hScan2D.logFileStem));
    % --- Copy and update filesystem timestamp ---
    try
        copyfile(mroi_src, dest);
        fprintf('[copyMROIFile] Copied: %s\n  -> %s\n', mroi_src, dest)
    catch ME
        fprintf('[copyMROIFile] Failed to copy MROI file: %s\n', ME.message)
    end

end