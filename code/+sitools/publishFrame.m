classdef publishFrame < handle
    properties
        jar_path
        monitor_port = 1
    end

    properties (SetAccess = private)
        context
        socket
        address string = "tcp://*:65179" % Change here
    end

    methods
        function obj = publishFrame(src)
            % address: e.g. "tcp://*:65179" (publisher binds)
            % subscribers connect to "tcp://<host>:65179"
            % https://docs.scanimage.org/Premium+Features/ZeroMQ.html

            obj.jar_path = fullfile(erase(mfilename("fullpath"), mfilename), "/jeromq-0.6.0.jar");
            if ~any(strcmpi(javaclasspath('-dynamic'), obj.jar_path)) && ~any(strcmpi(javaclasspath, obj.jar_path))
                javaaddpath(obj.jar_path);
            end
            import org.zeromq.*

            obj.context = ZContext();
            obj.socket  = obj.context.createSocket(SocketType.PUB);
            obj.socket.bind(char(obj.address));

            disp("ScanImage PUB bound: " + string(obj.address));
        end

        function send_frame(obj, src)
            % Publish one ScanImage-format message:
            %   multipart: [40-byte header][payload]
            %

            % Get latest stripe/frame from ScanImage display buffer
            last_stripe = src.hSI.hDisplay.stripeDataBuffer{src.hSI.hDisplay.stripeDataBufferPointer};

            % ---- Collect per-channel images ----
            nCh = length(last_stripe.roiData{1}.channels);

            % Use channel 1 to define geometry
            img1 = last_stripe.roiData{1}.imageData{1}{1};
            if ~isa(img1, 'int16')
                img1 = int16(img1);
            end

            % ScanImage payload order is (x, y, c); MATLAB image is usually (y, x)
            % So: permute (y,x) -> (x,y)
            payload_ch = cell(1, nCh);
            payload_ch{1} = permute(img1, [2 1]);

            for k = 2:nCh
                im = last_stripe.roiData{1}.imageData{k}{1};
                if ~isa(im, 'int16')
                    im = int16(im);
                end
                payload_ch{k} = permute(im, [2 1]);
            end

            pixelsPerLine = double(size(payload_ch{1}, 1)); % x
            linesPerFrame = double(size(payload_ch{1}, 2)); % y
            numChannels   = double(nCh);

            % ---- Build header (5 doubles = 40 bytes) ----
            % Header fields per ScanImage docs: pixelsPerLine, linesPerFrame,
            % numChannels, timestamp, frameNumber. :contentReference[oaicite:1]{index=1}
            timestamp = double(posixtime(datetime('now','TimeZone','UTC')));
            frameNumber = double(last_stripe.frameNumberAcq);

            headerVals  = double([pixelsPerLine, linesPerFrame, numChannels, timestamp, frameNumber]);
            headerBytes = typecast(headerVals, 'uint8');  % 40 bytes on little-endian machines

            % ---- Build payload int16 vector in (x, y, c) with x fastest ----
            % Stack channels into one int16 vector: [ch1(:); ch2(:); ...]
            payloadInt16 = zeros(pixelsPerLine * linesPerFrame * nCh, 1, 'int16');
            ofs = 0;
            for k = 1:nCh
                v = payload_ch{k}(:); % x fastest due to MATLAB column-major with x as first dim
                payloadInt16(ofs + (1:numel(v))) = v;
                ofs = ofs + numel(v);
            end

            % Ensure little-endian bytes on all machines
            if ~isequal(typecast(uint16(1),'uint8'), uint8([1 0]))
                payloadInt16 = swapbytes(payloadInt16);
            end
            payloadBytes = typecast(payloadInt16, 'uint8');

            % ---- Send multipart: [header][payload] ----
            obj.socket.sendMore(headerBytes);
            obj.socket.send(payloadBytes);
        end

        function delete(obj)
            try, obj.socket.close(); end %#ok<TRYNC>
            try, obj.context.close(); end %#ok<TRYNC>
        end
    end
end