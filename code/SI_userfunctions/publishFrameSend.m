function publishFrameSend(src, evt, vargin)
    % wrapper function since scanimage only takes 
    % function name strings and not actual objects
    % set it to FrameAcquired
    persistent local_zmq;
    local_zmq = evalin("base", "hZeroMQ");
    local_zmq.send_frame(src);
end