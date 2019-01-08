# make sure the hosts are created in order.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

hosts = '''
10.10.10.101 windows1.example.com
10.10.10.102 windows2.example.com
'''

Vagrant.configure('2') do |config|
  config.vm.provider "libvirt" do |lv, config|
    lv.memory = 2*1024
    lv.cpus = 2
    lv.cpu_mode = "host-passthrough"
    lv.keymap = "pt"
    # replace the default synced_folder with something that works in the base box.
    # NB for some reason, this does not work when placed in the base box Vagrantfile.
    config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: ENV['USER'], smb_password: ENV['VAGRANT_SMB_PASSWORD']
  end

  config.vm.provider :virtualbox do |v, override|
    v.linked_clone = true
    v.cpus = 2
    v.memory = 2*1024
    v.customize ['modifyvm', :id, '--vram', 64]
    v.customize ['modifyvm', :id, '--clipboard', 'bidirectional']
  end

  (1..2).each do |i|
    config.vm.define "windows#{i}" do |config|
      config.vm.box = 'windows-2019-amd64'
      config.vm.hostname = "windows#{i}"
      config.vm.network :private_network, ip: "10.10.10.10#{i}", libvirt__forward_mode: 'route', libvirt__dhcp_enabled: false
      config.vm.provision :shell, inline: "'#{hosts}' | Out-File -Encoding Ascii -Append c:/Windows/System32/drivers/etc/hosts"
      config.vm.provision :shell, path: 'ps.ps1', args: 'provision-common.ps1'
      config.vm.provision :shell, path: 'ps.ps1', args: 'provision-certificates.ps1'
      config.vm.provision :shell, path: 'ps.ps1', args: 'provision-tigervnc.ps1'
    end
  end
end
