require 'thread'

module SuperGossip::Routing
    # This is the supernode table that each node should have. It manages the
    # supernodes connecting to the node. It consists of authority set and hub
    # set. If any set exceeds the maximum size, it decides to discard some
    # supernodes. New supernode can be added to this table. 
    #
    # This class should be *thread safe*.
    class SupernodeTable
        attr_accessor :max_authority_size, :max_hub_size

        def initialize(authority_max_size,hub_max_size)
            @max_authority_size = authority_max_size
            @a_comparator = Proc.new {|x,y| y.score_a<=>x.score_a}
            # Actuall, with the comparator it is a min heap
            @a_set = MaxHeap.new([],@a_comparator)
            @a_hash = {}

            @max_hub_size = hub_max_size
            @h_comparator = Proc.new {|x,y| y.score_h<=>x.score_h}
            # Actuall, with the comparator it is a min heap
            @h_set = MaxHeap.new([],@h_comparator)
            @a_hash = {}

            @lock = Mutex.new
        end

        # Attempts to add a new supernode. Firstly, it checks if it is 
        # already in the table. If yes, it just updates the tables. After 
        # checking the current table size and comparing the scores with 
        # the existing ones, it decides whether to accept this new one. 
        # Returns +true+ if accepted, otherwise +false+.
        def add(sn)
            if include?(sn)
                update(sn)
                return true
            end

            is_added = false
            @lock.synchronize do
                # Try authority set
                if @a_set.size == @max_authority_size
                    # Authority set is full
                    if @a_comparator.call(sn,@a_set.first) < 0
                        sn_delete = @a_set.shift
                        @a_hash.delete(sn_delete.guid)
                        # close the socket if not in the other set
                        sn_delete.socket.close unless @h_hash.key?(sn.guid)

                        @a_set.add(sn)
                        @a_hash[sn.guid] = sn
                        is_added = true
                    end
                else
                    @a_set.add(sn)
                    @a_hash[sn.guid] = sn
                    is_added = true
                end
                    

                # Try hub set
                if @h_set.size == @max_hub_size
                    # Hub set is full
                    if @h_comparator.call(sn,@h_set.first) < 0
                        sn_delete = @h_set.shift
                        @h_hash.delete(sn_delete.guid)
                        # close the socket if not in the other set
                        sn_delete.socket.close unless @a_hash.key?(sn.guid)

                        @h_set.add(sn)
                        @h_hash[sn.guid] = sn
                        is_added = true
                    end
                else
                    @h_set.add(sn)
                    @h_hash[sn.guid] = sn
                    is_added = true
                end
            end
            is_added
        end
        
        # Updates the properties of the supernode.
        def update(sn)
            # Since references to objects are used, just rebuild the 
            # sets without modifying the objects.
            @lock.synchronize do
                @a_set.build_heap if @a_hash.has_key?(sn.guid)
                @h_set.build_heap if @h_hash.has_key?(sn.guid)
            end
        end

        # Deletes the supernode from this table.
        def delete(sn)
            # No harm if not included
            @lock.synchronize do
                @a_set.delete(sn)
                @a_hash.delete(sn.guid)
                @h_set.delete(sn)
                @h_hash.delete(sn.guid)
            end
        end

        # Get the supernodes in this table. If block is given, it provides each supernode
        # to it. If not given, return an array of supernodes.
        def supernodes
            sns = []
            @lock.synchronize do
                sns = @a_hash.values + @h_hash.values
                sns.uniq!
=begin
                # remove the duplicated ones
                @a_hash.each do |key,val|
                    # Cannot use +Array#delete+, it deletes all the items
                    sns.delete_at(sns.index(val)) if @h_hash.has_key?(key)
                end
=end
            end
            if block_given?
                sns.each do |s|
                    yield s
                end
            else 
                sns
            end
        end

        # Check whether this table includes the supernode. It only checks 
        # the +guid+.
        def include?(sn)
            @a_hash.has_key?(sn.guid) || @h_hash.has_key?(sn.guid)
        end

        # Returns the size of this table.
        def size
            size = @a_hash.size + @h_hash.size
            @a_hash.each_key do |key|
                (size -= 1) if @h_hash.has_key?(key)
            end
            size
        end

        # Returns +true+ if this table is empty.
        def empty?
            @a_set.empty? and @h_set.empty?
        end

        private

=begin never used, just retain it for future reference

        # Find the right place to insert entry into the set. Return the index
        # to be inserted at.
        def self.binary_insert(set,score)
            start = 0
            end_ = set.length-1
            index = (start+end_)/2
            while true
                if set[index].score >= score # find it in right hand
                    if index==end_   # last element
                        return end_+1
                    else
                        start = index+1
                    end
                else    # find it in the left hand
                    if index==start     # last element
                        return start
                    else
                        end_ = index-1
                    end
                end
                index = (start+end_)/2
            end
        end
=end
    end
end
