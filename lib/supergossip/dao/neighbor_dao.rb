require 'date'

module SuperGossip ; module DAO
    # This class provides an interface accessing neighbors in SQLite3 database.
    # A +SQLite3::Database+ object should be provided when initialized.
    # *Although this class performs operations on +neighbor+ table,
    # it only accepts and returns the object of +Model::Peer+.*
    #
    # Code snippet:
    #
    #   db = SQLite3::Database.new("data.db")
    #   neighbor_dao = NeighborDAO.new(db)
    #   ...
    #   db.close
    class NeighborDAO
        def initialize(db)
            @db = db
        end

        # Add a new neighbor or update an existing one.
        def add_or_update(neighbor)
            sql = "SELECT * FROM neighbor WHERE guid='#{neighbor.guid}';"
            result = @db.execute(sql)
            if result.empty?    # add new
                sql = "INSERT INTO neighbor VALUES('%s','%s',%f,%f,%f,%f,%d,'%s');" \
                    % [neighbor.guid,neighbor.name,neighbor.authority,neighbor.hub,neighbor.authority_prime,neighbor.hub_prime,neighbor.direction,neighbor.last_update.to_s]
            else    # update existing one
                sql = "UPDATE neighbor SET name='%s',authority=%f, hub=%f,authority_prime=%f,hub_prime=%f,direction=%d,last_update='%s' WHERE guid='%s';" \
                    % [neighbor.name,neighbor.authority,neighbor.hub,neighbor.authority_prime,neighbor.hub_prime,neighbor.direction,neighbor.last_update.to_s,neighbor.guid]
            end
            @db.execute(sql)
        end

        # Find neighbor by +guid+. Return +nil+ if no found.
        def find_by_guid(guid)
            sql = "SELECT * FROM neighbor WHERE guid='#{guid}';"
            result = @db.execute(sql)
            if result.empty?
                nil
            else
                neighbor = Model::Peer.new
                neighbor.guid = guid
                result.each do |row|    # should be only one row
                    neighbor.name = row[1]
                    neighbor.authority = row[2].to_f
                    neighbor.hub = row[3].to_f
                    neighbor.authority_prime = row[4].to_f
                    neighbor.hub_prime = row[5].to_f
                    neighbor.direction = row[6].to_i
                    neighbor.last_update = DateTime.parse(row[7])
                end
                neighbor
            end
        end

        # Find all the neighbors.
        def find_all
            sql = "SELECT * FROM neighbor;"
            result = @db.execute(sql)
            neighbors = []
            neighbor = Model::Peer.new
            result.each do |row|
                neighbor.guid = row[0]
                neighbor.name = row[1]
                neighbor.authority = row[2].to_f
                neighbor.hub = row[3].to_f
                neighbor.authority_prime = row[4].to_f
                neighbor.hub_prime = row[5].to_f
                neighbor.direction = row[6].to_i
                neighbor.last_update = DateTime.parse(row[7])
                neighbors << neighbor
            end
            neighbors
        end
    end
end ; end
