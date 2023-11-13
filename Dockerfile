FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    bc \
    build-essential \
    git \
    golang-go \
    graphviz \
    heaptrack \
    ruby \
    ruby-dev

RUN mkdir /app
WORKDIR /app

# copy the test and tiktoken-encoder directories into the container
COPY . ./
COPY Gemfile ./Gemfile
COPY Gemfile.lock ./Gemfile.lock
COPY tiktoken-encoder.gemspec ./tiktoken-encoder.gemspec
COPY .git ./.git
RUN gem install bundler

RUN script/setup
RUN script/build-clib
