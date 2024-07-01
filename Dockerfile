FROM cr.kruhlmann.dev/debian-bookworm-ocaml-5.1.1 AS builder

WORKDIR /home/$USERNAME
USER $USERNAME
COPY . .
RUN git config --global --add safe.directory /home/dockeruser \
    && eval $(opam env) \
    && opam install . --yes --deps-only \
    && make

FROM cr.kruhlmann.dev/debian:bookworm

COPY --from=builder /home/$USERNAME/_build/default/bin/main.exe /usr/local/bin/relic-token

ENTRYPOINT [ "/usr/local/bin/relic-token" ]
