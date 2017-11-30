function data = readAIrecoderBinFile(fname)
% Read bin file produced by the AI recorder
%
% function data = readAIrecoderBinFile(fname)
%
% Inputs
% fname - relative or absolute path to bin file
%
% Outputs
% data - structure containing the data
%
% Example
% d = readAIrecorderBinFile('myData.bin')
% plot(d.data)
%
%
% Rob Campbell - Basel 2017

if ~exist(fname,'file')
    fprintf('Can not find file %s\n', fname)
    data=[];
    return
end


[pathTofile, fileNameMinusExt, ext] = fileparts(fname);

% Load the meta-data file
metaFname = fullfile(pathTofile,[fileNameMinusExt,'_meta.mat']);
if ~exist(metaFname,'file')
    fprintf('Can not find meta data file at %s. Returning data as a single vector of 16 bit ints\n' , metaFname);
    %Read in all data
    fid = fopen(fname,'r');
    rawData = fread(fid,inf,'int16');
    fclose(fid);
    data.data = rawData;
    return
end


load(metaFname)

%Read in all data
fid = fopen(fname,'r');
rawData = fread(fid,inf,metaData.dataType);
fclose(fid);


metaData.data = reshape(rawData, length(metaData.AI_channels),[]).';

data=metaData;


