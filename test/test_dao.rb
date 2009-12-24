require 'sqlite3'
require 'test_helper'

# This test case tests data access object functions 
class TestDAO < Test::Unit::TestCase
    include SuperGossip

    def setup
        ##
        # Load configuration from file
        config = Config::Config.instance
        config.load(File.dirname(__FILE__)+'/../config/system.yaml')
        db_path = File.expand_path(config['db_path'].chomp('/'))
        unless Dir.exist?(db_path)
           Dir.mkdir(db_path) 
        end
    
        ##
        # Load database
        @db = SQLite3::Database.new(db_path+'/test.db')
        # user
        sql = IO.read('../lib/supergossip/user.sql')
        @db.execute_batch(sql)
        # routing
        sql = IO.read('../lib/supergossip/routing.sql')
        @db.execute_batch(sql)
    end

    def teardown
        @db.close
    end

    # Test +UserDAO+ class
    def test_user_dao
        sql = 'SELECT * FROM user';
        result = @db.execute(sql)
        assert result.empty?

        # add a new user
        userDAO = DAO::UserDAO.new(@db)
        user = Model::User.new
        user.name = 'test'
        user.password = 'testpswd'
        user.guid = UUID.user_id(user.name).to_s_compact
        userDAO.add(user)

        @db.execute(sql) do |row|
            assert_equal(user.guid,row[0])
            assert_equal(user.name,row[1])
            assert_equal(user.password,row[2])
            assert_not_nil(row[3])
        end

        # delete all users
        DAO::UserDAO.delete(@db)
        result = @db.execute(sql)
        assert result.empty?
    end

    # Test +RoutingDAO+ class
    def test_routing_dao
        # check the default value
        routingDAO = DAO::RoutingDAO.new(@db)
        routing = routingDAO.find
        assert !routing.nil?
        assert_equal(1.0,routing.authority)
        assert_equal(1.0,routing.hub)
        assert_equal(1.0,routing.authority_sum)
        assert_equal(1.0,routing.hub_sum)
        assert(!routing.supernode?)

        # test add one
        sql = 'DELETE FROM routing;'
        @db.execute(sql)
        routing = routingDAO.find
        assert_nil routing
        routing_new = Model::Routing.new
        routing_new.authority = 0.050
        routing_new.hub = 0.002
        routing_new.authority_sum = 15.567
        routing_new.hub_sum = 3.789
        routing_new.supernode = false
        routingDAO.addOrUpdate(routing_new)
        routing = routingDAO.find
        assert_equal(routing_new,routing)

        # test update one
        routing_new.supernode = true
        routingDAO.addOrUpdate(routing_new)
        routing = routingDAO.find
        assert_equal(routing_new,routing)
    end

    # Test +SupernodeDAO+ class
    def test_supernode_dao
        # Test empty table
        supernodeDAO = DAO::SupernodeDAO.new(@db)
        supernode = supernodeDAO.findByGuid('32323239847045')
        assert_nil supernode

        # Test add a new one
        supernode = Model::Supernode.new
        supernode.guid = UUID.user_id('supernode').to_s_compact
        supernode.authority = 0.045
        supernode.hub = 0.152
        supernode.score_a = 0.059
        supernode.score_h = 0.152
        supernode.latency = 300
        supernode.last_update = DateTime.now
        supernodeDAO.addOrUpdate(supernode)
        supernode_return = supernodeDAO.findByGuid(supernode.guid)
        assert_equal(supernode,supernode_return)

        # Test update an existing one
        supernode.authority = 0.112
        supernode.score_a = 0.133
        supernodeDAO.addOrUpdate(supernode)
        supernode_return = supernodeDAO.findByGuid(supernode.guid)
        assert_equal(supernode,supernode_return)
    end

    # Test +NeighborDAO+ class
    def test_neighbor_dao
        # Test empty table
        neighborDAO = DAO::NeighborDAO.new(@db)
        neighbor = neighborDAO.findByGuid("34343434343")
        assert_nil neighbor

        # Test add a new one
        neighbor = Model::Neighbor.new
        neighbor.guid = UUID.user_id('neighbor').to_s_compact
        neighbor.authority = 0.335
        neighbor.hub = 0.011
        neighbor.authority_sum = 12.765
        neighbor.hub_sum = 2.554
        neighbor.direction = 0
        neighbor.last_update = DateTime.now
        neighborDAO.addOrUpdate(neighbor)
        neighbor_return = neighborDAO.findByGuid(neighbor.guid)
        assert_equal(neighbor,neighbor_return)

        # Test update an existing one
        neighbor.authority = 0.245
        neighbor.authority_sum = 9.582
        neighborDAO.addOrUpdate(neighbor)
        neighbor_return = neighborDAO.findByGuid(neighbor.guid)
        assert_equal(neighbor,neighbor_return)
    end
end
