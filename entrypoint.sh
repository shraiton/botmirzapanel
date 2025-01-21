#!/bin/bash

set -e

# Optional: Enable debugging for troubleshooting
set -x

touch /var/log/php_errors.log
chown www-data:www-data /var/log/php_errors.log
chmod 664 /var/log/php_errors.log

# Function to initialize the database
init_database() {
    echo "Initializing database..."

    # Wait for MySQL to be ready
    until mysqladmin ping -h"$MYSQL_HOST" -u"root" -p"$MYSQL_ROOT_PASSWORD" --silent; do
        echo "Waiting for MySQL to be ready..."
        sleep 2
    done

    # Execute SQL commands as root to create database and user
    mysql -h"$MYSQL_HOST" -u"root" -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';
FLUSH PRIVILEGES;
EOF

    echo "Database initialization complete."
}

# Initialize the database
init_database

# Generate config.php using environment variables
CONFIG_FILE=/var/www/html/mirzabotconfig/config.php

cat <<EOL > $CONFIG_FILE
<?php
/*
channel => @mirzapanel
*/
// ----------------------------- Database Configuration -------------------------------
\$dbname = getenv('MYSQL_DATABASE');       // Database name
\$usernamedb = getenv('MYSQL_USER');       // Database username
\$passworddb = getenv('MYSQL_PASSWORD');   // Database password
\$dbhost = getenv('MYSQL_HOST');           // Database host (service name)

if (!\$dbname || !\$usernamedb || !\$passworddb || !\$dbhost) {
    die("Database configuration is incomplete. Please check environment variables.");
}

\$connect = mysqli_connect("\$dbhost", "\$usernamedb", "\$passworddb", "\$dbname");
if (\$connect->connect_error) {
    die("The connection to the database failed: " . \$connect->connect_error);
}
mysqli_set_charset(\$connect, "utf8mb4");
// ----------------------------- Info -------------------------------

\$APIKEY = getenv('YOUR_BOT_TOKEN');            // Your bot token
\$adminnumber = getenv('YOUR_CHAT_ID');          // Admin chat ID
\$domainhosts = getenv('BOT_DOMAIN_PATH'); // Webhook URL
\$usernamebot = getenv('YOUR_BOTNAME');          // Bot username (without @)
\$secrettoken = "";

\$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];
\$dsn = "mysql:host=\$dbhost;dbname=\$dbname;charset=utf8mb4";
try {
     \$pdo = new PDO(\$dsn, \$usernamedb, \$passworddb, \$options);
} catch (\PDOException \$e) {
     throw new \PDOException(\$e->getMessage(), (int)\$e->getCode());
}
?>
EOL

# Set appropriate permissions
chown www-data:www-data $CONFIG_FILE
chmod 644 $CONFIG_FILE

# Replace placeholder in Apache SSL config using alternative delimiter to avoid conflicts
APACHE_SSL_CONF=/etc/apache2/sites-available/default-ssl.conf
sed -i "s#\${YOUR_DOMAIN}#${YOUR_DOMAIN}#g" $APACHE_SSL_CONF

# Enable the SSL site and necessary Apache modules
a2ensite default-ssl
a2enmod ssl headers

# Function to set the Telegram webhook
set_webhook() {
    local attempts=0
    local max_attempts=5
    local sleep_time=10

    WEBHOOK_URL="${TELEGRAM_WEBHOOK_URL}"
    TELEGRAM_API_URL="https://api.telegram.org/bot${YOUR_BOT_TOKEN}/setWebhook"

    while [ $attempts -lt $max_attempts ]; do
        echo "Setting Telegram webhook (Attempt $((attempts + 1)) of $max_attempts)..."
        RESPONSE=$(curl -s -w "\n%{http_code}" -F "url=${WEBHOOK_URL}" "${TELEGRAM_API_URL}")
        HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
        BODY=$(echo "$RESPONSE" | head -n -1)

        if [ "$HTTP_STATUS" -eq 200 ]; then
            echo "Webhook set successfully."
            break
        else
            echo "Failed to set webhook. HTTP status: $HTTP_STATUS. Response: $BODY"
            echo "Retrying in $sleep_time seconds..."
            sleep $sleep_time
            attempts=$((attempts + 1))
        fi
    done

    if [ $attempts -ge $max_attempts ]; then
        echo "Failed to set webhook after $max_attempts attempts."
        # Check if apache2 is running before attempting to kill
        if pidof apache2 > /dev/null; then
            kill $(pidof apache2)
        fi
        exit 1
    fi
}

# Set the Telegram webhook
set_webhook

# Start Apache in the foreground
#exec apache2-foreground



(
    # Wait for Apache to start
    echo "Waiting for Apache to start..."
    while ! nc -z localhost 80; do
        sleep 1
    done
    echo "Apache is up and running."

    # Ensure Apache is fully up before running the curl command
    sleep 5

    # Now, after Apache is up, call the URL
    echo "Running the curl command to initialize the bot..."
    url="http://127.0.0.1:80/mirzabotconfig/table.php"
    curl $url || {
        echo "Error: Failed to fetch URL from domain."
        exit 1
    }
    echo "Initialization completed."
) &

#echo "ENTRYPOINT" > /root/testtouch
apachectl -D FOREGROUND
