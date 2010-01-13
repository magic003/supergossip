module SuperGossip ; module Protocol
    # Defines all the message types.
    module MessageType
        PING = 0x00
        PONG = 0x01
    end

    # It is used to exchange profile with supernodes. It contains the basic
    # routing properties of the node
    class Ping
        attr_accessor :guid, :name, :authority, :hub, :authority_sum, :hub_sum
        attr_writer :supernode
        attr_reader :type

        def initialize(guid=nil,name=nil,authority=nil,hub=nil,authority_sum=nil,hub_sum=nil,supernode=nil)
            @type = MessageType::PING
            @guid = guid
            @name = name
            @authority = authority
            @hub = hub
            @authority_sum = authority_sum
            @hub_sum = hub_sum
            @supernode = supernode
        end

        def supernode?
            @supernode
        end
    end

    # It is the response for +Ping+ message. It is the same as +Ping+ except
    # the message type.
    class Pong < Ping
        def initialize(guid=nil,authority=nil,hub=nil,authority_sum=nil,hub_sum=nil,supernode=nil)
            super(guid,authority,hub,authority_sum,hub_sum,supernode)
            @type = MessageType::PONG
    end
end ; end
