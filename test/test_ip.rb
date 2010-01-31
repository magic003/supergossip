require 'test_helper'

# Test case for +IP+ module utilities.
class TestIP < Test::Unit::TestCase
    # Tests +IP.local_ip+ method.
    def test_local_ip
        local_ip = '192.168.1.102'
        assert_equal(local_ip,IP.local_ip)
    end

    def test_private?
        assert_equal(true,IP.private?('10.108.0.1'))
        assert_equal(true,IP.private?('172.16.10.202'))
        assert_equal(true,IP.private?('192.168.1.102'))
        assert_equal(false,IP.private?('202.108.92.171'))
        assert_equal(false,IP.private?('55.102.34.12'))
    end
end
