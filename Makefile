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

INT_TEST_PROFILE 	?= $(CURDIR)/profile-int.cov
UNIT_TEST_PROFILE 	?= $(CURDIR)/profile-unit.cov
INT_BROKER_TEST_PROFILE ?= $(CURDIR)/profile-int-broker.cov
INT_OSB_AND_PLUGIN_TEST_PROFILE ?= $(CURDIR)/profile-int-osb-and-plugin.cov
INT_SERVICE_INSTANCE_AND_BINDINGS_TEST_PROFILE ?= $(CURDIR)/profile-int-service-instance-and-bindings.cov
INT_OTHER_TEST_PROFILE ?= $(CURDIR)/profile-int-other.cov
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
				./test/... $(TEST_FLAGS) -coverprofile=$(INT_TEST_PROFILE)

GO_INT_TEST_OTHER = $(GO) test -p 1 -timeout 30m -race -coverpkg $(shell go list ./... | egrep -v "fakes|test|cmd|parser" | paste -sd "," -) \
				$(shell go list ./test/... | egrep -v "broker_test|osb_and_plugin_test|service_instance_and_binding_test") $(TEST_FLAGS) -coverprofile=$(INT_OTHER_TEST_PROFILE)

GO_INT_TEST_BROKER = $(GO) test -p 1 -timeout 30m -race -coverpkg $(shell go list ./... | egrep -v "fakes|test|cmd|parser" | paste -sd "," -) \
				./test/broker_test/... $(TEST_FLAGS) -coverprofile=$(INT_BROKER_TEST_PROFILE)

GO_INT_TEST_OSB_AND_PLUGIN = $(GO) test -p 1 -timeout 30m -race -coverpkg $(shell go list ./... | egrep -v "fakes|test|cmd|parser" | paste -sd "," -) \
				./test/osb_and_plugin_test/... $(TEST_FLAGS) -coverprofile=$(INT_OSB_AND_PLUGIN_TEST_PROFILE)

GO_INT_TEST_SERVICE_INSTANCE_AND_BINDING = $(GO) test -p 1 -timeout 30m -race -coverpkg $(shell go list ./... | egrep -v "fakes|test|cmd|parser" | paste -sd "," -) \
				./test/service_instance_and_binding_test/... $(TEST_FLAGS) -coverprofile=$(INT_SERVICE_INSTANCE_AND_BINDINGS_TEST_PROFILE)

GO_UNIT_TEST 	= $(GO) test -p 1 -race -coverpkg $(shell go list ./... | egrep -v "fakes|test|cmd|parser" | paste -sd "," -) \
				$(shell go list ./... | egrep -v "test") -coverprofile=$(UNIT_TEST_PROFILE)

COUNTERFEITER   ?= "v6.0.2"

#-----------------------------------------------------------------------------
# Prepare environment to be able to run other make targets
#-----------------------------------------------------------------------------

prepare-counterfeiter:
	@echo "Installing counterfeiter $(COUNTERFEITER)..."
	@go get -u github.com/maxbrunsfeld/counterfeiter/v6
	#@cd ${GOPATH}/src/github.com/maxbrunsfeld/counterfeiter;\
	#	counterfeiterBranch=$(shell cd ${GOPATH}/src/github.com/maxbrunsfeld/counterfeiter && git symbolic-ref --short HEAD);\
	#	git checkout tags/$(COUNTERFEITER) >/dev/null 2>&1;\
	#	go install;\
	#	echo "Revert to last known branch: $$counterfeiterBranch";\
	#	git checkout $$counterfeiterBranch >/dev/null 2>&1
	#
	#@chmod a+x ${GOPATH}/bin/counterfeiter

prepare: prepare-counterfeiter build-gen-binary ## Installs some tools (dep, gometalinter, cover, goveralls)
#ifeq ($(shell which gometalinter),)
#	@echo "Installing gometalinter..."
#	@curl -L https://git.io/vp6lP | sh
#endif

# golangci-lint replacing depricated gometalinter
ifeq ($(shell which golangci-lint),)
	@echo "Installing golangci-lint..."
	@go get github.com/golangci/golangci-lint/cmd/golangci-lint
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

#build: .init dep-vendor-only service-manager ## Downloads vendored dependecies and builds the service-manager binary

#dep-check:
#	@which dep 2>/dev/null || (echo dep is required to build the project; exit 1)

