#
# Cookbook Name:: WebSphereAS85
# Recipe:: default
#
# Copyright 2016, rohit company
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#include_recipe 'InstallationManager'


wasbinary_dir = "#{Chef::Config[:file_cache_path]}/WASbinaries"
binaries = [ "#{node['WebSphereAS85']['package-name-1']}", "#{node['WebSphereAS85']['package-name-2']}", "#{node['WebSphereAS85']['package-name-3']}"]
checksums = [ "#{node['WebSphereAS85']['package1-sha256sum']}", "#{node['WebSphereAS85']['package2-sha256sum']}", "#{node['WebSphereAS85']['package3-sha256sum']}"]

was_dir = "/opt/IBM/WebSphere"
im_dir = "/opt/IBM/InstallationManager"
imagentdata_dir = "/opt/IBM/IMAgentData"
imshared_dir = "/opt/IBM/IMShared"

directory wasbinary_dir do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

directory 'was_dir' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

count = 0

binaries.each { | package_name |
	remote_file "#{wasbinary_dir}/#{package_name}" do
	  owner 'root'
	  group 'root'
	  mode '0644'
	  source "#{node['WebSphereAS85']['webserver']}/#{package_name}"
	  notifies :create, "ruby_block[Validate Package Checksum]", :immediately
	  end  


ruby_block "Validate Package Checksum" do
  action :run
  block do
  	require 'digest'

	    checksum = Digest::SHA256.file("#{wasbinary_dir}/#{package_name}").hexdigest
	    
	    if checksum != checksums[count]
	      raise "#{package_name} #{count} Downloaded package Checksum #{checksum} does not match known checksum #{checksums[count]}"
        else
        	count += 1
	    end
	end
end

	execute 'extract-WAS' do
		action :run
	  		#command "unzip -o #{package_name}"
        command "cat #{package_name} >> looptest"
	  		cwd wasbinary_dir
	end
  #raise "count after extract = #{count}"
}

template "#{wasbinary_dir}/#{node['WebSphereAS85']['was-responsefile']}" do
  source 'WAS-responsefile.erb'
  variables(
  wasid: "#{node['WebSphereAS85']['was85-packageid']}",
  wasdesc: "#{node['WebSphereAS85']['was85-profiledesc']}",
  wasfeatures: "#{node['WebSphereAS85']['was85-features']}",
  waspath: "#{node['WebSphereAS85']['was85-installpath']}",
  imsharedpath: "#{node['WebSphereAS85']['imshared_install_dir']}",
  wasbinarypath: "#{wasbinary_dir}"
  )
  owner 'root'
  group 'root'
  mode '0644'
  notifies :run, 'execute[install-WAS85]', :immediately
end

execute 'install-WAS85' do
  command "#{node['WebSphereAS85']['imcl-path']} -acceptLicense -showProgress input '#{wasbinary_dir}/#{node['WebSphereAS85']['was-responsefile']}' -dataLocation '#{node['WebSphereAS85']['imagentdata_install_dir']}' -log '#{wasbinary_dir}/WAS85NDinstall.log'"
  cwd wasbinary_dir
  action :run
end

