# Предистория

Вам понадобилось посчитать значение функции `f(a, b, c, d) = (a * b) + (c * d)`. Для подсчета имеется вебсервис(файл web_service.rb), но вот не задача данный сервис умеет только суммировать и то только по 2 числа, да ещё и время ожидания большое, а быстрый метод так вообще падает в 1 из 3 случаев...

Веб сервис запускается с помощью комманды `bundle exec puma -C ./puma.rb`, можно потестировать `curl http://localhost:9292/sum/1/2` или  `curl http://localhost:9292/fast_sum/1/2`.

## Решение "в лоб" (файл computer.rb)

Для решения данной задачи нужно для начала подготовить классы, с помощью которых, будем обращаться к сервису.

### Класс HttpFetcher

С помощью данного класса мы будем обращаться к сервису.

```ruby
class HttpFetcher
  def fetch(url)
    HTTP.get(url)
  end
end

# Вызывается вот так:
puts HttpFetcher.new.fetch('http://localhost:9292/sum/1/2').to_s
# => "3"
```

### Стоп, а как мы будем умножать?

Умножение представляется через операцию сложения: `4 * 3 = 4 + 4 + 4`

### Класс Plus

```ruby
class Plus
  def compute(a, b)
    fetcher = HttpFetcher.new
    result = fetcher.fetch("http://localhost:9292/sum/#{a}/#{b}")
    result.to_s.to_i
  end
end

# И вызов
puts Plus.new.compute(3, 7)
# => 10
```

### Класс Mult

```ruby
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

# Вызов
puts Mult.new.compute(2, 9)
# спустя некоторое время...
# => 18
```

### Собствено наша функция:

```ruby
class F
  def compute(a, b, c, d)
    a_b_mult = Mult.new.compute(a, b)
    c_d_mult = Mult.new.compute(c, d)

    Plus.new.compute(a_b_mult, c_d_mult)
  end
end

puts F.new.compute(3, 5, 7, 11)
```

### Первый запуск

```
$ time bundle exec ruby computer.rb
92

real    0m50.574s
user    0m3.568s
sys     0m0.304s
```

50 секунд, чтобы посчитать `(3 * 5) + (7 * 11)`, что-то долго очень...


Если обратить своё внимание на консоль с запущенным сервисом, то видно, что запросы идут один за другим, но ведь операция умножения может быть распараллелена.

## Celluloid

Библиотека celluloid поддерживает несколько способов, позволяющих прозрачно работать с потоками. Для начала нам очень интересны футуры: мы сможем насоздавать кучу параллельных вызовов(операции суммирования в методе Mult#compute) и потом их все собрать. И еще мы будем вызывать операции умножения в классе F так же параллельно.

Для того, чтобы начать работать нам примешать модуль Celluloid в класс, который будет вызываться в несколько потоков. У нас это классы Plus и Mult. Ну и еще, чтобы получить полный профит мы будем использовать возможноть библиотеки http поддерживать Celluloid либо нужно будет примешивать Celluloid::IO во все классы использующие IO.

Для вызова и получения результата будет ипользоваться следующас схема:

```ruby
class A
  include Celluloid

  def hard_work
    sleep 5 # заметка: тут происходит вызов Celluloid.sleep, а не Kernel.sleep
  end
end

a = A.new
# создаем футуру, не происходит блокировки
future = a.future.hard_work
# сообщение выводится сразу
puts "Воркер создан"
# получаем вичисленное значение(происходит блокировка до момента завершения вычисления)
puts future.value
```

## Многопоточный вычислитель(parallel-computer.rb)

Для начала примешаем Celluloid в класс HttpFetcher и научим использовать сокеты из пакета `celluloid-io`.

```ruby
class HttpFetcher
  include Celluloid

  def fetch(url)
    HTTP.get(url, :socket_class => Celluloid::IO::TCPSocket)
  end
end
```

С классом Plus все ещё проще: нужно только примешат Celluloid

```ruby
class Plus
  include Celluloid
  # остальное остается как есть
```

Для класса Mult, кроме того что, нужно примешать Celluloid, также нужно обучить вызывать Plus#compute параллельно для каждой пары чисел.

```ruby
class Mult
  include Celluloid

  def compute
    # ...
    # вносим небольшое изменение в метод #compute
    # меняем следующие строчки
    #  sequence = sequence.each_slice(2).map do |pair|
    #    Plus.new.compute(pair[0], pair[1])
    #  end

    sequence = sequence.each_slice(2).map do |pair|
      # производим вызов в отдельном потоке
      Plus.new.future.compute(pair[0], pair[1])
    end.map(&:value) # аггрегируем результаты

    # дальше все остается как есть
```

Ну и последнее изменение в нашей программе - обучаем класс F работать с футурами

```ruby
class F
  def compute(a, b, c, d)
    # вызываем операции умножения в отдельных потоках
    a_b_mult = Mult.new.future.compute(a, b)
    c_d_mult = Mult.new.future.compute(c, d)

    # собираем результаты
    Plus.new.compute(a_b_mult.value, c_d_mult.value)
  end
end
```

И теперь самое интересное: как быстро выполнится наша программа?

```
$ time bundle exec ruby parallel-computer.rb
92

real    0m17.162s
user    0m3.968s
sys     0m0.288s
```

17 секунд! мы ускорили нашу программу в 3 раза!
