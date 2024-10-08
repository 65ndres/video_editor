# Use the official Ruby image as the base image
FROM ruby:3.1.4

# Set the working directory inside the container
WORKDIR /app

# Install dependencies
RUN apt-get update && \
    apt-get install -y nodejs && \
    apt-get install -y ffmpeg && \
    gem install bundler

# Copy Gemfile and Gemfile.lock to the working directory
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install

# Copy the rest of the application code
COPY . .


# Expose port 3000 to the outside world
EXPOSE 3001

# Start the Rails server
CMD ["rails", "server", "-b", "0.0.0.0"]