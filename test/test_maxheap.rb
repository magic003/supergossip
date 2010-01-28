require 'test_helper'

# This is the test cases for max heap.
class TestMaxHeap < Test::Unit::TestCase
    def setup
        @arr = [10,3,5,7,6,20,4,5,6]
        @arr_sorted = @arr.sort
        @reverse_comp = Proc.new { |x,y| y<=>x}
    end

    def test_initialize
        heap = MaxHeap.new
        assert_equal(0,heap.size)
        
        heap = MaxHeap.new(@arr.clone)
        assert_equal(@arr.size,heap.size)

        heap = MaxHeap.new(@arr.clone,@reverse_comp)
        assert_equal(@arr.size,heap.size)
    end

    def test_buid_heap
        heap = MaxHeap.new(@arr.clone)
        i = @arr_sorted.size-1
        while i>=0
            assert_equal(@arr_sorted[i],heap.shift)
            i -= 1
        end

        heap = MaxHeap.new(@arr.clone,@reverse_comp)
        i = 0
        while i<@arr_sorted.size
            assert_equal(@arr_sorted[i],heap.shift)
            i += 1
        end
    end

    def test_first
        heap = MaxHeap.new
        assert_nil(heap.first)

        heap = MaxHeap.new(@arr.clone)
        assert_equal(@arr_sorted[@arr_sorted.size-1],heap.first)
    end

    def test_add
        heap = MaxHeap.new
        @arr.each do |e|
            heap.add(e)
        end
        i = @arr_sorted.size-1
        while i>=0
            assert_equal(@arr_sorted[i],heap.shift)
            i -= 1
        end

        heap = MaxHeap.new(@arr.clone)
        add_arr = [200,0,5]
        add_arr.each do |e|
            heap.add(e)
        end
        new_arr = @arr+add_arr
        new_arr.sort!
        i = new_arr.size-1
        while i>=0
            assert_equal(new_arr[i],heap.shift)
            i -= 1
        end
    end

    def test_delete
        heap = MaxHeap.new(@arr.clone)
        assert_nil(heap.delete(200))

        deleted = heap.delete(5)
        assert_equal(5,deleted)
        @arr_sorted.delete(5)
        i = @arr_sorted.size-1
        while i>=0
            assert_equal(@arr_sorted[i],heap.shift)
            i -= 1
        end
    end
end
