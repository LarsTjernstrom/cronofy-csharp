NUGET=tools/nuget.exe
NUGET_SOURCE=https://www.nuget.org/api/v2/package
NUNIT=packages/NUnit.Runners.*/tools/nunit-console.exe
SLN=Cronofy.sln
TEST_DLLS=build/Cronofy.Test/bin/Debug/Cronofy.Test.dll
GITCOMMIT:=$(shell git rev-parse --verify HEAD)
VERSION:=$(shell cat VERSION)

all: test

clean:
	rm -rf build

full_clean:
	git clean -dfX

mono_version:
	mono --version

install_tools:
	script/nuget-install

set_version:
	mkdir -p build
	echo $(VERSION) > build/VERSION.txt
	echo $(GITCOMMIT) > build/GITCOMMIT.txt
	sed s/%VERSION%/$(VERSION)/ Cronofy.nuspec.template > Cronofy.nuspec
	sed s/%VERSION%/$(VERSION)/ src/Cronofy/Properties/AssemblyVersion.cs.template > src/Cronofy/Properties/AssemblyVersion.cs

build: clean set_version mono_version install_tools
	mono $(NUGET) restore $(SLN)
	msbuild $(SLN)

build_release: build
	msbuild /p:Configuration=Release $(SLN)

test: build
	mkdir -p build/NUnit
	mono $(NUNIT) -result=build/NUnit/TestReport.xml $(TEST_DLLS)

package: test build_release
	mkdir -p artifacts
	mono $(NUGET) pack -Verbosity detailed -OutputDirectory artifacts Cronofy.nuspec

release: package guard-env-NUGET_API_KEY
	@git diff --exit-code --no-patch || (echo "Cannot release with uncommitted changes"; exit 1)
	git push
	@echo "Publishing artifacts/Cronofy.$(VERSION).nupkg"
	@mono $(NUGET) push -ApiKey $(NUGET_API_KEY) -Source $(NUGET_SOURCE) artifacts/Cronofy.$(VERSION).nupkg
	git tag rel-$(VERSION)
	git push --tags

guard-env-%:
	@ if [ "${${*}}" == "" ]; then \
		echo "$* must be set"; \
		exit 1; \
	fi
