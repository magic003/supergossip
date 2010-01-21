module SuperGossip ; module DAO
    # This class provides an interface accessing user entity in SQLite3 
    # database.
    # A +SQLite3::Database+ object should be provided when initialized.
    # 
    # Code snippet:
    #
    #   db = SQLite3::Database.new("data.db")
    #   userDAO = UserDAO.new(db)
    #   ...
    #   db.close
    class UserDAO
        def initialize(db)
            @db = db
        end

        # Adds a new user or updates an existing one. It guarantees that only
        # one user exsits in the table.
        def add_or_update(user)
            # Make sure there is not user available
            sql = "SELECT * FROM user;"
            result = @db.execute(sql)
            # FIXME should raise an exception?
            return false unless result.empty? || result[0][0]==user.guid

            if result.empty?    # add a new one
                sql = "INSERT INTO user(guid,name,password) VALUES('%s','%s','%s');"\
                    % [user.guid,user.name,user.password]
            else
                sql = "UPDATE user SET name='%s', password='%s', online_hours=%d WHERE guid='%s';"\
                    % [user.name,user.password,user.online_hours,user.guid]
            end
            @db.execute(sql)
            true
        end
        
        # Get the unique user in the database. Return +nil+ if not available.
        def find
            sql = 'SELECT * FROM user;'
            result = @db.execute(sql)
            unless result.empty?
                user = Model::User.new
                user.guid = result[0][0]
                user.name = result[0][1]
                user.password = result[0][2]
                user.online_hours = result[0][3].to_i
                user.register_date = DateTime.parse(result[0][4])
                return user
            end
            nil
        end

        # Delete all users from the database
        def self.delete(db)
            sql = 'DELETE FROM user;'
            db.execute(sql)
        end
    end
end; end
