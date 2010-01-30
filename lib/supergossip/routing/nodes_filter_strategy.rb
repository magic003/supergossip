module SuperGossip ; module Routing
    # It selects a couple of nodes from a collection of them using IP prefix
    # strategy. It compares the prefix of IP address with that of target 
    # socket, and selects a number of most match ones to return.
    class IPPrefixStrategy
        # Selects +count+ nodes from the set +nodes+ with most match +ip+
        # prefix. If the size of +nodes+ is less than +count+, just returns
        # all of them. An array of nodes will be returned, and they are NOT
        # sorted in prefix order.
        def filter(ip,nodes,count) 
            # If size of +nodes+ is less than count, we don't
            # bother to run the algorithm.
            if nodes.size <= count
                nodes
            else
                # Uses a minimum heap to keep the ones to be returned.
                # Each element in the heap is an array of size two. The
                # first one is the match count, and the second one if the
                # node. So the comparator compares the first element.
                comparator = Proc.new {|x,y| y[0]<=>x[0]}
                heap = MaxHeap.new([],comparator)
                nodes.each do |node|
                    m = matches(node.address.public_ip,ip)
                    if heap.size < count
                        heap.add([m,node])
                    else
                        if m > heap.first[0]
                            heap.shift
                            heap.add([m,node])
                        end
                    end
                end

                # Retrieves nodes from heap
                result = []
                heap.to_a.each do |elem|
                    result << elem[1]
                end
                result
            end
        end

        private

        # Compares the +address+ to the +target+ IP address, and returns
        # the number of prefix digits shared by both of them.
        def matches(address,target) 
            count = 0
            i = j = 0
            while i < target.size and j < address.size
                if target[i] == address[j]
                    count += 1 unless target[i] == '.'
                    i += 1
                    j += 1
                elsif target[i] == '.'
                    i += 1
                elsif address[j] == '.'
                    j += 1
                else
                    break
                end
            end
            count
        end
    end
end; end
