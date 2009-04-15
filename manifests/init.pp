class host-vmware-server inherits host-base {
  include ldap::client
  include redhat::static-ip

  $modulename = "host-vmware-server"

  package{"VMware-server": ensure => "2.0.1-156745" }

  service{"vmware":
    ensure => running,
    hasstatus => false,
    require => [Package["VMware-server"],Class["ldap::client"],Exec["configure vmware"]],
    pattern => "vmware-hostd",
  }
  
  # allow LDAP authentication
  file{"/etc/pam.d/vmware-authd":
    mode => 644, owner => root, group => root,
    require => Exec["configure vmware"],
    before => Service["vmware"],
    source => "puppet:///$modulename/etc/pam.d/vmware-authd",
  }

  # provide a basic config file, however we dont force managing this file as it depends on the network
  # configuration of the VMWare server
  file{"/etc/vmware/locations":
    owner => root, group => root,
    mode => 644,
    source => "puppet:///$modulename/etc/vmware/locations",
    require => Package["VMware-server"],
    replace => no,
  }

  file{"/etc/vmware/license.vs.1.0-00":
    owner => root, group => root,
    mode => 644,
    source => "puppet:///$modulename/etc/vmware/license.vs.1.0-00",
    require => Package["VMware-server"],
  }
  # stupid workaround for vmware-config.pl script, stupid stupid script
  file{"/usr/bin/cat":
    ensure => link,
    target => "/bin/cat",
  }
  
  # the stupid script which configures the VMWare server
  exec{"configure vmware":
    command => "/usr/bin/vmware-config.pl --skip-stop-start --preserve --try-modules EULA_AGREED=yes",
    onlyif => "/usr/bin/test -f /etc/vmware/not_configured",
    timeout => 60,
    require => [File["/etc/vmware/locations"],File["/etc/vmware/license.vs.1.0-00"],File["/usr/bin/cat"]],
  }
  
  exec{"cleanup vmware config":
    command => "/bin/rm -rf /etc/vmware/not_configured /etc/vmware/hostd/authorization.xml",
    refreshonly => true,
    subscribe => Exec["configure vmware"],
  }

  # provide basic default group to access VMWare server, by default root and padm group can manage the server
  # we don't force this file, as the server admin should change the permission if needed.
  file{"/etc/vmware/hostd/authorization.xml":
    owner => root, group => root, mode => 644,
    source => "puppet:///$modulename/etc/vmware/hostd/authorization.xml",
    require => Exec["cleanup vmware config"],
    before => Service["vmware"],
    replace => no,
  }

}
