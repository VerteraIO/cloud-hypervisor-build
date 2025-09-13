# Cloud Hypervisor RPM Build Makefile

# Variables
CH_REPO = https://github.com/cloud-hypervisor/cloud-hypervisor.git
TARGET = x86_64-unknown-linux-musl
EL_VERSION ?= 9
SOURCES_DIR = $(HOME)/rpmbuild/SOURCES
SPECS_DIR = $(HOME)/rpmbuild/SPECS

# Rust toolchain variables
RUSTUP ?= $(HOME)/.cargo/bin/rustup
CARGO  ?= $(HOME)/.cargo/bin/cargo

# Get version info from git
CH_VERSION := $(shell cd cloud-hypervisor 2>/dev/null && git describe --tags --always || echo "unknown")
CH_COMMIT := $(shell cd cloud-hypervisor 2>/dev/null && git rev-parse HEAD || echo "unknown")
CH_LATEST_TAG := $(shell cd cloud-hypervisor 2>/dev/null && git describe --tags --abbrev=0 2>/dev/null || echo "")
# Derive RPM spec gitver (major.minor) from CH_VERSION like v48.0, v48.0-1-g<hash>
CH_GITVER := $(shell echo $(CH_VERSION) | sed -E 's/^v?([0-9]+\.[0-9]+).*/\1/')
CH_GITNUM ?= 0

.PHONY: all clean setup clone setup-rust build-binary copy-files build-rpm test

all: setup clone setup-rust build-binary copy-files build-rpm

setup:
	@echo "=== Setting up RPM build environment ==="
	rpmdev-setuptree

clone:
	@echo "=== Cloning cloud-hypervisor repository ==="
	@if [ ! -d "cloud-hypervisor" ]; then \
		git clone $(CH_REPO); \
	else \
		cd cloud-hypervisor && git pull; \
	fi

