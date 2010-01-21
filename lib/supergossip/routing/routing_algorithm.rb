require 'thread'
require 'socket'
require 'date'

# Open class +TCPSocket+ to add +node+ which is th end of this connection.
class TCPSocket
    attr_accessor :node
end

module SuperGossip ; module Routing
    # This is the super class for +SNAlgorithm+ and +ONAlgorithm+ that are 
    # used for different types of nodes. It provides some common methods 
    # that used by both nodes. It behaviors like a abstract class so it should 
    # not be initialized directly.
    class RoutingAlgorithm  # :nodoc:
        attr_writer :timeout, :bandwidth_manager
        
        # Initialization.
        def initialize(driver)
            @driver = driver    # driver of routing algorithms
        end
        private :new

        private
        # Fetch a list of latest supernodes from cache. The size of list 
        # is 10 at most. The supernodes are sorted in descent order by ping
        # latency. If no supernodes found, connect to bootstrap nodes.
        def fetch_supernodes
            supernodes = []
            iter = SupernodeCacheIterator.new(@driver)
            # Get supernodes from cache. Make sure its size is 10.
            size = 10
            while supernodes.length < size    # FIXME using a parameter for 10
                sns = iter.next
                break if sns.empty?
                Routing.log { |logger| logger.info(self.class) {"Get #{sns.length} supernodes from cache"}}

                # Ping(TCP) the supernodes
                group = ThreadGroup.new
                lock = Mutex.new
                sns.each do |sn|
                    t = Thread.new(sn) { |sn|
                        ping = Net::Ping::TCP.new(sn.address.public_ip)
                        if ping.ping?
                            sn.latency = ping.duration
                            lock.synchronize {supernodes << sn}
                        end
                    }
                    group.add(t)
                end
                group.list.each { |t| t.join }
            end

            # Get supernodes from bootstrap nodes
            if supernodes.empty?
                Routing.log {|logger| logger.info(self.class) {"No supernode cache available. Get from bootstrap nodes."}}
                # FIXME add bootstrap process
            end
            supernodes.sort! {|s1,s2| s1.latency <=> s2.latency }
            supernodes[0,size]
        end

        # The +SuperGossip::Routing::RoutingAlgorithm#fetch_supernodes+ may
        # return empty list, so this method will attempt to invoke it for 
        # several times. The interval between each attempt is incremental.
        def attempt_fetch_supernodes
            interval = 10    # inital interval
            incr = 30        # Incrementation
            sns = fetch_supernodes
            while sns.empty?
                Routing.log {|logger| logger.error(self.class) { "No supernode. Retry in #{interval} seconds"}}
                Thread.current.sleep(interval)
                interval += incr
                sns = fetch_supernodes
            end
            sns
        end

        ###########################
        # Send messages           #
        ###########################
        
        # Handshaking with the supernode. This is a three way handshake:
        # Returns the socket connection if success, otherwise +nil+.
        def handshaking(sn) 
            sock = TCPSocket.new(sn.address.public_ip,sn.address.public_port)
            sn.socket = sock
            res = @protocol.connect(sock) do |up_b,up_t,down_b,down_t|
                unless @bandwidth_manager.nil?
                    @bandwidth_manager.uploaded(up_b,up_t)
                    @bandwidth_manager.downloaed(down_b,down_t)
                end
            end
            if res
                sock.node = sn
                sock
            else
                sock.close
                nil
            end
        end

        # Ping the supernode via the socket connection to exchange profiles
        # (including authority, hub and etc). If +msg+ is provided, it will be
        # sent. Create a new one otherwise.
        # Return +true+ if success, otherwise +false+.
        def ping(sock,msg=nil)
            unless msg.nil? or msg.type == Protocol::MessageType.PING
                Routing.log { |logger| logger.error(self.class) { "Not a PING message."}}
                return false
            end
            if msg.nil?
                routing = @driver.routing_dao.find()
                msg = Protocol::Ping.new(@driver.guid,routing.authority,routing.hub,routing.authority_prime,routing.hub_prime,routing.supernode?)
                msg.ctime = DateTime.now
            end
            msg.ftime = DateTime.now
            bytes = @protocol.send_message(sock,msg)
            @bandwidth_manager.uploaded(bytes,Time.now-msg.ftime.to_time) unless @bandwidth_manager.nil?
            Routing.log {|logger| logger.info(self.class) { "PING message is sent. Size: #{bytes} bytes."}}
            true
        end

        # Request supernodes from supernodes in the routing table. It sends a
        # +Protocol::RequestSupernodes+ message to the node. 
        # Return +true+ if success, otherwise +false+.
        def request_supernodes(sock,msg)
            unless msg.nil? or msg.type == Protocol::MessageType.REQUEST_SUPERNODES
                Routing.log { |logger| logger.error(self.class) { "Not a REQUEST_SUPERNODES message."}}
                return false
            end
            msg.ftime = DateTime.now
            bytes = @protocol.send_message(sock,msg)
            @bandwidth_manager.uploaded(bytes,Time.now-msg.ftime.to_time) unless @bandwidth_manager
            Routing.log {|logger| logger.info(self.class) { "REQUEST_SUPERNODES message is sent. Size: #{bytes} bytes."}}
            true
        end
        
        ##########################
        # Estimations            #
        ##########################

        # Estimate the hub score of the node with +guid+, considering its +hub+
        # value.
        # The estimation formula is:
        #   hub_score = (1 + b/in-degrees + directs_guid/directs_all) * hub
        # If current node has an in-degree from +guid+, +b+ is 1, 0 otherwise.
        def estimate_hub_score(guid,hub)
            out_degrees,in_degrees = @driver.degrees
            weight = 1.0
            if @driver.in_link?(guid)
                weight += 1.0/in_degrees
            end
            weight += @driver.directs(guid).to_f/@driver.total_directs
            weight * hub
        end

        # Estimate the authority score of the node with +guid+, considering its
        # +authority+ value.
        # The estimation formula is:
        #   authority_score = (1 + b/out-degrees + directs_guid/directs_all)
        #                       * authority
        # If current node has an out-degree to +guid+, +b+ is 1, 0 otherwise.
        def estimate_authority_score(guid,authority)
            out_degrees,in_degrees = @driver.degrees
            weight = 1.0
            if @driver.out_link?(guid)
                weight += 1.0/out_degrees
            end
            weight += @driver.directs(guid).to_f/@driver.total_directs
            weight * authority
        end

        # Estimate the authority and hub values of HITS algorithm.
        # Return the new routing properties.
        def estimate_hits
            peers = @driver.neighbors
            authority_prime = 0.0
            hub_prime = 0.0
            square_sum_authority_prime = 0.0
            square_sum_hub_prime = 0.0
            # Compute the sum
            peers.each do |p|
                authority_prime += p.hub
                hub_prime += p.authority
                square_sum_authority_prime += p.authority_prime**2
                square_sum_hub_prime += p.hub_prime**2
            end
            square_sum_authority_prime += authority_prime**2
            square_sum_hub_prime += hub_prime**2
            # Normalize
            authority = authority_prime**2/square_sum_authority_prime
            hub = hub_prime**2/square_sum_hub_prime

            # Update routing
            new_routing = @driver.update_routing do |routing|
                routing.authority = authority
                routing.hub = hub
                routing.authority_prime = authority_prime
                routing.hub_prime = hub_prime
            end

            new_routing
        end

        # An iterator over supernodes in the cache. 
        class SupernodeCacheIterator   # :nodoc:
            # Initialize the iterator. +Limit+ is the returned items each 
            # iteration, and +offset+ is how may items to skip at the beginning.
            def initialize(driver,limit=20,offset=0)
                @driver = driver
                @limit = limit
                @offset = offset
            end
            
            # Return the next +limit+ items start from position +offset+.
            # Pass the result to block if a block is given. Otherwise, 
            # return it.
            def next
                sns = @driver.supernode_dao.find(limit,offset)
                offset += limit
                sns
            end
        end
    end
end ; end
