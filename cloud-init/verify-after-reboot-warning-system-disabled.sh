# Check flag file is gone
ls -la /run/cloud-init-in-progress  # Should not exist

# Check normal banner is restored
cat /etc/ssh/banner  # Should show normal authorized access message

# Check completion marker exists
ls -la /var/lib/cloud/instance/hardening-complete  # Should exist

# Login should no longer show warning
# (test by opening a new SSH session)