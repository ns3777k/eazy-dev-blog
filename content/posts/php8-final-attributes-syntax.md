+++
title = "Финальный синтаксис атрибутов в PHP8"
date = "2020-09-03T00:41:10+03:00"
tags = ["php", "backend"]
+++

Разработчики PHP изменили синтаксис будущий атрибутов.

Было:

```
@@Attribute(Attribute::TARGET_FUNCTION)
```

Стало как в Rust:

```
#[Attribute(Attribute::TARGET_FUNCTION)]
```

Имхо стало намного лучше. Предыдущий синтаксис явно выбивался из всех существующих и выглядел очень странно.

[Пул Реквест](https://github.com/php/php-src/commit/8b37c1e993f17345312a76a239b77ae137d3f8e8)