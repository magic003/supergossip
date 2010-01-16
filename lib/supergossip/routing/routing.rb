module SuperGossip ; module Routing
    include Log

    # This is the driver of routing algorithm. 
    class Routing

        attr_reader :guid, :config, :routing_dao, :supernode_dao

        def initialize(user_db,routing_db)
            @user_db = user_db
            @routing_db = routing_db
            Routing.log {|logger| logger.info(self.class) {"Initial Routing"} }
            @config = Config::Config.instance
            # read guid
            user= DAO::UserDAO.new(@user_db).find()
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

            # Initiate routing algorithms
            routing = @routing_dao.find()
            if routing.supernode?
                Routing.log {|logger| logger.info(self.class) {"Supernode"}}

            else
                Routing.log {|logger| logger.info(self.class) {"Ordinary Node"}}
                # Initiate supernode table
                max_table_size = config['max_table_size_on'].to_i
                authority_size = (out_degrees.to_f/total_degrees*max_table_size).round
                hub_size = (in_degrees.to_f/total_degrees*max_table_size).round
                supernode_table = SupernodeTable.new(authority,hub_size)

                @algorithm = ONRouting.new(self,supernode_table)
                # set parameters for routing algorithm
                timeout = config['timeout'].to_i
                @algorithm.timeout = timeout
                @algorithm.start
            end
        end

        # Test if the node with +guid+ is a following(out_link). Return +true+ 
        # if yes, otherwise return +false+.
        def out_link?(guid)
            buddy = @buddy_dao.find_by_guid(guid)
            false if buddy.nil? or buddy.relationship == Model::Buddy::FOLLOWER
            true
        end

        # Test if the node with +guid+ is a follower(in_link). Return +true+ 
        # if yes, otherwise return +false+.
        def in_link?(guid)
            buddy = @buddy_dao.find_by_guid(guid)
            false if buddy.nil? or buddy.relationship == Model::Buddy::FOLLOWING
            true
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

        # Get all the neighbors of this node in the social network graph.
        def neighbors
            @neighbor_dao.find_all
        end

        def update_routing
            routing = @routing_dao.find
            yield routing
            @routing_dao.add_or_update(routing)
            routing
        end

        # Shutdown the routing algorithm. It will stop all the threads.
        def shutdown
        end
    end
end ; end
