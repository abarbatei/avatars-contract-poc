#!/bin/bash

# forge coverage --report lcov --contracts "../contracts"
# lcov --remove ../lcov.info  -o ./lcov.info 'test/*' 'script/*'

# genhtml -o ./report ./lcov.info
# rm -rf ../lcov.info
# rm -rf ./lcov.info

forge coverage | grep -v test/ | grep -v Total > coverage.txt