module SuperGossip::Protocol
    # Defines all the message types.
    module MessageType
        PING = 0x00
        PONG = 0x01

        REQUEST_SUPERNODES = 0x10
        RESPONSE_SUPERNODES = 0x11
        PROMOTION_ADS = 0x12
    end

    # Root class of all the messages in this protocol.
    class Message
        attr_reader :type
        attr_accessor :ctime, :ftime, :bytesize
    end

    # It is used to exchange profile with supernodes. It contains the basic
    # routing properties of the node
    class Ping < Message
        attr_accessor :guid, :name, :authority, :hub, :authority_prime, :hub_prime, :connection_count
        attr_writer :supernode

        def initialize
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
        def initialize
            @type = MessageType::PONG
        end
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
        attr_accessor :num, :supernodes
        def initialize
            @type = MessageType::RESPONSE_SUPERNODES
        end
    end

    # It represents an advertisement that the node has promoted to a
    # supernode. Actually, it is a kind of +Ping+ message.
    class PromotionAdvertisement < Ping
        def initialize
            @type = MessageType::PROMOTION_ADS
        end
    end
end 
