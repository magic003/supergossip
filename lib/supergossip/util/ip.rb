require 'ipaddr'
# This module provides some useful methods for IP address.
module IP
    # Array of private IP address ranges.
    PRIVATE_IPS = [
        IPAddr.new('10.0.0.0/8'),
        IPAddr.new('172.16.0.0/12'),
        IPAddr.new('192.168.0.0/16')]

    # Gets the local IP address of the machine. Different operating systems 
    # should use different methods, so it identifies the platform by global
    # variable +RUBY_PLATFORM+. It returns the IP address in human readable
    # string format. Returns +nil+ if failed.
    #
    # *Currently, it only support Linux and Windows systems.*
    def self.local_ip
        if RUBY_PLATFORM.downcase.include?('linux')
            output = %x{/sbin/ifconfig}
            output.split(/^\S/).each do |str|
                if str =~ /inet addr:(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/
                    ip = $1
                    unless ip.start_with?('127')
                        return ip
                    end
                end
            end
        else    # For Windows
            output = %x{ipconfig}
            output.split(/^\S/).each do |str|
                if str =~ /IP Addrees.*: (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/
                    ip = $1
                    unless ip.start_with?('127')
                        return ip
                    end
                end
            end
        end
        nil
    end
    
    # Returns +true+ if the +ip+ is a private address. Otherwise returns 
    # +false+.
    def self.private?(ip)
        ip_addr = IPAddr.new(ip)
        if ip_addr.ipv4?
            PRIVATE_IPS.each do |i|
                return true if i.include?(ip_addr)
            end
        end
        false
    end

    # Return +true+ if the +ip+ is a public address. Otherwise returns +false+.
    def self.public?(ip)
        !self.private?(ip)
    end
end
