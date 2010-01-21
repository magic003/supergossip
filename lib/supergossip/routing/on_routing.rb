require 'thread' 
require 'socket'
require 'date'

module SuperGossip ; module Routing
    # This implements the routing algorithm for ordinary nodes.
    class ONRouting < RoutingAlgorithm
        # Initialization
        def initialize(driver,supernode_table)
            super(driver)
            @supernode_table = supernode_table

            # Create protocol
            @protocol = Protocol::YAMLProtocol.new
        end
        
        # Start the routing algorithm
        def start
            # 1. Get supernodes from cache or bootstrap node
            Routing.log{|logger| logger.info(self.class) {"1. Getting SNs ..."}}
            sns = attempt_fetch_supernodes
            # 2. Connect to supernodes
            Routing.log {|logger| logger.info(self.class) {"2. Connect to SNs ..."}}
            @socks = []
            @lock = Mutex.new   # lock for @socks

            connect_supernodes(sns)

            # 3. Start the background threads
            @request_supernodes_thread = start_request_supernodes_thread
            @compute_hits_thread = start_compute_hits_thread

            # 4. Read +Protocol::Pong+ response from supernode, and estimate
            #   scores.
            @running = true
            while running
                # Wait for message from other nodes
                ready = select(@socks,nil,nil,@timeout)  
                readable = ready[0]
                
                unless readable.nil?
                    readable.each do |sock|
                        if sock.eof?        # The socket has disconnected
                            Routing.log {|logger| logger.info(self.class) {'Socket has disconnected.'}}
                            @lock.synchronize { @socks.delete(sock)}
                            # remove it if yes.
                            @supernode_table.delete(sock.node) if @supernode_table.include?(sn.node)
                            sock.close
                        else        # Message is ready for reading
                            msg = @protocol.read_message(sock)
                            handle_message(msg,sock)
                        end
                    end
                else        # timeout
                    @socks.delete_if do |sock|
                        sock.closed?     # Discarded by supernode table
                    end
                end
            end
        end

        # Stops the running algorithm and threads.
        def stop
            @request_supernodes_thread.exit
            @compute_hits_thread.exit
            @running = false
        end

        private 

        # Connect to supernodes, and PING them by creating threads for
        # each one.
        def connect_supernodes(sns)
            routing = @driver.routing_dao.find
            ping_msg = Protocol::Ping.new(routing.authority,routing.hub,routing.authority_prime,routing.hub_prime,routing.supernode?)
            ping_msg.ctime = DateTime.now
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

        #########################
        # Handle messages       #
        #########################

        # Handle the received +message+.
        def handle_message(message,sock)
            time = Time.now
            if message.nil? or !message.respond_to?(:type)
                Routing.log {|logger| logger.error(self.class) {"Not a correct message: #{message.to_s}."}}
                return
            end
            @bandwidth_manager.downloaded(message.bytesize,time-message.ftime.to_time) unless @bandwidth_manager.nil?

            case message.type
            when Protocol::MessageType::PING
                on_ping(message,sock)
            when Protocol::MessageType::PONG
                on_pong(message,sock)
            when Protocol::MessageType::REQUEST_SUPERNODES
                on_request_supernodes(message,sock)
            when Protocol::MessageType::RESPONSE_SUPERNODES
                on_response_supernodes(message,sock)
            else
                Routing.log{|logger| logger.error(self.class) {"Unknown message type: #{message.to_s}."}}
            end
        end
        
        # Handle +Protocol::Ping+ message.
        def on_ping(message,sock)

        end

        # Handle +Protocol::Pong+ message. Read the routing properties
        # (authority, hub and etc.) from the message, and estimate the scores
        # of the nodes to determine whether adding it to the routing table.
        def on_pong(message,sock)
            score_h = estimate_hub_score(message.guid,message.hub)
            score_a = estimate_authority_socre(message.guid,message.authority)
            
            # attempt to add into routing table
            result = @supernode_table.add(message.guid,sock,score_a,score_h)
            unless result or sock.closed?
                sock.close
            end
            # add to supernode cache
            if result
                sn = sock.node
                sn.authority = message.authority
                sn.hub = message.hub
                sn.score_a = score_a
                sn.score_h = score_h
                sn.last_update = DateTime.now
                @driver.supernode_dao.save_or_update(sn)
            end
        end

        # Handle +Protocol::RequestSupernodes+ message.
        def on_request_supernodes(message,sock)
        end

        # Handle +Protocol::ResponseSupernodes+ message. Get the responded 
        # supernodes and PING them.
        def on_response_supernodes(message,sock)
            # Delete the supernode which is currently connecting
            message.supernodes.delete_if {|sn| @supernode_talbe.include?(sn)}
            # Connect to the supernodes
            connect_supernodes(message.supernodes)
        end

        ##########################
        # Background thread      #
        ##########################
        
        # Create and start a thread which requests supernodes from the 
        # connecting ones periodically. It returns the +Thread+ object.
        def start_request_supernodes_thread
            Thread.new do 
                # read the request interval
                interval = @driver.config['request_interval']
                # number of supernodes each time
                number = @driver.config['request_number']
                
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
                interval = @driver.config['update_routing_interval']
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
    end
end ; end