setup-rust:
	@echo "=== Setting up Rust toolchain ==="
	@command -v $(RUSTUP) >/dev/null 2>&1 || (curl https://sh.rustup.rs -sSf | sh -s -- -y)
	@$(RUSTUP) default stable
	@$(RUSTUP) target add $(TARGET)

build-binary: setup-rust
	@echo "=== Building cloud-hypervisor binary ==="
	cd cloud-hypervisor && \
	$(CARGO) +stable build --release --target=$(TARGET) && \
	strip target/$(TARGET)/release/cloud-hypervisor

copy-files:
	@echo "=== Copying files to SOURCES directory ==="
	# Copy binary
	cp cloud-hypervisor/target/$(TARGET)/release/cloud-hypervisor $(SOURCES_DIR)/
	
	# Copy documentation files (with fallbacks)
	@if [ -f "cloud-hypervisor/RELEASE_NOTES.md" ]; then \
		cp cloud-hypervisor/RELEASE_NOTES.md $(SOURCES_DIR)/; \
	elif [ -f "cloud-hypervisor/release-notes.md" ]; then \
		cp cloud-hypervisor/release-notes.md $(SOURCES_DIR)/RELEASE_NOTES.md; \
	elif [ -f "cloud-hypervisor/RELEASES.md" ]; then \
		cp cloud-hypervisor/RELEASES.md $(SOURCES_DIR)/RELEASE_NOTES.md; \
	else \
		echo "# Cloud Hypervisor Release Notes" > $(SOURCES_DIR)/RELEASE_NOTES.md; \
		echo "" >> $(SOURCES_DIR)/RELEASE_NOTES.md; \
		echo "Version: $(CH_VERSION)" >> $(SOURCES_DIR)/RELEASE_NOTES.md; \
		echo "Commit: $(CH_COMMIT)" >> $(SOURCES_DIR)/RELEASE_NOTES.md; \
	fi
	
	# Copy README
	@if [ -f "cloud-hypervisor/README.md" ]; then \
		cp cloud-hypervisor/README.md $(SOURCES_DIR)/; \
	fi
	
	# Copy license files
	@if [ -f "cloud-hypervisor/LICENSES/Apache-2.0.txt" ]; then \
		cp cloud-hypervisor/LICENSES/Apache-2.0.txt $(SOURCES_DIR)/LICENSE-APACHE; \
	fi
	@if [ -f "cloud-hypervisor/LICENSES/BSD-3-Clause.txt" ]; then \
		cp cloud-hypervisor/LICENSES/BSD-3-Clause.txt $(SOURCES_DIR)/LICENSE-BSD-3-Clause; \
	fi
	
	# Generate RPM changelog
	@echo "* $$(date '+%a %b %d %Y') Build System <build@example.com> - $(CH_VERSION)-1" > $(SOURCES_DIR)/rpm_changelog.txt
	@echo "- Built from cloud-hypervisor $(CH_VERSION) ($(CH_COMMIT))" >> $(SOURCES_DIR)/rpm_changelog.txt
	@if [ -n "$(CH_LATEST_TAG)" ]; then \
		echo "- Release notes for $(CH_LATEST_TAG)" >> $(SOURCES_DIR)/rpm_changelog.txt; \
	fi
	@echo "- See /usr/share/doc/cloud-hypervisor/RELEASE_NOTES.md for detailed changes" >> $(SOURCES_DIR)/rpm_changelog.txt
	
	# Copy spec file
	cp packaging/cloud-hypervisor.spec $(SPECS_DIR)/

build-rpm:
	@echo "=== Building RPM package ==="
	rpmbuild -ba $(SPECS_DIR)/cloud-hypervisor.spec \
		--define "gitver $(CH_GITVER)" \
		--define "gitnum $(CH_GITNUM)" \
		--define "version $(CH_VERSION)" \
		--define "el_version $(EL_VERSION)"
	
	@echo "=== RPM build completed successfully ==="
	@echo "Generated RPM files:"
	@ls -la $(HOME)/rpmbuild/RPMS/x86_64/cloud-hypervisor-*.rpm
	@ls -la $(HOME)/rpmbuild/SRPMS/cloud-hypervisor-*.src.rpm
	
	@echo "=== Running rpmlint checks ==="
	-rpmlint $(HOME)/rpmbuild/RPMS/*/cloud-hypervisor*.rpm

test:
	@echo "=== Testing RPM installation ==="
	@if [ -f "$(HOME)/rpmbuild/RPMS/x86_64/cloud-hypervisor-"*".rpm" ]; then \
		echo "RPM file found, ready for testing"; \
		ls -la $(HOME)/rpmbuild/RPMS/x86_64/cloud-hypervisor-*.rpm; \
	else \
		echo "No RPM file found. Run 'make all' first."; \
		exit 1; \
	fi

clean:
	@echo "=== Cleaning build artifacts ==="
	rm -rf cloud-hypervisor
	rm -rf $(HOME)/rpmbuild/BUILD/*
	rm -rf $(HOME)/rpmbuild/BUILDROOT/*
	rm -f $(HOME)/rpmbuild/RPMS/*/cloud-hypervisor*
	rm -f $(HOME)/rpmbuild/SRPMS/cloud-hypervisor*
	rm -f $(SOURCES_DIR)/cloud-hypervisor
	rm -f $(SOURCES_DIR)/RELEASE_NOTES.md
	rm -f $(SOURCES_DIR)/README.md
	rm -f $(SOURCES_DIR)/LICENSE-*
	rm -f $(SOURCES_DIR)/rpm_changelog.txt

help:
	@echo "Cloud Hypervisor RPM Build Targets:"
	@echo "  all          - Complete build process (setup + clone + build + package)"
	@echo "  setup        - Set up RPM build environment"
	@echo "  clone        - Clone/update cloud-hypervisor repository"
	@echo "  build-binary - Build the cloud-hypervisor binary"
	@echo "  copy-files   - Copy files to RPM SOURCES directory"
	@echo "  build-rpm    - Build the RPM package"
	@echo "  test         - Test that RPM was built successfully"
	@echo "  clean        - Clean all build artifacts"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  EL_VERSION   - Enterprise Linux version (default: 9)"
