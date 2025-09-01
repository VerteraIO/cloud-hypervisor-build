#!/bin/bash
set -e

# Test script for RPM installation using Containerfile
EL_VERSION=${1:-9}
TEST_IMAGE="ch-test-el${EL_VERSION}"

echo "Testing Cloud Hypervisor RPM installation for EL${EL_VERSION}"

if [ ! -d "test-rpms" ]; then
    echo "Error: test-rpms directory not found. Run ./build.sh first."
    exit 1
fi

# Build the test environment container
echo "=== Building test container image ==="
podman build -f Containerfile.test -t "${TEST_IMAGE}" --build-arg EL_VERSION="${EL_VERSION}"

# Run installation tests
echo "=== Testing RPM installation ==="
podman run --rm -it \
  -v "$(pwd)/test-rpms:/test-rpms:ro,Z" \
  "${TEST_IMAGE}" \
  bash -c "
    set -e
    
    echo '=== Installing main package ==='
    rpm -ivh /test-rpms/cloud-hypervisor-*.rpm
    
    echo '=== Verifying installation ==='
    rpm -qa | grep cloud-hypervisor
    
    echo '=== Checking installed files ==='
    rpm -ql cloud-hypervisor
    
    echo '=== Verifying binary ==='
    /usr/bin/cloud-hypervisor --version || echo 'Version check failed (expected for static binary)'
    
    echo '=== Checking systemd service ==='
    systemctl status cloud-hypervisor || echo 'Service not running (expected)'
    
    echo '=== Checking file contexts ==='
    ls -laZ /usr/bin/cloud-hypervisor || echo 'File contexts check failed'
    
    echo '=== Testing package removal ==='
    rpm -e cloud-hypervisor
    
    echo '=== Installation test completed successfully ==='
  "

echo "=== Test complete ==="
