module SuperGossip ; module Model
    # This class holds the profile of a user.
    class User
        attr_accessor :guid, :name, :password, :online_hours, :register_date
    end

    # This class holds the following or follower.
    class Buddy
        # Relationship types
        module Relationships
            FOLLOWING = 0x01
            FOLLOWER = 0x02
            BOTH = (FOLLOWING | FOLLOWER)
        end
        include Relationships

        attr_accessor :guid, :relationship
    end

    # This class holds the content of a message.
    class Message
        # Direction types
        module Directions
            TO = 0x01
            FROM = 0x02
        end
        include Directions
        attr_accessor :id, :guid, :content, :direction, :time
    end

end; end
