# Makefile for GitHub release automation

# Variables
GITHUB_REPO := ssnow/arch_install
VERSION := $(shell git describe --tags --abbrev=0)
MAJOR := $(shell echo $(VERSION) | cut -d. -f1)
MINOR := $(shell echo $(VERSION) | cut -d. -f2)
PATCH := $(shell echo $(VERSION) | cut -d. -f3)

.PHONY: help release major minor patch update_changelog update_docs

help:
	@echo "Available commands:"
	@echo "  make release - Interactive release creation"
	@echo "  make major   - Create a new major release"
	@echo "  make minor   - Create a new minor release"
	@echo "  make patch   - Create a new patch release"

release:
	@echo "Current version: $(VERSION)"
	@echo "Select release type:"
	@echo "1) Major ($(MAJOR+1).0.0)"
	@echo "2) Minor ($(MAJOR).$(MINOR+1).0)"
	@echo "3) Patch ($(MAJOR).$(MINOR).$(PATCH+1))"
	@read -p "Enter your choice (1-3): " choice; \
	case $$choice in \
		1) make major ;; \
		2) make minor ;; \
		3) make patch ;; \
		*) echo "Invalid choice. Exiting."; exit 1 ;; \
	esac

major:
	$(eval NEXT_VERSION := $(shell echo $(VERSION) | awk -F. '{$$1 = $$1 + 1; $$2 = 0; $$3 = 0;} 1' | sed 's/ /./g'))
	@$(MAKE) create_release

minor:
	$(eval NEXT_VERSION := $(shell echo $(VERSION) | awk -F. '{$$2 = $$2 + 1; $$3 = 0;} 1' | sed 's/ /./g'))
	@$(MAKE) create_release

patch:
	$(eval NEXT_VERSION := $(shell echo $(VERSION) | awk -F. '{$$NF = $$NF + 1;} 1' | sed 's/ /./g'))
	@$(MAKE) create_release

update_changelog:
	@echo "Updating CHANGELOG.md..."
	@echo "## [$(NEXT_VERSION)] - $(shell date +%Y-%m-%d)" >> CHANGELOG.md.tmp
	@echo "" >> CHANGELOG.md.tmp
	@git log $(VERSION)..HEAD --pretty=format:"- %s" >> CHANGELOG.md.tmp
	@echo "" >> CHANGELOG.md.tmp
	@echo "" >> CHANGELOG.md.tmp
	@cat CHANGELOG.md >> CHANGELOG.md.tmp
	@mv CHANGELOG.md.tmp CHANGELOG.md
	@git add CHANGELOG.md
	@git commit -m "Update CHANGELOG for version $(NEXT_VERSION)"

update_docs:
	@echo "Updating documentation..."
	@sed -i 's/$(VERSION)/$(NEXT_VERSION)/g' README.md
	@git add README.md
	@git commit -m "Update version in README to $(NEXT_VERSION)"

create_release: update_changelog update_docs
	@echo "Creating new release $(NEXT_VERSION)..."
	@git checkout main
	@git pull origin main
	@git tag -a $(NEXT_VERSION) -m "Release $(NEXT_VERSION)"
	@read -p "Ready to push release $(NEXT_VERSION) to GitHub. Continue? (y/n) " answer; \
	if [ "$$answer" != "y" ]; then \
		echo "Release cancelled."; \
		exit 1; \
	fi
	@git push origin main --tags
	@echo "Release $(NEXT_VERSION) created and pushed to GitHub."
	@echo "Don't forget to review and finalize the release notes on GitHub!"
