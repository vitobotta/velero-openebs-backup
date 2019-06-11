#!/usr/bin/env ruby

require 'optparse'
require_relative "lib/backup"

options = {}

OptionParser.new do |opt|
  opt.on('--backup BACKUP') { |o| options[:backup] = o }
  opt.on('--include-namespaces INCLUDE_NAMESPACES') { |o| options[:included_namespaces] = o.split(",") }
  opt.on('--schedule SCHEDULE') { |o| options[:schedule] = o }
end.parse!

backup = Backup.new(options)
backup.run
