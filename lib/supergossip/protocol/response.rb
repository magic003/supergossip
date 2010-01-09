module SuperGossip ; module Protocol
    # This represents the response message from the other node. Usually, it is
    # used during the three way handshaking process.
    class Response
        # Regular expression pattern for headers
        HEADER_PATTERN =  /(?<header>[A-Za-z0-9\-]+)(\s)*:(\s)*(?<value>(\w)+)/
        # Regular expression pattern for response line
        LINE_PATTERN = /(?<name>[A-Z]+)\/(?<version>\d(\.\d)+)(\s)+(?<code>(\d)+)(\s)+(?<message>(\w)*)/

        attr_accessor :response_line, :code, :version, :message
        attr_reader :headers
        # Initialization
        def initialize
            @headers = {}
        end

        # Add header
        def add_header(name,val)
            @headers[name] = val
        end
    end
end ; end
