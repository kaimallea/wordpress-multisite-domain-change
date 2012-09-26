#!/bin/bash

read -p "Enter database name: " DB_NAME
if [[ -z $DB_NAME ]]; then
    echo "Database name required"
    exit 1
fi    

read -p "Enter current domain (to be replaced): " CURRENT_DOMAIN
if [[ -z $CURRENT_DOMAIN ]]; then
    echo "Current domain name required"
    exit 1
fi

read -p "Enter new domain: " NEW_DOMAIN
if [[ -z $NEW_DOMAIN ]]; then
    echo "New domain name required"
    exit 1
fi

echo "Finding wp_options tables in $DB_NAME..."
OPTIONS_TABLES=( $(mysql -u root -p -e "SELECT TABLE_NAME from information_schema.tables WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME LIKE 'wp%options';" | grep -Po 'wp_(\d+_)?options') )
echo "Found ${#OPTIONS_TABLES[@]} wp_options tables"

echo "Finding wp_posts tables in $DB_NAME..."
POSTS_TABLES=( $(mysql -u root -p -e "SELECT TABLE_NAME from information_schema.tables WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME LIKE 'wp%posts';" | grep -Po 'wp_(\d+_)?posts') )
echo "Found ${#POSTS_TABLES[@]} wp_posts tables"

OUTPUT_FILE=$PWD/wp_updates.sql

echo "Generating SQL updates into $OUTPUT_FILE..."

# Update "home" and "siteurl" fields
for table in "${OPTIONS_TABLES[@]}"
do
    echo "UPDATE $table SET option_value = replace(option_value, '$CURRENT_DOMAIN', '$NEW_DOMAIN') WHERE option_name = 'home' OR option_name='siteurl';" >> $OUTPUT_FILE
done

# Fix URLs for posts and pages, which are absolute URLs stored in the 'guid' field
for table in "${POSTS_TABLES[@]}"
do
    echo "UPDATE $table SET guid = replace(guid, '$CURRENT_DOMAIN', '$NEW_DOMAIN');" >> $OUTPUT_FILE
done

# Fix posts and pages that link internally using absolute URLs
for table in "${POSTS_TABLES[@]}"
do
    echo "UPDATE $table SET post_content = replace(post_content, '$CURRENT_DOMAIN', '$NEW_DOMAIN');" >> $OUTPUT_FILE
done

echo "UPDATE wp_blogs SET domain='$NEW_DOMAIN' WHERE domain='$CURRENT_DOMAIN';" >> $OUTPUT_FILE
echo "UPDATE wp_site SET domain='$NEW_DOMAIN' WHERE domain='$CURRENT_DOMAIN';" >> $OUTPUT_FILE
echo "UPDATE wp_sitemeta SET meta_value = replace(meta_value, '$CURRENT_DOMAIN', '$NEW_DOMAIN') WHERE meta_key='siteurl';" >> $OUTPUT_FILE
echo "UPDATE wp_usermeta SET meta_value='$NEW_DOMAIN' WHERE meta_key='source_domain';" >> $OUTPUT_FILE

echo "Done."
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. Backup your database (i.e., mysqldump --opt $DB_NAME -u root -p > /tmp/$DB_NAME-backup.sql)"
echo "2. Import the generated SQL updates (i.e., mysql -u root -p $DB_NAME < $OUTPUT_FILE)"
echo "3. Modify wp-config.php to reflect the new domain (i.e., define('DOMAIN_CURRENT_SITE', '$NEW_DOMAIN');)"
echo "4. Ensure your web server(s) is/are configured to handle $NEW_DOMAIN"
echo ""
