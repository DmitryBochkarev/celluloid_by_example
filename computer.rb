require "http"

class HttpFetcher
  def fetch(url)
    HTTP.get(url)
  end
end


class Plus
  def compute(a, b)
    fetcher = HttpFetcher.new
    result = fetcher.fetch("http://localhost:9292/sum/#{a}/#{b}")
    result.to_s.to_i
  end
end

class Mult
  def compute(a, b)
    # [4] * 3 == [4, 4, 4]
    sequence = [a] * b

    # производим операцию сложения, пока у нас есть хотя бы 1 пара
    while sequence.size > 1 do
      # если у нас не хватает до пары одного числа в последовательности,
      # то просто добавляем 0 в конец
      if sequence.size % 2 == 1
        sequence << 0
      end

      sequence = sequence.each_slice(2).map do |pair|
        Plus.new.compute(pair[0], pair[1])
      end
    end

    sequence[0]
  end
end

# f(a,b,c,d) = (a * b) + (c * d)
class F
  def compute(a, b, c, d)
    a_b_mult = Mult.new.compute(a, b)
    c_d_mult = Mult.new.compute(c, d)

    Plus.new.compute(a_b_mult, c_d_mult)
  end
end

puts F.new.compute(3, 5, 7, 11)
