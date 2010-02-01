#!/usr/bin/env ruby 
# coding=utf-8

# This script provides an interactive interface for running the software.
#
# Author::      Minjie Zha (mailto:minjiezha@gmail.com)
# Copyright::   Copyright (c) 2009-2010 Minjie Zha
# License::     MIT

require 'sqlite3'
require 'fileutils'
require 'logger'

begin
    require 'supergossip'
rescue LoadError
    $:.unshift(File.dirname(__FILE__)+'/../lib')
    retry
end

# It is the start point of the software, and it contains the starting steps.
class SuperGossipRunner
    def initialize
        @home_dir = File.expand_path('~/.supergossip')
        @config_file = @home_dir + '/config/conf.yaml'
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::INFO
        @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    end

    # Runs the program.
    def run
        unless installed?
            @logger.info(self.class) {"It is not installed. Install now ..."}
            install
        end
        @logger.info(self.class) {"Software installed."}
    end
    private

    # Checks if the software has been installed before. It checks this by
    # examine the ~/.supergossip directory and _user_ table in the SQLite3
    # database. Returns +true+ if installed.
    def installed?
        installed = false
        @logger.debug(self.class) {'Checking if installed ... '}
        if Dir.exist?(@home_dir) && File.exist?(@config_file)
            @logger.debug(self.class) { 'Home directory and config file found.'}
            config = SuperGossip::Config::Config.instance
            config.load(@config_file)
            user_db = config['db_path'].chomp('/') + '/' + config['user_db']
            user_db = File.expand_path(user_db)
            if File.exist?(user_db)
                @logger.debug(self.class) { 'User database file found.' }
                # Check if table _user_ is available
                db = SQLite3::Database.new(user_db)
                result = db.execute('SELECT * FROM sqlite_master WHERE name="user" AND type="table";')
                db.close
                unless result.empty?
                    @logger.debug(self.class) {'User table found.'}
                    installed = true
                end
            end
        end
        @logger.debug(self.class) {'Check finished.'}
        installed
    end

    # Install the software. It makes the directories, copies the 
    # configuration files and creates the database.
    def install
        # Make home directory
        @logger.debug(self.class) { 'Making home directory ...'}
        Dir.mkdir(@home_dir) unless Dir.exist?(@home_dir)
        # Copy files
        @logger.debug(self.class) { 'Copying configuration files ...'}
        abs_dir = File.dirname(__FILE__)
        FileUtils.cp_r(abs_dir+'/../config',@home_dir)
        # Make db and log directory
        @logger.debug(self.class) { 'Making db and log directory ...' }
        Dir.mkdir(@home_dir+'/log') unless Dir.exist?(@home_dir+'/log')
        config = SuperGossip::Config::Config.instance
        config.load(@config_file)
        db_path = File.expand_path(config['db_path'].chomp('/'))
        Dir.mkdir(db_path) unless Dir.exist?(db_path)
        # Create database
        @logger.debug(self.class) { 'Creating database ...' }
        user_db = db_path + '/' + config['user_db']
        routing_db = db_path + '/' + config['routing_db']
        user_sql = File.open(@home_dir+'/config/sql/user.sql','r') { |f| f.read }
        routing_sql = File.open(@home_dir+'/config/sql/routing.sql','r') { |f| f.read }
        begin
            db = SQLite3::Database.new(user_db)
            db.execute_batch(user_sql)
            db.close

            db = SQLite3::Database.new(routing_db)
            db.execute_batch(routing_sql)
            db.close
        rescue SQLite3::SQLException => err
            @logger.fatal(self.class) { 'Create database failed!' }
            @logger.fatal(self.class) { err.to_s }
        ensure
            db.close unless db.closed?
        end
    end
end

sg = SuperGossipRunner.new
sg.run
