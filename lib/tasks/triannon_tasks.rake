require_relative '../../app/services/triannon/ldp_writer'

namespace :triannon do
  desc "clean out then reset jetty from scratch for Triannon - starts jetty"
  task :jetty_reset => ['jetty:stop', 'jetty:clean', 'jetty:environment', :jetty_config, 'jetty:start']

  desc "configure Fedora and Solr in jetty for triannon"
  task :jetty_config => [:solr_jetty_config, :disable_fedora_auth_in_jetty]

	# don't display this in rake -T
	#desc "set up triannon core in jetty Solr"
  task :solr_jetty_config do
    `cp -r config/solr/triannon-core jetty/solr`
    `cp config/solr/solr.xml jetty/solr`
  end

	# don't display this in rake -T
	#desc "disable fedora basic authorization in jetty"
  task :disable_fedora_auth_in_jetty do
    `cp config/jetty/etc/* jetty/etc`
  end


  # ------- root container tasks ----------

  # don't display this in rake -T
  #desc 'ONLY WORKS WITHIN RAILS APP: Create the uber root annotation container per triannon.yml'
  task :create_uber_root_container do
    unless File.exist? Triannon.triannon_file
      puts "ERROR:  Triannon config file missing: #{Triannon.triannon_file} - are you in the rails app root directory?"
      raise "Triannon config file missing: #{Triannon.triannon_file}"
    end
    Triannon::LdpWriter.create_basic_container(nil, Triannon.config[:ldp]['uber_container'])
  end

  desc "ONLY WORKS WITHIN RAILS APP: Create root anno containers per triannon.yml"
  task :create_root_containers => :create_uber_root_container do
    unless File.exist? Triannon.triannon_file
      puts "ERROR:  Triannon config file missing: #{Triannon.triannon_file} - are you in the rails app root directory?"
      raise "Triannon config file missing: #{Triannon.triannon_file}"
    end
    Triannon.config[:ldp]['anno_containers'].each { |container_name|
	    Triannon::LdpWriter.create_basic_container(Triannon.config[:ldp]['uber_container'], container_name)
    }
  end
end # namespace triannon
