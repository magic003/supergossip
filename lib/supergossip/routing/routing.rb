require 'singleton'
require 'sqlite3'

module SuperGossip ; module Routing
    include Log

    # This is the driver of routing algorithm. It is implemented with 
    # singleton pattern, so there will be only one such instance in the system.
    #
    class Routing
        include Singleton

        attr_accessor :routing_dao, :supernode_dao

        # Initialization
        def initialize
            Routing.log {|logger| logger.info(self.class) {"Initial Routing"} }
            config = Config::Config.instance
            db_path = File.expaned_path(config['db_path'].chomp('/'))
            @db = SQLite3::Database.new(db_path+'/routing.db')
            Routing.log {|logger| logger.info(self.class) {"Load routing database") }}
            @routing_dao = DAO::RoutingDAO.new(@db)
            @supernode_dao = DAO::SupernodeDAO.new(@db)
            @buddy_dao = DAO::BuddyDAO.new(@db)
            @message_dao = DAO::MessageDAO.new(@db)

            routing = @routing_dao.find()
            if routing.supernode?
                Routing.log {|logger| logger.info(self.class) {"Supernode"}}

            else
                Routing.log {|logger| logger.info(self.class) {"Ordinary Node"}}
                @algorithm = ONRouting.new(self)
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

        # Shutdown the routing algorithm. It will stop all the threads, and 
        # close database connection.
        def shutdown
            @db.close
        end
    end
end ; end
