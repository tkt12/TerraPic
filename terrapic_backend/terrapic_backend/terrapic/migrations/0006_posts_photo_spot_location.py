# Generated by Django 4.2 on 2024-11-25 22:09

import django.contrib.gis.db.models.fields
from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('terrapic', '0005_remove_places_favolite_count_alter_favorites_place'),
    ]

    operations = [
        migrations.AddField(
            model_name='posts',
            name='photo_spot_location',
            field=django.contrib.gis.db.models.fields.PointField(blank=True, null=True, srid=4326),
        ),
    ]
