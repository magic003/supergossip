module SuperGossip ; module Model
    # This class holds the basic routing properties for the peer
    class Routing
        attr_accessor :authority, :hub, :authority_sum, :hub_sum

        def supernode?
            @is_supernode
        end

        def supernode=(is_supernode)
            @is_supernode = is_supernode
        end

        # Override the == method
        def ==(other)
            if other.nil? 
                false
            else
                @authority == other.authority && 
                @hub == other.hub && 
                @authority_sum == other.authority_sum && 
                @hub_sum == other.hub_sum
                @is_supernode == other.supernode?
            end
        end
    end
    
    # This class represents the address of the node.
    class NodeAddress
        attr_accessor :public_ip, :public_port, :private_ip, :private_port

        # Initialization.
        def initialize(public_ip=nil,public_port=nil,private_ip=nil,private_port=nil)
            @public_ip = public_ip
            @public_port = public_port
            @private_ip = private_ip
            @private_port = private_port
        end

        # Override the == method
        def ==(other)
            if other.nil?
                false
            else
                @public_ip == other.public_ip &&
                @public_port == other.public_port &&
                @private_ip == other.private_ip &&
                @private_port == other.private_port
            end
        end
    end

    # This class holds the properties of a cached supernode.
    class Supernode
        attr_accessor :guid, :authority, :hub, :score_a, :score_h, :latency, :last_update, :address

        # Override the == method
        def ==(other)
            if other.nil?
                false
            else
                @guid == other.guid &&
                @authority == other.authority &&
                @hub == other.hub &&
                @score_a == other.score_a &&
                @score_h == other.score_h &&
                @latency == other.latency &&
                @last_update === other.last_update &&
                @address == other.address
            end
        end
    end

    # This class holds the properties of a neighbor peer.
    class Neighbor
        attr_accessor :guid, :authority, :hub, :authority_sum, :hub_sum, :direction, :last_update

        # Override the == method
        def ==(other)
            if other.nil?
                false
            else
                @guid == other.guid &&
                @authority == other.authority &&
                @hub == other.hub &&
                @authority_sum == other.authority_sum &&
                @hub_sum == other.hub_sum &&
                @direction == other.direction &&
                @last_update === other.last_update
            end
        end
    end

end ; end
