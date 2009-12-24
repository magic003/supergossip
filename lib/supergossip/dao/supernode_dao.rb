require 'date'

module SuperGossip ; module DAO
    # This class provides an interface accessing supernode cache in SQLite3 database.
    # A +SQLite3::Database+ object should be provided when initialized.
    #
    # Code snippet:
    #
    #   db = SQLite3::Database.new("data.db")
    #   supernodeDAO = SupernodeDAO.new(db)
    #   ...
    #   db.close
    class SupernodeDAO
        def initialize(db)
            @db = db
        end

        # Add a new +Supernode+ or update an existing one
        def addOrUpdate(supernode)
            sql = "SELECT * FROM supernode_cache WHERE guid='#{supernode.guid}';"
            result = @db.execute(sql)
            if result.empty?    # add new
                sql = "INSERT INTO supernode_cache VALUES('%s',%f,%f,%f,%f,%d,'%s');"\
                    % [supernode.guid,supernode.authority,supernode.hub,supernode.score_a,supernode.score_h,supernode.latency,supernode.last_update.to_s]
            else    # update existing one
                sql = "UPDATE supernode_cache SET authority=%f, hub=%f, score_a=%f, score_h=%f, latency=%d, last_update='%s' WHERE guid='%s';" \
                    % [supernode.authority, supernode.hub, supernode.score_a, supernode.score_h, supernode.latency, supernode.last_update.to_s, supernode.guid]
            end
            @db.execute(sql)
        end

        # Get a +Supernode+ by GUID. Return +nil+ if not found.
        def findByGuid(guid)
            sql = "SELECT * FROM supernode_cache WHERE guid='#{guid}';"
            result = @db.execute(sql)
            if result.empty?
                nil
            else
                supernode = Model::Supernode.new
                supernode.guid = guid
                result.each do |row|    # should be only one row
                    supernode.authority = row[1].to_f
                    supernode.hub = row[2].to_f
                    supernode.score_a = row[3].to_f
                    supernode.score_h = row[4].to_f
                    supernode.latency = row[5].to_i
                    supernode.last_update = DateTime.parse(row[6])
                end
                supernode
            end
        end
    end
end ; end
