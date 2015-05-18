require 'sequel'

# Module that contains all of the banking system
module Banking
  # Module that contains everything to do with the database system
  module DB
    # Class containing a few common methods used by various
    # REST classes.
    class Common
      # Single instance of the database connector
      DB = Sequel.connect(adapter: 'mysql2', user: 'user',
                          password: 'password', host: 'localhost',
                          database: 'db')

      # Method to get the DB connector instance
      def self.db_instance
        DB
      end
    end
  end
end
