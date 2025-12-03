.PHONY: all clean rpm srpm build-tree install help

# Package information
NAME := versitygw-quadlet
SPEC := $(NAME).spec
VERSION := $(shell grep '^Version:' $(SPEC) | awk '{print $$2}')
RELEASE := $(shell grep '^Release:' $(SPEC) | awk '{print $$2}' | cut -d'%' -f1)

# RPM build directories
RPMBUILD := $(HOME)/rpmbuild
BUILD_DIR := $(RPMBUILD)/BUILD
RPMS_DIR := $(RPMBUILD)/RPMS
SRPMS_DIR := $(RPMBUILD)/SRPMS
SOURCES_DIR := $(RPMBUILD)/SOURCES
SPECS_DIR := $(RPMBUILD)/SPECS

# Output files
RPM_FILE := $(RPMS_DIR)/noarch/$(NAME)-$(VERSION)-$(RELEASE).el9.noarch.rpm
SRPM_FILE := $(SRPMS_DIR)/$(NAME)-$(VERSION)-$(RELEASE).el9.src.rpm

all: rpm ## Build the RPM (default target)

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build-tree: ## Set up the RPM build directory structure
	@echo "Setting up RPM build tree..."
	@rpmdev-setuptree 2>/dev/null || mkdir -p $(BUILD_DIR) $(RPMS_DIR) $(SRPMS_DIR) $(SOURCES_DIR) $(SPECS_DIR)

rpm: build-tree ## Build the binary RPM
	@echo "Copying sources to $(SOURCES_DIR)..."
	@cp SOURCES/* $(SOURCES_DIR)/
	@echo "Copying spec file to $(SPECS_DIR)..."
	@cp $(SPEC) $(SPECS_DIR)/
	@echo "Building RPM..."
	@rpmbuild -ba $(SPECS_DIR)/$(SPEC)
	@echo ""
	@echo "Build complete!"
	@echo "RPM: $(RPM_FILE)"
	@echo "SRPM: $(SRPM_FILE)"

srpm: build-tree ## Build the source RPM only
	@echo "Copying sources to $(SOURCES_DIR)..."
	@cp SOURCES/* $(SOURCES_DIR)/
	@echo "Copying spec file to $(SPECS_DIR)..."
	@cp $(SPEC) $(SPECS_DIR)/
	@echo "Building SRPM..."
	@rpmbuild -bs $(SPECS_DIR)/$(SPEC)
	@echo ""
	@echo "Build complete!"
	@echo "SRPM: $(SRPM_FILE)"

install: rpm ## Build and install the RPM
	@echo "Installing $(RPM_FILE)..."
	@sudo dnf install -y $(RPM_FILE)

clean: ## Clean up build artifacts
	@echo "Cleaning up build tree..."
	@rm -rf $(BUILD_DIR)/$(NAME)-*
	@rm -f $(RPMS_DIR)/noarch/$(NAME)-*
	@rm -f $(SRPMS_DIR)/$(NAME)-*
	@rm -f $(SOURCES_DIR)/versitygw-*
	@rm -f $(SPECS_DIR)/$(SPEC)
	@echo "Clean complete!"

distclean: clean ## Remove the entire rpmbuild directory
	@echo "Removing entire rpmbuild directory..."
	@rm -rf $(RPMBUILD)
	@echo "Distclean complete!"
