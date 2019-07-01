#!/bin/sh

# Exit if any command fails
set -e;

db_info='-h postgres -p 5432 -U atmo_app'
export PGPASSWORD='atmosphere'

# Create temporary database used to create database dump
createdb $db_info tmp_sanitary_db;

# If we exit for any reason (including end of this script), remove the temporary database
trap "dropdb ${db_info} tmp_sanitary_db" EXIT;

# Dump production database and load into temporary database
pg_dump $db_info atmo_prod | psql $db_info tmp_sanitary_db;

# Sanitize db
psql $db_info tmp_sanitary_db <<'EOF'
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
UPDATE atmosphere_user SET password = 'PASSWORD_REDACTED';
UPDATE ssh_key SET pub_key = 'PUB_KEY_REDACTED';
UPDATE boot_script SET title = 'title_REDACTED', script_text = 'script_text_REDACTED';
UPDATE credential SET key = 'key_REDACTED', value = 'value_REDACTED';
UPDATE django_admin_log SET change_message = 'change_message_REDACTED', object_repr = 'object_repr_REDACTED';
UPDATE django_cyverse_auth_accesstoken SET key = 'KEY_REDACTED';
-- This one tends to have millions of rows so we drop the secret column rather than overwriting it
ALTER TABLE django_cyverse_auth_token DROP COLUMN key CASCADE;
UPDATE django_cyverse_auth_userproxy SET "proxyIOU" = 'proxyIOU_REDACTED', "proxyTicket" = 'proxyTicket_REDACTED';
UPDATE django_session SET session_key = 'RDD_' || uuid_generate_v4(), session_data = 'session_data_REDACTED';
UPDATE external_link SET title = 'title_REDACTED', link = 'link_REDACTED', description = 'description_REDACTED';
UPDATE iplantauth_accesstoken SET key = 'KEY_REDACTED';
UPDATE iplantauth_token SET key = 'KEY_REDACTED_' || uuid_generate_v4();
UPDATE iplantauth_userproxy SET "proxyIOU" = 'proxyIOU_REDACTED', "proxyTicket" = 'proxyTicket_REDACTED';
UPDATE node_controller SET private_ssh_key = 'private_ssh_key_REDACTED';
UPDATE provider SET cloud_config = NULL;
UPDATE provider_credential SET key = 'key_REDACTED', value = 'value_REDACTED';
EOF

# These commands may fail (tables may not exist on all deployments), so always exit 0 and suppress stderr
QUERYMAYFAIL=`cat << EOF
UPDATE access_token SET key = 'KEY_REDACTED';
UPDATE auth_token SET key = 'KEY_REDACTED_' || uuid_generate_v4();
UPDATE auth_userproxy SET "proxyIOU" = 'proxyIOU_REDACTED', "proxyTicket" = 'proxyTicket_REDACTED';
EOF
`
# psql $db_info tmp_sanitary_db "$QUERYMAYFAIL" 2>/dev/null | true
echo $QUERYMAYFAIL | psql $db_info tmp_sanitary_db || true

# Create sanitary dump
pg_dump $db_info tmp_sanitary_db > /tmp/atmo_prod-sanitized.sql;
