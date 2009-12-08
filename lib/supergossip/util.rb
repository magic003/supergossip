require File.dirname(__FILE__)+'/util/uuid'

class UUID 
    # Add some methods to class +UUID+.
    class << self
        # Generate a user UUID from +name+ using SHA1. The namespace is generated using random number. So this can guarantee that the UUID is almost unique.
        def user_id name
            namespace = create_random
            ret = create_sha1(name,namespace)
            ret
        end
   end

   # Generate the string representation in compact format.
   def to_s_compact
        a = unpack
        tmp = a[-1].unpack 'C*'
        a[-1] = sprintf '%02x%02x%02x%02x%02x%02x', *tmp
        "%08x%04x%04x%02x%02x%s" % a
   end
 
end
