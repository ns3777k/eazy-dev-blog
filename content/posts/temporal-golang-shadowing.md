+++
title = "Затемнение переменной в golang"
date = "2021-04-04T21:13:15+03:00"
tags = ["backend", "golang"]
+++

Казалось бы, в интернете гора статей из рубрики *golang gotchas*, но это не мешает повторять одни и те же ошибки снова и
снова.

Разработчики проекта [Temporal](https://temporal.io/) рассказали с как столкнулись с *багом* из-за того, что затемнили
ошибку в условии. Даже не знаю, что может быть банальнее 🙂

*Затемнение переменной (variable shadowing)* можно продемонстрировать на примере:

```golang
package main

import (
    "fmt"
    "errors"
)

func test() (string, error){
    return "str", errors.New("error")
}

func main() {
    var err error
    
    defer func() {
        fmt.Println(err)
    }()
    
    if true {
        str, err := test()
        fmt.Println(str, err)
    }
}
```

Для нешарящих результат будет сюрпризом:

```text
str error
<nil>
```

Баг достаточно известный и возникает из-за того, что оператор `:=` ограничен только текущим скоупом и не выходит наружу.
IDE и линтер далеко не всегда могут указать на косяк. Удивительно, что разработчики из Temporal не знали об этом =\

[Ссылка на статью](https://docs.temporal.io/blog/go-shadowing-bad-choices/)