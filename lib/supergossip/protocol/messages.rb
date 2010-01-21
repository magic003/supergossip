module SuperGossip ; module Protocol
    # Defines all the message types.
    module MessageType
        PING = 0x00
        PONG = 0x01

        REQUEST_SUPERNODES = 0x10
        RESPONSE_SUPERNODES = 0x11
    end

    # Root class of all the messages in this protocol.
    class Message
        attr_reader :type
        attr_accessor :ctime, :ftime, :bytesize
    end

    # It is used to exchange profile with supernodes. It contains the basic
    # routing properties of the node
    class Ping < Message
        attr_accessor :guid, :name, :authority, :hub, :authority_prime, :hub_prime
        attr_writer :supernode

        def initialize(guid=nil,name=nil,authority=nil,hub=nil,authority_prime=nil,hub_prime=nil,supernode=nil)
            @type = MessageType::PING
            @guid = guid
            @name = name
            @authority = authority
            @hub = hub
            @authority_prime = authority_prime
            @hub_prime = hub_prime
            @supernode = supernode
        end

        def supernode?
            @supernode
        end
    end

    # It is the response for +Ping+ message. It is the same as +Ping+ except
    # the message type.
    class Pong < Ping
        def initialize(guid=nil,authority=nil,hub=nil,authority_prime=nil,hub_prime=nil,supernode=nil)
            super(guid,authority,hub,authority_prime,hub_prime,supernode)
            @type = MessageType::PONG
    end

    # It represents a request for supernodes.
    class RequestSupernodes < Message
        attr_accessor :num
        def initialize(num=nil)
            @type = MessageType::REQUEST_SUPERNODES
            @num = num
        end
    end

    # It represents a response for the supernodes request.
    class RespnonseSupernodes < Message
        attr_accessor :supernodes
        def initialize
            @type = MessageType::RESPONSE_SUPERNODES
        end
    end
end ; end
