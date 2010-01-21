require 'thread'

module SuperGossip ; module Routing
    # It monitors the upload and download bandwidths. It keeps the statistics
    # of uploaded bytes, download bytes, total upload time, total download 
    # time and other related datas. *It is thread safe.*
    #
    # Other parts of this routing module MUST add upload/download bytes and 
    # upload/download time to it after sending/receiving messages, so it can
    # track the bandwidth.
    class BandwidthManager
        attr_reader :uploaded_bytes, :downloaded_bytes

        def initialize
            @uploaded_bytes = 0
            @downloaded_bytes = 0
            @upload_time = 0.0
            @download_time = 0.0
            @lock_up = Mutex.new
            @lock_down = Mutex.new
        end

        # Tells this manager the number of +size+ bytes have been uploaded 
        # in +elapse+ seconds.
        def uploaded(size,elapse) 
            @lock_up.synchronize do
                @uploaded_bytes += size
                @upload_time += elapse
            end
        end

        # Tells this manager the number of +size+ bytes have been downloaded
        # in +elapse+ seconds.
        def downloaded(size,elapse)
            @lock_down.synchronize do
                @downloaded_bytes += size
                @download_time += elapse
            end
        end

        # Returns the average upload bandwidth from this manager is created
        # in bytes per second.
        def upload_bandwidth
            @lock_up.synchronize do
                @uploaded_bytes/@upload_time
            end
        end

        # Returns the average download bandwidth from this manager is created
        # in bytes per second.
        def download_bandwidth
            @lock_down.synchronize do
                @downloaded_bytes/@download_time
            end
        end
    end
end ; end
