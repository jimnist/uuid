spec = Gem::Specification.new do |spec|
  spec.name = 'gn0m30-uuid'
  spec.version = '2.2.1'
  spec.summary = "UUID generator with teenie format"
  spec.description = <<-EOF
UUID generator for producing universally unique identifiers based on RFC 4122
(http://www.ietf.org/rfc/rfc4122.txt).
EOF

  spec.authors << 'Assaf Arkin' << 'Eric Hodel' << 'jim nist'
  spec.email = 'reggie@loco8.org'
  spec.homepage = 'http://github.com/gn0m30/uuid'

  spec.files = Dir['{bin,test,lib,docs}/**/*'] + ['README.rdoc', 'MIT-LICENSE', 'Rakefile', 'CHANGELOG', 'gn0m30-uuid.gemspec']
  spec.has_rdoc = true
  spec.rdoc_options << '--main' << 'README.rdoc' << '--title' <<  'UUID generator' << '--line-numbers'
                       '--webcvs' << 'http://github.com/assaf/uuid'
  spec.extra_rdoc_files = ['README.rdoc', 'MIT-LICENSE']

  spec.add_dependency 'macaddr', ['~>1.0']
  spec.add_dependency 'base62', ['~>0.1.0']
end
