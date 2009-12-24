module SuperGossip ; module DAO
    # This class provides an interface accessing routing entry in SQLite3 database. *It should keep that there only one row in the table.*
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
        def addOrUpdate(routing)
            sql = 'SELECT * FROM routing;'
            result = @db.execute(sql)
            if result.empty?    # add new
                sql = "INSERT INTO routing VALUES(%f,%f,%f,%f,%d);"
            else # update existing one
                sql = "UPDATE routing SET authority=%f, hub=%f, authority_sum=%f, hub_sum=%f, is_supernode=%d;"
            end
            sql = sql % [routing.authority, routing.hub, routing.authority_sum, routing.hub_sum, if routing.supernode?; 1; else 0; end] 
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
                    routing.authority_sum = row[2].to_f
                    routing.hub_sum = row[3].to_f
                    routing.supernode = (row[4].to_i != 0)
                end
                routing
            end
        end
    end
end ; end
