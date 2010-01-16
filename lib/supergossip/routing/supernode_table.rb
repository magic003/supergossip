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
        def add(sn)
            is_added = false
            @lock.synchronize do
                # Try authority set
                index = SupernodeTable.binary_insert(@a_set,sn.score_a)
                if index < @a_set.length   # can be accepted
                    @a_set.insert(index,sn)
                    @a_hash[sn.guid] = sn
                    is_added = true
                end
                # the set size excesses the maximum size
                if @a_set.length > @max_authority_size      
                    # remove the last one
                    sn_delete = @a_set.pop
                    @a_hash.delete(sn_delete.guid)
                    sn_delete.socket.close    # close the socket
                end

                # Try hub set
                index = SupernodeTable.binary_insert(@h_set,sn.score_h)
                if index < @h_set.length     # can be accepted
                    @h_set.insert(index,sn)
                    @h_hash[sn.guid] = sn
                    is_added = true
                end
                # the set size excesses the maximum size
                if @h_set.length > @max_hub_size
                    sn_delete = @h_set.pop
                    @h_hash.delete(sn_delete.guid)
                    sn_delete.socket.close    # close the socket
                end
            end
            return is_added
        end
        
        # Get the supernodes in this table. If block is given, it provides each supernode
        # to it. If not given, return an array of supernodes.
        def supernodes
            @lock.synchronize do
                a_set_copy = @a_set.clone
                h_set_copy = @h_set.clone
            end
            # remove the duplicated entries
            a_set_copy.delete_if { |ele| h_set_copy.include?(ele) }
            a_set_copy.concat(h_set_copy)
            if block_give?
                a_set_copy.each do |ele|
                    yield ele
                end
            else 
                sns = []
                a_set_copy.each do |ele|
                    sns << ele
                end
                sns
            end
        end

        # Check whether this table includes the supernode. It only checks 
        # the +guid+.
        def include?(sn)
            @a_hash.has_key?(sn.guid) || @h_hash.has_key?(sn.guid)
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
    end
end ; end
