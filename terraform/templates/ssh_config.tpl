# SSH Configuration for ${hostname}
# Add this to your ~/.ssh/config or use: ssh -F .ssh_config ${hostname}

Host ${hostname}
    HostName ${host_address}
    User ${user}
    IdentityFile ${ssh_key}
    IdentitiesOnly yes
    StrictHostKeyChecking ask
    UserKnownHostsFile ~/.ssh/known_hosts
    
    # Yubikey FIDO2
    SecurityKeyProvider internal
    
    # Connection settings
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
    
    # Compression
    Compression yes
    
    # Forward agent (disable for security)
    ForwardAgent no
    ForwardX11 no
