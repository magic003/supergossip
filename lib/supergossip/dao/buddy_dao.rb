module SuperGossip ; module DAO
    # This class provides an interface accessing buddy entity in SQLite3
    # database. A +SQLite3::Database+ object should be provided.
    #
    # Code snippet:
    #
    #   db = SQLite::Database.new('data.db')
    #   buddy_dao = BuddyDAO.new(db)
    #   ...
    #   db.close
    class BuddyDAO
        def initialize(db)
            @db = db
        end

        # Add a new +Buddy+ or update the relationship of an existing one.
        def add_or_update(buddy)
            sql = "SELECT * FROM buddy WHERE guid='#{buddy.guid}';"
            result = @db.execute(sql)
            if result.empty?    # add a new one
                sql = "INSERT INTO buddy VALUES('%s',%d);"\
                    % [buddy.guid,buddy.relationship]
            else
                buddy.relationship |= result[0][1].to_i  # update old relationship
                sql = "UPDATE buddy SET relationship=%d WHERE guid='%s';"\
                    % [buddy.relationship,buddy.guid]
            end
            @db.execute(sql)
        end

        # Get a +Buddy+ by GUID. Return +nil+ if not found.
        def find_by_guid(guid)
            sql = "SELECT * FROM buddy WHERE guid='#{guid}';"
            result = @db.execute(sql)
            unless result.empty?
                buddy = Model::Buddy.new
                buddy.guid = result[0][0]
                buddy.relationship = result[0][1].to_i
                return buddy
            end
            nil
        end

        # Get the number of followings.
        def following_count
            sql = "SELECT count(guid) FROM buddy WHERE relationship=#{Model::Buddy::FOLLOWING} or relationship=#{Model::Buddy::BOTH};";
            result = @db.execute(sql)
            result[0][0].to_i
        end

        # Get the number of followers.
        def follower_count
            sql = "SELECT count(guid) FROM buddy WHERE relationship=#{Model::Buddy::FOLLOWER} or relationship=#{Model::Buddy::BOTH};";
            result = @db.execute(sql)
            result[0][0].to_i
        end
    end
end ; end
