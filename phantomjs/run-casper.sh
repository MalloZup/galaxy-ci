#! /bin/bash

casperjs --ignore-ssl-errors=true  --web-security=false --webdriver-loglevel=DEBUG --ssl-certificates-path= --ssl-protocol=tlsv1 casperjs.js
