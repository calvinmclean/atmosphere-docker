#!/bin/bash

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

echo "RUNNING COMMAND: ./travis/check_properly_generated_requirements.sh"
./travis/check_properly_generated_requirements.sh
echo "RUNNING COMMAND: pip-sync requirements.txt"
pip-sync requirements.txt
echo "RUNNING COMMAND: sed -i "s/DATABASE_HOST = localhost/DATABASE_HOST = postgres/" variables.ini.dist"
sed -i "s/DATABASE_HOST = localhost/DATABASE_HOST = postgres/" variables.ini.dist
echo "RUNNING COMMAND: cp ./variables.ini.dist ./variables.ini"
cp ./variables.ini.dist ./variables.ini
echo "RUNNING COMMAND: ./configure"
./configure
echo "RUNNING COMMAND: python manage.py check"
python manage.py check
echo "RUNNING COMMAND: python manage.py makemigrations --dry-run --check"
python manage.py makemigrations --dry-run --check
echo "RUNNING COMMAND: patch variables.ini variables_for_testing_cyverse.ini.patch"
patch variables.ini variables_for_testing_cyverse.ini.patch
echo "RUNNING COMMAND: ./configure"
./configure
echo "RUNNING COMMAND: pip-sync dev_requirements.txt"
pip-sync dev_requirements.txt
echo "RUNNING COMMAND: ./travis/check_for_dead_code_with_vulture.sh"
./travis/check_for_dead_code_with_vulture.sh
echo "RUNNING COMMAND: yapf --diff -p -- $(git ls-files | grep '\.py$')"
yapf --diff -p -- $(git ls-files | grep '\.py$')
echo "RUNNING COMMAND: prospector --profile prospector_profile.yaml --messages-only -- $(git ls-files | grep '\.py$')"
prospector --profile prospector_profile.yaml --messages-only -- $(git ls-files | grep '\.py$')
echo "RUNNING COMMAND: python manage.py test --keepdb --noinput --settings=atmosphere.settings"
python manage.py test --keepdb --noinput --settings=atmosphere.settings
echo "RUNNING COMMAND: python manage.py behave --keepdb --tags ~@skip-if-cyverse --settings=atmosphere.settings --format rerun --outfile rerun_failing.features"
python manage.py behave --keepdb --tags ~@skip-if-cyverse --settings=atmosphere.settings --format rerun --outfile rerun_failing.features
echo "RUNNING COMMAND: if [ -f "rerun_failing.features" ]; then python manage.py behave --logging-level DEBUG --capture-stderr --capture --verbosity 3 --keepdb @rerun_failing.features; fi"
if [ -f "rerun_failing.features" ]; then python manage.py behave --logging-level DEBUG --capture-stderr --capture --verbosity 3 --keepdb @rerun_failing.features; fi
echo "RUNNING COMMAND: python manage.py makemigrations --dry-run --check"
python manage.py makemigrations --dry-run --check
