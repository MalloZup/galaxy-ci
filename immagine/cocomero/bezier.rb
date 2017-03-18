#! /usr/bin/ruby

require 'gruff'

g = Gruff::Bezier.new
g.title = "Failures Spacewalk-testsuite"
g.data 'test-failures', [0,500, 32, 93, 44,1, 48, 88, 90, 100]
g.data 'bug', [0, 900, 100, 1499, 230, 400, 450]
g.x_axis_label = 'test runs'
g.y_axis_label = 'failures'
g.write("results.png")
