#!/bin/bash

# Script to run all tests as they run in CI
# Usage: ./run_all_tests.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track test results
FAILED_TESTS=()
PASSED_TESTS=()

# Function to print section header
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Function to print success message
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error message
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to run a test suite
run_test_suite() {
    local suite_name=$1
    local directory=$2
    local command=$3
    local env_vars=$4
    
    print_header "Running $suite_name"
    
    if [ ! -d "$directory" ]; then
        print_error "$suite_name: Directory $directory not found"
        FAILED_TESTS+=("$suite_name")
        return 1
    fi
    
    cd "$directory" || exit 1
    
    # Export environment variables if provided
    if [ -n "$env_vars" ]; then
        eval "export $env_vars"
    fi
    
    # Run the test command
    if eval "$command"; then
        print_success "$suite_name passed"
        PASSED_TESTS+=("$suite_name")
        cd - > /dev/null || exit 1
        return 0
    else
        print_error "$suite_name failed"
        FAILED_TESTS+=("$suite_name")
        cd - > /dev/null || exit 1
        return 1
    fi
}

# Get the script directory (project root)
# If running from inside Docker container, check /workspace first
if [ -f "/workspace/run_all_tests.sh" ]; then
    SCRIPT_DIR="/workspace"
elif [ -f "/app/run_all_tests.sh" ]; then
    SCRIPT_DIR="/app"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

cd "$SCRIPT_DIR" || exit 1

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║   Running All CI Tests                 ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Check for required services (optional - just warn if not available)
if ! command -v psql &> /dev/null; then
    print_warning "PostgreSQL client not found. Make sure PostgreSQL is running if Rails API tests need it."
fi

if ! command -v redis-cli &> /dev/null; then
    print_warning "Redis client not found. Make sure Redis is running if tests need it."
fi

# 1. Rails API Tests
print_header "1. Rails API Tests"
RAILS_API_DIR=""
if [ -d "$SCRIPT_DIR/rails_api" ]; then
    RAILS_API_DIR="$SCRIPT_DIR/rails_api"
elif [ -d "/app" ] && [ -f "/app/Gemfile" ]; then
    # Running from inside rails_api container
    RAILS_API_DIR="/app"
elif [ -d "rails_api" ]; then
    RAILS_API_DIR="rails_api"
fi

if [ -z "$RAILS_API_DIR" ]; then
    print_error "Rails API directory not found"
    FAILED_TESTS+=("Rails API")
else
    cd "$RAILS_API_DIR" || exit 1
    
    # Check if bundle is installed
    if ! command -v bundle &> /dev/null; then
        print_error "Bundler not found. Please install Ruby and Bundler first."
        FAILED_TESTS+=("Rails API")
        cd - > /dev/null || exit 1
    else
        # Install dependencies if needed
        if [ ! -d "vendor/bundle" ] && [ ! -f ".bundle/config" ]; then
            print_warning "Installing Rails API dependencies..."
            bundle install || {
                print_error "Failed to install Rails API dependencies"
                FAILED_TESTS+=("Rails API")
                cd - > /dev/null || exit 1
            }
        fi
        
        # Setup test database
        export DATABASE_URL="${DATABASE_URL:-postgresql://car_bot:car_bot_password@localhost:5432/car_bot_test}"
        export RAILS_ENV=test
        export REDIS_URL="${REDIS_URL:-redis://localhost:6379/0}"
        
        print_warning "Setting up test database..."
        bundle exec rails db:test:prepare || {
            print_error "Failed to setup test database"
            FAILED_TESTS+=("Rails API")
            cd - > /dev/null || exit 1
        }
        
        # Run tests
        if bundle exec rspec; then
            print_success "Rails API tests passed"
            PASSED_TESTS+=("Rails API")
        else
            print_error "Rails API tests failed"
            FAILED_TESTS+=("Rails API")
        fi
        
        cd - > /dev/null || exit 1
    fi
fi

# 2. Python Workers Tests
print_header "2. Python Workers Tests"
PYTHON_WORKERS_DIR=""
if [ -d "$SCRIPT_DIR/python_workers" ]; then
    PYTHON_WORKERS_DIR="$SCRIPT_DIR/python_workers"
elif [ -d "/app" ] && [ -f "/app/requirements.txt" ] && [ -d "/app/workers" ]; then
    # Running from inside python_workers container
    PYTHON_WORKERS_DIR="/app"
elif [ -d "python_workers" ]; then
    PYTHON_WORKERS_DIR="python_workers"
fi

if [ -z "$PYTHON_WORKERS_DIR" ]; then
    print_error "Python Workers directory not found"
    FAILED_TESTS+=("Python Workers")
