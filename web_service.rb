require 'sinatra'

#srand 1234

configure do
  set :logging, nil
end

# считает долго, но есть гарантия на результат
get '/sum/:a/:b' do |a, b|
  puts "searching #{a} + #{b}..."
  compute_duration = rand(1..3)
  sleep compute_duration
  res = a.to_i + b.to_i
  puts "find #{a} + #{b} = #{res} in #{compute_duration}"
  res.to_s
end

# считает быстро, но падает в 1 из 3 случаев :(
get '/fast_sum/:a/:b' do |a, b|
  puts "seaching #{a} + #{b}..."
  compute_duration = rand(0..1)
  sleep compute_duration

  if rand(0..3) == 0
    raise 'storage error'
  end

  res = a.to_i + b.to_i
  puts "done #{a} + #{b} = #{res} in #{compute_duration}"
  res.to_s
end
