# Deploy SSL private keys
#
# [*key_path*]
#   (optional) Path of SSL private key
#   Defaults to undef.
#
define openstack_integration::ssl_key(
  $key_path = undef,
) {

  include ::openstack_integration::config

  if $key_path == undef {
    $_key_path  = "/etc/${name}/ssl/private/${::fqdn}.pem"
  } else {
    $_key_path = $key_path
  }

  # If the user isn't providing an unexpected path, create the directory
  # structure.
  if $key_path == undef {
    file { "/etc/${name}/ssl":
      ensure                  => directory,
      owner                   => $name,
      mode                    => '0775',
      selinux_ignore_defaults => true,
    }
    file { "/etc/${name}/ssl/private":
      ensure                  => directory,
      owner                   => $name,
      mode                    => '0755',
      require                 => File["/etc/${name}/ssl"],
      selinux_ignore_defaults => true,
      before                  => File[$_key_path]
    }
  }

  file { $_key_path:
    ensure                  => present,
    owner                   => $name,
    source                  => "puppet:///modules/openstack_integration/ipv${openstack_integration::config::ip_version}.key",
    selinux_ignore_defaults => true,
    mode                    => '0600',
  }
}
