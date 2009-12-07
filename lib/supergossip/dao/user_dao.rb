module SuperGossip ; module DAO
    # This class provides an interface accessing user entity in SQLite3 database.
    # A +SQLite3::Database+ object should be provided when initialized.
    # 
    # Code snippet:
    #
    #   db = SQLite2::Database.new("data.db")
    #   userDAO = UserDAO.new(db)
    #   ...
    #   db.close
    class UserDAO
        def initialize(db)
            @db = db
        end

        # Add a new user to database
        def add(user)
            sql = "INSERT INTO user(guid,name,password) VALUES('%s','%s','%s');"\
                    % [user.guid,user.name,user.password]
            @db.execute(sql)
        end
    end
end; end
