module SuperGossip ; module Protocol
    # It represents the connect message sent when initiating the handshaking
    # with the other node.
    class Request
        # Message name
        CONNECT = 'CONNECT'
        # Regular expression pattern for headers
        HEADER_PATTERN = /(?<header>[A-Za-z0-9\-]+)(\s)*:(\s)*(?<value>(\w)+)/
        # Regular expression pattern for request line
        LINE_PATTERN = /(?<name>[A-Z]+)(\s)+#{CONNECT}\/(?<version>\d(\.\d)+)(\s)*/
        attr_accessor :version, :bytesize
        attr_reader :headers

        # Initialization
        def initialize
            @headers = {}
        end

        # Adds header
        def add_header(name,val)
            @headers[name] = val
        end

        # Returns the request line string.
        def request_line
            "#{Protocol::NAME} #{NAME}/#{@version}#{Protocol::CRLF}"
        end

        # Returns a text based version of this response.
        def to_s
            req = request_line
            @headers.each do |key,val|
                req << "#{key}: #{val}#{Protocol::CRLF}"
            end
            res << Protocol::CRLF
        end
    end
end ; end
