#!/bin/bash

which python

git clone https://github.com/cyverse/atmosphere.git /opt/dev/atmosphere
cd /opt/dev/atmosphere

# Wait for DB to be active
echo "Waiting for postgres..."
while ! nc -z postgres 5432; do sleep 5; done

psql -c "CREATE USER atmosphere_db_user WITH PASSWORD 'atmosphere_db_pass' CREATEDB;" -U postgres -h postgres
psql -c "CREATE DATABASE atmosphere_db WITH OWNER atmosphere_db_user;" -U postgres -h postgres

./travis/check_properly_generated_requirements.sh
pip-sync requirements.txt
cp ./variables.ini.dist ./variables.ini
sed -i "s/DATABASE_HOST = localhost/DATABASE_HOST = postgres/" variables.ini.dist
./configure
python manage.py check
python manage.py makemigrations --dry-run --check
patch variables.ini variables_for_testing_${DISTRIBUTION}.ini.patch
./configure
pip-sync dev_requirements.txt
./travis/check_for_dead_code_with_vulture.sh
yapf --diff -p -- $(git ls-files | grep '\.py$')
prospector --profile prospector_profile.yaml --messages-only -- $(git ls-files | grep '\.py$')
coverage run manage.py test --keepdb --noinput --settings=atmosphere.settings
coverage run --append manage.py behave --keepdb --tags ~@skip-if-${DISTRIBUTION} --settings=atmosphere.settings --format rerun --outfile rerun_failing.features
if [ -f "rerun_failing.features" ]; then python manage.py behave --logging-level DEBUG --capture-stderr --capture --verbosity 3 --keepdb @rerun_failing.features; fi
python manage.py makemigrations --dry-run --check
