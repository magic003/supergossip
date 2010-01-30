module SuperGossip::Routing
    include Log

    # This is the driver of routing algorithm. 
    class Router

        attr_reader :guid, :config

        def initialize(user_db,routing_db)
            @user_db = user_db
            @routing_db = routing_db
            Routing.log {|logger| logger.info(self.class) {"Initial Routing"} }
            @config = Config::Config.instance
            # read guid
            user= DAO::UserDAO.new(@user_db).find
            if user.nil?
                Routing.log {|logger| logger.error(self.class) {"No user found"}}
                # FIXME: better to raise an exception here
                return nil
            else 
                @guid = user.guid
            end
            
            # initialize DAOs
            @routing_dao = DAO::RoutingDAO.new(@routing_db)
            @supernode_dao = DAO::SupernodeDAO.new(@routing_db)
            @neighbor_dao = DAO::NeighborDAO.new(@routing_db)
            @buddy_dao = DAO::BuddyDAO.new(@user_db)
            @message_dao = DAO::MessageDAO.new(@user_db)

            @bandwidth_manager = BandwidthManager.new
            @protocol = Protocol::YAMLProtocol.new

            # Initiate routing algorithms
            routing = @routing_dao.find()
            if routing.supernode?
                Routing.log {|logger| logger.info(self.class) {"Supernode"}}
                # Start supernode routing algorithm
                max_sn_table_size = @config['max_supernode_connection_sn']
                authority_size = (out_degrees.to_f/total_degrees*max_sn_table_size).round
                hub_size = (in_degrees.to_f/total_degrees*max_sn_table_size).round
                @supernode_table = SupernodeTable.new(authority_size,hub_size)
                
                max_on_table_size = @config['max_ordinarynode_connection_sn']
                @on_table = OrdinaryNodeTable.new(max_on_table_size)
                @algorithm = SNRouting.new(self,@supernode_table,@on_table,@protocol)
            else
                Routing.log {|logger| logger.info(self.class) {"Ordinary Node"}}
                # Start supernode watch thread
                @supernode_watch_thread = start_supernode_watch_thread

                # Initiate supernode table
                max_table_size = @config['max_supernode_connection_on'].to_i
                authority_size = (out_degrees.to_f/total_degrees*max_table_size).round
                hub_size = (in_degrees.to_f/total_degrees*max_table_size).round
                @supernode_table = SupernodeTable.new(authority_size,hub_size)

                @algorithm = ONRouting.new(self,@supernode_table,@protocol)
            end
            # set parameters for routing algorithm
            timeout = config['timeout'].to_i
            @algorithm.timeout = timeout
            @algorithm.bandwidth_manager = @bandwidth_manager
            @algorithm.start
        end

        # Test if the node with +guid+ is a following(out_link). Return +true+ 
        # if yes, otherwise return +false+.
        def out_link?(guid)
            buddy = @buddy_dao.find_by_guid(guid)
            if buddy.nil? or buddy.relationship == Model::Buddy::FOLLOWER
                false
            else
                true
            end
        end

        # Test if the node with +guid+ is a follower(in_link). Return +true+ 
        # if yes, otherwise return +false+.
        def in_link?(guid)
            buddy = @buddy_dao.find_by_guid(guid)
            if buddy.nil? or buddy.relationship == Model::Buddy::FOLLOWING
                false
            else
                true
            end
        end

        # Test if the node with +guid+ is a neighbor(in_link or out_link).
        # Returns +true+ if it is.
        def neighbor?(guid)
            out_link?(guid) or in_link?(guid)
        end

        # Get the following and follower counts of the current node. It returns
        # an array with the first element as following count(out-degree) and 
        # the second one as follower count(in-degree).
        #--
        # FIXME: use observer pattern so it won't query the database every time.
        #++
        def degrees
           [@buddy_dao.following_count,@buddy_dao.follower_count] 
        end

        # Get the number of direct messages of a node with +guid+.
        def directs(guid)
            @message_dao.message_count(guid)
        end

        # Get the total number of direct messages.
        def total_directs
            @message_dao.message_count
        end

        ################################################
        # Work with database tables related to routing #
        ################################################

        # Gets all the neighbors of this node in the social network graph.
        def neighbors
            @neighbor_dao.find_all
        end

        # Gets the routing properties.
        def routing
            @routing_dao.find
        end

        # Updates the routing properties.
        def update_routing
            routing = @routing_dao.find
            yield routing
            @routing_dao.add_or_update(routing)
            routing
        end

        # Saves supernode to cache. Updates it if exists.
        def save_supernode(sn)
            @supernode_dao.add_or_update(sn)
        end

        # Saves neighbor to caceh. Updates it if exists.
        def save_neighbor(node)
            @neighbor_dao.add_or_update(node)
        end

        #############END OF ROUTING DATABASE TABLES####

        # Shutdown the routing algorithm. It will stop all the threads.
        def shutdown
            @supernode_watch_thread.exit
            @algorithm.stop
        end

        private

        # Starts a thread to examine if this node can be promoted to 
        # a supernode. 
        def start_supernode_watch_thread
            Thread.new do 
                while true
                    sleep(@config['supernode_watch_interval'])
                    # update online hours
                    # TODO better to do this in application layer?
                    user_dao = DAO::UserDAO.new(@user_db)
                    user = use_dao.find
                    user.online_hours += 1
                    user_dao.add_or_update(user)

                    if supernode_capable?
                        # update the routing properties
                        update_routing do |routing|
                            routing.supernode = true
                        end

                        promote_to_supernode
                        break
                    end
                end
            end
        end
        
        # Promotes this ordinary node to supernode.
        def promote_to_supernode
            Routing.log {|logger| logger.info(self.class) {"Promote to supernode."}}
            # Stop the current algorithm
            @algorithm.stop
            Routing.log {|logger| logger.info(self.class) {"Current routing algorithm is stopped."}}
            # Start the supernode routing algorithm
            max_sn_table_size = @config['max_supernode_connection_sn']
            authority_size = (out_degrees.to_f/total_degrees*max_sn_table_size).round
            hub_size = (in_degrees.to_f/total_degrees*max_sn_table_size).round
            @supernode_table.max_authority_size = authority_size
            @supernode_table.max_hub_size = hub_size
                
            max_on_table_size = @config['max_ordinarynode_connection_sn']
            @on_table = OrdinaryNodeTable.new(max_on_table_size)
            @algorithm = SNRouting.new(self,@supernode_table,@on_table,@protocol)
            # set parameters for routing algorithm
            timeout = config['timeout'].to_i
            @algorithm.timeout = timeout
            @algorithm.bandwidth_manager = @bandwidth_manager
            # FIXME start will blocked?
            @algorithm.start

            # Advertise supernode
            Routing.log {|logger| logger.info(self.class) {"Sending supernode advertisement."}}
            @algorithm.advertise
        end

        # Return +true+ if this node can be a supernode.
        def supernode_capable?
            if @config['force_supernode']
                true
            elsif @config['force_ordinary_node']
                false
            else
                # Check IP address
                ip = IP.local_ip
                Routing.log {|logger| logger.info(self.class) {"Local IP: #{ip}"}}
                return false if ip.nil? || IP.private?(ip)
                # Check bandwidth
                up_bandwidth = @bandwidth_manager.upload_bandwidth
                down_bandwidth = @bandwidth_manager.download_bandwidth
                Routing.log {|logger| logger.info(self.class) {"Upload bandwidth: #{up_bandwidth}KB/s, download bandwidth: #{down_bandwidth}KB/s"}}
                return false if up_bandwidth<@config['min_upload_speed'].to_i ||
                            down_bandwidth<@config['min_download_speed'].to_i
                # Check online time
                user= DAO::UserDAO.new(@user_db).find
                days = (DateTime.now-user.register_date).to_i
                if days==0 or (user.online_hours/days.to_f)<@config['min_online_rate'].to_i
                    return false
                end
                return true
            end
        end

        # An iterator over supernodes in the cache. 
        class SupernodeCacheIterator
            # Initialize the iterator. +Limit+ is the returned items each 
            # iteration, and +offset+ is how may items to skip at the beginning.
            def initialize(limit=20,offset=0)
                @limit = limit
                @offset = offset
            end
            
            # Return the next +limit+ items start from position +offset+.
            # Pass the result to block if a block is given. Otherwise, 
            # return it.
            def next
                sns = @supernode_dao.find(limit,offset)
                offset += limit
                sns
            end
        end
    end
end 
