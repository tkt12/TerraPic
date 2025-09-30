#!/bin/sh

# データベースの起動を待つ
echo "Waiting for postgres..."

while ! nc -z $DB_HOST $DB_PORT; do
  sleep 0.1
done

echo "PostgreSQL started"

# マイグレーションを実行
echo "Running migrations..."
python manage.py migrate --noinput

# 静的ファイルを収集
echo "Collecting static files..."
python manage.py collectstatic --noinput --clear

# 渡されたコマンドを実行
exec "$@"