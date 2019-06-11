#!/usr/bin/env ruby

require 'optparse'
require_relative "lib/restore"

options = {}

OptionParser.new do |opt|
  opt.on('--backup BACKUP') { |o| options[:backup] = o }
  opt.on('--include-namespaces INCLUDE_NAMESPACES') { |o| options[:included_namespaces] = o.split(",") }
end.parse!

backup = Restore.new(options)
backup.run
