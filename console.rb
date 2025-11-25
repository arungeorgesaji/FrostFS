#!/usr/bin/env ruby

$:.unshift(File.expand_path(File.dirname(__FILE__) + '/lib'))

require 'frostfs'
require 'pry'

puts "FrostFS Development Console"
puts "Type 'exit' to quit"
puts ""

binding.pry
