# Deploy SSL private keys
#
# [*root_path*]
#   (optional) Root directory path for SSL key
#   Defaults to undef.
#
# [*key_owner*]
#   (optional) Owner of SSL private key
#   Defaults to $name.
#
define openstack_integration::ssl_key (
  $root_path = undef,
  $key_owner = $name,
) {
  include openstack_integration::config

  $_root_path = $root_path ? {
    undef   => "/etc/${name}/ssl",
    default => $root_path,
  }

  # If the user isn't providing an unexpected path, create the directory.
  if $root_path == undef {
    file { $_root_path:
      ensure                  => directory,
      owner                   => $key_owner,
      mode                    => '0750',
      selinux_ignore_defaults => true,
    }
  }

  # Private key
  file { "${_root_path}/private":
    ensure                  => directory,
    owner                   => $key_owner,
    mode                    => '0750',
    selinux_ignore_defaults => true,
  }
  file { "${_root_path}/private/key.pem":
    ensure                  => file,
    owner                   => $key_owner,
    mode                    => '0640',
    source                  => 'puppet:///modules/openstack_integration/server.key',
    selinux_ignore_defaults => true,
  }

  # Public certificate
  file { "${_root_path}/certs":
    ensure                  => directory,
    owner                   => $key_owner,
    mode                    => '0750',
    selinux_ignore_defaults => true,
  }
  file { "${_root_path}/certs/cert.pem":
    ensure                  => file,
    owner                   => $key_owner,
    mode                    => '0640',
    source                  => 'puppet:///modules/openstack_integration/server.crt',
    selinux_ignore_defaults => true,
  }
}
