require 'fog'

module Backup
  module Storage
    class CloudStorage < Base
      include Storage::Cycler
      class Error < Backup::Error; end

      attr_accessor :storage_token, :storage_secret

      ##
      # Cloud Storage Credentials
      def initialize(model, storage_id = nil)
        super

        @path ||= 'backups'
        path.sub!(/^\//, '')
      end

      private
      def connection
        @connection ||= Fog::Storage.new(
            :provider                => 'Google',
            :google_storage_access_key_id  => storage_token,
            :google_storage_secret_access_key => storage_secret
        )
      end

      def transfer!
        directory = directory_for(remote_path, true)
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ dest }'..."
          File.open(src, 'r') do |file|
            directory.files.create(:key => filename, :body => file)
          end
        end
      end

      ##
      # Queries the connection for the directory for the given +remote_path+
      # Returns nil if not found, or creates the directory if +create+ is true.
      def directory_for(remote_path, create = false)
        directory = connection.directories.get(remote_path)
        if directory.nil? && create
          directory = connection.directories.create(:key => remote_path)
        end
        directory
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."

        remote_path = remote_path_for(package)
        directory = directory_for(remote_path)

        raise Error, "Directory at '#{ remote_path }' not found" unless directory

        package.filenames.each do |filename|
          file = directory.files.get(filename)
          file.destroy if file
        end

        directory.destroy
      end

    end
  end
end