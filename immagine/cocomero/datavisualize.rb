#! /usr/bin/ruby

require 'gruff'
require 'json'

# Doc here:
# http://www.rubydoc.info/github/topfunky/gruff/Gruff/Bezier

def bezier
  g = Gruff::Bezier.new
  g.title = "Failures Spacewalk-testsuite"
  # read number of failures from json file.
  # each entry corrispond a run , so the results
  # this can be like for years or something.
  g.data 'test-failures', [0,500, 32, 93, 39,44,44,44,1, 48, 88, 90, 100]
  g.x_axis_label = 'test runs'
  g.y_axis_label = 'failures'
  g.write("results.png")
end

def xy_line
  # xy_line is more weekly report
  g = Gruff::Line.new
  g.title = 'Results Spacewalk-testsuite-base'
  g.dataxy('failures', [1, 2, 3, 4, 5], [1, 3, 4, 5, 6])
  # label should be expanded per each day.
  g.labels = {0 => 'Montag', 2 => 'Dienstag', 3 => 'Mittwoch', 4 => 'Donnerstag', 5 => 'Freitag'}
  g.write('line_xy.png')
end

bezier
xy_line
