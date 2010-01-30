require 'date'

module SuperGossip; module DAO
    # This class provides an interface accessing routing entry in SQLite3 
    # database. *It should keep that there only one row in the table.*
    # A +SQLite3::Database+ object should be provided when initialized.
    #
    # Code snippet:
    #
    #   db = SQLite3::Database.new("data.db")
    #   routingDAO = RoutingDAO.new(db)
    #   ...
    #   db.close
    class RoutingDAO
        def initialize(db)
            @db = db
        end

        # Add a new +Routing+ record or update an existing one
        def add_or_update(routing)
            sql = 'SELECT * FROM routing;'
            result = @db.execute(sql)
            if result.empty?    # add new
                sql = "INSERT INTO routing VALUES(%f,%f,%f,%f,%d,'%s');"
            else # update existing one
                sql = "UPDATE routing SET authority=%f, hub=%f, authority_prime=%f, hub_prime=%f, is_supernode=%d, last_update='%s';"
            end
            sql = sql % [routing.authority, routing.hub, routing.authority_prime, routing.hub_prime, routing.supernode? ? 1 : 0,routing.last_update.to_s] 
            @db.execute(sql)
        end

        # Get the single +Routing+ record. Return +nil+ if not exists.
        def find
            sql = 'SELECT * FROM routing;'
            result = @db.execute(sql)
            if result.empty?
                nil
            else
                routing = Model::Routing.new
                result.each do |row|     # result should have one row at most
                    routing.authority = row[0].to_f
                    routing.hub = row[1].to_f
                    routing.authority_prime = row[2].to_f
                    routing.hub_prime = row[3].to_f
                    routing.supernode = (row[4].to_i != 0)
                    routing.last_update = DateTime.parse(row[5])
                end
                routing
            end
        end
    end
end ; end
