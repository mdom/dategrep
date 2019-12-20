FROM perl:5

COPY . /app/
WORKDIR /app

RUN cpan App::cpanminus
RUN cpanm Module::Build::Tiny

RUN perl Build.PL && ./Build && ./Build install

COPY "entrypoint.sh" "/entrypoint.sh"
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["dategrep"]

