function create_user_and_database() {
	local database=$1
	local password=$2
	echo "Ensuring role and database '$database' exist"

	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
	    DO \$\$
	    BEGIN
	       IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$database') THEN
	          CREATE ROLE $database LOGIN PASSWORD '$password';
	       ELSE
	          ALTER ROLE $database WITH PASSWORD '$password';
	       END IF;
	    END
	    \$\$;
EOSQL

	if ! psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$POSTGRES_DB" -lqt | cut -d '|' -f 1 | grep -qw "$database"; then
	    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE DATABASE $database OWNER $POSTGRES_USER;"
	fi

	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$POSTGRES_DB" -c "GRANT ALL PRIVILEGES ON DATABASE $database TO $database;"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$POSTGRES_DB" -c "GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;"

	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" -c "GRANT ALL ON SCHEMA public TO $database;"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" -c "GRANT ALL ON SCHEMA public TO $POSTGRES_USER;"

	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" -c "ALTER DEFAULT PRIVILEGES FOR ROLE $POSTGRES_USER IN SCHEMA public GRANT ALL ON TABLES TO $database;"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" -c "ALTER DEFAULT PRIVILEGES FOR ROLE $database IN SCHEMA public GRANT ALL ON TABLES TO $POSTGRES_USER;"
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
	echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"

	dbs=($(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '))
	passwords=($(echo $POSTGRES_MULTIPLE_PASSWORDS | tr ',' ' '))

	for i in "${!dbs[@]}"; do
		create_user_and_database "${dbs[$i]}" "${passwords[$i]}"
	done

	echo "Multiple databases created"
fi
