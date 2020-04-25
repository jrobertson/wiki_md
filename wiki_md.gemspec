Gem::Specification.new do |s|
  s.name = 'wiki_md'
  s.version = '0.9.1'
  s.summary = 'Designed for maintaining many wiki entries within a single ' + 
      'document in Markdown format. #nothrills #personalwiki'
  s.authors = ['James Robertson']
  s.files = Dir['lib/wiki_md.rb']
  s.add_runtime_dependency('dxsectionx', '~> 0.4', '>=0.4.0')
  s.add_runtime_dependency('dynarex-tags', '~> 0.5', '>=0.5.0')
  s.signing_key = '../privatekeys/wiki_md.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/wiki_md'
end
