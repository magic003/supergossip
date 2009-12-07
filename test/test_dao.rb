require 'test/unit'
require 'sqlite3'
require File.dirname(__FILE__) + '/../lib/supergossip'

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
        sql = IO.read('../lib/supergossip/user.sql')
        @db.execute_batch(sql)
    end

    def teardown
        @db.close
    end

    # Test UserDAO class
    def test_user_dao
        sql = 'SELECT * FROM user';
        result = @db.execute(sql)
        assert result.empty?

        userDAO = DAO::UserDAO.new(@db)
        user = Model::User.new
        user.guid = 'aw94312d'
        user.name = 'test'
        user.password = 'testpswd'
        userDAO.add(user)

        @db.execute(sql) do |row|
            assert_equal(user.guid,row[0])
            assert_equal(user.name,row[1])
            assert_equal(user.password,row[2])
            assert_not_nil(row[3])
        end
    end

end
