#!/usr/bin/env bash

# Adapted from build_doc.sh from SymPy

# Copyright (c) 2006-2014 SymPy Development Team
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   a. Redistributions of source code must retain the above copyright notice,
#      this list of conditions and the following disclaimer.
#   b. Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#   c. Neither the name of SymPy nor the names of its contributors
#      may be used to endorse or promote products derived from this software
#      without specific prior written permission.
#
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
# DAMAGE.

#################################################################################

# This file automatically deploys changes to http://conda.pydata.org/
# (including http://conda.pydata.org/docs). This will happen only when a PR
# gets merged which is basically when a new commit is added to master.  It
# requires an access token which should be present in .travis.yml file.
#
# Following is the procedure to get the access token:
#
# $ curl -X POST -u <github_username> -H "Content-Type: application/json" -H "X-GitHub-OTP: 2FA_TOKEN" -d  "{\"scopes\":[\"public_repo\"],\"note\":\"token for pushing from travis\"}" https://api.github.com/authorizations
#
# Replace 2FA_TOKEN with your two-factor token generated by SMS or the
# application.
#
# This will give you a JSON response having a key called "token".
#
# $ gem install travis
# $ travis encrypt -r conda/conda-docs GH_TOKEN=<token> env.global
#
# This will give you an access token("secure"). This helps in creating an
# environment variable named GH_TOKEN while building.
#
# Add this secure code to .travis.yml as described here http://docs.travis-ci.com/user/encryption-keys/

# WARNING: The environment variable $GH_TOKEN contains the private GitHub
# token that gives write access to the repo. Be EXTRA CAREFUL that the token
# is never printed.  Commands that use it should use > /dev/null 2>&1 so that
# no output leaks out.

# Exit on error
set -e

# Don't use set -x as that would print the GH_TOKEN variable
set +x

ACTUAL_TRAVIS_JOB_NUMBER=`echo $TRAVIS_JOB_NUMBER| cut -d'.' -f 2`

if [[ "$TRAVIS_BRANCH" == "master" && "$TRAVIS_PULL_REQUEST" == "false" ]]; then
    echo -e "Setting git attributes"
    git config --global user.email "conda@continuum.io"
    git config --global user.name "Conda (Travis CI)"

    echo -e "Adding token remote"
    git remote add origin_token https://${GH_TOKEN}@github.com/conda/conda-docs.git > /dev/null 2>&1
    echo -e "Fetching token remote"
    git fetch origin_token > /dev/null 2>&1
    echo -e "Checking out gh-pages"
    git checkout -b gh-pages --track origin_token/gh-pages
    echo "Done"

    if [[ -z "$GH_TOKEN" ]]; then
        echo -e "GH_TOKEN is not set"
        exit 1
    fi

    cd ..
    echo -e $(pwd)

    if [ "$ACTUAL_TRAVIS_JOB_NUMBER" == "1" ]; then
        # docs
        echo -e "Moving built docs into place"
        cp -R docs/build/html docs_
        rm -rf docs
        mv docs_ docs/
        git add -A docs/

        echo -e "Committing"
        git commit -am "Update docs after building Travis build $TRAVIS_BUILD_NUMBER"
        echo -e "Pulling"
        git pull
        echo -e "Pushing commit"
        git push -q origin_token gh-pages > /dev/null 2>&1
    fi

    if [ "$ACTUAL_TRAVIS_JOB_NUMBER" == "2" ]; then
        # web
        echo -e "Moving built website into place"
        rm -rf docs
        git checkout docs
        rsync -rvh --delete --exclude-from=exclusions web/build/html/ .
        rm -rf web
        git add -A .

        echo -e "Committing"
        git commit -am "Update website after building Travis build $TRAVIS_BUILD_NUMBER"
        echo -e "Pulling"
        git pull
        echo -e "Pushing commit"
        git push -q origin_token gh-pages > /dev/null 2>&1
    fi
fi

if [ "$TRAVIS_BRANCH" != "master" ]; then
    echo -e "The website and docs are only pushed to gh-pages from master"
    echo -e "This is the $TRAVIS_BRANCH branch"
fi

if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
    echo -e "The website and docs are not pushed to gh-pages on pull requests"
fi
