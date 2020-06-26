+++
title = "Релиз Hoverfly 1.3"
date = "2020-06-27T00:41:10+03:00"
tags = ["backend", "frontend", "sv"]
+++

Вышла новая версия [hoverfly](http://hoverfly.io/) с 2мя моими большими фичами:

1. [Добавление задержки индивидуально для любого ответа](https://docs.hoverfly.io/en/latest/pages/tutorials/basic/delays/specificresponses/specificresponses.html) 
2. [Возможность отдавать тело ответа из файла](https://docs.hoverfly.io/en/latest/pages/keyconcepts/simulations/pairs.html?highlight=bodyFile#serving-response-bodies-from-files)

**Hoverfly** используется для *сервисной виртуализации*, грубо говоря, для эмуляции сторонних сервисов. Он может
использоваться напрямую в интеграционных тестах (интеграция с **Java** особенно хороша) или просто эмулировать бэкенд
при разработке фронтовой части.

Скачать можно [тут](https://github.com/SpectoLabs/hoverfly/releases/tag/v1.3.0).