require 'thread' 
require 'socket'
require 'date'

module SuperGossip::Routing
    # This implements the routing algorithm for ordinary nodes.
    class ONRouting < RoutingAlgorithm
        # Initialization
        def initialize(driver,supernode_table,protocol)
            super(driver,supernode_table,protocol)
        end
        
        # Start the routing algorithm
        def start
            # 1. Get supernodes from cache or bootstrap node
            # NOTE The +attempt_to_supernodes+ will block here until get
            # some active supernodes. Ordinary nodes can work without 
            # supernodes.
            Routing.log{|logger| logger.info(self.class) {"1. Getting SNs ..."}}
            sns = attempt_fetch_supernodes
            # 2. Connect to supernodes
            Routing.log {|logger| logger.info(self.class) {"2. Connecting to SNs ..."}}
            connect_supernodes(sns)

            # 3. Start the background threads
            @request_supernodes_thread = start_request_supernodes_thread
            @compute_hits_thread = start_compute_hits_thread

            # 4. Read messages from supernodes, and handle them.
            @running = true
            while @running
                # Wait for message from other nodes
                ready = select(@socks,nil,nil,@timeout)  
                readable = ready[0]
                
                unless readable.nil?
                    readable.each do |sock|
                        if sock.eof?        # The socket has disconnected
                            Routing.log {|logger| logger.info(self.class) {'Socket has disconnected.'}}
                            @lock.synchronize { @socks.delete(sock)}
                            # Remove it if it is in supernode table
                            @supernode_table.delete(sock.node) if @supernode_table.include?(sn.node)
                            sock.close
                        else        # Message is ready for reading
                            msg = @protocol.read_message(sock)
                            unless msg.nil?
                                @bandwidth_manager.downloaded(msg.bytesize,Time.now-message.ftime.to_time) unless @bandwidth_manager.nil?
                                handle_message(msg,sock)
                            else
                                Routing.log {|logger| logger.error(self.class) {'The message read is nil.'}}
                            end
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

        #########################
        # Handle messages       #
        #########################

        # Handle the received +message+.
        def handle_message(message,sock)
            if message.nil? or !message.respond_to?(:type)
                Routing.log {|logger| logger.error(self.class) {"Not a correct message: #{message.to_s}."}}
                return
            end

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
            score_a = estimate_authority_score(message.guid,message.authority)
            
            # attempt to add into routing table
            Routing.update_node_from_pong(sock.node,message)
            sock.node.score_h = score_h
            sock.node.score_a = score_a
            result = @supernode_table.add(sock.node)
            unless result or sock.closed?
                sock.close
            end
            # add to supernode cache
            if result
                @driver.save_supernode(sock.node)
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
    end
end
