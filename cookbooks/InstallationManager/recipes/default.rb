#
# Cookbook Name:: InstallationManager
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

binary_dir = "#{Chef::Config[:file_cache_path]}/IMbinaries"
binary_path = "#{binary_dir}/agent.installer.linux.gtk.x86_64_#{node['InstallationManager']['im_version']}.zip"
base_dir = "/opt/IBM"
im_dir = "/opt/IBM/InstallationManager"
imagentdata_dir = "/opt/IBM/IMAgentData"
imshared_dir = "/opt/IBM/IMShared"


directory binary_dir do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

directory base_dir do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end


directory im_dir do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

directory imagentdata_dir do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

directory imshared_dir do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

execute 'unzip' do
  command value_for_platform(
"debian" => { "default" => "aptitude install unzip" },
"ubuntu" => { "default" => "apt-get install unzip" },
"rhel" => { "default" => "yum install unzip" }
)
  action :run
end

remote_file binary_path do
  owner 'root'
  group 'root'
  mode '0644'
  #source "http://9.191.4.193/agent.installer.linux.gtk.x86_64_1.8.3000.20150606_0047.zip"
  source "#{node['InstallationManager']['webserver']}/agent.installer.linux.gtk.x86_64_#{node['InstallationManager']['im_version']}.zip"
  checksum "#{node['InstallationManager']['im-sha256sum']}"
  notifies :create, "ruby_block[Validate IM Package Checksum]", :immediately
  #not_if { redis_exists? && node['redisio']['safe_install'] }
end

ruby_block "Validate IM Package Checksum" do
  action :run
  block do
    require 'digest'
    checksum = Digest::SHA256.file("#{binary_dir}/agent.installer.linux.gtk.x86_64_#{node['InstallationManager']['im_version']}.zip").hexdigest
    if checksum != node['InstallationManager']['im-sha256sum']
      raise "Downloaded Tarball Checksum #{checksum} does not match known checksum #{node['InstallationManager']['im-sha256sum']}"
    end
  end
  notifies :run, 'execute[extract-InstallationManager]', :immediately
end

execute 'extract-InstallationManager' do
  command "unzip -o #{binary_path}"
  cwd binary_dir
  # Only run after notified by remote_file download
  action :run
end

template "#{binary_dir}/#{node['InstallationManager']['im-responsefile']}" do
  source 'IM-responsefile.erb'
  variables(
  im: "#{node['InstallationManager']['im_install_dir']}",
  version: "#{node['InstallationManager']['im_version']}",
  id: "#{node['InstallationManager']['im_version']}"
  )
  owner 'root'
  group 'root'
  mode '0644'
  notifies :run, 'execute[install-InstallationManager]', :immediately
end

execute 'install-InstallationManager' do
  command "#{binary_dir}/userinstc -log #{binary_dir}/instman.log -acceptLicense -dataLocation #{node['InstallationManager']['imagentdata_install_dir']}"
  cwd binary_dir
  action :run
  notifies :run, "ruby_block[check InstallationManager]", :immediately
end


ruby_block 'check InstallationManager' do
   block do
     imclinstalledversion = `#{node['InstallationManager']['imcl-path']} listInstalledPackages`.to_str.strip
     if imclinstalledversion.include? ("node['InstallationManager']['imcl-packageid']").to_str.strip
      raise "Installed version :#{imclinstalledversion}: does not match expected version :#{node['InstallationManager']['imcl-packageid']}:"
    end
   end
 end 
 

directory binary_dir do
  action :delete
  recursive true
end