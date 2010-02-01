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
# Author::      Minjie Zha (mailto:minjiezha@gmail.com)
# Copyright::   Copyright (c) 2009-2010 Minjie Zha
# License::     MIT

require 'sqlite3'
require 'date'
require 'optparse'
require 'highline'
require 'digest/md5'

begin
    require 'supergossip'
rescue LoadError
    $:.unshift(File.dirname(__FILE__)+'/../lib')
    retry
end

class SuperGossipAccountOptions
    def self.parse(args)
        opts = OptionParser.new do |opts|
            opts.banner = "Usage: supergossip_account.rb [options]"
            
            opts.separator ""
            opts.separator "Options:"
            # Delete the user
            opts.on('-d','--delete','Delete the user') do 
                delete
            end

            # Create a new user
            opts.on('-c','--create','Create a new user') do
                create
            end

            # Display help message
            opts.on_tail('-h','--help','Display this help message') do
                puts opts
                exit(0)
            end

            # Show version
            opts.on_tail('-v','--version','Show version') do
                puts SuperGossip::VERSION
                exit(0)
            end
        end
        if args.nil? or args.empty?
            puts opts
            exit(0)
        end

        begin
            opts.parse!(args)
        rescue OptionParser::InvalidOption => e
            puts e
            puts opts
            exit(1)
        end
    end

    private 
    
    # Delete the user from database.
    def self.delete
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
    def self.create
        # Read user information
        highline = HighLine.new
        name = highline.ask('Name: ') do |q|
            q.whitespace = :chomp
            q.case = :downcase
            q.validate = /^[a-z0-9_]+$/
            q.responses[:not_valid] = 'Name should only contains digital, alphabet or underscore!'
        end

        while true
            password = highline.ask('Password: ') do |q|
                q.whitespace = :chomp
                q.echo = '*'
            end
            password2 = highline.ask('Retry: ') do |q|
                q.whitespace = :chomp
                q.echo = '*'
            end
            break if password == password2
            puts 'Passwords do not match!'
        end

        user = SuperGossip::Model::User.new
        user.name = name
        user.password = Digest::MD5.hexdigest(password)
        user.register_date = Date.today.to_s
        user.guid = UUID.user_id(user.name).to_s_compact

        begin
            db = init_db
            user_dao = SuperGossip::DAO::UserDAO.new(db)
            user_dao.add_or_update(user)
            STDOUT.puts 'User created.'
        rescue SuperGossip::DAO::TooManyUsersError
            puts 'A user already exists. Only one user is allowed.'
        rescue SQLite3::SQLException => err
            STDERR.puts 'Error: ' + err.to_s
        ensure
            db.close
        end
    end

    # Initiate the database handler.
    # Return the sqlite3 database object.
    def self.init_db
        # Load configuration from file
        config = SuperGossip::Config::Config.instance
        config.load(File.dirname(__FILE__)+'/../config/conf.yaml')
        db_path = File.expand_path(config['db_path'].chomp('/'))
        user_db = db_path+File::SEPARATOR+config['user_db']
        unless Dir.exist?(db_path)
            Dir.mkdir(db_path)
        end
        
        # Load database
        unless File.exist?(user_db)
            db = SQLite3::Database.new(user_db) 
            sql = File.open('../config/sql/user.sql','r') { |f| f.read }
            db.execute_batch(sql)
            return db
        end
        return SQLite3::Database.new(user_db)
    end
end

SuperGossipAccountOptions.parse(ARGV)

