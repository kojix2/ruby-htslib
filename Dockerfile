FROM rubylang/ruby:latest

RUN apt update -y && apt upgrade -y && \
    apt install -y automake autotools-dev libbz2-dev liblzma-dev libdeflate-dev libcurl4-openssl-dev

RUN git clone --depth 1 --recursive https://github.com/kojix2/ruby-htslib && \
    cd ruby-htslib && \
    bundle install && \
    bundle exec rake htslib:build && \
    bundle exec rake install && \
    bundle exec rake test
