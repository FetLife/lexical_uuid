require "rubygems"
require "socket"
require "inline"

class String
  inline :C do |builder|
    builder.c <<-__END__
      static long fnv1a() {
        long hash = 0xcbf29ce484222325;
        long i = 0;
      
        for(i = 0; i < RSTRING(self)->len; i++) {
          hash ^= RSTRING(self)->ptr[i];
          hash *= 0x100000001b3;
        }

        return hash;
      }
    __END__
  end
end

# Borrowed from the SimpleUUID gem
class Time
  def self.stamp
    Time.now.stamp
  end
  
  def stamp
    to_i * 1_000_000 + usec
  end
end

class LexicalUUID
  class << self
    def worker_id
      @worker_id ||= create_worker_id
    end

    private
      def create_worker_id
        Socket.gethostbyname(Socket.gethostname).first.fnv1a
      end
  end

  attr_reader :worker_id, :timestamp

  def initialize(bytes = nil)
    case bytes
    when String
      time_high, time_low, worker_high, worker_low = bytes.unpack("NNNN")
      @timestamp = (time_high << 32) | time_low
      @worker_id = (worker_high << 32) | worker_low
    when nil
      @worker_id = self.class.worker_id
      @timestamp = Time.stamp
    end
  end

  def to_bytes
    [timestamp >> 32,
     timestamp & 0xffffffff,
     worker_id >> 32,
     worker_id & 0xffffffff].pack("NNNN")
  end
end