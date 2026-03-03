function shutDownZeroMQ(src, evt, vargin)
    if evalin('base','exist("hZeroMQ","var")')

        evalin('base','hZeroMQ.delete();');  % close socket + context
        evalin('base','clear hZeroMQ');        % remove variable

        disp('hZeroMQ closed and cleared from base workspace.');

    else
        disp('hZeroMQ not found in base workspace.');
    end
end