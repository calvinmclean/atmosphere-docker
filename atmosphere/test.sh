#!/bin/bash

git clone https://github.com/cyverse/atmosphere.git /opt/dev/atmosphere
cd /opt/dev/atmosphere

# Wait for DB to be active
echo "Waiting for postgres..."
while ! nc -z postgres 5432; do sleep 5; done

apt-get update && apt-get install -y postgresql python-pip

pip install pip-tools

psql -c "CREATE USER atmosphere_db_user WITH PASSWORD 'atmosphere_db_pass' CREATEDB;" -U postgres -h postgres
psql -c "CREATE DATABASE atmosphere_db WITH OWNER atmosphere_db_user;" -U postgres -h postgres

./travis/check_properly_generated_requirements.sh
pip-sync requirements.txt
sed -i "s/DATABASE_HOST = localhost/DATABASE_HOST = postgres/" variables.ini.dist
cp ./variables.ini.dist ./variables.ini
./configure
python manage.py check
python manage.py makemigrations --dry-run --check
patch variables.ini variables_for_testing_cyverse.ini.patch
./configure
pip-sync dev_requirements.txt
./travis/check_for_dead_code_with_vulture.sh
python manage.py test --keepdb --noinput --settings=atmosphere.settings
if [ -f "rerun_failing.features" ]; then python manage.py behave --logging-level DEBUG --capture-stderr --capture --verbosity 3 --keepdb @rerun_failing.features; fi
python manage.py makemigrations --dry-run --check
