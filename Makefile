# KiloShare Project Makefile

.PHONY: help install start stop api app database clean

# Default target
help:
	@echo "KiloShare Project Commands:"
	@echo "  install   - Install all dependencies"
	@echo "  start     - Start all services"
	@echo "  stop      - Stop all services"
	@echo "  api   - Start api server only"
	@echo "  app    - Start Flutter app app"
	@echo "  database  - Setup database"
	@echo "  clean     - Clean all build files"

# Install all dependencies
install:
	@echo "Installing api dependencies..."
	cd api && composer install
	@echo "Installing app dependencies..."
	cd app && flutter pub get
	@echo "All dependencies installed!"

# Start all services
start:
	@echo "Starting api server..."
	cd api && php -S localhost:8080 -t public &
	@echo "Backend started on http://localhost:8080"
	@echo "To start app app, run: make app"

# Stop services
stop:
	@echo "Stopping services..."
	pkill -f "php -S localhost:8080" || true
	@echo "Services stopped!"

# Start api only
api:
	@echo "Starting api server..."
	cd api && php -S localhost:8080 -t public
	@echo "Backend started on http://localhost:8080"

# Start Flutter app app
app:
	@echo "Starting Flutter app app..."
	cd app && flutter run

# Setup database
database:
	@echo "Setting up database..."
	mysql -u root -e "CREATE DATABASE IF NOT EXISTS kiloshare CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
	mysql -u root kiloshare < database/schema.sql
	@echo "Database setup complete!"

# Clean build files
clean:
	@echo "Cleaning api..."
	cd api && rm -rf vendor/ composer.lock
	@echo "Cleaning app..."
	cd app && flutter clean
	@echo "Clean complete!"

# Development helpers
dev-setup: install database
	@echo "Development environment ready!"
	@echo "Run 'make start' to start the api"
	@echo "Run 'make app' to start the Flutter app"

# Backend composer commands
composer-install:
	cd api && composer install

composer-update:
	cd api && composer update

# Flutter commands
flutter-clean:
	cd app && flutter clean

flutter-get:
	cd app && flutter pub get

flutter-build-android:
	cd app && flutter build apk

flutter-build-ios:
	cd app && flutter build ios

# Database management
db-reset: database
	@echo "Database reset complete!"

db-backup:
	mysqldump -u root kiloshare > database/backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "Database backup created!"

# Logs
logs:
	tail -f api/logs/app.log