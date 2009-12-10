#!/usr/bin/env ruby 
# coding=utf-8

# This script provides an interactive interface for managing account in database.
#
# Usage:
#   ruby supergossip_account [options]
#   Options:
#       -d, --delete    Delete the user
#       -c, --create    Create a new user
#       -h, --help      Display this help message
#       -v, --version   Show version
#
# *SuperGossip only allows single user in the system, and this script does not do check this. It is intended to be used internally during development.*
#
# Author::      Minjie Zha (mailto:minjiezha@gmail.com)
# Copyright::   Copyright (c) 2009-2010 Minjie Zha
# License::     MIT

require 'sqlite3'
require 'date'
begin
    require 'supergossip'
rescue LoadError
    $:.unshift(File.dirname(__FILE__)+'/../lib')
    retry
end

# Display help message.
def usage
    puts "ruby supergossip_account [options]"
    puts "Options:"
    puts "\t-d,--delete\tDelete the user"
    puts "\t-c,--create\tCreate a new user"
    puts "\t-h,--help\tDisplay this help message"
    puts "\t-v,--version\tShow version"
    exit(0)
end
# Delete the user from database.
def delete
    db = init_db
    begin
        SuperGossip::DAO::UserDAO.delete(db)
        STDOUT.puts 'User deleted.'
    rescue SQLite3::SQLException => err
        STDERR.puts 'Error: ' + err.to_s
    ensure
        db.close
    end
end

# Create a new user.
def create
    # Read user information
    name = ''
    while true
        print 'Name: '
        name = STDIN.gets.chomp.downcase
        break unless name =~ /[^a-z0-9_]+/
        puts 'Name should only contains digital, alphabet or underscore!'
    end

    password = ''
    while true
        # FIXME mask password
        print 'Password: '
        password = STDIN.gets.chomp
        print 'Retype: '
        password2 = STDIN.gets.chomp
        break if password==password2
        puts 'Passwords do not match!'
    end
    
    user = SuperGossip::Model::User.new
    user.name = name
    # FIXME use MD5 to encrypt password
    user.password = password
    user.register_date = Date.today.to_s
    user.guid = UUID.user_id(user.name).to_s_compact

    begin
        db = init_db
        user_dao = SuperGossip::DAO::UserDAO.new(db)
        user_dao.add(user)
        STDOUT.puts 'User created.'
    rescue SQLite3::SQLException => err
        STDERR.puts 'Error: ' + err.to_s
    ensure
        db.close
    end
end

# Initiate the database handler.
# Return the sqlite3 database object.
def init_db
    ##
    # Load configuration from file
    config = SuperGossip::Config::Config.instance
    config.load(File.dirname(__FILE__)+'/../config/system.yaml')
    db_path = File.expand_path(config['db_path'].chomp('/'))
    unless Dir.exist?(db_path)
        Dir.mkdir(db_path) 
    end

    ##
    # Load database
    db = SQLite3::Database.new(db_path+'/user.db')
    db
end

# Get the option
opt = ARGV.first

case opt
when '-d','--delete' 
    delete
when '-c','--create'
    create
when '-v','--version'
    puts SuperGossip::VERSION
else # '-h','--help' and other options
    usage
end


