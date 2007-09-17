# nuweb build tasks

desc "Generate Ruby code"
task :tangle => Dir['source/*.w'].collect{|fn| fn.gsub /\.w/,'.ws'}+Dir['source/lib/**/*.rb'].collect{|fn| fn.gsub('source/lib/','lib/')}+[:test]

# directory 'lib'
# directory 'lib/nio'
# directory 'source/pdf'

rule '.ws' => ['.w'] do |t|
  puts "build dir: #{Dir.pwd}"
  puts "nuweb -t #{t.source}"
  puts `nuweb -t #{t.source}`
   File.open(t.name,'w'){|f| f.puts "sentinel"}
end

clean_exts = ['*.tex','*.dvi','*.log','*.aux','*.out','*.ws']

desc "clean up files"
task :clean_nuweb do |t| # to do: integrate in hoe clean
  rm_r clean_exts.collect{|x| Dir.glob('*'+x)+Dir.glob('source/*'+x)+Dir.glob('source/pdf/*'+x)}.flatten
end

desc "Generate source code (nuweb) documentation"
task :weave => ['source/pdf'] + Dir['source/*.w'].collect{|fn| fn.gsub(/\.w/,'.pdf').gsub('source/','source/pdf/')}

def rem_ext(fn, ext)
  ext = File.extname(fn) unless fn
  File.join(File.dirname(fn),File.basename(fn,ext))
end

def sub_dir(dir, fn)
  d,n = File.split(fn)
  File.join(d,File.join(dir,n))
end

def rep_dir(dir, fn)
  File.join(dir, File.basename(fn))
end

#note that if latex is run from the base directory and the file is in a subdirectory (source)
# .aux/.out/.log files are created in the subdirectory and won't be found by the second
# pass of latex;
def w_to_pdf(s)
  fn = rem_ext(s,'.w')
  puts "dir: #{File.dirname(fn)}"
  doc_dir = File.dirname(fn)!='.' ? './pdf' : '../source/pdf'
  cd(File.dirname(fn)) do
    fn = File.basename(fn)
    2.times do
      puts "nuweb -o -l #{fn}.w"
      puts `nuweb -o -l #{fn}.w`
      puts "latex #{fn}.tex"
      puts `latex #{fn}.tex` # problem: stdout disappears...
      puts "dvipdfm -o #{rep_dir(doc_dir,fn)}.pdf #{fn}.dvi"
     puts `dvipdfm -o #{rep_dir(doc_dir,fn)}.pdf #{fn}.dvi`
    end
  end
end

rule '.pdf' => [proc{|tn| File.join('source',File.basename(tn,'.pdf')+'.w')}] do |t|
  w_to_pdf t.source
end

rule /\Alib\/.*\.rb/ =>[proc{|tn| tn.sub(/\Alib\//, 'source/lib/') }]  do |t|
  cp t.source, t.name  if t.source
end

