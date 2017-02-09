#! /usr/bin/ruby

require 'minitest/autorun'
require 'minitest/reporters'
require_relative '../lib/opt_parser.rb'

#Options
#    -r, --repo REPO                  github repo you want to run test againstEXAMPLE: USER/REPO  MalloZup/gitbot
#    -c, --context CONTEXT            context to set on commentEXAMPLE: CONTEXT: python-test
#    -d, --description DESCRIPTION    description to set on comment
#    -t, --test TEST.SH               fullpath to the bashscript which contain test to be executed for pr
#    -f, --file '.py'                 specify the file type of the pr which you wantto run the test against ex .py, .java, .rb
#    -h, --help                       help

class SimpleTest < Minitest::Test

  def set_option(hash, s)
    OptParser.options = hash
    ex = assert_raises OptionParser::MissingArgument do
      OptParser.get_options
    end
    assert_equal("missing argument: #{s}", ex.message)
  end 

  def test_partial_import
    hash =  {repo: 'gino/gitbot'} 
    hash1 = {repo: 'gino/gitbot', context: 'python-t', description: 'functional', test: 'gino.sh'}
    set_option(hash, 'CONTEXT')
    set_option(hash1, 'SCRIPT FILE')
  end

  def test_full_option_import
   hash = {repo: 'gino/gitbot', context: 'python-t', description: 'functional', test_file: 'gino.sh', file_type: '.sh'}
   OptParser.options = hash
   options = OptParser.get_options
   assert_equal('gino/gitbot', options[:repo])
   assert_equal('python-t', options[:context])
   assert_equal('functional', options[:description])
   assert_equal('gino.sh', options[:test_file])
   assert_equal('.sh', options[:file_type])
  end
end
