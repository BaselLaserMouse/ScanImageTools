# ScanImageTools
Useful ScanImage-related MATLAB tools.

### Contents
* `sitools.monitor_blanker` - Blank monitors during fast axis turn-around periods
* `sitools.ai_recorder` - Acquire AI data during acquisition. Can start/stop in sync with ScanImage image acquisition. Automatically saves AI waveforms when images are saved during a Grab acquisition in ScanImage. 
* UserFunctionInjector - apply user functions at the command line using the class `scanImageTool_base`. An example is provided.   
* `appendDateAndTimeToFname` - User function that adds the current date and time to the start of the file name. Updates when Grab or loop is pressed.
* `useful/CamAcqWithFrameTimes.m` - Short code snippet containing a class that records images from a camera and in the frame headers stamps the current frame from the 2p rig. 