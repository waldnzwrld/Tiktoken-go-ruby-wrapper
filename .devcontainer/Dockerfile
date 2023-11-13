FROM mcr.microsoft.com/vscode/devcontainers/go:1-1.21-bullseye

USER root

RUN apt-get update && apt-get install -y \
    bc \
    build-essential \
    graphviz \
    heaptrack \
    ruby \
    ruby-dev

RUN gem install bundler

# grant write permissions to vscode user for gemdir
RUN chown -R vscode:vscode $(gem environment gemdir)

# grant write permission to vscode user for gem executable directory
RUN chown -R vscode:vscode $(gem env | grep "EXECUTABLE DIRECTORY" | awk -F': ' '{print $2}')

USER vscode
ENV GITHUB_ACTOR=github
