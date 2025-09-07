# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an AI Lead Generation application built with Rails 8.0.2, using modern Rails features including:
- Solid Cache, Solid Queue, and Solid Cable for database-backed adapters
- Hotwire (Turbo and Stimulus) for interactive frontend
- Tailwind CSS for styling
- PostgreSQL as the database
- Devise for authentication
- Stripe for billing
- OpenAI integration for AI capabilities

## Development Commands

### Initial Setup
```bash
bin/setup                 # Run complete setup (installs dependencies, prepares database, starts server)
```

### Development Server
```bash
bin/dev                   # Start development server with Rails and Tailwind CSS watcher
# or separately:
bin/rails server          # Start Rails server only
bin/rails tailwindcss:watch # Start Tailwind CSS watcher only
```

### Database Operations
```bash
bin/rails db:create       # Create the database
bin/rails db:migrate      # Run pending migrations
bin/rails db:prepare      # Create database and run migrations
bin/rails db:seed         # Load seed data
bin/rails db:reset        # Drop, create, migrate, and seed database
```

### Testing
```bash
bin/rails test            # Run all tests
bin/rails test:models     # Run model tests only
bin/rails test path/to/test_file.rb  # Run specific test file
```

### Code Quality
```bash
bundle exec rubocop       # Run Ruby linter (uses Omakase styling)
bundle exec rubocop -A    # Auto-fix linting issues
bundle exec brakeman      # Run security analysis
```

### Console & Debugging
```bash
bin/rails console         # Open Rails console with pry-rails for debugging
bin/rails c               # Shorthand for console
```

## Architecture & Models

### Core Domain Models

The application follows an AI-powered lead generation workflow:

1. **User** - Authenticated users with Devise integration
   - Has many Keywords
   - Has many Integrations

2. **Keyword** - Search terms/topics users want to monitor
   - Belongs to User
   - Has many Mentions

3. **Mention** - Instances where keywords are found
   - Belongs to Keyword
   - Has one AnalysisResult
   - Has one Lead

4. **AnalysisResult** - AI analysis of mentions
   - Belongs to Mention

5. **Lead** - Qualified leads generated from analyzed mentions
   - Belongs to Mention

6. **Integration** - Third-party service connections
   - Belongs to User

### Database Configuration

The application uses PostgreSQL with Rails 8's multi-database setup:
- **Primary database**: Main application data
- **Cache database**: Solid Cache storage
- **Queue database**: Solid Queue job processing
- **Cable database**: Solid Cable websocket connections

### Background Jobs

Uses Solid Queue for background processing with:
- Default configuration: 3 threads, configurable processes via `JOB_CONCURRENCY` env var
- Polling interval: 0.1 seconds

### Real-time Features

Solid Cable provides websocket functionality:
- Development uses async adapter
- Production uses database-backed solid_cable adapter

## Key Dependencies

- **Authentication**: Devise
- **Authorization**: Pundit
- **Payments**: Stripe
- **AI Integration**: ruby-openai
- **HTTP Client**: HTTParty
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Asset Pipeline**: Propshaft, Importmap

## Branch Workflow

**Important**: Create a new branch for every task, test, commit, and push, then create a pull request.

## Development Notes

- The application is configured for deployment with Kamal and Thruster
- Uses Rails 8's default configuration with Propshaft for assets
- Solid adapters eliminate Redis dependency
- RuboCop is configured with Rails Omakase styling rules