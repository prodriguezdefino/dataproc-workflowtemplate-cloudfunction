import pyspark

sc = pyspark.SparkContext()
rdd = sc.parallelize(['Hello,', 'world!', 'dog', 'elephant', 'panther'])
words = sorted(rdd.collect())
print(words)
