# This is an implementation of max heap data structure.
class MaxHeap
    # Creates a max heap. An array of initial elements can be provided, and
    # it will heapify them. The +comparator+ is a +Proc+ object, which takes
    # two arguments, and compares them. Returns -1 if the first is smaller,
    # 0 if equal, and 1 if greater. If +comparator+ is not provided, the 
    # +<=>+ method will be called on the elements.
    #
    # Code snippet:
    #
    #   comparator = Proc.new { |x,y| x.abs<=>y.abs }
    #   heap = MaxHeap.new([],comparator)
    def initialize(arr=nil,comparator=nil)
        @elements = arr.nil? ? [] : arr
        @comparator = comparator.nil? ? Proc.new {|x,y| x<=>y} : comparator
        unless @elements.empty?
            build_heap
        end
    end

    # Builds the max heap.
    def build_heap
        unless @elements.empty?
            i = (@elements.size-1)/2
            while i>=0
                heapify(i)
                i -= 1
            end
        end
    end

    # Returns the number of elements.
    def size
        @elements.size
    end

    # First element on the heap. If not element, returns +nil+.
    def first
        @elements.empty? ? nil : @elements[0]
    end

    # Returns the first element and removes it from the heap. Returns +nil+
    # if the heap is empty. It will rearrange the other elements to keep 
    # the heap properties.
    def shift
        if @elements.empty?
            return nil
        end

        swap(0,@elements.size-1)
        ele = @elements.pop
        heapify(0)
        ele
    end

    # Adds a new +element+ to this max heap, and maintains the heap 
    # properties.
    def add(elem)
        @elements << elem
        i = @elements.size-1
        pa = parent(i)
        while i>0 and @comparator.call(@elements[i],@elements[pa]) > 0
            swap(i,pa)
            i = pa
            pa = parent(pa)
        end
    end

    # Returns +ture+ if the element is included in _self_.
    def include?(elem)
        @elements.include?(elem)
    end

    # Deletes the +element+ from this max heap, and maintains the heap
    # properties. If the element is not found, return +nil+.
    def delete(elem)
        deleted = @elements.delete(elem)
        build_heap unless deleted.nil?
        deleted
    end

    # Returns the elements in an +Array+ object.
    def to_a
        @elements.clone
    end

    private

    # Returns the parent index of the element at +i+.
    def parent(i)
        (i-1)/2
    end

    # Returns the right child index of element at +i+.
    def right(i)
        i*2+2
    end

    # Returns the left child index of element at +i+.
    def left(i)
        i*2+1
    end
    
    # Heapifies the element at position +i+.
    def heapify(i)
        left = left(i)
        right = right(i)
        target = i
        if left < @elements.size and @comparator.call(@elements[i],@elements[left]) < 0
            target = left
        end
        if right < @elements.size and @comparator.call(@elements[target],@elements[right]) < 0
            target = right
        end

        unless target == i
            swap(target,i)
            heapify(target)
        end
    end

    # Swaps two elements.
    def swap(i,j)
        tmp = @elements[i]
        @elements[i] = @elements[j]
        @elements[j] = tmp
    end
end
