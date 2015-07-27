require 'celluloid/autostart'
require "celluloid/io"
require "http"

Celluloid.logger = nil

class HttpFetcher
  include Celluloid

  def fetch(url)
    HTTP.get(url, :socket_class => Celluloid::IO::TCPSocket)
  end
end

class Plus
  include Celluloid

  def compute(a, b)
    fetcher = HttpFetcher.new
    result = fetcher.fetch("http://localhost:9292/sum/#{a}/#{b}")
    result.to_s.to_i
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
        # производим вызов в отдельном потоке
        Plus.new.future.compute(pair[0], pair[1])
      end.map(&:value) # аггрегируем результаты
    end

    sequence[0]
  end
end

# f(a, b, c, d) = (a * b) + (c * d)
class F
  def compute(a, b, c, d)
    # вызываем операции умножения в отдельных потоках
    a_b_mult = Mult.new.future.compute(a, b)
    c_d_mult = Mult.new.future.compute(c, d)

    Plus.new.compute(a_b_mult.value, c_d_mult.value)
  end
end

puts F.new.compute(3, 5, 7, 11)
