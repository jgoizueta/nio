# nuweb build tasks
namespace :nuweb do

  NUWEB_PRODUCTS = []
  NUWEB_SOURCES = Dir['source/**/*.w']

  NUWEB_SOURCES.each do |input_fn|
    products = []
    File.open(input_fn) do |input|
      meta = '@'
      input.each_line do |line|
        if /^\s*%#{meta}r(.)%/.match(line)
          meta = $1
        elsif /^\s*[^#{meta}]?#{meta}(?:o|O)\s*(\S.*)\s*$/.match(line)
          products << $1
        end
      end
    end
    NUWEB_PRODUCTS.concat products
    products.each do |product|
      file product => [input_fn] do |t|
        puts "nuweb -t #{input_fn}"
        puts `nuweb -t #{input_fn}`
        touch product
      end
    end
  end

  %w{lib test}.each do |dir|
    sources = Dir["source/#{dir}/**/*"]
    NUWEB_SOURCES.concat sources
    NUWEB_PRODUCTS.concat sources.map{|s| s.sub("source/#{dir}/","#{dir}/")}
    rule(/\A#{dir}\/.*/ =>[proc{|tn| tn.sub(/\A#{dir}\//, "source/#{dir}/") }])  do |t|
      if t.source
        if File.directory?(t.source)
          cp_r t.source, t.name
        else
          cp t.source, t.name
        end
      end
    end
  end

  desc "Generate Ruby code from nuweb source"
  task :tangle => NUWEB_PRODUCTS + [:test]

  # directory 'lib'
  # directory 'lib/nio'
  # directory 'source/pdf'

  clean_exts = ['*.tex','*.dvi','*.log','*.aux','*.out']
  clobber_exts = []
  generated_dirs = ['lib', 'test', 'source/pdf']

  desc "Remove all nuweb generated files"
  task :clobber=>['^clobber'] do |t|
    generated_dirs.map{|dir| Dir["#{dir}/**/*"]}.flatten.each do |fn|
      rm fn unless File.directory?(fn)
    end
  end

  desc "Clean up nuweb weave temporary files"
  task :clean do |t|
    rm_r clean_exts.collect{|x| Dir.glob('source/*'+x)+Dir.glob('source/pdf/*'+x)}.flatten
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

  namespace :docs do

    Rake::PackageTask.new('nio-source-pdf', Nio::VERSION::STRING) do |p|
      # generate same formats as for the gem contents
      p.need_tar = PROJ.gem.need_tar
      p.need_zip = PROJ.gem.need_zip
      pdf_files = Dir['source/**/*.w'].map{|fn| File.join 'source','pdf',File.basename(fn,'.w')+'.pdf'}
      p.package_files.include *pdf_files
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

task :clobber=>'nuweb:clean'
task :clean=>'nuweb:clean'

gem_package_prerequisites = Rake::Task['gem:package'].prerequisites.dup
Rake::Task['gem:package'].clear_prerequisites.enhance ['nuweb:tangle']+gem_package_prerequisites

desc 'Generate code and documentation from nuweb sources'
task :nuweb => ['nuweb:tangle', 'nuweb:weave']
