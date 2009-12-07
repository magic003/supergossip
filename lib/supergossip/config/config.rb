require 'singleton'
require 'yaml'

module SuperGossip ; module Config
    # This class holds the configuration parameters of the system. It's implemented with Singleton pattern, and works like a hash table.
    class Config
        include Singleton

        # Return value by the parameter name. Key should be +String+.
        def [](key)
            @configs[key.to_s]
        end
        # Load parameters from file.
        # *This method should only be called once.*
        def load(file)
            @configs = YAML::load_file(file)
            self
        end
    end
end; end
