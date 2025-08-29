# KiloShare Project Makefile

.PHONY: help install start stop backend mobile database clean

# Default target
help:
	@echo "KiloShare Project Commands:"
	@echo "  install   - Install all dependencies"
	@echo "  start     - Start all services"
	@echo "  stop      - Stop all services"
	@echo "  backend   - Start backend server only"
	@echo "  mobile    - Start Flutter mobile app"
	@echo "  database  - Setup database"
	@echo "  clean     - Clean all build files"

# Install all dependencies
install:
	@echo "Installing backend dependencies..."
	cd backend && composer install
	@echo "Installing mobile dependencies..."
	cd mobile && flutter pub get
	@echo "All dependencies installed!"

# Start all services
start:
	@echo "Starting backend server..."
	cd backend && php -S localhost:8080 -t public &
	@echo "Backend started on http://localhost:8080"
	@echo "To start mobile app, run: make mobile"

# Stop services
stop:
	@echo "Stopping services..."
	pkill -f "php -S localhost:8080" || true
	@echo "Services stopped!"

# Start backend only
backend:
	@echo "Starting backend server..."
	cd backend && php -S localhost:8080 -t public
	@echo "Backend started on http://localhost:8080"

# Start Flutter mobile app
mobile:
	@echo "Starting Flutter mobile app..."
	cd mobile && flutter run

# Setup database
database:
	@echo "Setting up database..."
	mysql -u root -e "CREATE DATABASE IF NOT EXISTS kiloshare CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
	mysql -u root kiloshare < database/schema.sql
	@echo "Database setup complete!"

# Clean build files
clean:
	@echo "Cleaning backend..."
	cd backend && rm -rf vendor/ composer.lock
	@echo "Cleaning mobile..."
	cd mobile && flutter clean
	@echo "Clean complete!"

# Development helpers
dev-setup: install database
	@echo "Development environment ready!"
	@echo "Run 'make start' to start the backend"
	@echo "Run 'make mobile' to start the Flutter app"

# Backend composer commands
composer-install:
	cd backend && composer install

composer-update:
	cd backend && composer update

# Flutter commands
flutter-clean:
	cd mobile && flutter clean

flutter-get:
	cd mobile && flutter pub get

flutter-build-android:
	cd mobile && flutter build apk

flutter-build-ios:
	cd mobile && flutter build ios

# Database management
db-reset: database
	@echo "Database reset complete!"

db-backup:
	mysqldump -u root kiloshare > database/backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "Database backup created!"

# Logs
logs:
	tail -f backend/logs/app.log