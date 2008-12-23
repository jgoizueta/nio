# nuweb build tasks
namespace :nuweb do

  desc "Generate Ruby code from nuweb source"
  task :tangle => Dir['source/*.w'].collect{|fn| fn.gsub /\.w/,'.ws'}+
                  Dir['source/lib/**/*.rb'].collect{|fn| fn.gsub('source/lib/','lib/')}+
                  Dir['source/test/**/*'].collect{|fn| fn.gsub('source/test/','test/')}+
                  [:test]

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
  clobber_dirs = ['lib', 'source/pdf', 'test']
  clobber_exceptions = ['test/data.yaml', 'test/test_helper.rb']

  desc "Remove all nuweb generated files"
  task :clobber=>[:clean] do |t|
    clobber_dirs.map{|dir| Dir["#{dir}/**/*"]}.flatten.each do |fn|
      rm fn unless File.directory?(fn)
    end
  end

  desc "Clean up nuweb temporary files"
  task :clean do |t|
    rm_r clean_exts.collect{|x| Dir.glob('*'+x)+Dir.glob('source/*'+x)+Dir.glob('source/pdf/*'+x)}.flatten
  end

  desc "Generate nuweb source code documentation"
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
        puts "latex -halt-on-error #{fn}.tex"
        puts `latex -halt-on-error #{fn}.tex`
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

  rule /\Atest\/.*/ =>[proc{|tn| tn.sub(/\Atest\//, 'source/test/') }]  do |t|
    cp t.source, t.name  if t.source
  end

  namespace :docs do

    task :package=>['nuweb:weave']
    Rake::PackageTask.new('nio-source-pdf', Nio::VERSION::STRING) do |p|
      # generate same formats as for the gem contents
      p.need_tar = PROJ.gem.need_tar
      p.need_zip = PROJ.gem.need_zip
      p.package_files.include "source/pdf/**/*.pdf"
    end

  end

    Rake::PackageTask.new('nio-source', Nio::VERSION::STRING) do |p|
      # generate same formats as for the gem contents
      p.need_tar = PROJ.gem.need_tar
      p.need_zip = PROJ.gem.need_zip
      # to generate the strict source we could require the clobber task and then
      # pack everything left... but we will just define what to pack
      p.package_files.include "source/**/*.txt"
      p.package_files.include "source/helpers/**/*"
      p.package_files.include "source/lib/**/*"
      p.package_files.include "source/test/**/*"
      p.package_files.include "source/**/*.w"
      p.package_files.exclude "source/pdf/**/*"
      p.package_files.include 'History.txt', 'License.txt', 'Manifest.txt', 'Rakefile', 'README.txt', 'setup.rb'
      p.package_files.include "tasks/**/*"
    end

end

task :clobber=>'nuweb:clobber'
task :clean=>'nuweb:clean'
# namespace :gem do
#   task :package=>'nuweb:tangle'
# end

desc 'Generate code and documentation from nuweb sources'
task :nuweb => ['nuweb:tangle', 'nuweb:weave']
