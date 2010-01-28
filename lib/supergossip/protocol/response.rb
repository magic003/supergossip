module SuperGossip::Protocol
    # This represents the response message from the other node. Usually, it is
    # used during the three way handshaking process.
    class Response
        # Regular expression pattern for headers
        HEADER_PATTERN =  /(?<header>[A-Za-z0-9\-]+)(\s)*:(\s)*(?<value>(\w)+)/
        # Regular expression pattern for response line
        LINE_PATTERN = /(?<name>[A-Z]+)\/(?<version>\d(\.\d)+)(\s)+(?<code>(\d)+)(\s)+(?<message>(\w)*)/

        attr_accessor :code, :version, :message, :bytesize
        attr_reader :headers

        # Initialization
        def initialize
            @headers = {}
        end

        # Adds header.
        def add_header(name,val)
            @headers[name] = val
        end

        # Returns the response line string.
        def response_line
            "#{Protocol::NAME}/#{@version} #{@code} #{@message}#{Protocol::CRLF}"
        end

        # Returns a text based version of this response.
        def to_s
            res = response_line
            @headers.each do |key,val|
                res << "#{key}: #{val}#{Protocol::CRLF}"
            end
            res << Protocol::CRLF
        end
    end
end