else
    cd "$PYTHON_WORKERS_DIR" || exit 1
    
    # Check if Python is installed
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        print_error "Python not found. Please install Python 3.11+ first."
        FAILED_TESTS+=("Python Workers")
        cd - > /dev/null || exit 1
    else
        PYTHON_CMD=$(command -v python3 || command -v python)
        
        # Install dependencies if needed
        if [ ! -d "venv" ] && [ ! -d ".venv" ]; then
            print_warning "Installing Python Workers dependencies..."
            $PYTHON_CMD -m pip install --upgrade pip
            $PYTHON_CMD -m pip install -r requirements.txt || {
                print_error "Failed to install Python Workers dependencies"
                FAILED_TESTS+=("Python Workers")
                cd - > /dev/null || exit 1
            }
        fi
        
        # Run tests
        if $PYTHON_CMD -m pytest; then
            print_success "Python Workers tests passed"
            PASSED_TESTS+=("Python Workers")
        else
            print_error "Python Workers tests failed"
            FAILED_TESTS+=("Python Workers")
        fi
        
        cd - > /dev/null || exit 1
    fi
fi

# 3. Telegram Bot Tests
print_header "3. Telegram Bot Tests"
TELEGRAM_BOT_DIR=""
if [ -d "$SCRIPT_DIR/telegram_bot" ]; then
    TELEGRAM_BOT_DIR="$SCRIPT_DIR/telegram_bot"
elif [ -d "/app" ] && [ -f "/app/Gemfile" ] && [ -d "/app/lib" ]; then
    # Running from inside telegram_bot container
    TELEGRAM_BOT_DIR="/app"
elif [ -d "telegram_bot" ]; then
    TELEGRAM_BOT_DIR="telegram_bot"
fi

if [ -z "$TELEGRAM_BOT_DIR" ]; then
    print_error "Telegram Bot directory not found"
    FAILED_TESTS+=("Telegram Bot")
else
    cd "$TELEGRAM_BOT_DIR" || exit 1
    
    # Check if bundle is installed
    if ! command -v bundle &> /dev/null; then
        print_error "Bundler not found. Please install Ruby and Bundler first."
        FAILED_TESTS+=("Telegram Bot")
        cd - > /dev/null || exit 1
    else
        # Install dependencies if needed
        if [ ! -d "vendor/bundle" ] && [ ! -f ".bundle/config" ]; then
            print_warning "Installing Telegram Bot dependencies..."
            bundle install || {
                print_error "Failed to install Telegram Bot dependencies"
                FAILED_TESTS+=("Telegram Bot")
                cd - > /dev/null || exit 1
            }
        fi
        
        # Set environment variables
        export REDIS_URL="${REDIS_URL:-redis://localhost:6379/0}"
        
        # Run tests
        if bundle exec rspec; then
            print_success "Telegram Bot tests passed"
            PASSED_TESTS+=("Telegram Bot")
        else
            print_error "Telegram Bot tests failed"
            FAILED_TESTS+=("Telegram Bot")
        fi
        
        cd - > /dev/null || exit 1
    fi
fi

# 4. Mini App Tests
print_header "4. Mini App Tests"
MINI_APP_DIR=""
if [ -d "$SCRIPT_DIR/mini_app" ]; then
    MINI_APP_DIR="$SCRIPT_DIR/mini_app"
elif [ -d "/mini_app" ]; then
    # Running from inside rails_api container which mounts mini_app
    MINI_APP_DIR="/mini_app"
elif [ -d "mini_app" ]; then
    MINI_APP_DIR="mini_app"
fi

if [ -z "$MINI_APP_DIR" ]; then
    print_error "Mini App directory not found"
    FAILED_TESTS+=("Mini App")
else
    cd "$MINI_APP_DIR" || exit 1
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        print_error "Node.js not found. Please install Node.js 18+ first."
        FAILED_TESTS+=("Mini App")
        cd - > /dev/null || exit 1
    else
        # Check if npm is installed
        if ! command -v npm &> /dev/null; then
            print_error "npm not found. Please install npm first."
            FAILED_TESTS+=("Mini App")
            cd - > /dev/null || exit 1
        else
            # Install dependencies if needed
            if [ ! -d "node_modules" ]; then
                print_warning "Installing Mini App dependencies..."
                npm install || {
                    print_error "Failed to install Mini App dependencies"
                    FAILED_TESTS+=("Mini App")
                    cd - > /dev/null || exit 1
                }
            fi
            
            # Run tests
            if npm test; then
                print_success "Mini App tests passed"
                PASSED_TESTS+=("Mini App")
            else
                print_error "Mini App tests failed"
                FAILED_TESTS+=("Mini App")
            fi
            
            cd - > /dev/null || exit 1
        fi
    fi
fi

# Print summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}\n"

if [ ${#PASSED_TESTS[@]} -gt 0 ]; then
    echo -e "${GREEN}Passed (${#PASSED_TESTS[@]}):${NC}"
    for test in "${PASSED_TESTS[@]}"; do
        echo -e "  ${GREEN}✓${NC} $test"
    done
    echo ""
fi

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo -e "${RED}Failed (${#FAILED_TESTS[@]}):${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${RED}✗${NC} $test"
    done
    echo ""
    exit 1
else
    echo -e "${GREEN}All tests passed! 🎉${NC}\n"
    exit 0
fi

