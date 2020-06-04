# Copyright 2018 The Service Manager Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

all: build test-unit ## Default target that builds SM and runs unit-tests

GO 					?= go
GOFMT 				?= gofmt
BINDIR 				?= bin
PROJECT_PKG 		?= github.com/Peripli/service-manager

PLATFORM 			?= linux
ARCH     			?= amd64

UNIT_TEST_PROFILE 	?= $(CURDIR)/profile-unit.cov
INT_TEST_PROFILE 	?= $(CURDIR)/profile-int.cov
TEST_PROFILE 		?= $(CURDIR)/profile.cov
COVERAGE 			?= $(CURDIR)/coverage.html

VERSION          	?= $(shell git describe --tags --always --dirty)
DATE             	?= $(shell date -u '+%Y-%m-%d-%H%M UTC')
VERSION_FLAGS    	?= -X "main.Version=$(VERSION)" -X "main.BuildTime=$(DATE)"

# .go files - excludes fakes, mocks, generated files, etc...
SOURCE_FILES	= $(shell find . -type f -name '*.go' ! -name '*.gen.go' ! -name '*.pb.go' ! -name '*mock*.go' \
				! -name '*fake*.go' ! -path "./vendor/*" ! -path "./pkg/query/parser/*"  ! -path "*/*fakes*/*" \
				-exec grep -vrli 'Code generated by counterfeiter' {} \;)

# .go files with go:generate directives (currently files that contain interfaces for which counterfeiter fakes are generated)
GENERATE_PREREQ_FILES = $(shell find . -name "*.go" ! -path "./vendor/*" -exec grep "go:generate" -rli {} \;)

# GO_FLAGS - extra "go build" flags to use - e.g. -v (for verbose)
GO_BUILD 		= env CGO_ENABLED=0 GOOS=$(PLATFORM) GOARCH=$(ARCH) \
           		$(GO) build $(GO_FLAGS) -ldflags '-s -w $(BUILD_LDFLAGS) $(VERSION_FLAGS)'

# TEST_FLAGS - extra "go test" flags to use
GO_INT_TEST 	= $(GO) test -p 1 -timeout 30m -race -coverpkg $(shell go list ./... | egrep -v "fakes|test|cmd|parser" | paste -sd "," -) \
				./test/integration_test/... $(TEST_FLAGS) -coverprofile=$(INT_TEST_PROFILE)

GO_RES_TEST 	= $(GO) test -p 1 -timeout 30m -race -coverpkg $(shell go list ./... | egrep -v "fakes|test|cmd|parser" | paste -sd "," -) \
				./test/resources_test/... $(TEST_FLAGS) -coverprofile=$(INT_TEST_PROFILE)

GO_UNIT_TEST 	= $(GO) test -p 1 -race -coverpkg $(shell go list ./... | egrep -v "fakes|test|cmd|parser" | paste -sd "," -) \
				$(shell go list ./... | egrep -v "test") -coverprofile=$(UNIT_TEST_PROFILE)

COUNTERFEITER   ?= "v6.0.2"

#-----------------------------------------------------------------------------
# Prepare environment to be able to run other make targets
#-----------------------------------------------------------------------------

prepare-counterfeiter:
	@echo "Installing counterfeiter $(COUNTERFEITER)..."
	@go get github.com/maxbrunsfeld/counterfeiter
	@cd ${GOPATH}/src/github.com/maxbrunsfeld/counterfeiter;\
		counterfeiterBranch=$(shell cd ${GOPATH}/src/github.com/maxbrunsfeld/counterfeiter && git symbolic-ref --short HEAD);\
		git checkout tags/$(COUNTERFEITER) >/dev/null 2>&1;\
		go install;\
		echo "Revert to last known branch: $$counterfeiterBranch";\
		git checkout $$counterfeiterBranch >/dev/null 2>&1

	@chmod a+x ${GOPATH}/bin/counterfeiter

prepare: prepare-counterfeiter build-gen-binary ## Installs some tools (dep, gometalinter, cover, goveralls)
ifeq ($(shell which dep),)
	@echo "Installing dep..."
	@go get -u github.com/golang/dep/cmd/dep
	@chmod a+x ${GOPATH}/bin/dep
endif
ifeq ($(shell which gometalinter),)
	@echo "Installing gometalinter..."
	@go get -u github.com/alecthomas/gometalinter
	@gometalinter --install
endif
ifeq ($(shell which cover),)
	@echo "Installing cover tool..."
	@go get -u golang.org/x/tools/cmd/cover
endif
ifeq ($(shell which goveralls),)
	@echo "Installing goveralls..."
	@go get github.com/mattn/goveralls
endif
ifeq ($(shell which golint),)
	@echo "Installing golint... "
	@go get -u golang.org/x/lint/golint
endif

#-----------------------------------------------------------------------------
# Builds and dependency management
#-----------------------------------------------------------------------------

build: .init dep-vendor-only service-manager ## Downloads vendored dependecies and builds the service-manager binary

dep-check:
	@which dep 2>/dev/null || (echo dep is required to build the project; exit 1)

