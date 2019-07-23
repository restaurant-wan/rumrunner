ARG RUBY_TAG=latest

FROM ruby:${RUBY_TAG} AS build
WORKDIR /var/task/
COPY . .
ARG BUNDLE_SILENCE_ROOT_WARNING=1
RUN gem install bundler -v 2.0.2
RUN bundle install --path vendor/bundle/
RUN bundle exec rake gem:build

FROM ruby:${RUBY_TAG} AS test
WORKDIR /var/task/
COPY --from=build /usr/local/bundle/ /usr/local/bundle/
COPY --from=build /var/task/ .
RUN bundle exec rake

FROM ruby:${RUBY_TAG} AS release
WORKDIR /var/task/
COPY --from=build /usr/local/bundle/ /usr/local/bundle/
COPY --from=build /var/task/ .
ARG RUBYGEMS_API_KEY
RUN bundle exec rake gem:publish
