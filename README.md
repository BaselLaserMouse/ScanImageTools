# ScanImageTools
Useful ScanImage-related MATLAB tools.

### Contents
* `sitools.monitor_blanker` - Blank monitors during fast axis turn-around periods
* `sitools.ai_recorder` - Acquire AI data during acquisition. Can start/stop in sync with ScanImage image acquisition. Automatically saves AI waveforms when images are saved during a Grab acquisition in ScanImage. 
* UserFunctionInjector - apply user functions at the command line using the class `scanImageTool_base`. An example is provided.   
* `appendDateAndTimeToFname` - User function that adds the current date and time to the start of the file name. Updates when Grab or loop is pressed.
* `useful/CamAcqWithFrameTimes.m` - Short code snippet containing a class that records images from a camera and in the frame headers stamps the current frame from the 2p rig. 

### Functions
You can assign some functions using [ScanImage's User Function feature](https://docs.scanimage.org/Advanced+Features/User+Functions.html). This allows ScanImage to automatically start/stop the tools.

![blankMonitor_setting](https://github.com/BaselLaserMouse/ScanImageTools/blob/gallery/gallery/blankMonitor_setting.PNG)

### MFH Mods
If you want to install MFH Mods for ScanImage, you need to replace the original ScanImage files with the files found [here](\\ceph\mrsic_flogel\public\projects\SuKu_20231005_AllOpticalManipulation\2p-313\ScanImageMODs) (only available for SWC users).
* `DataRecorder MFH` - Updates ScanImage's DataRecorder to automatically use the same file name as the image file.