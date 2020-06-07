+++
title = "Атрибуты в PHP8"
date = "2020-06-07T23:54:57+03:00"
tags = ["php"]
+++

Еще 1 чуть запоздалая новость для тех, кто не следит за **php 8**. Несколько дней назад в мастер-ветку была влита новая
фича - [Атрибуты](https://wiki.php.net/rfc/attributes_v2). 

По сути, это замена неофициальных аннотаций, которые чаще всего парсились пакетом [doctrine/annotations](https://www.doctrine-project.org/projects/doctrine-annotations/en/1.10/index.html).
Многие не использовали аннотации, аргументируя это тем, что аннотации -  по сути комментарии и не могут быть кодом для
выполнения, а так же, функционал, который их использует, сложно распространять.

Пример из RFC:

```php
<?php

<<ExampleAttribute>>
class Foo
{
    <<ExampleAttribute>>
    public function foo(<<ExampleAttribute>> $bar)
    {
        // ...
    }
}
```

Синтаксис, конечно, на любителя 😊 Но уже есть [RFC](https://wiki.php.net/rfc/shorter_attribute_syntax) на введение
альтернативы. Причины такого синтаксиса и чем не угодили аннотации можно прочитать в RFC. Прочитать такие атрибуты
станет возможно через стандартную рефлексию:

```php
<?php

$reflectionClass = new \ReflectionClass(Foo::class);
$attributes = $reflectionClass->getAttributes();
```

Чтобы мигрировать свой проект в будущем с аннотаций до атрибутов, можно будет воспользоваться [ректором](https://getrector.org/).

Ждем новый PHP в начале декабря!