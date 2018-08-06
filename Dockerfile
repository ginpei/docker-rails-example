FROM rails:5.0.1

RUN mkdir /app
WORKDIR /app

COPY ./app/Gemfile /app/Gemfile
COPY ./app/Gemfile.lock /app/Gemfile.lock

RUN bundle install
CMD rm /app/tmp/pids/server.pid ; rails s
