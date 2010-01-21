require 'yaml'

module SuperGossip ; module Protocol
    # This class implements the protocol in +YAML+ format. The message is
    # converted to +YAML+ string by +Object#to_yaml+, and appended with a
    # CRLF to indicating the end of message.
    class YAMLProtocol
        include Protocol

        # Initialize the protocol.
        def initialize
            @headers = {}
        end

        # Sends a message to another connected node. Returns the number of 
        # bytes written.
        def send_message(sock,msg)
            body = msg.to_yaml + CRLF
            sock.write(body)
        end

        # Reads a message from another connected node. Returns the message
        # object. Returns +nil+ if error happens.
        def read_message(sock)
            body = ''
            bytes = 0
            sock.each_line do |line|
                bytes += line.bytesize
                if line == CRLF     # end of message
                    msg = YAML::load(body)
                    msg.bytesize = bytes
                    return msg
                else
                    body << line
                end
            end
            nil
        end
    end
end ; end
