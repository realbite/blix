require 'rubygems'
require 'rake'

Gem::Specification.new do |spec|

spec.name = 'blix'
spec.version = '0.2.2'
spec.author  = "Clive Andrews"
spec.email   = "pacman@realitybites.nl"

spec.platform = Gem::Platform::RUBY
spec.summary = 'Ruby based AMQP/JSON Client/Server.'
spec.require_path = 'lib'

spec.files = FileList['lib/**/*.rb'].to_a
spec.extra_rdoc_files = ['README']



spec.add_dependency('json', '>= 1.4.3')
spec.add_dependency('amqp', '>= 0.6.7')
spec.add_dependency('crack', '>= 0.1.7')
spec.add_dependency('bunny', '>= 0.6.0')
spec.add_dependency('flt', '>= 1.1.1')

end