dep: dep-check ## Runs dep ensure -v
	@dep ensure -v
	@dep status

dep-vendor-only: dep-check ## Runs dep ensure --vendor-only -v
	@dep ensure --vendor-only -v
	@dep status

dep-reload: dep-check clean-vendor dep ## Recreates the vendored dependencies

service-manager: $(BINDIR)/service-manager

# Build serivce-manager under ./bin/service-manager
$(BINDIR)/service-manager: FORCE | .init
	 $(GO_BUILD) -o $@ $(PROJECT_PKG)

# init creates the bin dir
.init: $(BINDIR)

# Force can be used as a prerequisite to a target and this will cause this target to always run
FORCE:

$(BINDIR):
	mkdir -p $@

clean-bin: ## Cleans up the binaries
	@echo Deleting $(CURDIR)/$(BINDIR) and built binaries...
	@rm -rf $(BINDIR)


clean-vendor: ## Cleans up the vendor folder and prints out the Gopkg.lock
	@echo Deleting vendor folder...
	@rm -rf vendor
	@echo > Gopkg.lock

build-gen-binary:
	@go install github.com/Peripli/service-manager/cmd/smgen

#-----------------------------------------------------------------------------
# Tests and coverage
#-----------------------------------------------------------------------------

generate: prepare-counterfeiter build-gen-binary $(GENERATE_PREREQ_FILES) ## Recreates gen files if any of the files containing go:generate directives have changed
	$(GO) list ./... | xargs $(GO) generate
	@touch $@

test-res: generate
	@echo Running unit tests:
	$(GO_RES_TEST)

test-unit: generate ## Runs the unit tests
	@echo Running unit tests:
	$(GO_UNIT_TEST)

test-int: generate ## Runs the integration tests. Use TEST_FLAGS="--storage.uri=postgres://postgres:postgres@localhost:5432/postgres?sslmode=disable" to specify the DB. All other SM flags are also supported
	@echo Running integration tests:
	$(GO_INT_TEST)

unit-test-report: test-unit
	@$(GO) get github.com/wadey/gocovmerge
	@gocovmerge $(CURDIR)/*.cov > $(TEST_PROFILE)

integration-test-report: test-int
	@$(GO) get github.com/wadey/gocovmerge
	@gocovmerge $(CURDIR)/*.cov > $(TEST_PROFILE)

resources-test-report: test-res
	@$(GO) get github.com/wadey/gocovmerge
	@gocovmerge $(CURDIR)/*.cov > $(TEST_PROFILE)

unit-test-coverage: unit-test-report ## Produces an HTML report containing code coverage details
	@go tool cover -html=$(TEST_PROFILE) -o $(COVERAGE)
	@echo Generated coverage report in $(COVERAGE).

integration-test-coverage: integration-test-report ## Produces an HTML report containing code coverage details
	@go tool cover -html=$(TEST_PROFILE) -o $(COVERAGE)
	@echo Generated coverage report in $(COVERAGE).

resources-test-coverage: resources-test-report ## Produces an HTML report containing code coverage details
	@go tool cover -html=$(TEST_PROFILE) -o $(COVERAGE)
	@echo Generated coverage report in $(COVERAGE).

clean-generate:
	@rm -f generate

clean-test-unit: clean-generate ## Cleans up unit test artifacts
	@echo Deleting $(UNIT_TEST_PROFILE)...
	@rm -f $(UNIT_TEST_PROFILE)

clean-test-int: clean-generate ## Cleans up integration test artifacts
	@echo Deleting $(INT_TEST_PROFILE)...
	@rm -f $(INT_TEST_PROFILE)

clean-test-report: clean-test-unit clean-test-int
	@echo Deleting $(TEST_PROFILE)...
	@rm -f $(TEST_PROFILE)

clean-coverage: clean-test-report ## Cleans up coverage artifacts
	@echo Deleting $(COVERAGE)...
	@rm -f $(COVERAGE)

#-----------------------------------------------------------------------------
# Formatting, Linting, Static code checks
#-----------------------------------------------------------------------------

unit-test-precommit: build unit-test-coverage format-check lint-check ## Run this before commiting (builds, recreates fakes, runs tests, checks linting and formating). This also runs integration tests - check test-int target for details
integration-test-precommit: build integration-test-coverage
resources-test-precommit: build resources-test-coverage

format: ## Formats the source code files with gofmt
	@echo The following files were reformated:
	@$(GOFMT) -l -s -w $(SOURCE_FILES)

format-check: ## Checks for style violation using gofmt
	@echo Checking if there are files not formatted with gofmt...
	@$(GOFMT) -l -s $(SOURCE_FILES) | grep ".*\.go"; if [ "$$?" = "0" ]; then echo "Files need reformating! Run make format!" ; exit 1; fi

lint-check: ## Runs some linters and static code checks
	@echo Running linter checks...
	@gometalinter --vendor ./...

#-----------------------------------------------------------------------------
# Useful utility targets
#-----------------------------------------------------------------------------

clean: clean-bin clean-coverage ## Cleans up binaries, test and coverage artifacts

help: ## Displays documentation about the makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
