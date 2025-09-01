#!/bin/bash
set -e

# Build script using Containerfile
EL_VERSION=${1:-9}
BUILD_IMAGE="ch-build-el${EL_VERSION}"

echo "Building Cloud Hypervisor RPMs for EL${EL_VERSION}"

# Build the build environment container
echo "=== Building container image ==="
podman build -f Containerfile.build -t "${BUILD_IMAGE}" --build-arg EL_VERSION="${EL_VERSION}"

# Run the build process
echo "=== Running RPM build ==="
podman run --rm -it \
  -v "$(pwd):/workspace:Z" \
  -w /workspace \
  "${BUILD_IMAGE}" \
  bash -c "
    set -e
    
    echo '=== Setting up environment variables ==='
    export CH_VERSION=\$(date +%Y%m%d.%H%M%S)
    export CH_COMMIT=\$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')
    export CH_LATEST_TAG=\$(git describe --tags --abbrev=0 2>/dev/null || echo '')
    
    echo \"Version: \$CH_VERSION\"
    echo \"Commit: \$CH_COMMIT\"
    echo \"Latest tag: \$CH_LATEST_TAG\"
    
    echo '=== Cloning cloud-hypervisor repository ==='
    if [ ! -d \"cloud-hypervisor\" ]; then
      git clone https://github.com/cloud-hypervisor/cloud-hypervisor.git
    fi
    cd cloud-hypervisor
    git fetch --tags
    
    echo '=== Fetching release notes ==='
    cd ..
    mkdir -p ~/rpmbuild/SOURCES
    
    # Create release notes file
    cat > ~/rpmbuild/SOURCES/RELEASE_NOTES.md << 'EOF'
# Cloud Hypervisor Release Notes

EOF
    
    # If we have a latest tag, fetch its release notes from GitHub API
    if [ -n \"\$CH_LATEST_TAG\" ]; then
      echo \"Fetching release notes for tag: \$CH_LATEST_TAG\"
      
      # Try to get release notes from GitHub API
      RELEASE_NOTES=\$(curl -s \"https://api.github.com/repos/cloud-hypervisor/cloud-hypervisor/releases/tags/\$CH_LATEST_TAG\" | \\
        python3 -c \"import sys, json; data=json.load(sys.stdin); print(data.get('body', '')) if 'body' in data else print('')\" 2>/dev/null || echo \"\")
      
      if [ -n \"\$RELEASE_NOTES\" ]; then
        echo \"## Release \$CH_LATEST_TAG\" >> ~/rpmbuild/SOURCES/RELEASE_NOTES.md
        echo \"\" >> ~/rpmbuild/SOURCES/RELEASE_NOTES.md
        echo \"\$RELEASE_NOTES\" >> ~/rpmbuild/SOURCES/RELEASE_NOTES.md
        echo \"\" >> ~/rpmbuild/SOURCES/RELEASE_NOTES.md
      else
        echo \"No release notes found for tag \$CH_LATEST_TAG\" >> ~/rpmbuild/SOURCES/RELEASE_NOTES.md
        echo \"\" >> ~/rpmbuild/SOURCES/RELEASE_NOTES.md
      fi
    else
      echo \"No release tag found - building from development branch\" >> ~/rpmbuild/SOURCES/RELEASE_NOTES.md
      echo \"\" >> ~/rpmbuild/SOURCES/RELEASE_NOTES.md
    fi
    
    # Generate RPM changelog format
    cat > ~/rpmbuild/SOURCES/rpm_changelog.txt << EOF
* \$(date '+%a %b %d %Y') Build System <build@example.com> - \${CH_VERSION}-1
- Built from cloud-hypervisor \${CH_VERSION} (\${CH_COMMIT})
\$(if [ -n \"\$CH_LATEST_TAG\" ]; then echo \"- Release notes for \${CH_LATEST_TAG}\"; fi)
- See /usr/share/doc/cloud-hypervisor/RELEASE_NOTES.md for detailed changes
EOF
    
    echo '=== Setting up RPM build environment ==='
    # Copy spec file to SPECS directory
    cp packaging/cloud-hypervisor.spec ~/rpmbuild/SPECS/
    
    echo '=== Building cloud-hypervisor binary ==='
    cd cloud-hypervisor
    cargo build --release --target=x86_64-unknown-linux-musl
    strip target/x86_64-unknown-linux-musl/release/cloud-hypervisor
    
    # Copy required files to SOURCES
    cp target/x86_64-unknown-linux-musl/release/cloud-hypervisor ~/rpmbuild/SOURCES/
    cp release-notes.md ~/rpmbuild/SOURCES/RELEASE_NOTES.md
    cp README.md ~/rpmbuild/SOURCES/
    cp LICENSES/Apache-2.0.txt ~/rpmbuild/SOURCES/LICENSE-APACHE
    cp LICENSES/BSD-3-Clause.txt ~/rpmbuild/SOURCES/LICENSE-BSD-3-Clause
    cp ../rpm_changelog.txt ~/rpmbuild/SOURCES/
    cd ..
    
    echo '=== Building main RPM package ==='
    rpmbuild -ba ~/rpmbuild/SPECS/cloud-hypervisor.spec \\
      --define \"version \$CH_VERSION\" \\
      --define \"el_version ${EL_VERSION}\"
    
    echo '=== RPM build completed successfully ==='
    echo 'Generated RPM files:'
    ls -la ~/rpmbuild/RPMS/x86_64/cloud-hypervisor-*.rpm
    ls -la ~/rpmbuild/SRPMS/cloud-hypervisor-*.src.rpm
    
    echo '=== Running rpmlint checks ==='
    rpmlint ~/rpmbuild/RPMS/*/cloud-hypervisor*.rpm || true
    
    
    echo '=== Copying RPMs to workspace ==='
    mkdir -p /workspace/test-rpms
    cp ~/rpmbuild/RPMS/*/cloud-hypervisor*.rpm /workspace/test-rpms/
    cp ~/rpmbuild/SRPMS/*.rpm /workspace/test-rpms/
    
    echo '=== Test build complete ==='
    echo 'RPMs available in ./test-rpms/'
    ls -la /workspace/test-rpms/
  "

echo "=== Build complete ==="
echo "RPMs created in ./test-rpms/"
