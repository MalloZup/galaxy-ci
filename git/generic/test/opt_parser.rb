#! /usr/bin/ruby

require 'minitest/autorun'
require 'minitest/reporters'
require_relative '../lib/opt_parser.rb'
class SimpleTest < Minitest::Test

  # test that we raise an ex
  def test_import_parser
    ex = assert_raises OptionParser::MissingArgument do
      OptParser.get_options
    end
    assert_equal('missing argument: REPO', ex.message)
  end

end
