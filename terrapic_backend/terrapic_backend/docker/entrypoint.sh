#!/bin/sh

if [ "$DATABASE" = "postgres" ]
then
    echo "Waiting for postgres..."

    while ! nc -z $SQL_HOST $SQL_PORT; do
      sleep 0.1
    done

    echo "PostgreSQL started"
fi

# manage.pyが存在するかどうかを確認
if [ -f "manage.py" ]; then
    # マイグレーションと静的ファイルの収集
    python manage.py migrate
    python manage.py collectstatic --no-input --clear
fi

exec "$@"
