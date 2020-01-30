#!/bin/bash

echo "running hive test..."

hive -f hivetest.sql

echo "running pyspark test..."

spark-submit --name "spark_test" --master yarn --deploy-mode client sparktest.py
