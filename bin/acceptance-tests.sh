#!/usr/bin/env bash

# -e          Exit immediately if a pipeline returns a non-zero status
# -o pipefail Produce a failure return code if any command errors
set -eo pipefail

# Prep:
docker-compose --profile acceptance-tests up -d
WP_PORT=`docker inspect --type=container --format='{{(index .NetworkSettings.Ports "80/tcp" 0).HostPort}}' qm-server`
CHROME_PORT=`docker inspect --type=container --format='{{(index .NetworkSettings.Ports "4444/tcp" 0).HostPort}}' qm-chrome`
DATABASE_PORT=`docker inspect --type=container --format='{{(index .NetworkSettings.Ports "3306/tcp" 0).HostPort}}' qm-database`
WP_URL="http://host.docker.internal:${WP_PORT}"
WP="docker-compose run --rm wpcli --url=${WP_URL}"

# Wait for Selenium, the web server, and the database:
./node_modules/.bin/wait-port -t 10000 $CHROME_PORT
./node_modules/.bin/wait-port -t 10000 $WP_PORT
./node_modules/.bin/wait-port -t 10000 $DATABASE_PORT

# Reset or install the test database:
echo "Installing database..."
$WP db reset --yes

# Install WordPress:
echo "Installing WordPress..."
$WP core install \
	--title="Example" \
	--admin_user="admin" \
	--admin_password="admin" \
	--admin_email="admin@example.com" \
	--skip-email \
	--require="wp-content/plugins/query-monitor/bin/mysqli_report.php"
echo "Home URL: $WP_URL"
$WP plugin activate query-monitor

# Run the acceptance tests:
echo "Running tests..."
TEST_SITE_WEBDRIVER_PORT=$CHROME_PORT \
	TEST_SITE_DATABASE_PORT=$DATABASE_PORT \
	TEST_SITE_WP_URL=$WP_URL \
	./vendor/bin/codecept run acceptance --steps "$1"

# Ciao:
docker-compose stop chrome
