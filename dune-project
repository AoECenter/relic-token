(lang dune 3.10)
(name relic-token)
(version 0.1.0)
(cram enable)
(generate_opam_files true)
(source (github AoeCenter/relic-token))
(authors 
  "echo 'QW5kcmVhcyBLcsO8aGxtYW5uIDxhbmRyZWFzQGtydWhsbWFubi5kZXY+Cg==' | base64 -d")
(maintainers 
  "echo 'QW5kcmVhcyBLcsO8aGxtYW5uIDxhbmRyZWFzQGtydWhsbWFubi5kZXY+Cg==' | base64 -d")
(license MIT)
(documentation https://github.com/AoeCenter/relic-token)
(package
 (name relic-token)
 (synopsis "Relic link token generator")
 (depends
  (ocaml
   (>= 4.14))
  (alcotest
   (and
    :with-test
    (>= 1.3.0)))
  (alcotest-lwt
   (and
    :with-test
    (>= 1.7.0)))
  (bisect_ppx
   (and
    :with-test
    (>= 2.3.0)))
  (ocamlformat
   (and
    :with-dev-setup
    (>= 0.26.1)))
  (base
   (>= v0.12.0))
  (dune
    (>= 3.14.2))
  dune-build-info))
