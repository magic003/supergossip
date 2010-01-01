require 'singleton'
require 'sqlite3'

module SuperGossip ; module Routing
    # This implements the steps of routing algorithm. It is implemented with 
    # singleton pattern, so there will be only one such instance in the system.
    # = Algorithm
    #
    class Routing
        include Singleton

        # Initialization
        def initialize
            Routing.log {|logger| logger.info(self.class) {"Initial Routing"} }
            config = Config::Config.instance
            db_path = File.expaned_path(config['db_path'].chomp('/'))
            @db = SQLite3::Database.new(db_path+'/routing.db')
            Routing.log {|logger| logger.info(self.class) {"Load routing database") }}
            routing = DAO::RoutingDAO.new(db).find()
            if routing.supernode?
                Routing.log {|logger| logger.info(self.class) {"Supernode"}}

            else
                Routing.log {|logger| logger.info(self.class) {"Ordinary Node"}}

            end
        end

        # Shutdown the routing algorithm. It will stop all the threads, and 
        # close database connection.
        def shutdown
            @db.close
        end
    end

    # Share logger among classes in this module
    class << self #:nodoc:
        attr_accessor :logger

        # A wrapper for logger. If logger is not +nil+, pass it to the block. 
        # Otherwise, print an error message.
        def log()
            if !@logger.nil? && block_given?
                yield @logger
            elsif @logger.nil?
                STDERR.puts "No log provided!"
            end
        end
    end
end ; end
