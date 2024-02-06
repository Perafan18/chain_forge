FROM ruby:3.2.2

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN gem install bundler -v 2.4.13 && bundle install

COPY . .

CMD ["bundle", "exec", "ruby", "main.rb", "-p", "1910"]
