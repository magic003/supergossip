require 'sqlite3'
require 'test_helper'

# This test case tests data access object functions 
class TestDAO < Test::Unit::TestCase
    include SuperGossip

    def setup
        ##
        # Load configuration from file
        config = Config::Config.instance
        config.load(File.dirname(__FILE__)+'/../config/conf.yaml')
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
        user.online_hours = 0
        userDAO.add_or_update(user)

        @db.execute(sql) do |row|
            assert_equal(user.guid,row[0])
            assert_equal(user.name,row[1])
            assert_equal(user.password,row[2])
            assert_equal(user.online_hours,row[3].to_i)
            assert_not_nil(row[4])
        end

        # add another user, should failed
        user1 = Model::User.new
        user1.name = 'test1'
        user1.password = 'test1passwd'
        user1.guid = UUID.user_id(user1.name).to_s_compact
        assert_equal(false,userDAO.add_or_update(user1))

        # find the user
        user_new = userDAO.find
        assert_equal(user.guid,user_new.guid)
        assert_equal(user.name,user_new.name)
        assert_equal(user.password,user_new.password)
        assert_equal(user.online_hours,user_new.online_hours)
        assert_not_nil(user_new.register_date)

        # update the user
        user.online_hours += 1
        userDAO.add_or_update(user)
        user_new = userDAO.find
        assert_equal(user.online_hours,user_new.online_hours)

        # delete all users
        DAO::UserDAO.delete(@db)
        result = @db.execute(sql)
        assert result.empty?
    end

    # Test +BuddyDAO+ class
    def test_buddy_dao
        sql = 'SELECT * FROM buddy';
        result = @db.execute(sql)
        assert result.empty?

        # add a new buddy
        buddy_dao = DAO::BuddyDAO.new(@db)
        buddy = Model::Buddy.new
        buddy.guid = UUID.user_id('buddy').to_s_compact
        buddy.relationship = Model::Buddy::FOLLOWING
        buddy_dao.add_or_update(buddy)

        # find buddy
        buddy_f = buddy_dao.find_by_guid('90977dfdfdfdfd')
        assert_nil buddy_f
        buddy_f = buddy_dao.find_by_guid(buddy.guid)
        assert_equal(buddy.relationship,buddy_f.relationship)

        # update a buddy
        buddy.relationship = Model::Buddy::FOLLOWER
        buddy_dao.add_or_update(buddy)
        buddy_f = buddy_dao.find_by_guid(buddy.guid)
        assert_equal(Model::Buddy::BOTH,buddy_f.relationship)

        # counts
        buddy1 = Model::Buddy.new
        buddy1.guid = UUID.user_id('buddy1').to_s_compact
        buddy1.relationship = Model::Buddy::FOLLOWING
        buddy_dao.add_or_update(buddy1)

        buddy2 = Model::Buddy.new
        buddy2.guid = UUID.user_id('buddy2').to_s_compact
        buddy2.relationship = Model::Buddy::FOLLOWER
        buddy_dao.add_or_update(buddy2)

        assert_equal(2,buddy_dao.following_count)
        assert_equal(2,buddy_dao.follower_count)
    end

    # Test +MessageDAO+ class
    def test_message_dao
        # add messages
        message_dao = DAO::MessageDAO.new(@db)
        message1 = Model::Message.new
        message1.guid = UUID.user_id('node1').to_s_compact
        message1.content = 'message1'
        message1.direction = Model::Message::TO
        message1.time = DateTime.now
        message_dao.add(message1)

        message2 = Model::Message.new
        message2.guid = UUID.user_id('node2').to_s_compact
        message2.content = 'message2'
        message2.direction = Model::Message::FROM
        message2.time = DateTime.now
        message_dao.add(message2)

        message3 = Model::Message.new
        message3.guid = message1.guid
        message3.content = 'message3'
        message3.direction = Model::Message::FROM
        message3.time = DateTime.now
        message_dao.add(message3)

        # counts
        assert_equal(3,message_dao.message_count)
        assert_equal(2,message_dao.message_count(message1.guid))
        assert_equal(1,message_dao.message_count(message2.guid))
    end

    # Test +RoutingDAO+ class
    def test_routing_dao
        # check the default value
        routing_dao = DAO::RoutingDAO.new(@db)
        routing = routing_dao.find
        assert !routing.nil?
        assert_equal(1.0,routing.authority)
        assert_equal(1.0,routing.hub)
        assert_equal(1.0,routing.authority_prime)
        assert_equal(1.0,routing.hub_prime)
        assert(!routing.supernode?)

        # test add one
        sql = 'DELETE FROM routing;'
        @db.execute(sql)
        routing = routing_dao.find
        assert_nil routing
        routing_new = Model::Routing.new
        routing_new.authority = 0.050
        routing_new.hub = 0.002
        routing_new.authority_prime = 15.567
        routing_new.hub_prime = 3.789
        routing_new.supernode = false
        routing_dao.add_or_update(routing_new)
        routing = routing_dao.find
        assert_equal(routing_new,routing)

        # test update one
        routing_new.supernode = true
        routing_dao.add_or_update(routing_new)
        routing = routing_dao.find
        assert_equal(routing_new,routing)
    end

    # Test +SupernodeDAO+ class
    def test_supernode_dao
        # Test empty table
        supernode_dao = DAO::SupernodeDAO.new(@db)
        supernode = supernode_dao.find_by_guid('32323239847045')
        assert_nil supernode

        # Test add a new one
        supernode = Model::Peer.new
        supernode.guid = UUID.user_id('supernode').to_s_compact
        supernode.name='supernde'
        supernode.authority = 0.045
        supernode.hub = 0.152
        supernode.score_a = 0.059
        supernode.score_h = 0.152
        supernode.latency = 300
        supernode.last_update = DateTime.now
        supernode.address = 
            Model::NodeAddress.new('127.0.0.1',8080,'localhost',8080)
        supernode_dao.add_or_update(supernode)
        supernode_return = supernode_dao.find_by_guid(supernode.guid)
        assert_equal(supernode,supernode_return)

        # Test update an existing one
        supernode.authority = 0.112
        supernode.score_a = 0.133
        supernode_dao.add_or_update(supernode)
        supernode_return = supernode_dao.find_by_guid(supernode.guid)
        assert_equal(supernode,supernode_return)

        # Test the find method
        supernode.guid = UUID.user_id('sn1').to_s_compact
        supernode.name = 'sn1'
        supernode.last_update = DateTime.parse('2009-12-25T10:30:50+08:00')
        supernode_dao.add_or_update(supernode)

        supernode.guid = UUID.user_id('sn2').to_s_compact
        supernode.name = 'sn2'
        supernode.last_update = DateTime.parse('2009-12-24T09:30:50+08:00')
        supernode_dao.add_or_update(supernode)
        
        supernode.guid = UUID.user_id('sn3').to_s_compact
        supernode.name = 'sn3'
        supernode.last_update = DateTime.parse('2009-12-25T15:30:50+08:00')
        supernode_dao.add_or_update(supernode)

        supernode.guid = UUID.user_id('sn4').to_s_compact
        supernode.name = 'sn4'
        supernode.last_update = DateTime.parse('2009-12-26T10:10:50+08:00')
        supernode_dao.add_or_update(supernode)

        sns = supernode_dao.find(10,0)
        assert_equal(5,sns.length)
        0.upto(3) do |i|
            assert_equal(1,sns[i].last_update<=>sns[i+1].last_update)
        end
        sns = supernode_dao.find(3,0)
        assert_equal(3,sns.length)
        0.upto(1) do |i|
            assert_equal(1,sns[i].last_update<=>sns[i+1].last_update)
        end

        sns = supernode_dao.find(5,2)
        assert_equal(3,sns.length)
        sns = supernode_dao.find(5,5)
        assert_equal(0,sns.length)
    end

    # Test +NeighborDAO+ class
    def test_neighbor_dao
        # Test empty table
        neighbor_dao = DAO::NeighborDAO.new(@db)
        neighbor = neighbor_dao.find_by_guid("34343434343")
        assert_nil neighbor

        # Test add a new one
        neighbor = Model::Peer.new
        neighbor.guid = UUID.user_id('neighbor').to_s_compact
        neighbor.name = 'neighbor'
        neighbor.authority = 0.335
        neighbor.hub = 0.011
        neighbor.authority_prime = 12.765
        neighbor.hub_prime = 2.554
        neighbor.direction = Model::Peer::INOUT
        neighbor.last_update = DateTime.now
        neighbor_dao.add_or_update(neighbor)
        neighbor_return = neighbor_dao.find_by_guid(neighbor.guid)
        assert_equal(neighbor,neighbor_return)

        # Test update an existing one
        neighbor.authority = 0.245
        neighbor.authority_prime = 9.582
        neighbor_dao.add_or_update(neighbor)
        neighbor_return = neighbor_dao.find_by_guid(neighbor.guid)
        assert_equal(neighbor,neighbor_return)

        # Test find all
        ngbr1 = Model::Peer.new
        ngbr1.guid = UUID.user_id('neighbor1').to_s_compact
        ngbr1.name = 'neighbor1'
        ngbr1.authority = 0.335
        ngbr1.hub = 0.011
        ngbr1.authority_prime = 12.765
        ngbr1.hub_prime = 2.554
        ngbr1.direction = Model::Peer::IN
        ngbr1.last_update = DateTime.now
        neighbor_dao.add_or_update(ngbr1)

        ngbr2 = Model::Peer.new
        ngbr2.guid = UUID.user_id('neighbor2').to_s_compact
        ngbr2.name = 'neighbor2'
        ngbr2.authority = 0.335
        ngbr2.hub = 0.011
        ngbr2.authority_prime = 12.765
        ngbr2.hub_prime = 2.554
        ngbr2.direction = Model::Peer::IN
        ngbr2.last_update = DateTime.now
        neighbor_dao.add_or_update(ngbr2)

        ngbrs = neighbor_dao.find_all
        assert_equal(3,ngbrs.size)
    end
end
