#!/bin/bash

function echo_and_run() {
  echo "RUNNING COMMAND: $1"
  bash -c "$1"
}

git clone https://github.com/cyverse/atmosphere.git /opt/dev/atmosphere
cd /opt/dev/atmosphere

# Wait for DB to be active
echo "Waiting for postgres..."
while ! nc -z postgres 5432; do sleep 5; done

apt-get update && apt-get install -y postgresql python-pip
service redis-server start

pip install -U pip==9.0.3 setuptools
pip install pip-tools==1.11.0

psql -c "CREATE USER atmosphere_db_user WITH PASSWORD 'atmosphere_db_pass' CREATEDB;" -U postgres -h postgres
psql -c "CREATE DATABASE atmosphere_db WITH OWNER atmosphere_db_user;" -U postgres -h postgres

echo_and_run "./travis/check_properly_generated_requirements.sh"
echo_and_run "pip-sync requirements.txt"
echo_and_run "sed -i 's/DATABASE_HOST = localhost/DATABASE_HOST = postgres/' variables.ini.dist"
echo_and_run "cp ./variables.ini.dist ./variables.ini"
echo_and_run "./configure"
echo_and_run "python manage.py check"
echo_and_run "python manage.py makemigrations --dry-run --check"
echo_and_run "patch variables.ini variables_for_testing_cyverse.ini.patch"
echo_and_run "./configure"
echo_and_run "pip-sync dev_requirements.txt"
echo_and_run "./travis/check_for_dead_code_with_vulture.sh"
echo_and_run "yapf --diff -p -- $(git ls-files | grep '\.py$')"
echo_and_run "prospector --profile prospector_profile.yaml --messages-only -- $(git ls-files | grep '\.py$')"
echo_and_run "python manage.py test --keepdb --noinput --settings=atmosphere.settings"
echo_and_run "python manage.py behave --keepdb --tags ~@skip-if-cyverse --settings=atmosphere.settings --format rerun --outfile rerun_failing.features"
echo_and_run "if [ -f 'rerun_failing.features' ]; then python manage.py behave --logging-level DEBUG --capture-stderr --capture --verbosity 3 --keepdb @rerun_failing.features; fi"
echo_and_run "python manage.py makemigrations --dry-run --check"
