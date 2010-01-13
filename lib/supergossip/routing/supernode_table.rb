require 'thread'

module SuperGossip ; module Routing
    # This is the supernode table that each node should have. It manages the
    # supernodes connecting to the node. It consists of authority set and hub
    # set. If any set exceeds the maximum size, it decides to discard some
    # supernodes. New supernode can be added to this table. 
    #
    # This class should be *thread safe*.
    class SupernodeTable
        def initialize(authority_max_size,hub_max_size)
            @max_authority_size = authority_max_size
            @a_set = []
            @a_hash = {}

            @max_hub_size = hub_max_size
            @h_set = []
            @a_hash = {}

            @lock = Mutex.new
        end

        # Attempt to add a new supernode. After checking the current table size
        # and comparing the scores with the existing ones, it decides whether
        # to accept this new one. Returns +true+ if accepted, otherwise +false+.
        def add(guid,sock,authority_score,hub_score)
            is_added = false
            @lock.synchronize do
                # Try authority set
                index = SupernodeTable.binary_insert(@a_set,authority_score)
                if index < @a_set.length   # can be accepted
                    entry = Entry.new(guid,authority_score,sock)
                    @a_set.insert(index,entry)
                    @a_hash[guid] = entry
                    is_added = true
                end
                # the set size excesses the maximum size
                if @a_set.length > @max_authority_size      
                    # remove the last one
                    entry = @a_set.pop
                    @a_hash.delete(entry.guid)
                    entry.sock.close    # close the socket
                end

                # Try hub set
                index = SupernodeTable.binary_insert(@h_set,hub_score)
                if index < @h_set.length     # can be accepted
                    entry = Entry.new(guid,hub_score,sock)
                    @h_set.insert(index,entry)
                    @h_hash[guid] = entry
                    is_added = true
                end
                # the set size excesses the maximum size
                if @h_set.length > @max_hub_size
                    entry = @h_set.pop
                    @h_hash.delete(entry.guid)
                    entry.sock.close    # close the socket
                end
            end
            return is_added
        end
        
        private

        # Find the right place to insert entry into the set. Return the index
        # to be inserted at.
        def self.binary_insert(set,score)
            start = 0
            end_ = score.length-1
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

        # Entry holding the connection information in the supernode table.
        class Entry # :nodoc:
            attr_reader :score, :sock

            def initialize(guid,score,sock)
                @guid = guid
                @score = score
                @sock = sock
            end
        end
    end
end ; end
