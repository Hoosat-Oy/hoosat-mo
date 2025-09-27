# Blake3 Motoko Library Makefile

.PHONY: help build test clean install

help:
	@echo "Blake3 Motoko Library"
	@echo "===================="
	@echo "Available targets:"
	@echo "  build     - Build the library"
	@echo "  test      - Run tests"
	@echo "  clean     - Clean build artifacts"
	@echo "  install   - Install dependencies"
	@echo "  deploy    - Deploy test canisters"

build:
	@echo "Building Blake3 Motoko library..."
	@dfx build

test: build
	@echo "Running Blake3 tests..."
	@dfx canister call blake3_test runAllTests
	@dfx canister call blake3_test runZeroPaddedKeyTests
	@dfx canister call blake3_test testZeroPaddedKeyUniqueness

clean:
	@echo "Cleaning build artifacts..."
	@dfx clean

install:
	@echo "Installing dependencies..."
	@dfx start --background

deploy: build
	@echo "Deploying test canisters..."
	@dfx deploy blake3_test
	@dfx deploy blake3_example

demo: deploy
	@echo "Running demo..."
	@dfx canister call blake3_example demonstrateUsage

lint:
	@echo "Running linter..."
	@moc --check src/Blake3.mo
	@moc --check src/Blake3Test.mo
	@moc --check src/Blake3Example.mo
