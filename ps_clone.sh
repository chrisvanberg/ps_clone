#!/bin/bash
while getopts d:s:p:u: option
do
case "${option}"
in
d) DEST=${OPTARG};;
s) SOURCE=${OPTARG};;
p) MAIN_FOLDER=${OPTARG};;
u) URL=${OPTARG};;
esac
done

SAN_DEST=${DEST//./}
SAN_SOURCE=${SOURCE//./}

echo "Version :" $DEST;
echo "Source :" $SOURCE;

if [ -d "$MAIN_FOLDER/versions/$DEST" ]
then
  echo "$MAIN_FOLDER/versions/$DEST  directory already exists!"
  exit -1
else
  echo "Activating the maintenance mode on production"
    mysql -u christophe -p -e 'UPDATE `ps_configuration` SET `value` = NULL WHERE `ps_configuration`.`id_configuration` = 28;' prestashop$SAN_SOURCE
    echo "... Done.";

  echo "Starting the copy of $SOURCE to $DEST";
    rsync -a $MAIN_FOLDER/versions/$SOURCE/ $MAIN_FOLDER/versions/$DEST/ --exclude /img --exclude /var/cache --exclude /var/logs --exclude /cache
    rsync -a --include '*/' --include 'index.php' --exclude '*' $MAIN_FOLDER/versions/$SOURCE/cache $MAIN_FOLDER/versions/$DEST/
    ln -sfn $MAIN_FOLDER/versions/$SOURCE/img $MAIN_FOLDER/versions/$DEST/img
    echo "... Done.";

  echo "Config Edit";
    sed -i "s/prestashop$SAN_SOURCE/prestashop$SAN_DEST/g" $MAIN_FOLDER/versions/$DEST/app/config/parameters.php
    echo "... Done";

  echo "Dumping the source database";
    mysqldump -u christophe -p --add-drop-database --routines  --databases prestashop$SAN_SOURCE > $MAIN_FOLDER/tools/ps_clone/prestashop-$SAN_SOURCE-$SAN_DEST.sql
    echo "... Done.";

  echo "Deactivating the maintenance mode on production"
    mysql -u christophe -p -e 'UPDATE `ps_configuration` SET `value` = '1' WHERE `ps_configuration`.`id_configuration` = 28;' prestashop$SAN_SOURCE
    echo "... Done.";

  echo "Changing the database name";
    sed -i "s/prestashop$SAN_SOURCE/prestashop$SAN_DEST/g" $MAIN_FOLDER/tools/ps_clone/prestashop-$SAN_SOURCE-$SAN_DEST.sql
    echo "... Done.";

  echo "Changing the prestashop url";
    sed -i "s/www.${URL}.com/staging.${URL}.com/g" $MAIN_FOLDER/tools/ps_clone/prestashop-$SAN_SOURCE-$SAN_DEST.sql
    echo "... Done";

  echo "Importing the new database";
    mysql -u christophe -p < $MAIN_FOLDER/tools/ps_clone/prestashop-$SAN_SOURCE-$SAN_DEST.sql
    echo "... Done.";

  echo "Granting the permissions to prestashop";
    mysql -u christophe -p -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, CREATE TEMPORARY TABLES, CREATE VIEW, SHOW VIEW  ON prestashop"$SAN_DEST".* TO 'prestashop'@'localhost';"
    echo "... Done.";

  echo "Changing the htaccess";
    sed -i "s/www.${URL}.com/staging.${URL}.com/g" $MAIN_FOLDER/versions/$DEST/.htaccess
    echo "... Done";

  echo "Updating the symlink";
    ln -sfn $MAIN_FOLDER/versions/$DEST $MAIN_FOLDER/staging
    echo "... Done";

  echo "Cleaning mysql dump";
      rm $MAIN_FOLDER/tools/ps_clone/prestashop-$SAN_SOURCE-$SAN_DEST.sql
      echo "... Done.";

  echo "Don't forget to reload apache to update the symlinks cache"
fi
