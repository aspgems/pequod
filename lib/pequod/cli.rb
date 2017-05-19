# frozen_string_literal: true

require 'thor'
require 'docker'
require 'etc'

module Pequod
  # docker run --name school_admin --rm -it -v $(pwd):/home/dev/app
  # -v ~/.ssh/id_rsa:/home/dev/.ssh/id_rsa -p 3000:3000 school_admin bundle
  # exec rails s -p 3000 -b 0.0.0.0
  class FileUtils
    def self.save_last_build_image(image_id)
      File.open("/tmp/pequod_last_build", "w") do |f|
        f.puts(image_id)
      end
    end

    def self.last_build_image
      File.open("/tmp/pequod_last_build", "r").read.delete("\n") if File.exist?("/tmp/pequod_last_build")
    end

    def self.remove_last_build
      File.delete("/tmp/pequod_last_build") if File.exist?("/tmp/pequod_last_build")
    end

    def self.absolute_path(directory)
      File.expand_path(directory)
    end

    def self.basedir(directory)
      dir_names = File.expand_path(directory).split(File::SEPARATOR)
      dir_names.each_with_index.map { |dir, index|
        index = index-1 > -1 ? index-1 : 0
        "#{dir_names[0..index].join(File::SEPARATOR)}#{File::SEPARATOR}#{dir}"
      }.sort{ |x,y| y.length <=> x.length }.find{ |path|
        Pathname("#{path}#{File::SEPARATOR}Gemfile").exist?
      }
    end
  end

  # adasd
  class UserUtils
    def self.buildargs(docker_directory)
      <<-BUILD_ARGS
      {"USER_NAME":"#{Pequod::UserUtils.user_name(docker_directory)}",
       "USER_UID":"#{Pequod::UserUtils.uid}",
       "USER_GID":"#{Pequod::UserUtils.gid}"}
      BUILD_ARGS
    end

    private

      def self.uid
        Process.euid
      end

      def self.gid
        Process.egid
      end

      def self.user_name(docker_directory)
        File.basename("#{File.expand_path(docker_directory)}")
      end
  end

  # Environment value class
  class Environment
    attr_reader :basedir, :buildargs
    def initialize(directory)
      @basedir = FileUtils.basedir(directory)
      @buildargs = UserUtils.buildargs(@basedir)
    end
  end


  # this is the CLi interpreter class
  class Harpoon < Thor
    desc 'build', 'This will build the Dockerfile image'
    option :directory, default: '.', type: :string
    def build
      environment = Environment.new(options[:directory])
      image = Docker::Image.build_from_dir(
        directory,
        'buildargs': environment.buildargs(directory)
      ) do |v|
        if (log = JSON.parse(v)) && log.key?('stream')
          $stdout.puts log['stream']
        end
      end
      Pequod::FileUtils.save_last_build_image(image.id)
    end

    desc 'destroy', 'This will remove the image forcing the delete'
    option :image_id, default: Pequod::FileUtils.last_build_image, type: :string
    def destroy
      image_id = options[:image_id]
      if image_id && Docker::Image.exist?(image_id)
        image = Docker::Image.get(image_id)
        $stdout.puts "Destroying #{image_id}"
        $stdout.puts image.json['Config']['Env'].find{|env| env.include?('APP_HOME=')}.sub('APP_HOME=','')
        # $stdout.puts image.remove(force: true)
        # Pequod::FileUtils.remove_last_build
      else
        $stdout.puts 'No image found'
      end
    end

    desc 'install', 'This will execute bundle install in the project image'
    option :directory, default: '.', type: :string
    option :image_id, default: Pequod::FileUtils.last_build_image, type: :string
    def install
      image_id = options[:image_id]
      if image_id && Docker::Image.exist?(image_id)
        # Docker.options[:read_timeout]=999999
        app_home = Docker::Image.get(image_id).json['Config']['Env'].find{|env| env.include?('APP_HOME=')}.sub('APP_HOME=','')
        environment = Environment.new(options[:directory])
        container = Docker::Container.create('Image' => image_id,
        "Cmd" => ["bundle", "install"],
        "Env" => ["SSH_AUTH_SOCK=/tmp/agent.sock"],
        "HostConfig" => {
          "Binds" => ["#{environment.basedir}:#{app_home}",
                      "#{ENV['SSH_AUTH_SOCK']}:/tmp/agent.sock"]
        }, 'Tty' => true, detach: false)
        container.wait(10*60)
        container
        .tap(&:start)
        .attach(:stream => true, :stdin => nil, :stdout => true, :stderr => true, :logs => true, :tty => true) {|stream, _chunk| $stdout.print("#{stream}")}
      else
        $stdout.puts 'No image found'
      end
    end

    desc 'shows ENV variables needed', 'shows ENV variables needed for the gem'
    option :directory, default: '.', type: :string
    def env
      environment = Environment.new(options[:directory])
      $stdout.puts "ENV[SSH_AUTH_SOCK] #{ENV['SSH_AUTH_SOCK']}"
      $stdout.puts "Environment: #{environment.inspect}"
    end
  end
end
