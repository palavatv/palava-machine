Dir[File.dirname(__FILE__) + '/jobs/*'].each { |filename|
  require_relative "jobs/#{ File.basename(filename) }"
}
