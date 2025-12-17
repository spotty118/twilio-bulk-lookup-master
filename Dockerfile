FROM ruby:3.3.5

# Install system dependencies
RUN apt-get update -qq && apt-get install -y \
    postgresql-client \
    nodejs \
    npm \
    libvips \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install bundler
RUN gem install bundler:2.5.6

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install dependencies
RUN bundle check || bundle install

# Copy application code
COPY . .

# Add a script to be executed every time the container starts
COPY bin/docker-entrypoint /usr/bin/
RUN chmod +x /usr/bin/docker-entrypoint
ENTRYPOINT ["docker-entrypoint"]

# Expose port
EXPOSE 3000

# Start server
CMD ["rails", "server", "-b", "0.0.0.0"]
