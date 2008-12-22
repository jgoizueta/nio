require File.join(File.dirname(__FILE__),'../source/lib/nio/version')

AUTHOR = 'Javier Goizueta'  # can also be an array of Authors
EMAIL = "javier@goizueta.info"
DESCRIPTION = "Numeric input/output"
GEM_NAME = 'nio' # what ppl will type to install your gem
RUBYFORGE_PROJECT = 'nio' # The unix name for your project
HOMEPATH = "http://#{RUBYFORGE_PROJECT}.rubyforge.org"
DOWNLOAD_PATH = "http://rubyforge.org/projects/#{RUBYFORGE_PROJECT}"

# Generate all the Rake tasks
# Run 'rake -T' to see list of generated tasks (from gem root directory)
$hoe = Hoe.new(GEM_NAME, Nio::VERSION::STRING) do |p|
  p.developer AUTHOR, EMAIL
  p.description = DESCRIPTION
  p.summary = DESCRIPTION
  p.url = HOMEPATH
  p.rubyforge_name = RUBYFORGE_PROJECT if RUBYFORGE_PROJECT
  p.test_globs = ["test/**/test_*.rb"]
  p.clean_globs |= ['**/.*.sw?', '*.gem', '.config', '**/.DS_Store']  #An array of file patterns to delete on clean.
  
  path = (p.rubyforge_name == p.name) ? p.rubyforge_name : "\#{p.rubyforge_name}/\#{p.name}"
  #p.remote_rdoc_dir = File.join(path.gsub(/^#{p.rubyforge_name}\/?/,''), 'rdoc')
  p.remote_rdoc_dir = '' # we start using the rdoc as the project home-page, later we'll setup separate page
  p.rsync_args = '-av --delete --ignore-errors'
  p.changes = p.paragraphs_of("History.txt", 0..1).join("\\n\\n")

  #p.extra_deps = []     # An array of rubygem dependencies [name, version], e.g. [ ['active_support', '>= 1.3.1'] ]
  
  p.spec_extras = {
    :rdoc_options => [
          "--main", "README.txt",
          '--quiet', '--title', 'Nio documentation',
          "--opname", "index.html",
          "--line-numbers",
          "--inline-source"
    ],
    :autorequire=>'nio',
  }

end

require 'newgem/tasks' # load /tasks/*.rake
