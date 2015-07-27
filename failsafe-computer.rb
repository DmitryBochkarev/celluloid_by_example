require 'celluloid/autostart'
require "celluloid/io"

Celluloid.logger = nil
#Celluloid.task_class = Celluloid::TaskThread
require "http"

class HttpFetcher
  include Celluloid

  def fetch(url)
    resp = HTTP.get(url, :socket_class => Celluloid::IO::TCPSocket)

    if resp.code != 200
      raise resp.reason
    end

    resp.to_s
  end
end


class Plus
  include Celluloid

  trap_exit :log_error

  def initialize
    @fetcher = HttpFetcher.new_link
  end

  def compute(a, b)
    result = @fetcher.fetch("http://localhost:9292/fast_sum/#{a}/#{b}")
    result.to_s.to_i
  rescue
    @fetcher = HttpFetcher.new_link
    retry
  end

  def log_error(actor, ex)
    if ex
      $stderr.puts ex.message.gsub(/\n\z/, '')
    end
  end
end

class Mult
  include Celluloid

  def compute(a, b)
    sequence = [a] * b

    while sequence.size > 1 do
      if sequence.size % 2 == 1
        sequence << 0
      end

      sequence = sequence.each_slice(2).map do |pair|
        Plus.new_link.future.compute(pair[0], pair[1])
      end.map(&:value)
    end

    sequence[0]
  end
end

# f(a, b, c, d) = (a * b) + (c * d)
class F
  include Celluloid

  def compute(a, b, c, d)
    a_b_mult = Mult.new_link.future.compute(a, b)
    c_d_mult = Mult.new_link.future.compute(c, d)

    Plus.new_link.compute(a_b_mult.value, c_d_mult.value)
  end
end

#puts F.new.compute(7, 137, 43, 73)
#puts F.new.compute(7, 179, 3, 223)
puts F.new.compute(13, 179, 17, 223)
