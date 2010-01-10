# This module provides the logger solution in this project. Any class or module
# can add logger support by including it. After included, it adds a class
# variable +logger+ and a class method +log+ to the including class or module.
# Before using the +log+ method, should set +logger+ for the including class.
module Log
    def Log.includes(base)
        base.extend ClassMethods
    end

    module ClassMethods
        attr_accessor :logger
        # A wrapper for logger. If logger is not +nil+, pass it to the block. 
        # Otherwise, print an error message.
        def log
            if !@logger.nil? && block_given?
                yield @logger
            elsif @logger.nil?
                STDERR.puts "No logger provided!"
            end
        end
    end
end
