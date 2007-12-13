require 'rubygems'
input = File.read('show_nio.rb')
File.open('show.txt','a') do |file|
  
  #$stdout = file
  out = StringIO.new
  
  indent = 4
  align = 60

  input.each do |line|
    file.write line.chomp
    $stdout = StringIO.new
    eval line, TOPLEVEL_BINDING
    out = $stdout.string
    unless out.empty?
      file.write " "*[0,(align-line.size)].max + " -> " + out.chomp
    end
    file.write "\n"    
  end
  $stdout = STDOUT

end

