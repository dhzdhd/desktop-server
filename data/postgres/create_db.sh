#!/bin/bash
set -e
set -u

function create_user_and_database() {
	local database=$1
	echo "  Ensuring role and database '$database' exist"

	psql -v ON_ERROR_STOP=1 --username "$PGUSER" <<-EOSQL
	    DO \$\$
	    BEGIN
	       IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$database') THEN
	          CREATE ROLE $database LOGIN;
	       END IF;
	    END
	    \$\$;
EOSQL

	if ! psql -v ON_ERROR_STOP=1 --username "$PGUSER" -lqt | cut -d '|' -f 1 | grep -qw "$database"; then
	    psql -v ON_ERROR_STOP=1 --username "$PGUSER" -c "CREATE DATABASE $database OWNER $PGUSER;"
	fi

	# Both roles get full privileges on the database
	psql -v ON_ERROR_STOP=1 --username "$PGUSER" -c "GRANT ALL PRIVILEGES ON DATABASE $database TO $database;"
	psql -v ON_ERROR_STOP=1 --username "$PGUSER" -c "GRANT ALL PRIVILEGES ON DATABASE $database TO $PGUSER;"

	# Schema-level grants (needed on PG15+, public schema is no longer world-writable by default)
	psql -v ON_ERROR_STOP=1 --username "$PGUSER" -d "$database" -c "GRANT ALL ON SCHEMA public TO $database;"
	psql -v ON_ERROR_STOP=1 --username "$PGUSER" -d "$database" -c "GRANT ALL ON SCHEMA public TO $PGUSER;"

	# Make sure future tables/sequences created by either role are usable by both
	psql -v ON_ERROR_STOP=1 --username "$PGUSER" -d "$database" -c "ALTER DEFAULT PRIVILEGES FOR ROLE $PGUSER IN SCHEMA public GRANT ALL ON TABLES TO $database;"
	psql -v ON_ERROR_STOP=1 --username "$PGUSER" -d "$database" -c "ALTER DEFAULT PRIVILEGES FOR ROLE $database IN SCHEMA public GRANT ALL ON TABLES TO $PGUSER;"
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
	echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
	for db in $(echo "$POSTGRES_MULTIPLE_DATABASES" | tr ',' ' '); do
		create_user_and_database "$db"
	done
	echo "Multiple databases created/verified"
fi
