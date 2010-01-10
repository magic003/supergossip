require 'thread' 
require 'socket'

module SuperGossip ; module Routing
    # This implements the routing algorithm for ordinary nodes.
    class ONRouting < RoutingAlgorithm
        # Initialization
        def initialize(driver)
            super(driver)

            # Create protocol
            @protocol = Protocol::YAMLProtocol.new
            
            # 1. Get supernodes from cache or bootstrap node
            Routing.log{|logger| logger.info(self.class) {"1. Getting SNs ..."}}
            sns = attempt_fetch_supernodes
            # 2. Connect to supernodes
            Routing.log {|logger| logger.info(self.class) {"2. Connect to SNs ..."}}
            @socks = []
            ping_msg = Protocol::Ping.new(@routing.authority,@routing.hub,@routing.authority_sum,@routing.hub_sum,@routing.supernode?)
            group = ThreadGroup.new
            lock = Mutex.new
            sns.each do |sn|
                t = Thread.new(sn) { |sn|
                    sock = handshaking(sn)
                    if !sock.nil? and ping(sock,ping_msg)
                        lock.synchronize { @socks << sock }
                    end
                }
            end
            group.list.each { |t| t.join }

            # 3. Read +Protocol::Pong+ response from supernode, and estimate
            #   scores.
            @running = true
            while running
                ready = select(@socks)  # Wait for message from other nodes
                readable = ready[0]

                readable.each do |sock|
                    if sock.eof?        # The socket has disconnected
                        Routing.log {|logger| logger.info(self.class) {'Socket has disconnected.'}}
                        @socks.delete(sock)
                        # FIXME test if sock is in routing table, remove it if
                        # yes.
                        sock.close
                    else        # Message is ready for reading
                        msg = @protocol.read_message(sock)
                        handle_message(msg)
                    end
                end
            end
        end
        
        private 
        # Handle the received +message+.
        def handle_message(message)
            if message.nil? or !message.respond_to?(:type)
                Routing.log {|logger| logger.error(self.class) {"Not a correct message: #{message.to_s}."}}
                return
            end

            case message.type
            when Protocol::MessageType::PING
                on_ping(message)
            when Protocol::MessageType::PONG
                on_pong(message)
            else
                Routing.log{|logger| logger.error(self.class) {"Unknown message type: #{message.to_s}."}}
            end
        end
        
        # Handle +Protocol::Ping+ message.
        def on_ping(message)

        end

        # Handle +Protocol::Pong+ message. Read the routing properties
        # (authority, hub and etc.) from the message, and estimate the scores
        # of the nodes to determine whether adding it to the routing table.
        def on_pong(message)
            score_h = estimate_hub_score(message.guid,message.hub)
            score_a = estimate_authority_socre(message.guid,message.authority)
            
            # attempt to add into routing table
        end
    end
end ; end
