require 'supergossip/dao/user_dao'
require 'supergossip/dao/buddy_dao'
require 'supergossip/dao/message_dao'
require 'supergossip/dao/routing_dao'
require 'supergossip/dao/supernode_dao'
require 'supergossip/dao/neighbor_dao'

module SuperGossip ; module DAO

    # It is the exception raised when trying to add two or more +Model::User+.
    class TooManyUsersError < StandardError ; end
end ; end
