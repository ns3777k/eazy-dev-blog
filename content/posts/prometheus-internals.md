+++
title = "Внутреннее устройство Prometheus"
date = "2020-10-03T00:41:10+03:00"
tags = ["prometheus"]
+++

Ганеш Вернекар начал серию статей про внутреннее устройство **Prometheus**, которые объясняют файловую структуру базы,
как она устроена, зачем нужен **WAL**, что такое **head chunks** и т.д. с ссылками на исходники. Статей пока написано 4,
они достаточно короткие, но строго по делу.

- [Prometheus TSDB (Part 1): The Head Block](https://ganeshvernekar.com/blog/prometheus-tsdb-the-head-block/)
- [Prometheus TSDB (Part 2): WAL and Checkpoint](https://ganeshvernekar.com/blog/prometheus-tsdb-wal-and-checkpoint/)
- [Prometheus TSDB (Part 3): Memory Mapping of Head Chunks from Disk](https://ganeshvernekar.com/blog/prometheus-tsdb-mmapping-head-chunks-from-disk/)
- [Prometheus TSDB (Part 4): Persistent Block and its Index](https://ganeshvernekar.com/blog/prometheus-tsdb-persistent-block-and-its-index/)
