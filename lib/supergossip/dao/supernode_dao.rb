require 'date'

module SuperGossip ; module DAO
    # This class provides an interface accessing supernode cache in SQLite3 
    # database.
    # A +SQLite3::Database+ object should be provided when initialized.
    # *Although this class performs operations on +supernode_cache+ table,
    # it only accepts and returns the object of +Model::Peer+.*
    #
    # Code snippet:
    #
    #   db = SQLite3::Database.new("data.db")
    #   supernode_dao = SupernodeDAO.new(db)
    #   ...
    #   db.close
    class SupernodeDAO
        def initialize(db)
            @db = db
        end

        # Add a new +supernode+ or update an existing one.
        def add_or_update(supernode)
            sql = "SELECT * FROM supernode_cache WHERE guid='#{supernode.guid}';"
            result = @db.execute(sql)
            if result.empty?    # add new
                sql = "INSERT INTO supernode_cache VALUES('%s','%s',%f,%f,%f,%f,%f,'%s','%s',%d,'%s',%d);"\
                    % [supernode.guid,supernode.name,supernode.authority,supernode.hub,supernode.score_a,supernode.score_h,supernode.latency,supernode.last_update.to_s,supernode.address.public_ip,supernode.address.public_port,supernode.address.private_ip,supernode.address.private_port]
            else    # update existing one
                sql = "UPDATE supernode_cache SET name='%s',authority=%f, hub=%f, score_a=%f, score_h=%f, latency=%f, last_update='%s', public_ip='%s', public_port=%d, private_ip='%s', private_port=%d WHERE guid='%s';" \
                    % [supernode.name,supernode.authority, supernode.hub, supernode.score_a, supernode.score_h, supernode.latency, supernode.last_update.to_s, supernode.address.public_ip, supernode.address.public_port, supernode.address.private_ip, supernode.address.private_port, supernode.guid]
            end
            @db.execute(sql)
        end

        # Get a supernode by GUID. Return +nil+ if not found.
        def find_by_guid(guid)
            sql = "SELECT * FROM supernode_cache WHERE guid='#{guid}';"
            result = @db.execute(sql)
            if result.empty?
                nil
            else
                supernode = Model::Peer.new
                supernode.guid = guid
                result.each do |row|    # should be only one row
                    supernode.name = row[1]
                    supernode.authority = row[2].to_f
                    supernode.hub = row[3].to_f
                    supernode.score_a = row[4].to_f
                    supernode.score_h = row[5].to_f
                    supernode.latency = row[6].to_f
                    supernode.last_update = DateTime.parse(row[7])
                    supernode.address = Model::NodeAddress.new(row[8],row[9].to_i,row[10],row[11].to_i)
                end
                supernode.supernode=true
                supernode
            end
        end

        # Get a list of supernodes from cache, with max size +limit+ and 
        # from +offset+. The list is sorted in descent order of +last_update+. 
        # Return an empty list of no supernode available.
        def find(limit,offset)
            sql = "SELECT * FROM supernode_cache ORDER BY last_update DESC LIMIT #{limit} OFFSET #{offset};"
            result = @db.execute(sql)
            supernodes = []
            result.each do |row|
                sn = Model::Peer.new
                sn.guid = row[0]
                sn.name = row[1]
                sn.authority = row[2].to_f
                sn.hub = row[3].to_f
                sn.score_a = row[4].to_f
                sn.score_h = row[5].to_f
                sn.latency = row[6].to_f
                sn.last_update = DateTime.parse(row[7])
                sn.address = Model::NodeAddress.new(row[8],row[9].to_i,row[10],row[11].to_i)
                sn.supernode=true
                supernodes << sn
            end
            supernodes
        end
    end
end ; end
