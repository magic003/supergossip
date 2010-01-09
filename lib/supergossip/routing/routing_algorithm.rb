require 'thread'
require 'socket'

module SuperGossip ; module Routing
    # This is the super class for +SNAlgorithm+ and +ONAlgorithm+ that are 
    # used for different types of nodes. It provides some common methods 
    # that used by both nodes. It behaviors like a abstract class so it should 
    # not be initialized directly.
    class RoutingAlgorithm  # :nodoc:
        
        # Initialization.
        def initialize(db,routing)
            @db = db
            @routing = routing
        end
        private :new

        private
        # Fetch a list of latest supernodes from cache. The size of list 
        # is 10 at most. The supernodes are sorted in descent order by PING 
        # latency. If no supernodes found, connect to bootstrap nodes.
        def fetch_supernodes
            supernodes = []
            iter = SupernodeCacheIterator.new(@db)
            # Get supernodes from cache. Make sure its size is 10.
            while supernodes.length < 10    # FIXME using a parameter for 10
                sns = iter.next
                break if sns.empty?
                Routing.log { |logger| logger.info(self.class) {"Get #{sns.length} supernodes from cache"}}

                # Ping(TCP) the supernodes
                group = ThreadGroup.new
                lock = Mutex.new
                sns.each do |sn|
                    t = Thread.new(sn) { |sn|
                        ping = Net::Ping::TCP.new(sn.public_ip)
                        if ping.ping?
                            sn.latency = ping.duration
                            lock.synchronize {supernodes << sn}
                        end
                    }
                end
                group.list.each { |t| t.join }
            end

            # Get supernodes from bootstrap nodes
            if supernodes.empty?
                Routing.log {|logger| logger.info(self.class) {"No supernode cache available. Get from bootstrap nodes."}}
                # FIXME add bootstrap process
            end
            supernodes.sort! {|s1,s2| s1.latency <=> s2.latency }
            supernodes[0,10]
        end

        # The +SuperGossip::Routing::RoutingAlgorithm#fetch_supernodes+ may
        # return empty list, so this method will try to invoke it for several
        # times. The interval between each attempt is incremental.
        def try_fetch_supernodes
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
        
        # Handshaking with the supernode. This is a three way handshake:
        # 1. This node sends a "CONNECT" request to the supernode;
        # 2. The supernode sends response with code 200 if accepts the 
        # connection. Otherwise replies with error code and closes the 
        # connection.
        # 3. This node sends response with code 200 if success. Otherwise,
        # closes the connection.
        #
        # Returns the socket connection if success, otherwise +nil+.
        def handshaking(sn) 
            sock = TCPSocket.new(sn.public_ip,sn.public_port)
            if @protocol.connect(sock)
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
            unless msg.nil? or msg.type == Protocol::MessageType.PING)
                Routing.log { |logger| logger.error(self.class) { "Not a PING message."}
                return false
            if msg.nil?
                msg = Protocol::Ping.new(@routing.authority,@routing.hub,@routing.authority_sum,@routing.hub_sum,@routing.supernode?)
            end
            bytes = @protocol.send_message(sock,msg)
            Routing.log {|logger| logger.info(self.class) { "PING message is sent. Size: #{bytes} bytes."}}
            true
        end

        # An iterator over supernodes in the cache. 
        class SupernodeCacheIterator   # :nodoc:
            # Initialize the iterator. +Limit+ is the returned items each 
            # iteration, and +offset+ is how may items to skip at the beginning.
            def initialize(db,limit=20,offset=0)
                @db = db
                @supernodeDAO = DAO::SupernodeDAO.new(@db)  
                @limit = limit
                @offset = offset
            end
            
            # Return the next +limit+ items start from position +offset+.
            # Pass the result to block if a block is given. Otherwise, 
            # return it.
            def next
                sns = @supernodeDAO.find(limit,offset)
                offset += limit
                sns
            end
        end
    end
end ; end
