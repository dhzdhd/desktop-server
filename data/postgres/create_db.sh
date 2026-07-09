#!/bin/bash
set -e
set -u

function create_user_and_database() {
	local database=$1
	echo "  Ensuring role and database '$database' exist"

	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
	    DO \$\$
	    BEGIN
	       IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$database') THEN
	          CREATE ROLE $database LOGIN;
	       END IF;
	    END
	    \$\$;
EOSQL

	if ! psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -lqt | cut -d '|' -f 1 | grep -qw "$database"; then
	    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "CREATE DATABASE $database OWNER $POSTGRES_USER;"
	fi

	# Both roles get full privileges on the database
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "GRANT ALL PRIVILEGES ON DATABASE $database TO $database;"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;"

	# Schema-level grants (needed on PG15+, public schema is no longer world-writable by default)
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" -c "GRANT ALL ON SCHEMA public TO $database;"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" -c "GRANT ALL ON SCHEMA public TO $POSTGRES_USER;"

	# Make sure future tables/sequences created by either role are usable by both
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" -c "ALTER DEFAULT PRIVILEGES FOR ROLE $POSTGRES_USER IN SCHEMA public GRANT ALL ON TABLES TO $database;"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" -c "ALTER DEFAULT PRIVILEGES FOR ROLE $database IN SCHEMA public GRANT ALL ON TABLES TO $POSTGRES_USER;"
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
	echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
	for db in $(echo "$POSTGRES_MULTIPLE_DATABASES" | tr ',' ' '); do
		create_user_and_database "$db"
	done
	echo "Multiple databases created/verified"
fi
