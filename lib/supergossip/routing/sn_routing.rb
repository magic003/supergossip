require 'thread'
require 'socket'
require 'date'

module SuperGossip::Routing
    # This is the routing algorithm for supernodes.
    class SNRouting < RoutingAlgorithm
        # Initialization
        def initialize(driver,supernode_table,protocol)
            super(driver,supernode_table,protocol)
            @nodes_filter_strategy = IPPrefixStrategy.new
        end

        # Starts the routing algorithm.
        def start
            if @supernode_table.empty?
                # The supernode table is empty, so this node is probably 
                # starting and not promoted to supernode mode.
                
                # NOTE The +attempt_fetch_supernodes+ will block if no 
                # supernode is found. Since supernodes should still work 
                # even there is no other active supernodes, a thread is created
                # here. So it can still accept connections from other ordinary
                # nodes.
                Thread.new do 
                    # 1. Get supernodes from cache or bootstrap node
                    Routing.log {|logger| logger.info(self.class) {'1. Getting SNs ...'}}
                    sns = attempt_fetch_supernodes
                    # 2. Connect to supernodes
                    Routing.log {|logger| logger.info(self.class) {'2. Connecting to SNs ...'}}
                    connect_supernodes(sns)
                end
            else
                # It is promoted to supernode mode.
                @supernode_table.supernodes.each do |sn|
                    @lock.synchronize { @socks << sn.socket }
                end
            end

            # 3. Start the background threads
            @request_supernode_thread = start_request_supernodes_thread
            @compute_hits_thread = start_compute_hits_thread

            # 4. Create the server socket and handle incoming messages
            @server = TCPServer.open(@driver.config['listening_port'].to_i)
            @socks << @server
            @running = true
            while @running
                # Wait for messages from other nodes
                ready = select(@socks,nil,nil,@timeout)
                readable = ready[0]

                unless readable.nil?
                    readable.each do |sock|
                        if sock == @server  # Accept new client
                            client = @server.accept
                            accepted = on_handshaking(client)
                            if accepted
                                @lock.synchronize { @socks << client }
                            else
                                client.close
                            end
                        elsif sock.eof?     # Socket has disconnected
                            Routing.log {|logger| logger.info(self.class) {'Socket has disconnected.'}}
                            @lock.synchronize {@socks.delete(sock)}
                            # Remove it if it is in supernode table
                            @supernode_table.delete(sock.node) if @supernode_table.include?(sn.node)
                            sock.close
                        else    # Message is ready for reading
                            msg = @protocol.read_message(sock)
                            unless msg.nil?
                                @bandwidth_manager.downloaded(msg.bytesize,Time.now-message.ftime.to_time) unless @bandwidth_manager.nil?
                                handle_message(msg,sock)
                            else
                                Routing.log {|logger| logger.error(self.class) {'The message read is nil.'}}
                            end
                        end
                    end
                else    # Timeout
                    @socks.delete_if do |sock|
                        sock.closed?    # Discarded by supernode table
                    end
                end
            end
        end

        private
        ##########################
        # Handle messages        #
        ##########################

        # Handles the handshaking request from a client node.
        def on_handshaking(client)
            accepted,datas = @protocol.connect_reply(client) do |request|
                node = Model::Node.new
                node.socket = client
                client.node = node
                addr = Model::NodeAddress.new
                addr.public_ip = socket.peeraddr[3]
                addr.public_port = socket.peeraddr[1]
                node.address = addr
                # TODO check the headers to decide whether accept it
                # Just return +true+ here
                true
            end
            unless @bandwidth_manager.nil?
                @bandwidth_manager.uploaded(datas[0],datas[1])
                @bandwidth_manager.downloaded(datas[0],datas[1])
            end
            accepted
        end

        # Handles the received +message+.
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

        # Handles +Protocol::Ping+ message.
        def on_ping(message,sock)
            Routing.update_node_from_ping(sock.node,message)
            picked = false
            if message.supernode?   # sent by a supernode
                score_h = estimate_hub_score(message.guid,message.hub)
                score_a = estimate_authority_score(message.guid,message.authority)
                sock.node.score_h = score_h
                sock.node.score_a = score_a
                picked = @supernode_table.add(sock.node)
            else    # an ordinary node
                picked = @ordinary_node_table.add(sock.node)
            end
            # If the node is picked, send back +Pong+ message. Or close the
            # connection.
            if picked
                # Pongs back
                pong = construct_pong
                pong(sock,pong)
            else
                sock.close unless sock.closed?
            end
        end

        # Handles +Protocol::Pong+ message.
        def on_pong(message,sock)
            if message.supernode?   # only supernode allowed
                score_h = estimate_hub_score(message.guid,message.hub)
                score_a = estimate_authority_score(message.guid,message.authority)

                # Attempts to add into supernode table
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
        end

        # Handles +Protocol::RequestSupernodes+ messages.
        def on_request_supernodes(message,sock)
            # Gets a list of supernodes filtered by some strategy
            nodes = @nodes_filter_strategy.filter(sock.node.address.public_ip,@supernode_table.supernodes,message.num*2) 
            # Selects specified quantity randomly
            nodes = Random.random_select(nodes,message.num)
            # Constructs the +Protocol::ResponseSupernodes+ message
            response = Protocol::ResponseSupernodes.new
            response.ctime = DateTime.now
            response.num = nodes.size
            response.supernodes = nodes
            # Sends the response
            response_supernodes(sock,response)
        end

        # Handles +Protocol::ResponseSupernodes+ messages. Gets the received
        # supernodes and PING them.
        def on_response_supernodes(message,sock)
            # Delete the supernodes which are currently connection
            message.supernodes.delete_if {|sn| @supernode_table.include?(sn)}
            # Connect to the supernodes
            connect_supernodes(message.supernodes)
        end
    end
end
