module SuperGossip
    # This module implements the protocols for communications between nodes
    # in the system, including supernode<->ordinary node and 
    # supernode<->supernode. It defines the handshaking process and message
    # formats. Every Protocol implementation should mixin this module.
    module Protocol
        include Log

        NAME = 'SUPERGOSSIP'
        CRLF = "\r\n"

        # It defines the codes used in response line.
        module Code
            OK = 200

            ERROR = 500
            UNKNOWN = -1    # The request line is unparsable.
        end
        include Code

        # Starts three way handshaking with a node via the +sock+ connection.
        # It returns an array, with the first element indicating whether it is
        # successful, and the second element is an array containing the
        # _uploaded bytes_, _upload time_, _downloaded bytes_ and _download 
        # time_ in order.
        #
        # Handshaking:      
        # 1. This node sends a "CONNECT" request;
        # 2. The other node sends response with code 200 if accepts the 
        # connection. Otherwise replies with error code and closes the 
        # connection.
        # 3. This node sends response with code 200 if success. Otherwise,
        # closes the connection.
        def connect(sock)
            # construct the request
            request = Request.new
            request.version = SuperGossip::VERSION
            @headers.each do |key,val|
                request.add_header(key,val)
            end

            # send request
            start_time = Time.now
            uploaded_bytes = sock.write(request.to_s)
            upload_time = Time.now-start_time
            request.bytesize = uploaded_bytes
            Protocol.log {|logger| logger.info(self.class) { "Send request:\n#{request.to_s}"}}

            # read response
            start_time = Time.now
            res = read_response(sock)
            read_time = Time.now-start_time

            if res.code==OK
                # send the OK response
                response = Response.new
                response.version = SuperGossip::VERSION
                response.code = OK
                response.message = 'OK'
                start_time = Time.now
                uploaded_bytes += sock.write(response.to_s)
                upload_time += (Time.now-start_time)
                [true,[uploaded_bytes,upload_time,res.bytesize,read_time]]
            else
                [false,[uploaded_bytes,upload_time,res.bytesize,read_time]]
            end
        end

        # Replies to the three way handshaking request from a node via the 
        # +sock+ connection. It passes the received +Protocol::Request+ to the
        # block, and use the return value of the block +true+ or +false+ to 
        # determine whether accepts or refuses the request.
        #
        # It returns an array, with the first element indicating whether it is
        # successful, and the second element is an array containing the
        # _uploaded bytes_, _upload time_, _downloaded bytes_ and _download 
        # time_ in order.
        #
        # Reply to handshaking:      
        # 1. This node receives a "CONNECT" request;
        # 2. Test the request to decide whether accepts or refuses it. If yes,
        # send back a response with code 200. Otherwise, send back one with
        # error code.
        # 3. If accepted, wait for response from the other node. If the 
        # response code is 200, the connection is established.
        def connect_reply(sock)
            # read the request
            start_time = Time.now
            request = read_request(sock)
            read_time = Time.now-start_time
            read_bytes = request.bytesize
            Protocol.log {|logger| logger.info(self.class) {"Receive request:\n#{request.to_s}"}}

            # test the request
            accept = block_given? ? (yield request) : true

            # send back response
            response = Response.new
            response.version = SuperGossip::VERSION
            if accept
                response.code = OK
                response.message = 'OK'
            else
                response.code = ERROR
                response.message = 'ERROR'
            end
            @headers.each do |key,val|
                response.add_header(key,val)
            end

            start_time = Time.now
            response.bytesize = sock.write(response.to_s)
            upload_time = Time.now-start_time
            Protocol.log {|logger| logger.info(self.class) { "Send response:\n#{response.to_s}"}}

            if accept   # wait for response if accepted
                # read response
                start_time = Time.now
                response_received = read_response(sock)
                read_time += Time.now-start_time
                read_bytes += response_received.bytesize
                Protocol.log {|logger| logger.info(self.class) {"Received response\n:#{response_received.to_s}"}}

                if response_received.code == OK
                    return [true,[response.bytesize,upload_time,read_bytes,read_time]]
                end
            end
            [false,[response.bytesize,upload_time,read_bytes,read_time]]
        end

        private 

        # Reads response from the +sock+ connection. Parses the response, and 
        # returns a +SuperGossip::Protocol::Response+ object. 
        def read_response(sock)
            res = Response.new
            read_bytes = 0
            begin
                # parse response line
                response_line = sock.readline
                read_bytes = response_line.bytesize
                response_line.chomp!(CRLF)
                Protocol.log {|logger| logger.info(self.class) { "Read response:\n#{response_line}"}}
                if Response::LINE_PATTERN =~ response_line
                    res.version = $~[:version]
                    res.code = $~[:code].to_i
                    res.message = $~[:message]
                else
                    res.code = UNKNOWN
                end

                # read headers
                sock.each_line(CRLF) do |line|
                    read_bytes += line.bytesize
                    line.chomp!(CRLF)
                    Protocol.log {|logger| logger.info(self.class) { "Response header: #{line}"}}
                    if line.empty?
                        break   # end of the headers
                    elsif Response::HEADER_PATTERN =~ line
                        res.add_header($~[:header],$~[:value])
                    end
                end
            rescue EOFError, IOError
                res.code = UNKNOWN
            end
            res.bytesize = read_bytes
            res
        end

        # Reads request from the +sock+ connection. Parses the request, and 
        # returns a +SuperGossip::Protocol::Request+ object.
        def read_request(sock)
            req = Request.new
            read_bytes = 0
            begin
                # parse request line
                request_line = sock.readline
                read_bytes = request.bytesize
                request_line.chomp!(CRLF)
                Protocol.log {|logger| logger.info(self.class) { "Read request:\n#{request_line}"}}
                if Request::LINE_PATTERN =~ request_line
                    req.version = $~[:version]
                end

                # read headers
                sock.each_line(CRLF) do |line|
                    read_bytes += line.bytesize
                    line.chomp!(CRLF)
                    Protocol.log {|logger| logger.info(self.class) { "Request header: #{line}"}}
                    if line.empty?
                        break   # end of the headers
                    elsif Request::HEADER_PATTERN =~ line
                        req.add_header($~[:header],$~[:value])
                    end
                end
            rescue EOFError, IOError
                Protocol.log {|logger| logger.error(self.class) { 'Read request failed.'}}
            end
            req.bytesize = read_bytes
            req
        end
    end
end
