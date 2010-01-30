require 'test_helper'

# Test case for class +SuperGossip::Routing::IPPrefixStrategy+.
class TestIPPrefixStrategy < Test::Unit::TestCase
    include SuperGossip

    # Tests the +#filter+ method.
    def test_filter
        ip = '202.119.34.2'

        node1 = Model::Node.new
        addr1 = Model::NodeAddress.new
        addr1.public_ip = '202.119.25.12'
        node1.address = addr1

        node2 = Model::Node.new
        addr2 = Model::NodeAddress.new
        addr2.public_ip = '202.120.23.32'
        node2.address = addr2

        node3 = Model::Node.new
        addr3 = Model::NodeAddress.new
        addr3.public_ip = '56.119.34.111'
        node3.address = addr3

        node4 = Model::Node.new
        addr4 = Model::NodeAddress.new
        addr4.public_ip = '205.76.0.111'
        node4.address = addr4

        node5 = Model::Node.new
        addr5 = Model::NodeAddress.new
        addr5.public_ip = '215.108.92.111'
        node5.address = addr5

        nodes = [node1,node2,node3,node4,node5]
        nodes_sorted = [node1,node2,node4,node5,node3]

        strategy = Routing::IPPrefixStrategy.new
        nodes_ret = strategy.filter(ip,nodes,2)
        for i in 0...2
            assert_equal(nodes_sorted[i],nodes_ret[i])
        end

        nodes_ret = strategy.filter(ip,nodes,4)
        for i in 0...4
            assert_equal(nodes_sorted[i],nodes_ret[i])
        end
    end
end
