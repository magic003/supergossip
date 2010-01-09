module SuperGossip
    # This module implements the protocols for communications between nodes
    # in the system, including supernode<->ordinary node and 
    # supernode<->supernode. It defines the handshaking process and message
    # formats.
    module Protocol
        NAME = 'SUPERGOSSIP'
        CRLF = '\r\n'

        # It defines the codes used in response line.
        module Code
            OK = 200
        end
        include Code

        # Run the three way handshaking with a node via the +sock+ connection.
        # Returns +true+ if succeeded, otherwise +false+.
        def connect(sock)
            # construct the request
            request = "#{NAME} CONNECT/#{SuperGossip::VERSION}#{CRLF}" 
            @headers.each do |key,val|
                request << "#{key}: #{val}#{CRLF}"
            end
            request << CRLF

            # send request
            sock.write(request)
            # read response
            res = read_response(sock)
            if res.code==OK
                # send the OK response
                sock.write("#{NAME}/#{SuperGossip::VERSION} #{OK.to_s} OK#{CRLF}")
                true
            else
                false
            end
        end

        # Read response from the +sock+ connection. Parse the response, and 
        # return a +SuperGossip::Protocol::Response+ object, +nil+ if error
        # happens.
        def read_response(sock)
            begin
                res = Response.new
                # parse response line
                response_line = sock.readline.chomp(CRLF)
                if Response::LINE_PATTERN =~ response_line
                    res.response_line = response_line
                    res.version = $~[:version]
                    res.code = $~[:code].to_i
                    res.message = $~[:message]
                else
                    return nil
                end
                # read headers
                sock.each_line(CRLF) do |line|
                    line.chomp!(CRLF)
                    if line.empty?
                        break   # end of the headers
                    elsif Response::HEADER_PATTERN =~ line
                        res.add_header($~[:header],$~[:value])
                    end
                end
                res
            rescue EOFError, IOError
                nil
            end
        end
    end
end
