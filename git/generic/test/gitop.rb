#! /usr/bin/ruby

require 'minitest/autorun'
require 'minitest/reporters'
require_relative '../lib/opt_parser.rb'
require_relative '../lib/git_op.rb'
class SimpleTest < Minitest::Test

  def test_basic
     git = GitOp.new("gitty")
  end
end
