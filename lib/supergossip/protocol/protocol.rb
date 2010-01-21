module SuperGossip
    # This module implements the protocols for communications between nodes
    # in the system, including supernode<->ordinary node and 
    # supernode<->supernode. It defines the handshaking process and message
    # formats.
    module Protocol
        include Log

        NAME = 'SUPERGOSSIP'
        CRLF = '\r\n'

        # It defines the codes used in response line.
        module Code
            OK = 200

            UNKNOWN = -1    # The request line is unparsable.
        end
        include Code

        # Run the three way handshaking with a node via the +sock+ connection.
        # Returns +true+ if succeeded, otherwise +false+.
        #
        # Handshakes:      
        # 1. This node sends a "CONNECT" request;
        # 2. The other node sends response with code 200 if accepts the 
        # connection. Otherwise replies with error code and closes the 
        # connection.
        # 3. This node sends response with code 200 if success. Otherwise,
        # closes the connection.
        #--
        # It provides the upload/download bytes and times to the block via
        # +yield+, so the information can be passed to bandwidth manager. 
        # I don't think this is good method because this method should only
        # focus on the handshaking protocol.
        #++
        def connect(sock)
            # construct the request
            request = "#{NAME} CONNECT/#{SuperGossip::VERSION}#{CRLF}" 
            @headers.each do |key,val|
                request << "#{key}: #{val}#{CRLF}"
            end
            request << CRLF

            # send request
            start_time = Time.now
            uploaded_bytes = sock.write(request)
            upload_time = Time.now-start_time
            Protocol.log {|logger| logger.info(self.class) { "Send request:\n#{request}"}}

            # read response
            start_time = Time.now
            res,read_bytes = read_response(sock)
            read_time = Time.now-start_time

            if res.code==OK
                # send the OK response
                start_time = Time.now
                uploaded_bytes +=
                    sock.write("#{NAME}/#{SuperGossip::VERSION} #{OK.to_s} OK#{CRLF}")
                upload_time += (Time.now-start_time)
                yield uploaded_bytes,upload_time,read_bytes,read_time
                true
            else
                yield uploaded_bytes,upload_time,read_bytes,read_time
                false
            end
        end

        private 

        # Read response from the +sock+ connection. Parse the response, and 
        # return an array. The first element is a 
        # +SuperGossip::Protocol::Response+ object. The second element is 
        # bytes read.
        def read_response(sock)
            res = Response.new
            read_bytes = 0
            begin
                # parse response line
                response_line = sock.readline
                read_bytes = response.bytesize
                response_line.chomp!(CRLF)
                Protocol.log {|logger| logger.info(self.class) { "Read response:\n#{response_line}"}}
                if Response::LINE_PATTERN =~ response_line
                    res.response_line = response_line
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
            [res,read_bytes]
        end
    end
end
