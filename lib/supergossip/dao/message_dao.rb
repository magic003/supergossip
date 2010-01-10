require 'date'

module SuperGossip ; module DAO
    # This class provides an interface accessing message entity in SQLite3 
    # database. A +SQLite3::Database+ object should be provided.
    #
    # Code snippet:
    #
    #   db = SQLite3::Database.new('data.db')
    #   message_dao = MessageDAO.new(db)
    #   ...
    #   db.close
    class MessageDAO
        def initialize(db)
            @db = db
        end

        # Add a new +Message+.
        def add(message)
            sql = "INSERT INTO message(guid,content,direction,time) VALUES('%s','%s',%d,'%s');"\
                % [message.guid,message.content,message.direction,message.time]
            @db.execute(sql)
        end

        # Get the number of messages with node +guid+. If +guid+ is +nil+, 
        # return the number of all messages.
        def message_count(guid=nil)
            sql = "SELECT count(*) FROM message"
            unless guid.nil?
                sql << " WHERE guid='#{guid}'"
            end
            sql << ';'
            result = @db.execute(sql)
            result[0][0].to_i
        end
    end
end ; end
