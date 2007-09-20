input = File.read('show_nio.rb')
File.open('show.txt','a') do |file|
  
  #$stdout = file
  out = StringIO.new

  # vars must be predefined
  x = y = z = fmt = nil
  
  indent = 4
  align = 60

  input.each do |line|
    file.write line.chomp
    $stdout = StringIO.new
    eval line
    out = $stdout.string
    unless out.empty?
      file.write " "*[0,(align-line.size)].max + " -> " + out.chomp
    end
    file.write "\n"    
  end
  $stdout = STDOUT

end

