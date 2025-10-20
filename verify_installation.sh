#!/bin/bash

# ================================================================
# Installation Verification Script
# ================================================================
# This script checks if all new features are properly installed
# Run this after deployment to verify everything is functional
#
# Usage: ./verify_installation.sh
# ================================================================

set -e

echo "========================================"
echo "  Feature Installation Verification"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# ================================================================
# Helper Functions
# ================================================================

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# ================================================================
# Check 1: Required Files Exist
# ================================================================

echo "1. Checking Required Files..."
echo ""

FILES=(
    "app/models/admin_user_column_preference.rb"
    "app/services/open_cell_id_service.rb"
    "app/services/verizon_probability_service.rb"
    "app/jobs/verizon_probability_calculation_job.rb"
    "app/views/admin/contacts/_column_settings.html.arb"
    "app/assets/javascripts/column_settings.js"
    "config/initializers/opencellid.rb"
    "db/migrate/20251020051031_add_probability_to_contacts.rb"
    "db/migrate/20251020051050_create_admin_user_column_preferences.rb"
    "db/migrate/20251020053443_add_coordinates_to_contacts.rb"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        check_pass "$file exists"
    else
        check_fail "$file MISSING"
    fi
done

echo ""

# ================================================================
# Check 2: Migration Files Are Valid Ruby
# ================================================================

echo "2. Checking Migration Syntax..."
echo ""

if command -v ruby &> /dev/null; then
    for migration in db/migrate/202510200*.rb; do
        if ruby -c "$migration" &> /dev/null; then
            check_pass "$(basename $migration) syntax valid"
        else
            check_fail "$(basename $migration) has syntax errors"
        fi
    done
else
    check_warn "Ruby not found, skipping syntax check"
fi

echo ""

# ================================================================
# Check 3: Database Migration Status
# ================================================================

echo "3. Checking Database Migrations..."
echo ""

if command -v rails &> /dev/null; then
    # Check if migrations are pending
    if rails db:migrate:status | grep -q "down.*20251020051031"; then
        check_fail "Migration 20251020051031 (probability) not run"
    else
        check_pass "Probability migration run"
    fi

    if rails db:migrate:status | grep -q "down.*20251020051050"; then
        check_fail "Migration 20251020051050 (column preferences) not run"
    else
        check_pass "Column preferences migration run"
    fi

    if rails db:migrate:status | grep -q "down.*20251020053443"; then
        check_fail "Migration 20251020053443 (coordinates) not run"
    else
        check_pass "Coordinates migration run"
    fi
else
    check_warn "Rails not found, cannot check migration status"
    echo "   Run manually: rails db:migrate:status"
fi

echo ""

# ================================================================
# Check 4: Environment Configuration
# ================================================================

echo "4. Checking Environment Configuration..."
echo ""

if [ -f ".env" ]; then
    check_pass ".env file exists"

    if grep -q "OPENCELLID_API_KEY" .env; then
        if grep -q "OPENCELLID_API_KEY=your" .env; then
            check_warn "OPENCELLID_API_KEY is placeholder (system will use fallback)"
        else
            check_pass "OPENCELLID_API_KEY is configured"
        fi
    else
        check_warn "OPENCELLID_API_KEY not in .env (system will use fallback)"
    fi
else
    check_warn ".env file not found (may use system environment variables)"
fi

echo ""

# ================================================================
# Check 5: Model and Service Files Syntax
# ================================================================

echo "5. Checking Ruby Syntax..."
echo ""

if command -v ruby &> /dev/null; then
    RUBY_FILES=(
        "app/models/admin_user_column_preference.rb"
        "app/models/contact.rb"
        "app/services/open_cell_id_service.rb"
        "app/services/verizon_probability_service.rb"
        "app/services/verizon_coverage_service.rb"
        "app/jobs/verizon_probability_calculation_job.rb"
        "app/jobs/verizon_coverage_check_job.rb"
    )

    for file in "${RUBY_FILES[@]}"; do
        if [ -f "$file" ]; then
            if ruby -c "$file" &> /dev/null; then
                check_pass "$(basename $file) syntax valid"
            else
                check_fail "$(basename $file) has syntax errors"
            fi
        fi
    done
else
    check_warn "Ruby not found, skipping syntax check"
fi

echo ""

# ================================================================
# Check 6: Database Schema (if Rails available)
# ================================================================

echo "6. Checking Database Schema..."
echo ""

if command -v rails &> /dev/null; then
    # Try to check schema
    if rails runner "puts Contact.column_names.include?('verizon_5g_probability')" 2>/dev/null | grep -q "true"; then
        check_pass "verizon_5g_probability column exists"
    else
        check_fail "verizon_5g_probability column missing"
    fi

    if rails runner "puts Contact.column_names.include?('verizon_lte_probability')" 2>/dev/null | grep -q "true"; then
        check_pass "verizon_lte_probability column exists"
    else
        check_fail "verizon_lte_probability column missing"
    fi

    if rails runner "puts Contact.column_names.include?('latitude')" 2>/dev/null | grep -q "true"; then
        check_pass "latitude column exists"
    else
        check_fail "latitude column missing"
    fi

    if rails runner "puts Contact.column_names.include?('longitude')" 2>/dev/null | grep -q "true"; then
        check_pass "longitude column exists"
    else
        check_fail "longitude column missing"
    fi

    if rails runner "AdminUserColumnPreference" &> /dev/null; then
        check_pass "AdminUserColumnPreference model loads"
    else
        check_fail "AdminUserColumnPreference model has errors"
    fi
else
    check_warn "Rails not found, cannot check database schema"
    echo "   Run manually: rails runner 'puts Contact.column_names'"
fi

echo ""

# ================================================================
# Check 7: Asset Pipeline
# ================================================================

echo "7. Checking Asset Pipeline..."
echo ""

if [ -f "app/assets/javascripts/column_settings.js" ]; then
    check_pass "column_settings.js exists"
else
    check_fail "column_settings.js missing"
fi

if [ -f "app/assets/stylesheets/active_admin.scss" ]; then
    check_pass "active_admin.scss exists"

    if grep -q "probability-badge" app/assets/stylesheets/active_admin.scss; then
        check_pass "Probability badge styles present"
    else
        check_warn "Probability badge styles may be missing"
    fi
else
    check_fail "active_admin.scss missing"
fi

echo ""

# ================================================================
# Check 8: Routes (if Rails available)
# ================================================================

echo "8. Checking Routes..."
echo ""

if command -v rails &> /dev/null; then
    if rails routes | grep -q "column_settings"; then
        check_pass "Column settings routes configured"
    else
        check_fail "Column settings routes missing"
    fi
else
    check_warn "Rails not found, cannot check routes"
fi

echo ""

# ================================================================
# Summary
# ================================================================

echo "========================================"
echo "  Verification Summary"
echo "========================================"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo "  System is ready to use."
    echo ""
    echo "Next steps:"
    echo "  1. Start Rails server: rails server"
    echo "  2. Visit http://localhost:3000/admin"
    echo "  3. Test 'Customize Columns' button"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Checks passed with $WARNINGS warning(s)${NC}"
    echo "  System should work but review warnings above."
    echo ""
    echo "Common warnings:"
    echo "  - OPENCELLID_API_KEY not set (system will use fallback)"
    echo "  - Ruby/Rails not in PATH (run in Rails environment)"
    exit 0
else
    echo -e "${RED}✗ $ERRORS error(s) found, $WARNINGS warning(s)${NC}"
    echo "  System may not be functional. Fix errors above."
    echo ""
    echo "Common fixes:"
    echo "  - Run migrations: rails db:migrate"
    echo "  - Fix syntax errors in reported files"
    echo "  - Ensure all files were copied correctly"
    exit 1
fi
