+++
title = "Проверка существования классов в PHP"
date = "2020-10-24T00:41:10+03:00"
tags = ["php", "backend"]
+++

Чуть *интересностей* из **php**, которые можно похейтить. Простой код:

```php
<?php

$class = FreakYou::class;

if ($argv[0] instanceof $class || $argv[0] instanceof FreakYouTwice) {
  echo 'instanceof freak';
}

try {
  throw new Exception('test');
} catch (FreakYouException $freak) {
  var_dump($freak);
} catch (...) ...
```

Ни класса `FreakYou` ни `FreakYouTwice` ни `FreakYouException` не существует, но **php** никогда не сообщит об этом 😁
Существование класса проверяется только при их использовании. Не так критично, потому что нормальные пацаны используют
нормальные **IDE**, но некомфортно.
