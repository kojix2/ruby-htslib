FROM rubylang/ruby:latest

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y automake autotools-dev \
    libbz2-dev liblzma-dev libdeflate-dev libcurl4-openssl-dev zlib1g-dev \
    libffi-dev build-essential git

WORKDIR /workspace

RUN git clone --depth 1 --recursive https://github.com/kojix2/ruby-htslib && \
    cd ruby-htslib && \
    bundle install && \
    bundle exec rake htslib:build && \
    bundle exec rake install && \
    bundle exec rake test

# Remove build dependencies
RUN apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*
