+++
title = "Проверка интерфейса на nil в Golang"
date = "2020-06-18T02:50:50+03:00"
tags = ["golang", "backend"]
+++

Расскажу об интересном кейсе, с которым я столкнулся засылая коммиты в [hoverfly](https://hoverfly.io/). Сначала
посмотрим на магию на таком примере:

```go
func getError() error {
	var err *reflect.ValueError = nil
	return err
}

func main() {
	err := getError()

	println("Type of error is", reflect.TypeOf(err).String()) // *reflect.ValueError
	println("Is value nil?", reflect.ValueOf(err).IsNil()) // true
	println("err equals nil?", err == nil) // false
}
```

Это одна из распространенных уловок в go - `nil` не всегда равен `nil` :-)

Тип `*reflect.ValueError` взят для удобства из пакета `reflect`, потому ниже этот пакет тоже используется. На месте этой
ошибки, может быть любая другая, которая реализует интерфейс `error`. Тут стоит обратить внимание, что `error` - это
интерфейс и магия происходит именно из-за того, что мы возвращаем конкретный тип, *обернутый* в интерфейс.

Интерфейс в **golang** представлен структурой [iface](https://github.com/golang/go/blob/go1.14.4/src/runtime/runtime2.go#L200),
которая хранит 2 указателя:

1. указатель на так называемый `interface table` или `itab` - это по сути это структура, которая хранит информацию о
фактическом типе данных за интерфейсом (в нашем случае - `*reflect.ValueError`)
2. указатель на, собственно, данные стракта :-)

Важно усвоить 1 простое правило: Интерфейс будет равен `nil` только в том случае, когда у него отсутствует **и**
значение **и** тип. В нашем примере, значение действительно отсутствует, но тип присваивается конкретному
`*reflect.ValueError`.

Вот [реальный кейс в hoverfly](https://github.com/SpectoLabs/hoverfly/blob/master/core/handlers/v2/simulation_views_v5.go#L90).
Метод `GetLogNormalDelay` специально не возвращает просто `this.LogNormalDelay`, потому что тип будет обернут в
интерфейс и его нельзя будет просто сравнить с `nil`.

Оставляю ссылку на [официальную документацию](https://golang.org/doc/faq#nil_error), более подробный [технический доклад
про внутрянку интерфейсов](https://research.swtch.com/interfaces), [техническое исследование nil](https://go101.org/article/nil.html) и
[более наглядную мини статью на хабре](https://habr.com/ru/post/325468/#interfeysy).

Не будьте мной - я потратил достаточно много времени, когда впервые столкнулся с этим, чтобы понять, что происходит :-)
