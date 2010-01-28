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
        def initialize(driver,supernode_table,protocol)
            @driver = driver    # driver of routing algorithms
            @supernode_table = supernode_table  # supernode table
            @protocol = protocol

            @socks = []         # All the socket connections
            @lock = Mutex.new   # lock for @socks
            @running = false    # whether this algorithm is running,
                                # should be set to true in 'start' method
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
            size = @driver.config['fetched_supernodes_number'].to_i || 10
            while supernodes.length < size    
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

        # Connect to supernodes, and PING them by creating threads for
        # each one.
        def connect_supernodes(sns)
            ping_msg = construct_ping
            group = ThreadGroup.new
            sns.each do |sn|
                t = Thread.new(sn) { |sn|
                    sock = handshaking(sn)
                    if !sock.nil? and ping(sock,ping_msg)
                        @lock.synchronize { @socks << sock }
                    end
                }
                group.add(t)
            end
            group.list.each { |t| t.join }
        end

        ###########################
        # Send messages           #
        ###########################
        
        # Handshaking with the supernode. 
        # Returns the socket connection if success, otherwise +nil+.
        def handshaking(sn) 
            sock = TCPSocket.new(sn.address.public_ip,sn.address.public_port)
            sn.socket = sock
            sock.node = sn
            res,datas = @protocol.connect(sock) 
            unless @bandwidth_manager.nil?
                @bandwidth_manager.uploaded(datas[0],datas[1])
                @bandwidth_manager.downloaed(datas[2],datas[3])
            end

            if res
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
                msg = construct_ping
            end
            msg.ftime = DateTime.now
            bytes = @protocol.send_message(sock,msg)
            @bandwidth_manager.uploaded(bytes,Time.now-msg.ftime.to_time) unless @bandwidth_manager.nil?
            Routing.log {|logger| logger.info(self.class) { "PING message is sent. Size: #{bytes} bytes."}}
            true
        end

        # Sends a pong message to the node via +sock+ connection. If +msg+ is
        # not provided, a new one will be created.
        # Returns +true+ if success, +false+ otherwise.
        def pong(sock,msg=nil)
            unless msg.nil? or msg.type == Protocol::MessageType.PONG
                Routing.log {|logger| logger.error(self.class) { 'Not a PONG message.'}}
                return false
            end
            if msg.nil?
                msg = construct_pong
            end
            msg.ftime = DateTime.now
            bytes = @protocol.send_message(sock,msg)
            @bandwidth_manager.uploaded(bytes,Time.now-msg.ftime.to_time) unless @bandwidth_manager.nil?
            Routing.log {|logger| logger.info(self.class) { "PONG message is sent. Size: #{bytes} bytes."}}
            true
        end

        # Request supernodes from supernodes in the routing table. It sends a
        # +Protocol::RequestSupernodes+ message to the node. 
        # Returns +true+ if success, otherwise +false+.
        def request_supernodes(sock,msg)
            unless msg.nil? or msg.type == Protocol::MessageType.REQUEST_SUPERNODES
                Routing.log { |logger| logger.error(self.class) { "Not a REQUEST_SUPERNODES message."}}
                return false
            end
            msg.ftime = DateTime.now
            bytes = @protocol.send_message(sock,msg)
            @bandwidth_manager.uploaded(bytes,Time.now-msg.ftime.to_time) unless @bandwidth_manager.nil?
            Routing.log {|logger| logger.info(self.class) { "REQUEST_SUPERNODES message is sent. Size: #{bytes} bytes."}}
            true
        end

        # Sends +Protocol::ResponseSupernodes+ message  to the node.
        # Returns +true+ if success, otherwise +false+.
        def response_supernodes(sock,msg)
            unless msg.nil? or msg.type == Protocol::MessageType.RESPONSE_SUPERNODES
                Routing.log { |logger| logger.error(self.class) { "Not a RESPONSE_SUPERNODES message."}}
                return false
            end
            msg.ftime = DateTime.now
            bytes = @protocol.send_message(sock,msg)
            @bandwidth_manager.uploaded(bytes,Time.now-msg.ftime.to_time) unless @bandwidth_manager.nil?
            Routing.log {|logger| logger.info(self.class) { "RESPONSE_SUPERNODES message is sent. Size: #{bytes} bytes."}}
            true
        end
        
        # Constructs a new +Protocol::Ping+ message.
        def construct_ping
            msg = Protocol::Ping.new
            msg.ctime = DateTime.now
            msg.guid = @driver.guid
            msg.name = @driver.name
            msg.connection_count = @supernode_table.size
            Routing.update_ping_from_routing(msg,@driver.routing)
            msg
        end

        # Constructs a new +Protocol::Pong+ message.
        def construct_pong
            msg = Protocol::Pong.new
            msg.ctime = DateTime.now
            msg.guid = @driver.guid
            msg.name = @driver.name
            msg.connection_count = @supernode_table.size
            Routing.update_ping_from_routing(msg,@driver.routing)
            msg
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
            nodes = @driver.neighbors
            authority_prime = 0.0
            hub_prime = 0.0
            square_sum_authority_prime = 0.0
            square_sum_hub_prime = 0.0
            # Compute the sum
            nodes.each do |p|
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

        ##########################
        # Background thread      #
        ##########################
        
        # Create and start a thread which requests supernodes from the 
        # connecting ones periodically. It returns the +Thread+ object.
        def start_request_supernodes_thread
            Thread.new do 
                # read the request interval
                interval = @driver.config['request_interval'].to_i
                # number of supernodes each time
                number = @driver.config['request_number'].to_i
                
                while true
                    sleep(interval)
                    # get supernodes sockets from supernode table
                    socks = @supernode_table.supernodes
                    # Sends +RequestSupernodes+ message. Because the number of socks is not
                    # so large, and it doesn't wait for the response after sending, it sends
                    # messages one by one here instead of using multiple threads.
                    request_msg = Protocol::RequestSupernodes.new(number)
                    request_msg.ctime = DateTime.now
                    socks.each do |sock|
                        request_supernodes(sock,request_msg)
                    end
                end
            end
        end
        
        # Create and start a thread which computes the values of HITS 
        # algorithm periodically. It returns the +Thread+ object.
        def start_compute_hits_thread
            Thread.new do
                interval = @driver.config['update_routing_interval'].to_i
                while true
                    sleep(interval)
                    routing = estimate_hits

                    # Send updated values to the supernodes
                    ping_msg = Protocol::Ping.new(routing.authority,routing.hub,routing.authority_prime,routing.hub_prime,routing.supernode?)
                    ping_msg.ctime = DateTime.now
                    sns = @supernode_table.supernodes
                    group = ThreadGroup.new
                    sns.each do |sn|
                        t = Thread.new(sn) do |sn|
                            ping(sn.socket,ping_msg) unless sn.socket.nil?
                        end
                        group.add(t)
                    end
                    group.list.each { |t| t.join }
                end
            end
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
