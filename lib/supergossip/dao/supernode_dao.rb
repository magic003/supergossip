require 'date'

module SuperGossip ; module DAO
    # This class provides an interface accessing supernode cache in SQLite3 
    # database.
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
                sql = "INSERT INTO supernode_cache VALUES('%s',%f,%f,%f,%f,%f,'%s','%s',%d,'%s',%d);"\
                    % [supernode.guid,supernode.authority,supernode.hub,supernode.score_a,supernode.score_h,supernode.latency,supernode.last_update.to_s,supernode.address.public_ip,supernode.address.public_port,supernode.address.private_ip,supernode.address.private_port]
            else    # update existing one
                sql = "UPDATE supernode_cache SET authority=%f, hub=%f, score_a=%f, score_h=%f, latency=%f, last_update='%s', public_ip='%s', public_port=%d, private_ip='%s', private_port=%d WHERE guid='%s';" \
                    % [supernode.authority, supernode.hub, supernode.score_a, supernode.score_h, supernode.latency, supernode.last_update.to_s, supernode.address.public_ip, supernode.address.public_port, supernode.address.private_ip, supernode.address.private_port, supernode.guid]
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
                    supernode.latency = row[5].to_f
                    supernode.last_update = DateTime.parse(row[6])
                    supernode.address = Model::NodeAddress.new(row[7],row[8].to_i,row[9],row[10].to_i)
                end
                supernode
            end
        end

        # Get a list of +Supernode+ from cache, with max side +limit+ and 
        # from +offset+. The list is sorted in descent order of +last_update+. 
        # Return an empty list of no +Supernode+ available.
        def find(limit,offset)
            sql = "SELECT * FROM supernode_cache ORDER BY last_update DESC LIMIT #{limit} OFFSET #{offset};"
            result = @db.execute(sql)
            supernodes = []
            result.each do |row|
                sn = Model::Supernode.new
                sn.guid = row[0]
                sn.authority = row[1].to_f
                sn.hub = row[2].to_f
                sn.score_a = row[3].to_f
                sn.score_h = row[4].to_f
                sn.latency = row[5].to_f
                sn.last_update = DateTime.parse(row[6])
                sn.address = Model::NodeAddress.new(row[7],row[8].to_i,row[9],row[10].to_i)
                supernodes << sn
            end
            supernodes
        end
    end
end ; end
