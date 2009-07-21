# Look in the tasks/setup.rb file for the various options that can be
# configured in this Rakefile. The .rake files in the tasks directory
# are where the options are used.

begin
  require 'bones'
  Bones.setup
rescue LoadError
  load 'tasks/setup.rb'
end

ensure_in_path 'lib'
#require 'nio'
require File.join(File.dirname(__FILE__),'source/lib/nio/version')

task :default => 'spec:run'

depend_on 'flt', '1.0.0'

PROJ.name = 'nio'
PROJ.description = "Numeric input/output"
PROJ.authors = 'Javier Goizueta'
PROJ.email = 'javier@goizueta.info'
PROJ.version = Nio::VERSION::STRING
PROJ.rubyforge.name = 'nio'
PROJ.url = "http://#{PROJ.rubyforge.name}.rubyforge.org"
PROJ.rdoc.opts = [
  "--main", "README.txt",
  '--title', 'Nio Documentation',
  "--opname", "index.html",
  "--line-numbers",
  "--inline-source"
  ]

# EOF