#dep: dep-check ## Runs dep ensure -v
#	@dep ensure -v
#	@dep status

#dep-vendor-only: dep-check ## Runs dep ensure --vendor-only -v
#	@dep ensure --vendor-only -v
#	@dep status

#dep-reload: dep-check clean-vendor dep ## Recreates the vendored dependencies

build: .init gomod-vendor service-manager ## Downloads vendored dependecies and builds the service-manager binary

gomod-vendor:
	@go mod vendor

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
	@echo > go.mod

build-gen-binary:
	@go install github.com/Peripli/service-manager/cmd/smgen

#-----------------------------------------------------------------------------
# Tests and coverage
#-----------------------------------------------------------------------------

generate: prepare-counterfeiter build-gen-binary $(GENERATE_PREREQ_FILES) ## Recreates gen files if any of the files containing go:generate directives have changed
	$(GO) list ./... | xargs $(GO) generate
	@touch $@

test-unit:
	@echo Running unit tests:
	$(GO_UNIT_TEST)

test-int: generate ## Runs the integration tests. Use TEST_FLAGS="--storage.uri=postgres://postgres:postgres@localhost:5432/postgres?sslmode=disable" to specify the DB. All other SM flags are also supported
	@echo Running integration tests:
	$(GO_INT_TEST)

test-int-other:
	@echo Running integration tests:
	$(GO_INT_TEST_OTHER)

test-int-broker:
	@echo Running integration tests:
	$(GO_INT_TEST_BROKER)

test-int-osb-and-plugin:
	@echo Running integration tests:
	$(GO_INT_TEST_OSB_AND_PLUGIN)

test-int-service-instance-and-binding:
	@echo Running integration tests:
	$(GO_INT_TEST_SERVICE_INSTANCE_AND_BINDING)

test-report: test-int test-unit
	@$(GO) get github.com/wadey/gocovmerge
	@gocovmerge $(CURDIR)/*.cov > $(TEST_PROFILE)


coverage: test-report ## Produces an HTML report containing code coverage details
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
precommit: build coverage format-check lint-check ## Run this before commiting (builds, recreates fakes, runs tests, checks linting and formating). This also runs integration tests - check test-int target for details
precommit-integration-tests-broker: build test-int-broker ## Run this before commiting (builds, recreates fakes, runs tests, checks linting and formating). This also runs integration tests - check test-int target for details
precommit-integration-tests-osb-and-plugin: build test-int-osb-and-plugin ## Run this before commiting (builds, recreates fakes, runs tests, checks linting and formating). This also runs integration tests - check test-int target for details
precommit-integration-tests-service-instance-and-binding: build test-int-service-instance-and-binding ## Run this before commiting (builds, recreates fakes, runs tests, checks linting and formating). This also runs integration tests - check test-int target for details
precommit-integration-tests-other: build test-int-other ## Run this before commiting (builds, recreates fakes, runs tests, checks linting and formating). This also runs integration tests - check test-int target for details
precommit-unit-tests: build test-unit format-check lint-check ## Run this before commiting (builds, recreates fakes, runs tests, checks linting and formating). This also runs integration tests - check test-int target for details
precommit-new-unit-tets: prepare build test-unit format-check lint-check

precommit-new-unit-tets: prepare build test-unit format-check lint-check
precommit-new-integration-tests-broker: prepare build  test-int-broker
precommit-new-integration-tests-osb-and-plugin: prepare build test-int-osb-and-plugin
precommit-new-integration-tests-service-instance-and-binding: prepare build test-int-service-instance-and-binding
precommit-integration-tests-other: prepare build test-int-other

format: ## Formats the source code files with gofmt
	@echo The following files were reformated:
	@$(GOFMT) -l -s -w $(SOURCE_FILES)

format-check: ## Checks for style violation using gofmt
	@echo Checking if there are files not formatted with gofmt...
	@$(GOFMT) -l -s $(SOURCE_FILES) | grep ".*\.go"; if [ "$$?" = "0" ]; then echo "Files need reformating! Run make format!" ; exit 1; fi

lint-check: ## Runs some linters and static code checks
	@echo Running linter checks...
	#@gometalinter --vendor ./...
	@golangci-lint run

#-----------------------------------------------------------------------------
# Useful utility targets
#-----------------------------------------------------------------------------

clean: clean-bin clean-coverage ## Cleans up binaries, test and coverage artifacts

help: ## Displays documentation about the makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
