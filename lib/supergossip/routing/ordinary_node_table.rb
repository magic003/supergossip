require 'thread'

module SuperGossip::Routing
    # This is the ordinary node table that may be maintained by each 
    # supernode. It consists of the ordinary nodes currently connected to
    # it. If the size exceeds the maximum value, it removes the node with
    # most active connections from it.
    class OrdinaryNodeTable
        def initialize(max_size_on_table)
            @max_size = max_size_on_table
            @comparator = 
                Proc.new {|x,y| x.connection_count<=>y.connection_count}
            @table = MaxHeap.new([],@comparator)

            @lock = Mutex.new
        end

        # Attempts to add a ordinary node. It checks if it already exists 
        # first. If so, just updates the table. If the size of this table
        # meets the maximum value, it compares the connection count of the
        # new node with that of the largest one to decide whether removes
        # the largest one or discard the new one. Returns +ture+ if the new
        # node is accepted.
        def add(on)
            if include?(on)
                update(on)
                return true
            end

            @lock.synchronize do
                if @table.size == @max_size
                    unless @comparator.call(on,@table.first) > 0
                        deleted = @table.shift
                        deleted.socket.close

                        @table.add(on)
                        return true
                    end
                else 
                    @table.add(on)
                    return true
                end
            end
            false
        end

        # Updates the properties of the ordinary node.
        def update(on)
            # Just rebuild the table
            @lock.synchronize do
                @table.build_heap
            end
        end

        # Returns +true+ if the nodes is included in this table.
        def include?(on)
            @lock.synchronize { @table.include?(on) }
        end

        # Deletes the ordinary node from _self_.
        def delete(on)
            @lock.synchronize { @table.delete(on) }
        end

        # Get the ordinary nodes in _self_. If a block is given, it provides
        # each node to it. If not given, returns an array of the nodes.
        def nodes
            @lock.synchronize do
                ons = @table.to_a
                if block_given?
                    ons.each do |on|
                        yield on
                    end
                else
                    return ons
                end
            end
        end

        # Returns the size of this table.
        def size
            @table.size
        end

        # Returns +ture+ if this table is empty.
        def empty?
            @table.size==0
        end
    end
end
