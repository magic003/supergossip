# This module provides the utilities about random selections.
module Random
    # Selects a subset of size +count+ from +set+ randomly.
    def self.random_select(set,count)
        # Returns the +set+ if count is larger than the size of +set+.
        return set unless count < set.size
        result = []
        set_clone = set.clone
        while result.size < count
            i = rand(set_clone.size)
            result << set_clone[i]
            set_clone.delete_at(i)
        end
        result
    end
end
