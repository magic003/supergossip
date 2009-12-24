require 'date'

module SuperGossip ; module DAO
    # This class provides an interface accessing neighbors in SQLite3 database.
    # A +SQLite3::Database+ object should be provided when initialized.
    #
    # Code snippet:
    #
    #   db = SQLite3::Database.new("data.db")
    #   neighborDAO = NeighborDAO.new(db)
    #   ...
    #   db.close
    class NeighborDAO
        def initialize(db)
            @db = db
        end

        # Add a new +Neighbor+ or update an existing one
        def addOrUpdate(neighbor)
            sql = "SELECT * FROM neighbors WHERE guid='#{neighbor.guid}';"
            result = @db.execute(sql)
            if result.empty?    # add new
                sql = "INSERT INTO neighbors VALUES('%s',%f,%f,%f,%f,%d,'%s');" \
                    % [neighbor.guid,neighbor.authority,neighbor.hub,neighbor.authority_sum,neighbor.hub_sum,neighbor.direction,neighbor.last_update.to_s]
            else    # update existing one
                sql = "UPDATE neighbors SET authority=%f, hub=%f,authority_sum=%f,hub_sum=%f,direction=%d,last_update='%s' WHERE guid='%s';" \
                    % [neighbor.authority,neighbor.hub,neighbor.authority_sum,neighbor.hub_sum,neighbor.direction,neighbor.last_update.to_s,neighbor.guid]
            end
            @db.execute(sql)
        end

        # Find +Neighbor+ by GUID. Return +nil+ if no found.
        def findByGuid(guid)
            sql = "SELECT * FROM neighbors WHERE guid='#{guid}';"
            result = @db.execute(sql)
            if result.empty?
                nil
            else
                neighbor = Model::Neighbor.new
                neighbor.guid = guid
                result.each do |row|    # should be only one row
                    neighbor.authority = row[1].to_f
                    neighbor.hub = row[2].to_f
                    neighbor.authority_sum = row[3].to_f
                    neighbor.hub_sum = row[4].to_f
                    neighbor.direction = row[5].to_i
                    neighbor.last_update = DateTime.parse(row[6])
                end
                neighbor
            end
        end
    end
end ; end
