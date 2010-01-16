module SuperGossip ; module Model
    # This class holds the basic routing properties for the peer
    class Routing
        attr_accessor :authority, :hub, :authority_prime, :hub_prime

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
                @authority_prime == other.authority_prime && 
                @hub_prime == other.hub_prime
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

=begin The codes should be deleted in the future

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

=end
    # This is an abstraction of peers in the network. It contains of all
    # the properties that may be used during the routing. For different kinds
    # of peers, it may only have part of properties set.
    class Peer
        attr_accessor :guid, :name, :latency, :address, :direction, :last_update
        attr_accessor :authority, :hub, :authority_prime, :hub_prime, :score_a, :score_h
        attr_accessor :socket
        attr_writer :supernode

        # Defines the direction of the edges in network graphs.
        # *The values should be consistent with them in database schema.*
        module Direction
            IN = -1
            INOUT = 0
            OUT = 1
        end
        include Direction

        def supernode?
            @supernode
        end

        # Override the == method. 
        # Peers have the same +guid+, +name+, and +last_update+ time are considered equal.
        def ==(other)
            if other.nil?
                false
            else
                @guid == other.guid &&
                @name == other.name &&
                @last_update === other.last_update
            end
        end
    end

end ; end
