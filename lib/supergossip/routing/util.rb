require 'date'

module SuperGossip
    # This files defines the utilities in +Routing + module.
    module Routing
        # Updates the properties of a +node+ from a +ping+ message.
        def self.update_node_from_ping(node,ping)
            node.guid = ping.guid
            node.name = ping.name
            node.authority = ping.authority
            node.hub = ping.hub
            node.authority_prime = ping.authority_prime
            node.hub_prime = ping.hub_prime
            node.connection_count = ping.connection_count
            node.supernode = ping.supernode?
            node.last_update = DateTime.now
        end

        # Updates the properties of a +node+ from a +pong+ message.
        def self.update_node_from_pong(node,pong)
            self.update_node_from_ping(node,pong)
        end

        # Updates the +ping+ message from the routing properties.
        def self.update_ping_from_routing(ping,routing)
            ping.authority = routing.authority
            ping.hub = routing.hub
            ping.authority_prime = routing.authority_prime
            ping.hub_prime = routing.hub_prime
            ping.supernode = routing.supernode?
        end

        # Updates the +pong+ message from the routing properties.
        def self.update_pong_from_routing(pong,routing)
            self.update_ping_from_routing(pong,routing)
        end
    end
end
